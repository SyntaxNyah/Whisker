// Whisker Optional Plugin — Command Usage Stats [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Counts which OOC commands get used most, so you can see what your players
// actually reach for — handy for pruning dead commands, spotting a popular plugin,
// or noticing a command being spammed. `/cmdstats` shows the leaderboard. Drop the
// compiled .dll / .so into plugins/ and restart. Optional.
//
// This source file is provided as a learning exercise. To compile a C3 plugin
// yourself, follow the Plugin Dev Guide: plugins/PLUGIN DEV GUIDE README.md
//
// ============================================================
// What it does
// ============================================================
//
//   /cmdstats [N]    show the top N most-used commands (default 15)
//
// It counts the command word of any OOC line starting with `/` (e.g. `/roll`,
// `/cm`), across every player. Counts persist across clean restarts in
// config/cmd_stats.txt. It does NOT store arguments — only which command, how
// often — so it never records passwords from a mistyped `/login`.
//
// ============================================================
// Why this is an OPTIONAL plugin — and near-zero cost
// ============================================================
//
// It's an ops/insight tool most servers don't need running all the time, so it's
// opt-in. The work is one `CT` hook that returns instantly for any line that
// isn't a command; a command line costs a short token-extract plus a small-table
// increment — microseconds, and only on OOC commands (never the IC path).

module cmd_stats;

import std::io;

// ============================================================
// Whisker plugin interface (standalone) — v4 prefix.
// ============================================================

struct PluginInfo { String name; String version; String author; String description; }
alias CommandHandler = fn void(void* client, String args);
alias PacketHook     = fn bool(void* client, void* packet);

alias RegisterCommandFn    = fn void(String, CommandHandler, ulong, String, String);
alias RegisterHookFn       = fn void(String, PacketHook, String);
alias FindClientFn         = fn void*(int);
alias BroadcastAreaMsgFn   = fn void(int, String);
alias BroadcastAreaRawFn   = fn void(int, String);
alias BroadcastArupFn      = fn void(int);
alias GetAreaCountFn       = fn int();
alias AreaIsCmFn           = fn bool(int, int);
alias AreaAddCmFn          = fn void(int, int);
alias AreaRemoveCmFn       = fn void(int, int);
alias AreaCmCountFn        = fn int(int);
alias AreaClearCmsFn       = fn void(int);
alias AreaUninviteFn       = fn void(int, int);
alias AreaSetStatusFn      = fn void(int, int);
alias AreaGetStatusFn      = fn int(int);
alias AreaGetNameFn        = fn String(int);
alias AreaSetSongFn        = fn void(int, String, int);
alias ForceMoveFn          = fn void(void*, int);
alias ClientSendMsgFn      = fn void(void*, String);
alias ClientSendRawFn      = fn void(void*, String);
alias ClientGetUidFn       = fn int(void*);
alias ClientGetAreaFn      = fn int(void*);
alias ClientIsModFn        = fn bool(void*);
alias ClientDisplayNameFn  = fn String(void*);
alias ClientGetCharIdFn    = fn int(void*);
alias ClientGetShownameFn  = fn String(void*);
alias ClientGetCharNameFn  = fn String(void*);
alias ClientIsJoinedFn     = fn bool(void*);
alias ClientSetPositionFn  = fn void(void*, String);
alias BroadcastAllMsgFn     = fn void(String);
alias BroadcastAllRawFn     = fn void(String);
alias GetPlayerCountFn      = fn int();
alias GetAreaPlayerCountFn  = fn int(int);
alias ClientGetIpidFn       = fn String(void*);
alias PacketGetFieldFn      = fn String(void*, int);
alias PacketGetFieldCountFn = fn int(void*);
alias ClientKickFn          = fn void(void*);
alias ClientMuteFn          = fn void(void*);
alias ClientUnmuteFn        = fn void(void*);
alias AreaGetBackgroundFn   = fn String(int);
alias AreaSetBackgroundFn   = fn void(int, String);
alias AreaGetLockFn         = fn int(int);
alias AreaSetLockFn         = fn void(int, int);
alias AreaInviteFn          = fn void(int, int);
alias ArgsSplitFn           = fn int(String, String*, int);
alias ToLowerFn             = fn int(String, char*, int);
alias LifecycleHook           = fn void(void*, int);
alias RegisterLifecycleHookFn = fn void(LifecycleHook, String);
alias ClientGetOocNameFn      = fn String(void*);
alias ClientIsHiddenFn        = fn bool(void*);
alias ClientGetIpFn         = fn String(void*);
alias ConnectionFilter      = fn bool(String);
alias RegisterConnFilterFn  = fn void(ConnectionFilter, String);
alias BroadcastPermRawFn    = fn void(String, ulong);

struct PluginAPI {
    RegisterCommandFn   register_command;
    RegisterHookFn      register_hook;
    FindClientFn        find_client;
    BroadcastAreaMsgFn  broadcast_area_msg;
    BroadcastAreaRawFn  broadcast_area_raw;
    BroadcastArupFn     broadcast_arup;
    GetAreaCountFn      get_area_count;
    AreaIsCmFn          area_is_cm;
    AreaAddCmFn         area_add_cm;
    AreaRemoveCmFn      area_remove_cm;
    AreaCmCountFn       area_cm_count;
    AreaClearCmsFn      area_clear_cms;
    AreaUninviteFn      area_uninvite;
    AreaSetStatusFn     area_set_status;
    AreaGetStatusFn     area_get_status;
    AreaGetNameFn       area_get_name;
    AreaSetSongFn       area_set_song;
    ForceMoveFn         force_move;
    ClientSendMsgFn     client_send_msg;
    ClientSendRawFn     client_send_raw;
    ClientGetUidFn      client_get_uid;
    ClientGetAreaFn     client_get_area;
    ClientIsModFn       client_is_mod;
    ClientDisplayNameFn client_display_name;
    ClientGetCharIdFn   client_get_char_id;
    ClientGetShownameFn client_get_showname;
    ClientGetCharNameFn client_get_char_name;
    ClientIsJoinedFn    client_is_joined;
    ClientSetPositionFn client_set_position;
    BroadcastAllMsgFn     broadcast_all_msg;
    BroadcastAllRawFn     broadcast_all_raw;
    GetPlayerCountFn      get_player_count;
    GetAreaPlayerCountFn  get_area_player_count;
    ClientGetIpidFn       client_get_ipid;
    PacketGetFieldFn      packet_get_field;
    PacketGetFieldCountFn packet_get_field_count;
    ClientKickFn          client_kick;
    ClientMuteFn          client_mute;
    ClientUnmuteFn        client_unmute;
    AreaGetBackgroundFn   area_get_background;
    AreaSetBackgroundFn   area_set_background;
    AreaGetLockFn         area_get_lock;
    AreaSetLockFn         area_set_lock;
    AreaInviteFn          area_invite;
    ArgsSplitFn           args_split;
    ToLowerFn             to_lower;
    RegisterLifecycleHookFn register_lifecycle_hook;
    ClientGetOocNameFn      client_get_ooc_name;
    ClientIsHiddenFn        client_is_hidden;
    ClientGetIpFn         client_get_ip;
    RegisterConnFilterFn  register_conn_filter;
    BroadcastPermRawFn    broadcast_perm_raw;
}

extern fn void* fopen_c(ZString path, ZString mode) @cname("fopen");
extern fn char* fgets_c(char* buf, CInt size, void* stream) @cname("fgets");
extern fn CInt  fclose_c(void* stream) @cname("fclose");
extern fn CInt  fputs_c(ZString s, void* stream) @cname("fputs");

const String PLUGIN_NAME = "Command Usage Stats";
const int MAX_CMDS = 512;
const int CMD_CAP  = 31;

PluginAPI* api;

struct CmdCount { bool used; char[32] name; int len; long count; }
CmdCount[MAX_CMDS] cmds;

// ============================================================
// Helpers
// ============================================================

fn usz put_str(char[] buf, usz n, String s) {
    foreach (char ch : s) { if (n >= buf.len) break; buf[n] = ch; n++; }
    return n;
}
fn usz put_long(char[] buf, usz n, long v) {
    if (v < 0) { n = put_str(buf, n, "-"); v = -v; }
    if (v == 0) return put_str(buf, n, "0");
    char[24] tmp; int t = 0;
    while (v > 0) { tmp[t] = (char)('0' + (int)(v % 10)); t++; v /= 10; }
    while (t > 0) { t--; if (n >= buf.len) break; buf[n] = tmp[t]; n++; }
    return n;
}
fn String nstr(char* buf, int len) {
    if (len <= 0) return "";
    return (String)buf[0..len - 1];
}
fn String cstr(char* buf) {
    int len = 0;
    while (buf[len] != 0) len++;
    if (len == 0) return "";
    return (String)buf[0..len - 1];
}
fn char lower(char ch) {
    if (ch >= 'A' && ch <= 'Z') return (char)(ch + 32);
    return ch;
}

fn void bump(char* name, int len) {
    if (len <= 0) return;
    String w = (String)name[0..len - 1];
    for (int i = 0; i < MAX_CMDS; i++) {
        if (cmds[i].used && nstr(&cmds[i].name[0], cmds[i].len) == w) { cmds[i].count++; return; }
    }
    for (int i = 0; i < MAX_CMDS; i++) {
        if (!cmds[i].used) {
            cmds[i].used = true;
            for (int k = 0; k < len; k++) cmds[i].name[k] = name[k];
            cmds[i].len = len; cmds[i].count = 1;
            return;
        }
    }
}

// ============================================================
// CT hook — count the command word of any "/..." OOC line
// ============================================================

fn bool on_ct(void* c, void* pkt) {
    if (api.packet_get_field_count(pkt) < 2) return false;
    String msg = api.packet_get_field(pkt, 1); // CT field 1 = message
    if (msg.len < 2 || msg[0] != '/') return false;
    char[32] word; int wl = 0;
    for (usz i = 1; i < msg.len; i++) {
        char ch = msg[i];
        if (ch == ' ' || ch == '\t') break;
        if (wl < CMD_CAP) { word[wl] = lower(ch); wl++; }
    }
    if (wl > 0) bump(&word[0], wl);
    return false;
}

// ============================================================
// /cmdstats — top N
// ============================================================

fn void cmd_cmdstats(void* c, String args) {
    int topn = args.trim().len == 0 ? 15 : (args.trim().to_int() ?? 15);
    if (topn < 1) topn = 1;
    if (topn > 30) topn = 30;

    int distinct = 0;
    for (int i = 0; i < MAX_CMDS; i++) { if (cmds[i].used) distinct++; }
    if (distinct == 0) { api.client_send_msg(c, "No commands counted yet."); return; }
    if (topn > distinct) topn = distinct;

    api.client_send_msg(c, "— Most-used commands —");

    bool[MAX_CMDS] taken;
    for (int i = 0; i < MAX_CMDS; i++) taken[i] = false;

    for (int rank = 0; rank < topn; rank++) {
        long best = -1; int bi = -1;
        for (int i = 0; i < MAX_CMDS; i++) {
            if (!cmds[i].used || taken[i]) continue;
            if (cmds[i].count > best) { best = cmds[i].count; bi = i; }
        }
        if (bi < 0) break;
        taken[bi] = true;

        char[80] m; usz n = 0;
        n = put_long(m[..], n, (long)(rank + 1));
        n = put_str(m[..], n, ". /");
        n = put_str(m[..], n, nstr(&cmds[bi].name[0], cmds[bi].len));
        n = put_str(m[..], n, " — ");
        n = put_long(m[..], n, cmds[bi].count);
        api.client_send_msg(c, (String)m[0..n - 1]);
    }
}

// ============================================================
// Persistence — config/cmd_stats.txt  (name<TAB>count)
// ============================================================

fn void load_counts() {
    void* f = fopen_c("config/cmd_stats.txt", "r");
    if (f == null) f = fopen_c("../config/cmd_stats.txt", "r");
    if (f == null) return;
    char[128] line;
    while (fgets_c(&line[0], 128, f) != null) {
        String raw = cstr(&line[0]);
        usz end = raw.len;
        while (end > 0 && (raw[end - 1] == '\n' || raw[end - 1] == '\r')) end--;
        raw = end > 0 ? raw[0..end - 1] : "";
        if (raw.len == 0 || raw[0] == '#') continue;
        usz tab = 0; bool found = false;
        for (usz i = 0; i < raw.len; i++) { if (raw[i] == '\t') { tab = i; found = true; } }
        if (!found || tab == 0 || tab + 1 >= raw.len) continue;
        String name = raw[0..tab - 1];
        long cnt = 0;
        for (usz i = tab + 1; i < raw.len; i++) { if (raw[i] >= '0' && raw[i] <= '9') cnt = cnt * 10 + (long)(raw[i] - '0'); }
        if (name.len > CMD_CAP || cnt <= 0) continue;
        for (int i = 0; i < MAX_CMDS; i++) {
            if (!cmds[i].used) {
                cmds[i].used = true;
                int k = (int)name.len;
                for (int j = 0; j < k; j++) cmds[i].name[j] = name[j];
                cmds[i].len = k; cmds[i].count = cnt;
                break;
            }
        }
    }
    fclose_c(f);
}

fn void save_counts() {
    void* f = fopen_c("config/cmd_stats.txt", "w");
    if (f == null) f = fopen_c("../config/cmd_stats.txt", "w");
    if (f == null) return;
    fputs_c((ZString)"# Whisker command usage counts (name<TAB>count). Auto-saved.\n", f);
    for (int i = 0; i < MAX_CMDS; i++) {
        if (!cmds[i].used) continue;
        char[80] line; usz n = 0;
        n = put_str(line[..], n, nstr(&cmds[i].name[0], cmds[i].len));
        n = put_str(line[..], n, "\t");
        n = put_long(line[..], n, cmds[i].count);
        n = put_str(line[..], n, "\n");
        line[n] = 0;
        fputs_c((ZString)&line[0], f);
    }
    fclose_c(f);
}

// ============================================================
// Plugin interface (exported)
// ============================================================

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return {
        .name        = "Command Usage Stats",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Counts which commands get used most: /cmdstats. Optional.",
    };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    for (int i = 0; i < MAX_CMDS; i++) cmds[i].used = false;
    load_counts();
    api.register_hook("CT", &on_ct, PLUGIN_NAME);
    api.register_command("cmdstats", &cmd_cmdstats, 0, "Top N most-used commands: /cmdstats [N]", PLUGIN_NAME);
    io::printn("[cmd_stats] Loaded. /cmdstats ready.");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    save_counts();
    io::printn("[cmd_stats] Saved + unloaded.");
}
