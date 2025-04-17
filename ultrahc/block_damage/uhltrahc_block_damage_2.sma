/*========================================================================================
  ULTRAHC Damage Blocker 2.1 (частичный урон + голосования)
  AMX Mod X 1.9‑1.10 | REAPI | Pawn
========================================================================================*/

#include <amxmodx>
#include <amxmisc>
#include <reapi>
#include <sqlx>
#include <nvault>

#pragma semicolon 1
#define PLUGIN_NAME    "ULTRAHC Damage Blocker"
#define PLUGIN_VERSION "2.1-vote"
#define PLUGIN_AUTHOR  "Asura + ChatGPT"

#define IsPlayer(%1)   (1 <= (%1) <= g_iMaxPlayers)

/*** ── SQL CVars (как в ultrahc_discord) ── ***/
#define CVAR_SQL_HOST  "ultrahc_ds_sql_host"
#define CVAR_SQL_USER  "ultrahc_ds_sql_user"
#define CVAR_SQL_PASS  "ultrahc_ds_sql_pass"
#define CVAR_SQL_DB    "ultrahc_ds_sql_db"

/*** ── Проценты ── ***/
enum EPower { POWER_BLOCK, POWER_25, POWER_50, POWER_75, POWER_FULL };
new const kPowerStr[5][8]  = { "Block", "25%", "50%", "75%", "Unblock" };
new const Float:kFactor[5] = { 0.0,     0.25,  0.50,  0.75,  1.0     };

/*** ── Хранилища ── ***/
new Float:g_fAdminPerc[33] = { 1.0, ... };   // постоянное (nVault)
new Float:g_fVotePerc[33]  = { 1.0, ... };   // до конца карты
new bool:g_bDiscord[33];                     // игрок есть в БД
new bool:g_bHasSQL = false;                  // БД подключена

/*** ── Ядро ── ***/
new Handle:g_hVault;
new Handle:g_hSQL;
new g_iMaxPlayers;

/*** ── Голосование ── ***/
new bool:g_bVoteInProgress;
new g_iVoteTarget;
new g_iVoteChoice[5];
new bool:g_bVoted[33];
new g_iVoteTotal;
new Handle:g_MenuVote;

/*==============================================================================*/
public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

    register_cvar(CVAR_SQL_HOST, "", FCVAR_PROTECTED);
    register_cvar(CVAR_SQL_USER, "", FCVAR_PROTECTED);
    register_cvar(CVAR_SQL_PASS, "", FCVAR_PROTECTED);
    register_cvar(CVAR_SQL_DB,   "", FCVAR_PROTECTED);

    register_concmd("uhc_blockdmg_set",  "CmdAdminSet",  ADMIN_BAN, "<nick> <0.0‑1.0>");
    register_concmd("uhc_blockdmg_rem",  "CmdAdminRem",  ADMIN_BAN, "<nick>");
    register_concmd("uhc_blockdmg_vote", "CmdVoteStart", 0,         "<nick>");

    RegisterHookChain(RG_CBasePlayer_TakeDamage, "OnTakeDamagePre", 0);

    g_hVault = nvault_open("ultrahc_block_damage");
    if (g_hVault == INVALID_HANDLE) set_fail_state("nVault failed");

    g_iMaxPlayers = get_maxplayers();
}

/*==============================================================================*/
public OnConfigsExecuted()
{
    new h[64], d[64], u[64], p[64];
    get_cvar_string(CVAR_SQL_HOST, h, charsmax(h));
    get_cvar_string(CVAR_SQL_DB,   d, charsmax(d));

    if (h[0] && d[0])
    {
        get_cvar_string(CVAR_SQL_USER, u, charsmax(u));
        get_cvar_string(CVAR_SQL_PASS, p, charsmax(p));
        g_hSQL = SQL_MakeDbTuple(h, u, p, d);
        SQL_SetCharset(g_hSQL, "utf8");
        g_bHasSQL = true;
    }
}

/*==============================================================================*/
public client_authorized(id)
{
    new auth[35], buf[16];
    get_user_authid(id, auth, charsmax(auth));

    if (nvault_get(g_hVault, auth, buf, charsmax(buf)))
        g_fAdminPerc[id] = str_to_float(buf);
    else
        g_fAdminPerc[id] = 1.0;

    new key[64]; formatex(key, charsmax(key), "tmp_%s", auth);
    if (nvault_get(g_hVault, key, buf, charsmax(buf)))
        g_fVotePerc[id] = str_to_float(buf);
    else
        g_fVotePerc[id] = 1.0;

    if (g_bHasSQL)
    {
        new q[128]; formatex(q, charsmax(q), "SELECT 1 FROM users WHERE steam_id='%s'", auth);
        new data[4]; num_to_str(id, data, charsmax(data));
        SQL_ThreadQuery(g_hSQL, "SQLDiscordCB", q, data, charsmax(data));
    }
    else g_bDiscord[id] = false;
}

public SQLDiscordCB(fail, Handle:q, err[], errn, data[], size, qt)
{
    new id = str_to_num(data);
    g_bDiscord[id] = (fail == TQUERY_SUCCESS && SQL_NumResults(q) > 0);
}

/*==============================================================================*/
public plugin_cfg()
{
    for (new id = 1; id <= g_iMaxPlayers; id++)
        if (g_fVotePerc[id] < 1.0)
            set_task(15.0 + float(id), "AutoVoteKeep", id);
}

public AutoVoteKeep(id)
{
    if (is_user_connected(id)) { g_iVoteTarget = id; StartVoteMenu(true); }
}

/*==============================================================================*/
public CmdAdminSet(id, lvl, cid)
{
    if (!cmd_access(id, lvl, cid, 3)) return PLUGIN_HANDLED;

    new arg[35], val[16];
    read_argv(1, arg, charsmax(arg));
    read_argv(2, val, charsmax(val));

    new tgt = cmd_target(id, arg, CMDTARGET_ALLOW_SELF);
    if (!tgt) return PLUGIN_HANDLED;

    new Float:perc = floatclamp(str_to_float(val), 0.0, 1.0);
    g_fAdminPerc[tgt] = perc;  SaveAdmin(tgt);
    PrintTo(id, "Admin: %.0f%% for %n", perc*100.0, tgt);
    return PLUGIN_HANDLED;
}

public CmdAdminRem(id, lvl, cid)
{
    if (!cmd_access(id, lvl, cid, 2)) return PLUGIN_HANDLED;

    new arg[35]; read_argv(1, arg, charsmax(arg));
    new tgt = cmd_target(id, arg, CMDTARGET_ALLOW_SELF);
    if (!tgt) return PLUGIN_HANDLED;

    g_fAdminPerc[tgt] = 1.0;  SaveAdmin(tgt);
    PrintTo(id, "Admin: unblocked %n", tgt);
    return PLUGIN_HANDLED;
}

SaveAdmin(id)
{
    new auth[35], buf[16]; get_user_authid(id, auth, charsmax(auth));
    if (g_fAdminPerc[id] < 1.0) { float_to_str(g_fAdminPerc[id], buf, charsmax(buf)); nvault_set(g_hVault, auth, buf); }
    else nvault_remove(g_hVault, auth);
}

/*==============================================================================*/
public CmdVoteStart(id, lvl, cid)
{
    if (!g_bHasSQL)        { PrintTo(id, "Voting disabled."); return PLUGIN_HANDLED; }
    if (!g_bDiscord[id])   { PrintTo(id, "Only Discord users."); return PLUGIN_HANDLED; }
    if (g_bVoteInProgress) { PrintTo(id, "Vote in progress."); return PLUGIN_HANDLED; }

    new arg[35]; read_argv(1, arg, charsmax(arg));
    new tgt = cmd_target(id, arg, CMDTARGET_NO_BOTS);
    if (!tgt) return PLUGIN_HANDLED;

    g_iVoteTarget = tgt;   StartVoteMenu(false);
    return PLUGIN_HANDLED;
}

/*==============================================================================*/
StartVoteMenu(bool:keep)
{
    arrayset(g_bVoted, false, sizeof g_bVoted);
    arrayset(g_iVoteChoice, 0, sizeof g_iVoteChoice);
    g_bVoteInProgress = true;

    g_iVoteTotal = 0;
    for (new i = 1; i <= g_iMaxPlayers; i++)
        if (g_bDiscord[i] && is_user_connected(i)) g_iVoteTotal++;

    new name[32]; get_user_name(g_iVoteTarget, name, charsmax(name));
    if (g_MenuVote) menu_destroy(g_MenuVote);

    if (keep)
    {
        new title[64]; formatex(title, charsmax(title), "Keep damage %% for %s ?", name);
        g_MenuVote = menu_create(title, "MenuKeepHandler");
        menu_additem(g_MenuVote, "Keep", "1");
        menu_additem(g_MenuVote, "Remove", "0");
        set_task(15.0, "FinishKeepVote");
    }
    else
    {
        new title[64]; formatex(title, charsmax(title), "Reduce damage for %s to ...", name);
        g_MenuVote = menu_create(title, "MenuVoteHandler");
        for (new i = 0; i < 5; i++) { new idx[2]; num_to_str(i, idx, 1); menu_additem(g_MenuVote, kPowerStr[i], idx); }
        set_task(15.0, "FinishVote");
    }

    for (new i = 1; i <= g_iMaxPlayers; i++)
        if (g_bDiscord[i] && is_user_connected(i)) menu_display(i, g_MenuVote, 0);

    client_print(0, print_chat, "[AMXX] Vote started (15 sec).");
}

public MenuVoteHandler(id, menu, item)
{
    if (item == MENU_EXIT || g_bVoted[id]) return PLUGIN_HANDLED;
    new info[2]; menu_item_getinfo(menu, item, _, info, 1);
    g_iVoteChoice[str_to_num(info)]++; g_bVoted[id] = true;
    return PLUGIN_HANDLED;
}

public MenuKeepHandler(id, menu, item)
{
    if (item == MENU_EXIT || g_bVoted[id]) return PLUGIN_HANDLED;
    g_iVoteChoice[item]++; g_bVoted[id] = true;
    return PLUGIN_HANDLED;
}

/*==============================================================================*/
public FinishVote()
{
    if (!g_bVoteInProgress) return;
    g_bVoteInProgress = false;

    new best = 4, bestCnt = g_iVoteChoice[4];
    for (new i = 0; i < 4; i++) if (g_iVoteChoice[i] > bestCnt) { best = i; bestCnt = g_iVoteChoice[i]; }

    if (!bestCnt) { client_print(0, print_chat, "[AMXX] Vote failed."); return; }

    new name[32]; get_user_name(g_iVoteTarget, name, charsmax(name));
    g_fVotePerc[g_iVoteTarget] = kFactor[best];

    new auth[35], buf[16], key[64];
    get_user_authid(g_iVoteTarget, auth, charsmax(auth));
    float_to_str(g_fVotePerc[g_iVoteTarget], buf, charsmax(buf));
    formatex(key, charsmax(key), "tmp_%s", auth);
    nvault_set(g_hVault, key, buf);

    client_print(0, print_chat, "[AMXX] Damage for %s set to %s", name, kPowerStr[best]);
}

public FinishKeepVote()
{
    if (!g_bVoteInProgress) return;
    g_bVoteInProgress = false;

    new name[32]; get_user_name(g_iVoteTarget, name, charsmax(name));
    new auth[35], key[64]; get_user_authid(g_iVoteTarget, auth, charsmax(auth));
    formatex(key, charsmax(key), "tmp_%s", auth);

    if (g_iVoteChoice[1] > g_iVoteChoice[0])
        client_print(0, print_chat, "[AMXX] Reduction for %s kept.", name);
    else
    {
        g_fVotePerc[g_iVoteTarget] = 1.0;
        nvault_remove(g_hVault, key);
        client_print(0, print_chat, "[AMXX] Reduction for %s removed.", name);
    }
}

/*==============================================================================*/
public OnTakeDamagePre(const this, pev_inflictor, pev_attacker, Float:damage, damage_type)
{
    if (!IsPlayer(pev_attacker)) return HC_CONTINUE;

    new Float:coef = g_fAdminPerc[pev_attacker] * g_fVotePerc[pev_attacker];
    if (coef >= 0.999) return HC_CONTINUE;

    if (coef <= 0.001)
    {
        SetHookChainReturn(ATYPE_INTEGER, 0);      // полный блок
        return HC_BREAK;
    }

    SetHookChainArg(4, ATYPE_FLOAT, damage * coef);
    return HC_CONTINUE;
}

/*==============================================================================*/
stock PrintTo(id, const fmt[], any:...)
{
    static msg[192]; vformat(msg, charsmax(msg), fmt, 3);
    client_print(id, print_chat, "[AMXX] %s", msg);
}
