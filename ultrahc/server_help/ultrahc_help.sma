#include <amxmodx>
#include <amxmisc>

#pragma semicolon 1

#define VERSION "1.1.0"
#define PAGE_SIZE 5
#define MAX_ENTRIES 112
#define RULE_LIMIT 64
#define RULE_LINE_LIMIT 256
#define MENU_NAME "UltraHC_Pika_RU"
#define MOTD_BYTES 1450
#define MOTD_BODY_BYTES 950

enum { ACTION_INFO, ACTION_RUN, ACTION_VOTE, ACTION_SET_DAMAGE, ACTION_REMOVE_DAMAGE };

enum _:HelpEntry {
    Section,
    Title[96],
    Description[384],
    Command[64],
    Owner[64],
    ExtraFlags,
    Action
};

new g_Entries[MAX_ENTRIES][HelpEntry], g_Count;
new g_Section[33], g_Page[33][4], g_Visible[33][PAGE_SIZE];
new bool:g_HelpOpen[33], bool:g_RulesOnly[33], g_HelpPage[33];
new g_TargetMenu[33], g_TargetUserId[33], g_TargetEntry[33];
new Float:g_NextOpen[33];
new const g_Sections[][] = {"Пикабу", "Команды игрока", "Правила", "Команды администратора"};
new const MOTD_HEAD[] = "<html><head><meta http-equiv=Content-Type content=^"text/html; charset=utf-8^"><style>body{background:#17212b;color:#e5edf5;font:14px Arial;margin:18px}h3{color:#ffc568}pre{font:13px Arial;white-space:pre-wrap;word-wrap:break-word}small{color:#abb9c8}</style></head><body><h3>Пикабу / помощь</h3><pre>";
new const MOTD_END[] = "</pre><hr><small>!pika — команды. Закройте окно для перелистывания.</small></body></html>";

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
    g_HelpOpen[id] = false;
    g_TargetMenu[id] = -1;
    g_TargetUserId[id] = 0;
    g_TargetEntry[id] = -1;
    g_NextOpen[id] = 0.0;
    for (new i; i < 4; i++) g_Page[id][i] = 0;
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
    trim(argument);
    if (argument[0] && (!is_str_num(argument) || strlen(argument) > 3)) {
        client_print(id, print_chat, "[Пикабу] Справка: !help или !help 2 (номер страницы).");
        return PLUGIN_HANDLED;
    }
    ShowHelp(id, max(0, str_to_num(argument) - 1));
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
    g_HelpOpen[id] = false;
    ShowRoot(id);
    return PLUGIN_HANDLED;
}

public OpenHelp(id) {
    if (!CanOpen(id)) return PLUGIN_HANDLED;
    new argument[16];
    read_argv(1, argument, charsmax(argument));
    if (argument[0] && (!is_str_num(argument) || strlen(argument) > 3)) {
        client_print(id, print_chat, "[Пикабу] В консоли: ultrahc_help [номер страницы].");
        return PLUGIN_HANDLED;
    }
    ShowHelp(id, max(0, str_to_num(argument) - 1));
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
    Add(1, "Меню и справка", "!pika — доступные действия сервера.^n!help — эта справка, !help 2 — страница 2.^nПосле закрытия MOTD можно листать страницы.^nВ консоли: pika и ultrahc_help.");
    Add(1, "Боты: меню и сложность", "В чате: !bots или /bots^nВ консоли: botmenu^nМеню доступно игрокам.^nДля добавления и сложности выберите T/CT^nи оставайтесь единственным игроком.", "botmenu", "botcontrol.amxx");
    Add(1, "Статистика: меню", "В чате: /stats^nОткрывает меню статистики.", "say /stats", "statsx_rbs.amxx");
    Add(1, "Ваш ранг", "В чате: /rank^nПоказывает ранг игрока.", "say /rank", "statsx_rbs.amxx");
    Add(1, "Общая статистика", "В чате: /rankstats^nПоказывает общую статистику.", "say /rankstats", "statsx_rbs.amxx");
    Add(1, "Статистика за карту", "В чате: /statsme^nВаша статистика за текущую карту.", "say /statsme", "statsx_rbs.amxx");
    Add(1, "Лучшие игроки", "В чате: /top15^nТаблица лучших игроков.", "say /top15", "statsx_rbs.amxx");
    Add(1, "Рейтинг HLstats", "В чате: /hlxtop^nТаблица лучших игроков HLstats.", "say /hlxtop", "hlstat_top.amxx");
    Add(1, "Лучшие из играющих сейчас", "В чате: /hot^nРейтинг игроков, которые сейчас на сервере.", "say /hot", "statsx_rbs.amxx");
    Add(1, "Здоровье убийцы", "В чате: /hp^nПоказывает здоровье вашего убийцы.", "say /hp", "statsx_rbs.amxx");
    Add(1, "Нанесённый урон", "В чате: /me^nПоказывает нанесённый вами урон.", "say /me", "statsx_rbs.amxx");
    Add(1, "Сообщения статистики", "В чате: /switch^nВключает или выключает сообщения статистики.", "say /switch", "statsx_rbs.amxx");
    Add(1, "Голосование за карту", "В чате: /rtv^nЗапрос досрочного голосования за карту.", "say /rtv");
    Add(1, "Открыть или закрыть проходы", "В чате: /mode^nГолосование за открытие или закрытие^nпроходов во вторую половину карты.", "say /mode", "mode.amxx");
    Add(1, "Отключить голос игрока", "В чате: /mute^nОткрывает выбор игрока.^nОтключает его голос только для вас.^nЭто не голосование и не блокировка чата.", "say /mute", "CA_Mute.amxx");
    Add(1, "Discord сервера", "Адрес сообщества из объявлений сервера:^ndiscord.com/invite/r3kCQNxX5Z");
    Add(1, "Встречи сообщества", "Собираемся по пятницам^nв 20:30 по московскому времени.^nИнформация из надписей на de_dust2.");
    Add(1, "Ограничение урона", "На сервере есть отдельное дополнение^nдля ограничения урона игроков.^nДоступные команды зависят от ваших прав.", "", "uhltrahc_block_damage_2.amxx");
    Add(1, "Урон: начать голосование", "В консоли:^nuhc_blockdmg_vote ^"Ник игрока^"^nЗапуск и участие — для пользователей,^nчей Steam ID найден в базе Discord.^nБез настройки базы запуск отключён.", "uhc_blockdmg_vote", "uhltrahc_block_damage_2.amxx");
    Add(1, "Урон: варианты голосования", "Голосование длится 15 секунд.^nВарианты урона: 0, 25, 50, 75, 100%.^nЦель — игрок, не бот.^nОдновременно проводится одно голосование.", "uhc_blockdmg_vote", "uhltrahc_block_damage_2.amxx");
    Add(1, "Чат сервера", "Обычный чат — клавиша Y.^nКомандный чат — клавиша U.^nСправка доступна в обоих чатах.", "", "ultrahc_chat_manager.amxx");
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
            WrapRule(line);
            formatex(title, charsmax(title), "Правило %d", count + 1);
            Add(2, title, line);
            count++;
        }
        if (physicalLine == RULE_LINE_LIMIT) log_amx("Rules read capped at %d physical lines.", RULE_LINE_LIMIT);
        fclose(file);
    }
    if (!count) Add(2, "Правила пока не опубликованы", "Текст правил в справку пока не добавлен.^nУточните действующие правила^nу администрации сервера.");
}

WrapRule(text[]) {
    new columns, lastSpace = -1, sinceSpace;
    for (new i; text[i]; i++) {
        if ((text[i] & 0xC0) == 0x80) continue;
        columns++;
        sinceSpace++;
        if (text[i] == ' ') { lastSpace = i; sinceSpace = 0; }
        if (columns >= 38 && lastSpace >= 0) {
            text[lastSpace] = '^n';
            columns = sinceSpace;
            lastSpace = -1;
        }
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
        "say /statsme", "say /top15", "say /hlxtop", "say /hot", "say /hp", "say /me",
        "say /switch", "say /rtv", "say /mode", "say /mute", "uhc_blockdmg_menu",
        "slmainmenu", "slselect", "sleditmode", "slsave", "delete_ad", "iga_closer",
        "iga_farther", "iga_scale_up", "iga_scale_down"};
    for (new entry; entry < g_Count; entry++) {
        for (new i; i < sizeof direct; i++) {
            if (equal(g_Entries[entry][Command], direct[i])) g_Entries[entry][Action] = ACTION_RUN;
        }
        if (equal(g_Entries[entry][Title], "Урон: начать голосование")) g_Entries[entry][Action] = ACTION_VOTE;
        if (equal(g_Entries[entry][Command], "uhc_blockdmg_set")) g_Entries[entry][Action] = ACTION_SET_DAMAGE;
        if (equal(g_Entries[entry][Command], "uhc_blockdmg_rem")) g_Entries[entry][Action] = ACTION_REMOVE_DAMAGE;
    }
}

bool:HasAdminActions(id) {
    for (new i; i < g_Count; i++) {
        if (g_Entries[i][Section] == 3 && g_Entries[i][Action] != ACTION_INFO && Available(id, i)) return true;
    }
    return false;
}

ShowRoot(id) {
    g_HelpOpen[id] = false;
    g_Section[id] = 0;
    new menu[512], keys = MENU_KEY_1 | MENU_KEY_2 | MENU_KEY_3 | MENU_KEY_0;
    new len = formatex(menu, charsmax(menu), "\yПикабу — меню сервера\w^n^n1. Доступные команды^n2. Справка (окно MOTD)^n3. Правила (окно MOTD)^n");
    if (HasAdminActions(id)) {
        len += formatex(menu[len], charsmax(menu) - len, "4. Команды администратора^n");
        keys |= MENU_KEY_4;
    }
    formatex(menu[len], charsmax(menu) - len, "^n0. Закрыть");
    show_menu(id, keys, menu, -1, MENU_NAME);
}

ShowList(id) {
    g_HelpOpen[id] = false;
    new entries[MAX_ENTRIES], count, section = g_Section[id];
    if (section != 1 && section != 3) { ShowRoot(id); return; }
    for (new i; i < g_Count; i++) {
        if (g_Entries[i][Section] == section && g_Entries[i][Action] != ACTION_INFO && Available(id, i)) entries[count++] = i;
    }
    new pages = max(1, (count + PAGE_SIZE - 1) / PAGE_SIZE);
    g_Page[id][section] = clamp(g_Page[id][section], 0, pages - 1);
    new page = g_Page[id][section], menu[512];
    new len = formatex(menu, charsmax(menu), "\y%s (%d/%d)\w^n^n", g_Sections[section], page + 1, pages);
    new keys = MENU_KEY_8 | MENU_KEY_9 | MENU_KEY_0;
    for (new i; i < PAGE_SIZE; i++) {
        new index = page * PAGE_SIZE + i;
        g_Visible[id][i] = index < count ? entries[index] : -1;
        if (index >= count) continue;
        len += formatex(menu[len], charsmax(menu) - len, "%d. %s^n", i + 1, g_Entries[entries[index]][Title]);
        keys |= (1 << i);
    }
    if (!count) len += formatex(menu[len], charsmax(menu) - len, "Доступных пунктов сейчас нет.^n");
    if (page > 0) {
        len += formatex(menu[len], charsmax(menu) - len, "^n6. Предыдущая страница");
        keys |= MENU_KEY_6;
    }
    if (page + 1 < pages) {
        len += formatex(menu[len], charsmax(menu) - len, "^n7. Следующая страница");
        keys |= MENU_KEY_7;
    }
    formatex(menu[len], charsmax(menu) - len, "^n8. В начало^n9. Справка^n0. Закрыть");
    show_menu(id, keys, menu, -1, MENU_NAME);
}

public OnMenu(id, key) {
    if (!is_user_connected(id)) return PLUGIN_HANDLED;
    if (key == 9) { g_HelpOpen[id] = false; return PLUGIN_HANDLED; }
    if (g_HelpOpen[id]) {
        if (key == 5 || key == 6) ShowHelp(id, g_HelpPage[id] + (key == 5 ? -1 : 1), g_RulesOnly[id]);
        else if (key == 7) ShowRoot(id);
        return PLUGIN_HANDLED;
    }
    if (!g_Section[id]) {
        if (key == 0 || (key == 3 && HasAdminActions(id))) {
            g_Section[id] = key == 0 ? 1 : 3;
            ShowList(id);
        } else if (key == 1 || key == 2) ShowHelp(id, 0, key == 2);
        else ShowRoot(id);
        return PLUGIN_HANDLED;
    }
    if (key >= 0 && key < PAGE_SIZE) RunAction(id, g_Visible[id][key]);
    else if (key == 5 || key == 6) {
        g_Page[id][g_Section[id]] += key == 5 ? -1 : 1;
        ShowList(id);
    } else if (key == 7) {
        ShowRoot(id);
    } else if (key == 8) ShowHelp(id);
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
    g_HelpOpen[id] = false;
}

ShowTargets(id, entry) {
    if (!Available(id, entry)) { ShowList(id); return; }
    CloseTargetMenu(id);
    new menu = menu_create("\yВыберите игрока", "OnTarget"), name[32], data[24], count;
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

// Append one complete HTML entity or UTF-8 character at a time. Page boundaries
// cannot break either. Only the requested page is retained; all text is counted.
MotdText(const text[], wanted, &page, &used, output[], capacity) {
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
        new length = strlen(token);
        if (used + length > MOTD_BODY_BYTES) { page++; used = 0; }
        if (page == wanted) add(output, capacity, token);
        used += length;
    }
}

BuildMotd(const entries[], count, wanted, output[], capacity) {
    copy(output, capacity, MOTD_HEAD);
    new page, used;
    for (new i; i < count; i++) {
        MotdText(g_Entries[entries[i]][Title], wanted, page, used, output, capacity);
        MotdText("^n", wanted, page, used, output, capacity);
        MotdText(g_Entries[entries[i]][Description], wanted, page, used, output, capacity);
        MotdText("^n^n", wanted, page, used, output, capacity);
    }
    add(output, capacity, MOTD_END);
    return page + 1;
}

ShowHelp(id, requested = 0, bool:rulesOnly = false) {
    new entries[MAX_ENTRIES], count, motd[MOTD_BYTES + 1];
    // Evaluate availability once per open; never leak admin prose to other players.
    for (new i; i < g_Count; i++) {
        if ((!rulesOnly || g_Entries[i][Section] == 2) && Available(id, i)) entries[count++] = i;
    }
    requested = max(0, requested);
    new pages = BuildMotd(entries, count, requested, motd, charsmax(motd));
    if (requested >= pages) {
        requested = pages - 1;
        BuildMotd(entries, count, requested, motd, charsmax(motd));
    }
    g_HelpOpen[id] = true;
    g_RulesOnly[id] = rulesOnly;
    g_HelpPage[id] = requested;
    new menu[512], keys = MENU_KEY_8 | MENU_KEY_0, header[96];
    formatex(header, charsmax(header), "Пикабу: %s (%d/%d)", rulesOnly ? "правила" : "справка", requested + 1, pages);
    new len = formatex(menu, charsmax(menu), "\y%s\w^n^nПосле закрытия окна:^n", header);
    if (requested > 0) {
        len += formatex(menu[len], charsmax(menu) - len, "6. Предыдущая страница^n");
        keys |= MENU_KEY_6;
    }
    if (requested + 1 < pages) {
        len += formatex(menu[len], charsmax(menu) - len, "7. Следующая страница^n");
        keys |= MENU_KEY_7;
    }
    formatex(menu[len], charsmax(menu) - len, "8. Меню !pika^n0. Закрыть");
    show_menu(id, keys, menu, -1, MENU_NAME);
    show_motd(id, motd, header);
}
