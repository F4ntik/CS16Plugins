#include <amxmodx>
#include <amxmisc>

#pragma semicolon 1

#define VERSION "1.0.3"
#define PAGE_SIZE 5
#define MAX_ENTRIES 112
#define RULE_LIMIT 64
#define RULE_LINE_LIMIT 256
#define MENU_NAME "UltraHC_Help_RU"

enum _:HelpEntry {
    Section,
    Title[96],
    Description[384],
    Command[64],
    Owner[64],
    ExtraFlags
};

new g_Entries[MAX_ENTRIES][HelpEntry], g_Count;
new g_Section[33], g_Page[33][4], g_Detail[33], g_Visible[33][PAGE_SIZE];
new Float:g_NextOpen[33];
new const g_Sections[][] = {"Справка сервера", "Игрокам", "Правила", "Администратору"};

public plugin_init() {
    register_plugin("UltraHC: Russian server help", VERSION, "UltraHC / Codex");
    // Do not inherit a cmdaccess.ini override for the general say handler.
    register_clcmd("say", "OnSay", ADMIN_ALL, "", 0);
    register_clcmd("say_team", "OnSay", ADMIN_ALL, "", 0);
    register_clcmd("ultrahc_help", "OpenHelp", ADMIN_ALL, "Russian server help", 0);
    register_menucmd(register_menuid(MENU_NAME), 1023, "OnMenu");
    LoadFeatures();
}

public plugin_cfg() {
    LoadRules();
}

public client_putinserver(id) {
    g_Section[id] = 0;
    g_Detail[id] = -1;
    g_NextOpen[id] = 0.0;
    for (new i; i < 4; i++) g_Page[id][i] = 0;
}

public OnSay(id) {
    new text[192];
    if (read_args(text, charsmax(text)) >= charsmax(text)) return PLUGIN_CONTINUE;
    remove_quotes(text);
    trim(text);
    if (!equali(text, "!help") && !equali(text, "/help")) return PLUGIN_CONTINUE;
    OpenHelp(id);
    return PLUGIN_HANDLED;
}

public OpenHelp(id) {
    if (id < 1 || id > MaxClients || !is_user_connected(id) || is_user_bot(id)) return PLUGIN_HANDLED;
    new Float:now = get_gametime();
    if (now < g_NextOpen[id]) return PLUGIN_HANDLED;
    g_NextOpen[id] = now + 0.35;
    g_Section[id] = 0;
    g_Detail[id] = -1;
    ShowRoot(id);
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
    Add(1, "Как пользоваться справкой", "В общем или командном чате:^n!help или /help^nВ консоли: ultrahc_help^nВыберите пункт цифрой. 0 — закрыть.");
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

bool:HasAdminTopics(id) {
    for (new i; i < g_Count; i++) if (g_Entries[i][Section] == 3 && Available(id, i)) return true;
    return false;
}

ShowRoot(id) {
    new menu[512], keys = MENU_KEY_1 | MENU_KEY_2 | MENU_KEY_0;
    new len = formatex(menu, charsmax(menu), "\yСправка сервера\w^n^n1. Игрокам^n2. Правила^n");
    if (HasAdminTopics(id)) {
        len += formatex(menu[len], charsmax(menu) - len, "3. Администратору^n");
        keys |= MENU_KEY_3;
    }
    formatex(menu[len], charsmax(menu) - len, "^n0. Закрыть");
    show_menu(id, keys, menu, -1, MENU_NAME);
}

ShowList(id) {
    new entries[MAX_ENTRIES], count, section = g_Section[id];
    for (new i; i < g_Count; i++) if (g_Entries[i][Section] == section && Available(id, i)) entries[count++] = i;
    new pages = max(1, (count + PAGE_SIZE - 1) / PAGE_SIZE);
    g_Page[id][section] = clamp(g_Page[id][section], 0, pages - 1);
    new page = g_Page[id][section], menu[768];
    new len = formatex(menu, charsmax(menu), "\y%s (%d/%d)\w^n^n", g_Sections[section], page + 1, pages);
    new keys = MENU_KEY_8 | MENU_KEY_0;
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
    formatex(menu[len], charsmax(menu) - len, "^n8. В начало^n0. Закрыть");
    show_menu(id, keys, menu, -1, MENU_NAME);
}

ShowDetail(id, entry) {
    if (!Available(id, entry)) {
        g_Detail[id] = -1;
        ShowList(id);
        return;
    }
    new menu[640];
    g_Detail[id] = entry;
    formatex(menu, charsmax(menu), "\y%s\w^n^n%s^n^n8. Назад к списку^n0. Закрыть", g_Entries[entry][Title], g_Entries[entry][Description]);
    show_menu(id, MENU_KEY_8 | MENU_KEY_0, menu, -1, MENU_NAME);
}

public OnMenu(id, key) {
    if (!is_user_connected(id)) return PLUGIN_HANDLED;
    if (key == 9) { g_Detail[id] = -1; return PLUGIN_HANDLED; }
    if (g_Detail[id] >= 0) {
        g_Detail[id] = -1;
        ShowList(id);
        return PLUGIN_HANDLED;
    }
    if (!g_Section[id]) {
        if (key < 0 || key > 2 || (key == 2 && !HasAdminTopics(id))) { ShowRoot(id); return PLUGIN_HANDLED; }
        g_Section[id] = key + 1;
        ShowList(id);
        return PLUGIN_HANDLED;
    }
    if (key >= 0 && key < PAGE_SIZE) ShowDetail(id, g_Visible[id][key]);
    else if (key == 5 || key == 6) {
        g_Page[id][g_Section[id]] += key == 5 ? -1 : 1;
        ShowList(id);
    } else if (key == 7) {
        g_Section[id] = 0;
        ShowRoot(id);
    }
    return PLUGIN_HANDLED;
}
