#include <amxmodx>
#include <amxmisc>

#pragma semicolon 1

#define VERSION "1.2.0"
#define PAGE_SIZE 5
#define MAX_ENTRIES 112
#define RULE_LIMIT 64
#define RULE_LINE_LIMIT 256
#define MENU_NAME "UltraHC_Pika_RU"
#define MOTD_BYTES 1450

enum { ACTION_INFO, ACTION_RUN, ACTION_VOTE, ACTION_SET_DAMAGE, ACTION_REMOVE_DAMAGE };
enum { GROUP_ROOT, GROUP_VOTES, GROUP_STATS, GROUP_ADMIN, GROUP_DAMAGE, GROUP_LETTERS, GROUP_ADS, GROUP_BOTS, GROUP_VOICE, GROUP_COUNT };

enum _:HelpEntry {
    Section,
    Title[96],
    Description[384],
    Command[64],
    Owner[64],
    ExtraFlags,
    Action,
    Group
};

new g_Entries[MAX_ENTRIES][HelpEntry], g_Count;
new g_Section[33], g_Page[33][GROUP_COUNT], g_Visible[33][PAGE_SIZE];
new g_TargetMenu[33], g_TargetUserId[33], g_TargetEntry[33];
new Float:g_NextOpen[33];
new const g_Sections[][] = {"Пикабу", "Голосования", "Статистика CS", "Администратору", "Урон игрока", "Надписи", "Реклама", "Боты", "Личный звук"};
new const MOTD_HEAD[] = "<html><head><meta http-equiv=Content-Type content=^"text/html;charset=utf-8^"><style>body{background:#15232b;color:#deebef;font:14px Arial;margin:16px}a{color:#8dd8c4}h2{color:#ffc878;font-size:16px;border-bottom:1px solid #38515b}p{line-height:1.4}</style></head><body><a name=t></a><b>ПИКАБУ</b> / справка<br>";
new const MOTD_BOTS[] = "<h2><a name=b></a>Боты</h2><p><b>!bots</b> — меню ботов. Добавление и сложность: если вы единственный человек на сервере и играете за T/CT.</p>";
new const MOTD_VOTES[] = "<h2><a name=v></a>Голосования</h2>";
new const MOTD_MAP[] = "<b>/rtv</b> — за досрочную смену карты.<br>";
new const MOTD_MODE[] = "<b>/mode</b> — за открытие/закрытие проходов.<br>";
new const MOTD_DAMAGE[] = "За урон игроку: <b>!pika</b> &gt; Голосования. Нужна регистрация в Discord.<br>";
new const MOTD_PERSONAL[] = "<h2><a name=p></a>Личное</h2>";
new const MOTD_STATS[] = "<b>/stats</b> — статистика CS.<br>";
new const MOTD_MUTE[] = "<b>/mute</b> — отключить голос только для себя.<br>";
new const MOTD_ADMIN[] = "<h2><a name=a></a>Администратору</h2><b>!pika</b> &gt; Администратору: действия по вашим правам.";
new const MOTD_END[] = "<p><a href=https://discord.com/invite/r3kCQNxX5Z>Наш Discord</a> &middot; <a href=#t>Наверх</a></p></body></html>";
new const MOTD_NAV_ADMIN[] = " <a href=#a>Админу</a>";

public plugin_init() {
    register_plugin("UltraHC: Pika menu and help", VERSION, "UltraHC / Codex");
    // Do not inherit a cmdaccess.ini override for the general say handler.
    register_clcmd("say", "OnSay", ADMIN_ALL, "", 0);
    register_clcmd("say_team", "OnSay", ADMIN_ALL, "", 0);
    register_clcmd("ultrahc_help", "OpenHelp", ADMIN_ALL, "Russian server help", 0);
    register_clcmd("pika", "OpenPika", ADMIN_ALL, "Available server actions", 0);
    register_menucmd(register_menuid(MENU_NAME), 1023, "OnMenu");
    LoadFeatures();
    ConfigureActions();
    arrayset(g_TargetMenu, -1, sizeof g_TargetMenu);
}

public plugin_cfg() {
    LoadRules();
}

public client_putinserver(id) {
    g_Section[id] = 0;
    g_TargetMenu[id] = -1;
    g_TargetUserId[id] = 0;
    g_TargetEntry[id] = -1;
    g_NextOpen[id] = 0.0;
    for (new i; i < GROUP_COUNT; i++) g_Page[id][i] = 0;
}

public OnSay(id) {
    new text[192], cmd[24], argument[160];
    if (read_args(text, charsmax(text)) >= charsmax(text)) return PLUGIN_CONTINUE;
    remove_quotes(text);
    trim(text);
    strtok(text, cmd, charsmax(cmd), argument, charsmax(argument), ' ', 1);
    // Exact command tokens only: ordinary chat/Discord messages pass unchanged.
    if (equali(cmd, "!pika") || equali(cmd, "/pika")) {
        OpenPika(id);
        return PLUGIN_HANDLED;
    }
    if (!equali(cmd, "!help") && !equali(cmd, "/help")) return PLUGIN_CONTINUE;
    if (!CanOpen(id)) return PLUGIN_HANDLED;
    ShowHelp(id);
    return PLUGIN_HANDLED;
}

bool:CanOpen(id) {
    if (id < 1 || id > MaxClients || !is_user_connected(id) || is_user_bot(id) || is_user_hltv(id)) return false;
    new Float:now = get_gametime();
    if (now < g_NextOpen[id]) return false;
    g_NextOpen[id] = now + 0.35;
    CloseTargetMenu(id);
    return true;
}

public OpenPika(id) {
    if (!CanOpen(id)) return PLUGIN_HANDLED;
    g_Section[id] = 0;
    ShowRoot(id);
    return PLUGIN_HANDLED;
}

public OpenHelp(id) {
    if (!CanOpen(id)) return PLUGIN_HANDLED;
    ShowHelp(id);
    return PLUGIN_HANDLED;
}

Add(section, const title[], const description[], const command[] = "", const owner[] = "", extra = 0) {
    if (g_Count >= MAX_ENTRIES) return;
    g_Entries[g_Count][Section] = section;
    copy(g_Entries[g_Count][Title], charsmax(g_Entries[][Title]), title);
    copy(g_Entries[g_Count][Description], charsmax(g_Entries[][Description]), description);
    copy(g_Entries[g_Count][Command], charsmax(g_Entries[][Command]), command);
    copy(g_Entries[g_Count][Owner], charsmax(g_Entries[][Owner]), owner);
    g_Entries[g_Count][ExtraFlags] = extra;
    g_Count++;
}

LoadFeatures() {
    Add(1, "Боты: меню и сложность", "В чате: !bots или /bots^nВ консоли: botmenu^nМеню доступно игрокам.^nДля добавления и сложности выберите T/CT^nи оставайтесь единственным игроком.", "botmenu", "botcontrol.amxx");
    Add(1, "Статистика: меню", "В чате: /stats^nОткрывает меню статистики.", "say /stats", "statsx_rbs.amxx");
    Add(1, "Ваш ранг", "В чате: /rank^nПоказывает ранг игрока.", "say /rank", "statsx_rbs.amxx");
    Add(1, "Общая статистика", "В чате: /rankstats^nПоказывает общую статистику.", "say /rankstats", "statsx_rbs.amxx");
    Add(1, "Статистика за карту", "В чате: /statsme^nВаша статистика за текущую карту.", "say /statsme", "statsx_rbs.amxx");
    Add(1, "Лучшие игроки", "В чате: /top15^nТаблица лучших игроков.", "say /top15", "statsx_rbs.amxx");
    Add(1, "Лучшие из играющих сейчас", "В чате: /hot^nРейтинг игроков, которые сейчас на сервере.", "say /hot", "statsx_rbs.amxx");
    Add(1, "Здоровье убийцы", "В чате: /hp^nПоказывает здоровье вашего убийцы.", "say /hp", "statsx_rbs.amxx");
    Add(1, "Нанесённый урон", "В чате: /me^nПоказывает нанесённый вами урон.", "say /me", "statsx_rbs.amxx");
    Add(1, "Сообщения статистики", "В чате: /switch^nВключает или выключает сообщения статистики.", "say /switch", "statsx_rbs.amxx");
    Add(1, "За досрочную смену карты (RTV)", "/rtv — ваш голос за досрочное^nголосование по выбору карты.", "say /rtv");
    Add(1, "За открытие / закрытие проходов", "/mode — голосование за открытие^nили закрытие второй половины карты.", "say /mode", "mode.amxx");
    Add(1, "Отключить голос игрока", "В чате: /mute^nОткрывает выбор игрока.^nОтключает его голос только для вас.^nЭто не голосование и не блокировка чата.", "say /mute", "CA_Mute.amxx");
    Add(1, "Discord сервера", "Адрес сообщества из объявлений сервера:^ndiscord.com/invite/r3kCQNxX5Z");
    Add(1, "Встречи сообщества", "Собираемся по пятницам^nв 20:30 по московскому времени.^nИнформация из надписей на de_dust2.");
    Add(1, "За ограничение урона игроку", "Выберите игрока для голосования.^nЗапуск и участие — после регистрации^nSteam ID в базе Discord.^n15 секунд; исходящий урон 0/25/50/75/100%.", "uhc_blockdmg_vote", "uhltrahc_block_damage_2.amxx");
    Add(3, "Урон: задать долю", "В консоли:^nuhc_blockdmg_set <имя или #userid> <доля>^n0 — блок; 1 — без ограничения админа.^nДоля умножается на результат голосования.", "uhc_blockdmg_set", "uhltrahc_block_damage_2.amxx");
    Add(3, "Урон: снять ограничение", "В консоли:^nuhc_blockdmg_rem <имя или #userid>^nСнимает только ограничение администратора.^nРезультат голосования остаётся в силе.", "uhc_blockdmg_rem", "uhltrahc_block_damage_2.amxx");
    Add(3, "Урон: меню", "В консоли: uhc_blockdmg_menu^nОткрывает выбор игрока и доли урона.", "uhc_blockdmg_menu");
    Add(3, "Надписи: главное меню", "В консоли: slmainmenu^nГлавное меню редактора надписей.^nВыберите надпись командой slselect.^nПосле окончательной настройки: slsave.", "slmainmenu", "SprLett-Editor.amxx", ADMIN_RCON);
    Add(3, "Надписи: создать", "В консоли: slcreate ^"Текст^"^nТекст обязателен; пробелы — в кавычках.^nРедактор: slmainmenu.^nПосле окончательной настройки: slsave.", "slcreate", "SprLett-Editor.amxx", ADMIN_RCON);
    Add(3, "Надписи: выбрать", "В консоли: slselect^nВыбор надписи для редактирования.", "slselect", "SprLett-Editor.amxx", ADMIN_RCON);
    Add(3, "Надписи: режим редактора", "В консоли: sleditmode^nПереключает режим редактирования надписей.", "sleditmode", "SprLett-Editor.amxx", ADMIN_RCON);
    Add(3, "Надписи: сохранить", "В консоли: slsave^nСохраняет выбранную надпись.^nВыполните после окончательной настройки.^nДождитесь сообщения об успешном сохранении.", "slsave", "SprLett-Editor.amxx", ADMIN_RCON);
    Add(3, "Реклама: размещение", "Привязка в консоли: bind p +place_ad^nУдерживайте P для размещения рекламы.^nОтпустите P для следующего шага.", "+place_ad", "in_game_ads.amxx", ADMIN_RCON);
    Add(3, "Реклама: удаление", "В консоли: delete_ad^nОткрывает удаление размещённой рекламы.^nПроверьте выбранный объект в меню.", "delete_ad", "in_game_ads.amxx", ADMIN_RCON);
    Add(3, "Реклама: ближе", "В консоли: iga_closer^nПеремещает редактируемую рекламу ближе.", "iga_closer", "in_game_ads.amxx", ADMIN_RCON);
    Add(3, "Реклама: дальше", "В консоли: iga_farther^nПеремещает редактируемую рекламу дальше.", "iga_farther", "in_game_ads.amxx", ADMIN_RCON);
    Add(3, "Реклама: увеличить", "В консоли: iga_scale_up^nУвеличивает размер редактируемого спрайта.", "iga_scale_up", "in_game_ads.amxx", ADMIN_RCON);
    Add(3, "Реклама: уменьшить", "В консоли: iga_scale_down^nУменьшает размер редактируемого спрайта.", "iga_scale_down", "in_game_ads.amxx", ADMIN_RCON);
}

// Optional UTF-8 text, one short rule per physical line. Never execute this file.
LoadRules() {
    new path[256], line[512], title[64], count;
    get_configsdir(path, charsmax(path));
    add(path, charsmax(path), "/ultrahc_help_rules.txt");
    new file = fopen(path, "rt");
    if (file) {
        new physicalLine;
        for (physicalLine = 0; physicalLine < RULE_LINE_LIMIT && count < RULE_LIMIT; physicalLine++) {
            line[0] = EOS;
            new bytesRead = fgets(file, line, charsmax(line));
            if (!bytesRead) break;
            if (bytesRead >= charsmax(line)) {
                log_amx("Rules physical line too long; rules file rejected.");
                while (g_Count && g_Entries[g_Count - 1][Section] == 2) g_Count--;
                count = 0;
                break;
            }
            if (line[0] == 0xEF && line[1] == 0xBB && line[2] == 0xBF) copy(line, charsmax(line), line[3]);
            trim(line);
            if (!line[0] || line[0] == ';' || line[0] == '#') continue;
            // Reject long rules, including truncated physical lines; never publish partial rules.
            if (strlen(line) > 320) {
                log_amx("Rules line too long (maximum 320 UTF-8 bytes); rules file rejected.");
                while (g_Count && g_Entries[g_Count - 1][Section] == 2) g_Count--;
                count = 0;
                break;
            }
            // Remove old-menu formatting/control characters from configured prose.
            for (new i; line[i]; i++) if (line[i] == '\' || (line[i] > 0 && line[i] < 32)) line[i] = ' ';
            formatex(title, charsmax(title), "Правило %d", count + 1);
            Add(2, title, line);
            count++;
        }
        if (physicalLine == RULE_LINE_LIMIT) log_amx("Rules read capped at %d physical lines.", RULE_LINE_LIMIT);
        fclose(file);
    }
}

bool:PluginRunning(plugin) {
    if (plugin < 0) return false;
    new status[24];
    get_plugin(plugin, .status = status, .len5 = charsmax(status));
    return equal(status, "running") != 0 || equal(status, "debug") != 0;
}

bool:AllowedFlags(id, flags) {
    // Mirror AMXX cmd_access: any bit from the command's access mask suffices.
    if (flags == ADMIN_ALL) return true;
    if (flags == ADMIN_ADMIN) return is_user_admin(id) != 0;
    return (get_user_flags(id) & flags) != 0;
}

bool:Available(id, entry) {
    if (entry < 0 || entry >= g_Count) return false;
    if (!AllowedFlags(id, g_Entries[entry][ExtraFlags])) return false;
    new owner = -1;
    if (g_Entries[entry][Owner][0]) {
        owner = find_plugin_byfile(g_Entries[entry][Owner]);
        if (!PluginRunning(owner)) return false;
        // The old live BotControl 1.1 has no menu. Require the new menu handler.
        if (equal(g_Entries[entry][Owner], "botcontrol.amxx") && get_func_id("show_bot_menu", owner) < 0) return false;
        if (equal(g_Entries[entry][Command], "uhc_blockdmg_vote") && get_func_id("CmdVoteStart", owner) < 0) return false;
    }
    if (!g_Entries[entry][Command][0]) return true;
    new command[64], info[2], flags, bool:registered;
    new count = get_concmdsnum(-1, 1);
    for (new i; i < count; i++) {
        if (!get_concmd(i, command, charsmax(command), flags, info, charsmax(info), -1, 1)) continue;
        if (!equal(command, g_Entries[entry][Command])) continue;
        new plugin = get_concmd_plid(i, -1, 1);
        if (!PluginRunning(plugin) || (owner >= 0 && plugin != owner)) continue;
        registered = true;
        if (!AllowedFlags(id, flags)) continue;
        // Administrative topics require the command's actual privileged mask,
        // or a separately verified internal check (SpriteLetters EDIT_ACCESS).
        if (g_Entries[entry][Section] == 3 && !flags && !g_Entries[entry][ExtraFlags]) continue;
        return true;
    }
    if (registered) return false;
    // AMXX omits commands registered with default flags=-1 from enumeration.
    // Public fallback is limited to commands published in server advertisements
    // with a known active provider. Editor fallback has a verified internal gate.
    if (owner >= 0 && g_Entries[entry][Section] == 1) return true;
    return owner >= 0 && equal(g_Entries[entry][Owner], "SprLett-Editor.amxx") != 0;
}

ConfigureActions() {
    // Only source-defined, argument-free commands may run directly. Never execute
    // descriptions/rules or dispatch as server console; original plugin gates remain.
    new const direct[][] = {"botmenu", "say /stats", "say /rank", "say /rankstats",
        "say /statsme", "say /top15", "say /hot", "say /hp", "say /me",
        "say /switch", "say /rtv", "say /mode", "say /mute", "uhc_blockdmg_menu",
        "slmainmenu", "slselect", "sleditmode", "slsave", "delete_ad", "iga_closer",
        "iga_farther", "iga_scale_up", "iga_scale_down"};
    for (new entry; entry < g_Count; entry++) {
        for (new i; i < sizeof direct; i++) {
            if (equal(g_Entries[entry][Command], direct[i])) g_Entries[entry][Action] = ACTION_RUN;
        }
        if (equal(g_Entries[entry][Command], "uhc_blockdmg_vote")) g_Entries[entry][Action] = ACTION_VOTE;
        if (equal(g_Entries[entry][Command], "uhc_blockdmg_set")) g_Entries[entry][Action] = ACTION_SET_DAMAGE;
        if (equal(g_Entries[entry][Command], "uhc_blockdmg_rem")) g_Entries[entry][Action] = ACTION_REMOVE_DAMAGE;
        if (equal(g_Entries[entry][Owner], "statsx_rbs.amxx")) g_Entries[entry][Group] = GROUP_STATS;
        if (equal(g_Entries[entry][Owner], "botcontrol.amxx")) g_Entries[entry][Group] = GROUP_BOTS;
        if (equal(g_Entries[entry][Owner], "CA_Mute.amxx")) g_Entries[entry][Group] = GROUP_VOICE;
        if (equal(g_Entries[entry][Command], "say /rtv") || equal(g_Entries[entry][Command], "say /mode")
            || g_Entries[entry][Action] == ACTION_VOTE) g_Entries[entry][Group] = GROUP_VOTES;
        if (g_Entries[entry][Section] == 3) {
            g_Entries[entry][Group] = GROUP_DAMAGE;
            if (equal(g_Entries[entry][Owner], "SprLett-Editor.amxx")) g_Entries[entry][Group] = GROUP_LETTERS;
            if (equal(g_Entries[entry][Owner], "in_game_ads.amxx")) g_Entries[entry][Group] = GROUP_ADS;
        }
    }
}

bool:HasAdminActions(id) {
    for (new i; i < g_Count; i++) {
        if (g_Entries[i][Section] == 3 && g_Entries[i][Action] != ACTION_INFO && Available(id, i)) return true;
    }
    return false;
}

ShowRoot(id) {
    g_Section[id] = GROUP_ROOT;
    new menu[512], keys = MENU_KEY_5 | MENU_KEY_0;
    new len = formatex(menu, charsmax(menu), "\yПИКАБУ \d/ \wМеню сервера^n^n");
    if (HasGroup(id, GROUP_BOTS)) { len += formatex(menu[len], charsmax(menu) - len, "\r1. \wБоты: добавить / настроить^n"); keys |= MENU_KEY_1; }
    if (HasGroup(id, GROUP_VOTES)) { len += formatex(menu[len], charsmax(menu) - len, "\r2. \wГолосования^n"); keys |= MENU_KEY_2; }
    if (HasGroup(id, GROUP_STATS)) { len += formatex(menu[len], charsmax(menu) - len, "\r3. \wСтатистика CS^n"); keys |= MENU_KEY_3; }
    if (HasGroup(id, GROUP_VOICE)) { len += formatex(menu[len], charsmax(menu) - len, "\r4. \wОтключить голос для себя^n"); keys |= MENU_KEY_4; }
    len += formatex(menu[len], charsmax(menu) - len, "^n\r5. \wПомощь^n");
    if (HasAdminActions(id)) {
        len += formatex(menu[len], charsmax(menu) - len, "\r6. \yАдминистратору^n");
        keys |= MENU_KEY_6;
    }
    formatex(menu[len], charsmax(menu) - len, "^n\r0. \wВыход");
    show_menu(id, keys, menu, -1, MENU_NAME);
}

bool:HasGroup(id, group) {
    for (new i; i < g_Count; i++) {
        if (g_Entries[i][Group] == group && g_Entries[i][Action] != ACTION_INFO && Available(id, i)) return true;
    }
    return false;
}

RunGroup(id, group) {
    for (new i; i < g_Count; i++) {
        if (g_Entries[i][Group] == group && g_Entries[i][Action] != ACTION_INFO && Available(id, i)) { RunAction(id, i); return; }
    }
    ShowRoot(id);
}

ShowAdmin(id) {
    if (!HasAdminActions(id)) { ShowRoot(id); return; }
    g_Section[id] = GROUP_ADMIN;
    new menu[512], keys = MENU_KEY_9 | MENU_KEY_0;
    new len = formatex(menu, charsmax(menu), "\yПИКАБУ \d/ \wАдминистратору^n^n");
    for (new group = GROUP_DAMAGE; group <= GROUP_ADS; group++) {
        if (!HasGroup(id, group)) continue;
        new key = group - GROUP_DAMAGE;
        len += formatex(menu[len], charsmax(menu) - len, "\r%d. \w%s^n", key + 1, g_Sections[group]);
        keys |= 1 << key;
    }
    formatex(menu[len], charsmax(menu) - len, "^n\r9. \wВ меню^n\r0. \wВыход");
    show_menu(id, keys, menu, -1, MENU_NAME);
}

ShowList(id) {
    new entries[MAX_ENTRIES], count, section = g_Section[id];
    if (section == GROUP_ADMIN) { ShowAdmin(id); return; }
    if (section <= GROUP_ROOT || section >= GROUP_BOTS) { ShowRoot(id); return; }
    for (new i; i < g_Count; i++) {
        if (g_Entries[i][Group] == section && g_Entries[i][Action] != ACTION_INFO && Available(id, i)) entries[count++] = i;
    }
    new pages = max(1, (count + PAGE_SIZE - 1) / PAGE_SIZE);
    g_Page[id][section] = clamp(g_Page[id][section], 0, pages - 1);
    new page = g_Page[id][section], menu[512];
    new len = formatex(menu, charsmax(menu), "\yПИКАБУ \d/ \w%s \d[%d/%d]^n^n", g_Sections[section], page + 1, pages);
    new keys = MENU_KEY_9 | MENU_KEY_0;
    for (new i; i < PAGE_SIZE; i++) {
        new index = page * PAGE_SIZE + i;
        g_Visible[id][i] = index < count ? entries[index] : -1;
        if (index >= count) continue;
        len += formatex(menu[len], charsmax(menu) - len, "\r%d. \w%s^n", i + 1, g_Entries[entries[index]][Title]);
        keys |= (1 << i);
    }
    if (!count) len += formatex(menu[len], charsmax(menu) - len, "Доступных пунктов сейчас нет.^n");
    if (page > 0) {
        len += formatex(menu[len], charsmax(menu) - len, "^n\r7. \wНазад");
        keys |= MENU_KEY_7;
    }
    if (page + 1 < pages) {
        len += formatex(menu[len], charsmax(menu) - len, "^n\r8. \wДальше");
        keys |= MENU_KEY_8;
    }
    formatex(menu[len], charsmax(menu) - len, "^n\r9. \w%s^n\r0. \wВыход", section >= GROUP_DAMAGE ? "К разделам админа" : "В меню");
    show_menu(id, keys, menu, -1, MENU_NAME);
}

public OnMenu(id, key) {
    if (!is_user_connected(id)) return PLUGIN_HANDLED;
    if (key == 9) return PLUGIN_HANDLED;
    // A late key from a menu closed by !help cannot execute a stale action.
    if (g_Section[id] < GROUP_ROOT || g_Section[id] >= GROUP_COUNT) return PLUGIN_HANDLED;
    if (g_Section[id] == GROUP_ROOT) {
        if (key == 0) RunGroup(id, GROUP_BOTS);
        else if (key == 3) RunGroup(id, GROUP_VOICE);
        else if (key == 1 || key == 2) {
            g_Section[id] = key == 1 ? GROUP_VOTES : GROUP_STATS;
            ShowList(id);
        } else if (key == 4) ShowHelp(id);
        else if (key == 5) ShowAdmin(id);
        else ShowRoot(id);
        return PLUGIN_HANDLED;
    }
    if (g_Section[id] == GROUP_ADMIN) {
        if (key >= 0 && key <= 2 && HasGroup(id, GROUP_DAMAGE + key)) {
            g_Section[id] = GROUP_DAMAGE + key;
            ShowList(id);
        } else ShowRoot(id);
        return PLUGIN_HANDLED;
    }
    if (key >= 0 && key < PAGE_SIZE) RunAction(id, g_Visible[id][key]);
    else if (key == 6 || key == 7) {
        g_Page[id][g_Section[id]] += key == 6 ? -1 : 1;
        ShowList(id);
    } else if (key == 8) {
        if (g_Section[id] >= GROUP_DAMAGE) ShowAdmin(id);
        else ShowRoot(id);
    }
    return PLUGIN_HANDLED;
}

RunAction(id, entry) {
    if (!Available(id, entry) || g_Entries[entry][Action] == ACTION_INFO) {
        client_print(id, print_chat, "[Пикабу] Команда сейчас недоступна. Список обновлён.");
        ShowList(id);
        return;
    }
    if (g_Entries[entry][Action] != ACTION_RUN) { ShowTargets(id, entry); return; }
    // Clear our menu BEFORE dispatch: the provider may open its own persistent menu.
    show_menu(id, 0, "");
    if (equal(g_Entries[entry][Command], "say ", 4)) {
        amxclient_cmd(id, "say", g_Entries[entry][Command][4]);
    } else amxclient_cmd(id, g_Entries[entry][Command]);
}

CloseTargetMenu(id) {
    if (g_TargetMenu[id] < 0) return;
    new menu = g_TargetMenu[id];
    g_TargetMenu[id] = -1;
    menu_cancel(id);
    menu_destroy(menu);
}

public client_disconnected(id) {
    CloseTargetMenu(id);
    g_TargetUserId[id] = 0;
    g_TargetEntry[id] = -1;
}

ShowTargets(id, entry) {
    if (!Available(id, entry)) { ShowList(id); return; }
    CloseTargetMenu(id);
    new heading[160];
    if (g_Entries[entry][Action] == ACTION_VOTE)
        copy(heading, charsmax(heading), "\yГолосование: ограничение урона^n\wВыберите игрока");
    else formatex(heading, charsmax(heading), "\y%s^n\wВыберите игрока", g_Entries[entry][Title]);
    new menu = menu_create(heading, "OnTarget"), name[32], data[24], count;
    g_TargetMenu[id] = menu;
    g_TargetEntry[id] = entry;
    for (new target = 1; target <= MaxClients; target++) {
        if (!is_user_connected(target) || is_user_bot(target) || is_user_hltv(target)) continue;
        get_user_name(target, name, charsmax(name));
        for (new i; name[i]; i++) if (name[i] == '\' || (name[i] > 0 && name[i] < 32)) name[i] = ' ';
        formatex(data, charsmax(data), "%d", get_user_userid(target));
        menu_additem(menu, name, data);
        count++;
    }
    if (!count) {
        g_TargetMenu[id] = -1;
        menu_destroy(menu);
        client_print(id, print_chat, "[Пикабу] Сейчас нет подходящих игроков.");
        ShowList(id);
        return;
    }
    menu_setprop(menu, MPROP_PERPAGE, PAGE_SIZE);
    menu_setprop(menu, MPROP_BACKNAME, "Назад");
    menu_setprop(menu, MPROP_NEXTNAME, "Далее");
    menu_setprop(menu, MPROP_EXITNAME, "Закрыть");
    menu_display(id, menu);
}

public OnTarget(id, menu, item) {
    if (g_TargetMenu[id] != menu) return PLUGIN_HANDLED;
    g_TargetMenu[id] = -1;
    if (item < 0 || !is_user_connected(id)) { menu_destroy(menu); return PLUGIN_HANDLED; }
    new data[24], entry = g_TargetEntry[id];
    menu_item_getinfo(menu, item, _, data, charsmax(data));
    menu_destroy(menu);
    g_TargetUserId[id] = str_to_num(data);
    if (!ValidTarget(id, entry)) { ShowList(id); return PLUGIN_HANDLED; }
    if (g_Entries[entry][Action] == ACTION_SET_DAMAGE) {
        menu = menu_create("\yИсходящий урон игрока", "OnDamage");
        g_TargetMenu[id] = menu;
        menu_additem(menu, "0% — заблокировать", "0");
        menu_additem(menu, "25%", "0.25");
        menu_additem(menu, "50%", "0.5");
        menu_additem(menu, "75%", "0.75");
        menu_additem(menu, "100% — без ограничения админа", "1");
        menu_setprop(menu, MPROP_EXITNAME, "Отмена");
        menu_display(id, menu);
    } else if (g_Entries[entry][Action] == ACTION_VOTE || g_Entries[entry][Action] == ACTION_REMOVE_DAMAGE) {
        new target[16];
        formatex(target, charsmax(target), "#%d", g_TargetUserId[id]);
        amxclient_cmd(id, g_Entries[entry][Command], target);
    }
    return PLUGIN_HANDLED;
}

bool:ValidTarget(id, entry) {
    if (!Available(id, entry)) {
        client_print(id, print_chat, "[Пикабу] Права или доступность команды изменились.");
        return false;
    }
    new target = find_player("k", g_TargetUserId[id]);
    if (!target || !is_user_connected(target) || is_user_bot(target) || is_user_hltv(target)) {
        client_print(id, print_chat, "[Пикабу] Этот игрок уже вышел. Выберите заново.");
        return false;
    }
    return true;
}

public OnDamage(id, menu, item) {
    if (g_TargetMenu[id] != menu) return PLUGIN_HANDLED;
    g_TargetMenu[id] = -1;
    if (item < 0 || !is_user_connected(id)) { menu_destroy(menu); return PLUGIN_HANDLED; }
    new factor[8], entry = g_TargetEntry[id];
    menu_item_getinfo(menu, item, _, factor, charsmax(factor));
    menu_destroy(menu);
    if (!ValidTarget(id, entry) || g_Entries[entry][Action] != ACTION_SET_DAMAGE) return PLUGIN_HANDLED;
    new target[16];
    formatex(target, charsmax(target), "#%d", g_TargetUserId[id]);
    amxclient_cmd(id, g_Entries[entry][Command], target, factor);
    return PLUGIN_HANDLED;
}

// Unlike the former guide, this is one self-contained HTML document. Links are
// fragment navigation only, never client/server command URLs. Files do not bypass
// GoldSrc's 1536-byte MOTD limit; refuse overflow rather than cut markup or rules.
bool:HtmlAdd(output[], capacity, const fragment[]) {
    if (strlen(output) + strlen(fragment) > capacity) return false;
    add(output, capacity, fragment);
    return true;
}

bool:HtmlText(output[], capacity, const text[]) {
    new token[8], bytes;
    for (new i; text[i]; i += bytes) {
        bytes = 1;
        switch (text[i]) {
            case '&': copy(token, charsmax(token), "&amp;");
            case '<': copy(token, charsmax(token), "&lt;");
            case '>': copy(token, charsmax(token), "&gt;");
            default: {
                if ((text[i] & 0xE0) == 0xC0) bytes = 2;
                else if ((text[i] & 0xF0) == 0xE0) bytes = 3;
                else if ((text[i] & 0xF8) == 0xF0) bytes = 4;
                for (new j = 1; j < bytes; j++) {
                    if (!text[i + j] || (text[i + j] & 0xC0) != 0x80) { bytes = 1; break; }
                }
                copy(token, bytes, text[i]);
            }
        }
        if (!HtmlAdd(output, capacity, token)) return false;
    }
    return true;
}

bool:HasCommand(id, const command[]) {
    for (new entry; entry < g_Count; entry++) {
        if (equal(g_Entries[entry][Command], command) && Available(id, entry)) return true;
    }
    return false;
}

bool:BuildMotd(id, output[], capacity) {
    new bool:bots = HasGroup(id, GROUP_BOTS), bool:votes = HasGroup(id, GROUP_VOTES);
    new bool:stats = HasCommand(id, "say /stats"), bool:voice = HasGroup(id, GROUP_VOICE);
    new bool:admin = HasAdminActions(id), bool:rules;
    for (new i; i < g_Count; i++) if (g_Entries[i][Section] == 2) rules = true;
    output[0] = EOS;
    if (!HtmlAdd(output, capacity, MOTD_HEAD) || !HtmlAdd(output, capacity, "<p>")) return false;
    if (bots && !HtmlAdd(output, capacity, "<a href=#b>Боты</a> ")) return false;
    if (votes && !HtmlAdd(output, capacity, "<a href=#v>Голосования</a> ")) return false;
    if ((stats || voice) && !HtmlAdd(output, capacity, "<a href=#p>Личное</a> ")) return false;
    if (admin && !HtmlAdd(output, capacity, MOTD_NAV_ADMIN)) return false;
    if (rules && !HtmlAdd(output, capacity, " <a href=#r>Правила</a>")) return false;
    if (!HtmlAdd(output, capacity, "</p>")) return false;
    if (bots && !HtmlAdd(output, capacity, MOTD_BOTS)) return false;
    if (votes) {
        if (!HtmlAdd(output, capacity, MOTD_VOTES)) return false;
        if (HasCommand(id, "say /rtv") && !HtmlAdd(output, capacity, MOTD_MAP)) return false;
        if (HasCommand(id, "say /mode") && !HtmlAdd(output, capacity, MOTD_MODE)) return false;
        if (HasCommand(id, "uhc_blockdmg_vote") && !HtmlAdd(output, capacity, MOTD_DAMAGE)) return false;
    }
    if (stats || voice) {
        if (!HtmlAdd(output, capacity, MOTD_PERSONAL)) return false;
        if (stats && !HtmlAdd(output, capacity, MOTD_STATS)) return false;
        if (voice && !HtmlAdd(output, capacity, MOTD_MUTE)) return false;
    }
    if (admin && !HtmlAdd(output, capacity, MOTD_ADMIN)) return false;
    if (rules) {
        if (!HtmlAdd(output, capacity, "<h2><a name=r></a>Правила</h2>")) return false;
        for (new i; i < g_Count; i++) {
            if (g_Entries[i][Section] != 2) continue;
            if (!HtmlText(output, capacity, g_Entries[i][Description]) || !HtmlAdd(output, capacity, "<br>")) return false;
        }
    }
    return HtmlAdd(output, capacity, MOTD_END);
}

ShowHelp(id) {
    CloseTargetMenu(id);
    // Cancel a currently open provider menu as well; its handle belongs to that
    // provider and must NOT be destroyed here. No menu is scheduled on MOTD close.
    new oldMenu, newMenu;
    get_user_menu(id, oldMenu, newMenu);
    if (newMenu >= 0) menu_cancel(id);
    show_menu(id, 0, "");
    g_Section[id] = -1;
    new motd[MOTD_BYTES + 1];
    if (!BuildMotd(id, motd, charsmax(motd))) {
        log_amx("Help exceeds %d UTF-8 bytes; shorten configured rules. No partial rules shown.", MOTD_BYTES);
        show_motd(id, "Справка не поместилась в MOTD. Сообщите администрации: нужно сократить текст правил.", "Пикабу");
        return;
    }
    show_motd(id, motd, "Пикабу — справка");
}
