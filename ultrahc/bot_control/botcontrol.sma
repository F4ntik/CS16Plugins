#include <amxmodx>
#include <cstrike>

// Based on the read Bot Control 1.2 source by Mep3ocTb and the live 1.1 image.
// Original source: D:/cs/compilator_1_9_0/botcontrol.sma.
// Keep live 1.1 access and disconnect semantics; see the comparison fixture.
// ZBot commands intentionally retain the engine's original quota side effects.
#define TASK_SOLO 5000
#define TASK_HINT 5100

new const PTB_PLUGIN[] = "ptb.amxx";
new const DIFFICULTY[][] = {"Лёгкая", "Обычная", "Сложная", "Эксперт"};

new g_MaxPlayers;
new g_Difficulty, g_JoinDelay, g_AutoBalance, g_LimitTeams;
new g_SelectedDifficulty[33];
new g_SoloUserId, g_PendingUserId;
new g_PreviousBots[33];
new Float:g_AddDeadline;
new g_SavedAutoBalance, g_SavedLimitTeams;
new bool:g_PausedPtb;
new bool:g_ExecutingCommand;

public plugin_init()
{
    register_plugin("Bot Control", "1.3", "Mep3ocTb");
    register_clcmd("say !ba", "add_bot_command");
    register_clcmd("say_team !ba", "add_bot_command");
    register_clcmd("say !br", "remove_bots_command");
    register_clcmd("say_team !br", "remove_bots_command");
    register_clcmd("say !bk", "kill_bots_command");
    register_clcmd("say_team !bk", "kill_bots_command");
    register_clcmd("say !bots", "show_bot_menu");
    register_clcmd("say_team !bots", "show_bot_menu");
    register_clcmd("say /bots", "show_bot_menu");
    register_clcmd("say_team /bots", "show_bot_menu");
    register_clcmd("say !bm", "show_bot_menu");
    register_clcmd("say_team !bm", "show_bot_menu");
    register_clcmd("botmenu", "show_bot_menu");
    // Server/RCON diagnostic only. No server-side action or access bypass.
    register_srvcmd("bc_status", "print_bot_status");
    g_MaxPlayers = get_maxplayers();
    g_Difficulty = get_cvar_pointer("bot_difficulty");
    g_JoinDelay = get_cvar_pointer("bot_join_delay");
    g_AutoBalance = get_cvar_pointer("mp_autoteambalance");
    g_LimitTeams = get_cvar_pointer("mp_limitteams");
    for (new id = 1; id <= g_MaxPlayers; id++)
        g_SelectedDifficulty[id] = g_Difficulty ? clamp(get_pcvar_num(g_Difficulty), 0, 3) : 3;
}

bool:has_public_access(id)
{
    return id >= 1 && id <= g_MaxPlayers && is_user_connected(id)
        && !is_user_bot(id) && !is_user_hltv(id);
}

count_humans()
{
    new count;
    for (new id = 1; id <= g_MaxPlayers; id++)
    {
        // Include spectators, unassigned humans and connecting humans.
        if ((is_user_connected(id) || is_user_connecting(id))
            && !is_user_bot(id) && !is_user_hltv(id))
            count++;
    }
    return count;
}

bool:has_solo_access(id, bool:notify = false)
{
    if (!has_public_access(id))
        return false;
    if (count_humans() != 1)
    {
        if (notify)
            client_print(id, print_chat, "[Боты] Добавление и сложность доступны, только когда вы один на сервере.");
        return false;
    }
    new team = get_user_team(id);
    if (team != 1 && team != 2)
    {
        if (notify)
            client_print(id, print_chat, "[Боты] Сначала выберите команду T или CT.");
        return false;
    }
    return true;
}

public show_bot_menu(id)
{
    if (!has_public_access(id))
        return PLUGIN_HANDLED;
    new title[192], line[96], bots[32], count;
    get_players(bots, count, "dh");
    formatex(title, charsmax(title), "\yУправление ботами\w^nБотов на сервере: %d", count);
    new menu = menu_create(title, "bot_menu_handler");
    menu_additem(menu, "Добавить одного бота против меня");
    if (g_Difficulty)
        formatex(line, charsmax(line), "Сложность новых ботов: %s", DIFFICULTY[clamp(g_SelectedDifficulty[id], 0, 3)]);
    else
        copy(line, charsmax(line), "Сложность недоступна: ZBot не найден");
    menu_additem(menu, line);
    menu_additem(menu, "Убить всех ботов (они возродятся)");
    menu_additem(menu, "Удалить всех ботов с сервера");
    menu_additem(menu, "Обновить меню");
    menu_setprop(menu, MPROP_EXITNAME, "Закрыть");
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public bot_menu_handler(id, menu, item)
{
    menu_destroy(menu);
    if (item < 0 || !has_public_access(id))
        return PLUGIN_HANDLED;
    // Recheck action-specific access after every click, not just when opened.
    switch (item)
    {
        case 0: return add_bot_command(id);
        case 1: return show_difficulty_menu(id);
        case 2: return kill_bots_command(id);
        case 3: return remove_bots_command(id);
    }
    return show_bot_menu(id);
}

public show_difficulty_menu(id)
{
    if (!has_solo_access(id, true) || !g_Difficulty)
        return show_bot_menu(id);
    new menu = menu_create("\yСложность новых ботов", "difficulty_menu_handler");
    for (new level = 0; level < sizeof DIFFICULTY; level++)
        menu_additem(menu, DIFFICULTY[level]);
    menu_additem(menu, "Назад в меню ботов");
    menu_setprop(menu, MPROP_EXITNAME, "Закрыть");
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public difficulty_menu_handler(id, menu, item)
{
    menu_destroy(menu);
    if (!has_public_access(id))
        return PLUGIN_HANDLED;
    // A closed/replaced/timed-out menu must not be reopened by its callback.
    if (item < 0)
        return PLUGIN_HANDLED;
    if (item == sizeof DIFFICULTY)
        return show_bot_menu(id);
    if (!has_solo_access(id, true) || !g_Difficulty)
        return show_bot_menu(id);
    if (g_PendingUserId || g_ExecutingCommand)
        client_print(id, print_chat, "[Боты] Дождитесь завершения добавления бота.");
    else if (item < sizeof DIFFICULTY)
    {
        new level = clamp(item, 0, 3);
        g_SelectedDifficulty[id] = level;
        client_print(id, print_chat, "[Боты] Сложность новых ботов: %s. Уже добавленные боты остаются прежними.", DIFFICULTY[level]);
    }
    return show_bot_menu(id);
}

public add_bot_command(id)
{
    if (!has_solo_access(id, true))
        return show_bot_menu(id);
    if (!g_Difficulty || !g_AutoBalance || !g_LimitTeams)
    {
        client_print(id, print_chat, "[Боты] Не найдены настройки ZBot или команд. Добавление недоступно.");
        return show_bot_menu(id);
    }
    if (g_PendingUserId || g_ExecutingCommand)
    {
        client_print(id, print_chat, "[Боты] Бот ещё добавляется. Дождитесь сообщения о результате.");
        return show_bot_menu(id);
    }
    new occupied;
    for (new slot = 1; slot <= g_MaxPlayers; slot++)
        if (is_user_connected(slot) || is_user_connecting(slot))
            occupied++;
    if (occupied >= g_MaxPlayers)
    {
        client_print(id, print_chat, "[Боты] На сервере нет свободного места.");
        return show_bot_menu(id);
    }
    if (!begin_solo(id))
        return show_bot_menu(id);

    // One request at a time, bound to a connection userid (not a reusable slot).
    for (new bot = 1; bot <= g_MaxPlayers; bot++)
        g_PreviousBots[bot] = is_user_connected(bot) && is_user_bot(bot) ? get_user_userid(bot) : 0;
    g_PendingUserId = get_user_userid(id);
    new delay = g_JoinDelay ? get_pcvar_num(g_JoinDelay) : 10;
    g_AddDeadline = get_gametime() + float(clamp(delay + 5, 5, 60));
    // ZBot selects its profile inside bot_add, synchronously. Apply the personal
    // choice to that one creation, then restore the server's difficulty setting.
    new savedDifficulty = get_pcvar_num(g_Difficulty);
    new selectedDifficulty = clamp(g_SelectedDifficulty[id], 0, 3);
    set_pcvar_num(g_Difficulty, selectedDifficulty);
    g_ExecutingCommand = true;
    if (get_user_team(id) == 1)
        server_cmd("bot_add_ct");
    else
        server_cmd("bot_add_t");
    // Execute the fixed command in this callback; no delayed client arguments.
    server_exec();
    if (get_pcvar_num(g_Difficulty) == selectedDifficulty)
        set_pcvar_num(g_Difficulty, savedDifficulty);
    g_ExecutingCommand = false;
    remove_task(TASK_HINT + id);
    client_print(id, print_chat, "[Боты] Добавляется один противник. Следующего можно добавить после подтверждения.");
    return show_bot_menu(id);
}

public kill_bots_command(id)
{
    if (!has_public_access(id) || g_ExecutingCommand)
        return PLUGIN_HANDLED;
    g_ExecutingCommand = true;
    // ZBot's fixed bot-only command; never interpolate client names or arguments.
    server_cmd("bot_kill");
    server_exec();
    g_ExecutingCommand = false;
    client_print(id, print_chat, "[Боты] Выполнена команда убить всех ботов.");
    return show_bot_menu(id);
}

public remove_bots_command(id)
{
    if (!has_public_access(id) || g_ExecutingCommand)
        return PLUGIN_HANDLED;
    kick_all_bots();
    client_print(id, print_chat, "[Боты] Выполнена команда удалить всех ботов.");
    return show_bot_menu(id);
}

kick_all_bots()
{
    end_solo();
    g_ExecutingCommand = true;
    // Preserve bot_kick's quota reset. Generic player kick would cause refills.
    server_cmd("bot_kick");
    server_exec();
    g_ExecutingCommand = false;
}

bool:begin_solo(id)
{
    if (g_SoloUserId == get_user_userid(id))
        return true;
    end_solo();
    new status[16];
    get_ptb_status(status, charsmax(status));
    if (equal(status, "running") || equal(status, "debug"))
    {
        if (!pause("ac", PTB_PLUGIN))
        {
            client_print(id, print_chat, "[Боты] Не удалось временно отключить балансировщик. Добавление отменено.");
            return false;
        }
        g_PausedPtb = true;
    }
    // This lease starts only after an explicit add and ends before another human plays.
    g_SavedAutoBalance = get_pcvar_num(g_AutoBalance);
    g_SavedLimitTeams = get_pcvar_num(g_LimitTeams);
    set_pcvar_num(g_AutoBalance, 0);
    set_pcvar_num(g_LimitTeams, 0);
    g_SoloUserId = get_user_userid(id);
    set_task(0.25, "maintain_solo", TASK_SOLO, _, _, "b");
    return true;
}

end_solo()
{
    remove_task(TASK_SOLO);
    g_PendingUserId = 0;
    if (g_SoloUserId)
    {
        // Do not overwrite a different value set by the administrator/another addon.
        if (g_AutoBalance && get_pcvar_num(g_AutoBalance) == 0)
            set_pcvar_num(g_AutoBalance, g_SavedAutoBalance);
        if (g_LimitTeams && get_pcvar_num(g_LimitTeams) == 0)
            set_pcvar_num(g_LimitTeams, g_SavedLimitTeams);
    }
    g_SoloUserId = 0;
    if (g_PausedPtb)
    {
        g_PausedPtb = false;
        new status[16];
        get_ptb_status(status, charsmax(status));
        if (equal(status, "paused") && !unpause("ac", PTB_PLUGIN))
            log_amx("Could not restore ptb.amxx after solo session; check amxx plugins.");
    }
}

public maintain_solo()
{
    new owner = find_player("k", g_SoloUserId);
    if (!g_SoloUserId || !has_solo_access(owner))
    {
        end_solo();
        return;
    }
    new status[16];
    get_ptb_status(status, charsmax(status));
    if (get_pcvar_num(g_AutoBalance) != 0 || get_pcvar_num(g_LimitTeams) != 0
        || (g_PausedPtb && !equal(status, "paused")))
    {
        end_solo();
        client_print(owner, print_chat, "[Боты] Настройки баланса изменились. Одиночный режим завершён.");
        return;
    }
    new bots[32], count, team = get_user_team(owner) == 1 ? 2 : 1;
    get_players(bots, count, "dh");
    for (new i = 0; i < count; i++)
    {
        new bot = bots[i], botTeam = get_user_team(bot);
        // Only bots already assigned to a playing team; never move a human.
        if (!is_user_connected(bot) || !is_user_bot(bot) || (botTeam != 1 && botTeam != 2))
            continue;
        if (botTeam != team)
        {
            if (is_user_alive(bot))
                user_silentkill(bot);
            cs_set_user_team(bot, team);
        }
        if (g_PendingUserId == get_user_userid(owner)
            && g_PreviousBots[bot] != get_user_userid(bot))
        {
            g_PendingUserId = 0;
            client_print(owner, print_chat, "[Боты] Противник добавлен. Можно добавить следующего.");
            new name[32];
            get_user_name(owner, name, charsmax(name));
            server_print("[Bot Control] %s added one opposing bot.", name);
        }
    }
    if (g_PendingUserId && g_AddDeadline > 0.0 && get_gametime() >= g_AddDeadline)
    {
        // A timeout is not proof of failure: the engine may still fulfill its quota.
        // Keep the single request reserved until it joins or !br cancels it.
        g_AddDeadline = 0.0;
        client_print(owner, print_chat, "[Боты] Вход бота пока не подтверждён. Подождите или отмените добавление пунктом «Удалить всех ботов».");
    }
    if (!count && !g_PendingUserId && get_cvar_num("bot_quota") <= 0)
        end_solo();
}

public client_connect(id)
{
    remove_task(TASK_HINT + id);
    // Do not classify a new client in this early forward: our own bot_add
    // must not cancel its pending request before the bot is fully initialized.
    // maintain_solo counts connecting humans; client_putinserver also checks.
}

public client_putinserver(id)
{
    if (!has_public_access(id))
        return;
    g_SelectedDifficulty[id] = g_Difficulty ? clamp(get_pcvar_num(g_Difficulty), 0, 3) : 3;
    if (g_SoloUserId && !has_solo_access(id))
        end_solo();
    if (count_humans() == 1)
        set_task(5.0, "display_bot_commands", TASK_HINT + id);
}

public client_disconnected(id)
{
    remove_task(TASK_HINT + id);
    if (g_SoloUserId && get_user_userid(id) == g_SoloUserId)
        end_solo();
    // Live 1.1 rule (unlike source 1.2): ANY non-bot disconnect removes all bots.
    // This also includes an unassigned human or HLTV. Keep the existing rule.
    if (!is_user_bot(id))
        kick_all_bots();
}

public display_bot_commands(taskId)
{
    new id = taskId - TASK_HINT;
    if (!has_public_access(id) || count_humans() != 1)
        return;
    client_print(id, print_chat, "[Боты] Меню: !bots. !ba — добавить противника, !br — удалить ботов, !bk — убить ботов.");
    set_task(30.0, "display_bot_commands", taskId);
}

get_ptb_status(status[], length)
{
    new plugin = is_plugin_loaded(PTB_PLUGIN, true);
    if (plugin < 0)
        copy(status, length, "not_loaded");
    else
        get_plugin(plugin, _, _, _, _, _, _, _, _, status, length);
}

public print_bot_status()
{
    new bots[32], count, status[16], quotaMode[32], joinTeam[32];
    get_players(bots, count, "dh");
    get_ptb_status(status, charsmax(status));
    get_cvar_string("bot_quota_mode", quotaMode, charsmax(quotaMode));
    get_cvar_string("bot_join_team", joinTeam, charsmax(joinTeam));
    server_print("[Bot Control 1.3] engine=ZBot cvars_available=%d humans=%d bots=%d solo_userid=%d pending_userid=%d", !!g_Difficulty, count_humans(), count, g_SoloUserId, g_PendingUserId);
    server_print("[Bot Control] access=all_humans add=solo_T_or_CT kill_remove=all_humans ptb=%s paused_by_us=%d", status, g_PausedPtb);
    server_print("[Bot Control] bot_quota=%d quota_mode=%s join_team=%s difficulty=%d mp_autoteambalance=%d mp_limitteams=%d", get_cvar_num("bot_quota"), quotaMode, joinTeam, get_cvar_num("bot_difficulty"), get_cvar_num("mp_autoteambalance"), get_cvar_num("mp_limitteams"));
    return PLUGIN_HANDLED;
}

public plugin_pause()
{
    end_solo();
}

public plugin_end()
{
    end_solo();
}
