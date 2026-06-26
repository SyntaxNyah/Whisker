// Whisker Optional Plugin — Perf Stats [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A quick server health readout for operators: uptime, current and peak player
// counts, area count, and the process's memory use. Drop the compiled .dll / .so
// into plugins/ and restart. Optional.
//
// This source file is provided as a learning exercise. To compile a C3 plugin
// yourself, follow the Plugin Dev Guide: plugins/PLUGIN DEV GUIDE README.md
//
// ============================================================
// What it does
// ============================================================
//
//   /perf      show uptime, players (now / peak), areas, and memory use
//
// ============================================================
// Why this is an OPTIONAL plugin — and zero passive cost
// ============================================================
//
// Stats are handy on a server you operate and pointless clutter on one you don't,
// so it's opt-in. It registers one command and a lifecycle hook that only updates
// a peak-players counter on join (a single integer compare); it has **no packet
// hooks**, so nothing runs on the chat path. Memory is read on demand from the OS
// when you type /perf, never in a loop.

module perf_stats;

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

extern fn long time_c(void* t) @cname("time");

// Process memory — platform specific.
extern fn void* fopen_c(ZString path, ZString mode) @cname("fopen") @if(!env::WIN32);
extern fn char* fgets_c(char* buf, CInt size, void* stream) @cname("fgets") @if(!env::WIN32);
extern fn CInt  fclose_c(void* stream) @cname("fclose") @if(!env::WIN32);

struct ProcMemCounters {
    uint cb;
    uint page_fault_count;
    usz  peak_working_set;
    usz  working_set;
    usz  quota_peak_paged_pool;
    usz  quota_paged_pool;
    usz  quota_peak_nonpaged_pool;
    usz  quota_nonpaged_pool;
    usz  pagefile_usage;
    usz  peak_pagefile_usage;
}
extern fn void* get_current_process() @cname("GetCurrentProcess") @if(env::WIN32);
extern fn int k32_proc_mem(void* proc, ProcMemCounters* c, uint cb) @cname("K32GetProcessMemoryInfo") @if(env::WIN32);

const String PLUGIN_NAME = "Perf Stats";
const int EVENT_JOIN = 0;

PluginAPI* api;
long start_time;
int  peak_players;

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
fn String cstr(char* buf) {
    int len = 0;
    while (buf[len] != 0) len++;
    if (len == 0) return "";
    return (String)buf[0..len - 1];
}

// Resident set size in bytes, or -1 if unavailable.
fn long rss_bytes() {
    $if env::WIN32:
        ProcMemCounters pmc;
        // cb must equal sizeof(PROCESS_MEMORY_COUNTERS): DWORD+DWORD + 8×SIZE_T = 72 on x64.
        uint pmc_size = 72;
        pmc.cb = pmc_size;
        if (k32_proc_mem(get_current_process(), &pmc, pmc_size) != 0) {
            return (long)pmc.working_set;
        }
        return -1;
    $else
        void* f = fopen_c("/proc/self/statm", "r");
        if (f == null) return -1;
        char[128] line;
        long rss = -1;
        if (fgets_c(&line[0], 128, f) != null) {
            String s = cstr(&line[0]);
            int tok = 0; long val = 0; bool indig = false;
            for (usz i = 0; i <= s.len; i++) {
                char ch = i < s.len ? s[i] : ' ';
                if (ch >= '0' && ch <= '9') { val = val * 10 + (long)(ch - '0'); indig = true; }
                else if (indig) {
                    tok++;
                    if (tok == 2) { rss = val * 4096; break; }  // 2nd field = resident pages
                    val = 0; indig = false;
                }
            }
        }
        fclose_c(f);
        return rss;
    $endif
}

fn void update_peak() {
    int p = api.get_player_count();
    if (p > peak_players) peak_players = p;
}

// ============================================================
// /perf
// ============================================================

fn void cmd_perf(void* c, String args) {
    update_peak();
    long up = time_c(null) - start_time;
    if (up < 0) up = 0;
    long d = up / 86400;
    long h = (up % 86400) / 3600;
    long m = (up % 3600) / 60;
    long s = up % 60;

    char[256] b; usz n = 0;
    n = put_str(b[..], n, "Server: up ");
    if (d > 0) { n = put_long(b[..], n, d); n = put_str(b[..], n, "d "); }
    if (d > 0 || h > 0) { n = put_long(b[..], n, h); n = put_str(b[..], n, "h "); }
    n = put_long(b[..], n, m); n = put_str(b[..], n, "m ");
    n = put_long(b[..], n, s); n = put_str(b[..], n, "s");

    n = put_str(b[..], n, " | players ");
    n = put_long(b[..], n, (long)api.get_player_count());
    n = put_str(b[..], n, " (peak ");
    n = put_long(b[..], n, (long)peak_players);
    n = put_str(b[..], n, ") | areas ");
    n = put_long(b[..], n, (long)api.get_area_count());

    long rss = rss_bytes();
    if (rss >= 0) {
        n = put_str(b[..], n, " | mem ");
        n = put_long(b[..], n, rss / (1024 * 1024));
        n = put_str(b[..], n, " MB");
    }
    api.client_send_msg(c, (String)b[0..n - 1]);
}

fn void on_life(void* c, int event) {
    if (event == EVENT_JOIN) update_peak();
}

// ============================================================
// Plugin interface (exported)
// ============================================================

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return {
        .name        = "Perf Stats",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Server health readout: /perf. Optional.",
    };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    start_time = time_c(null);
    peak_players = 0;
    update_peak();

    api.register_lifecycle_hook(&on_life, PLUGIN_NAME);
    api.register_command("perf", &cmd_perf, 0, "Show server uptime, players, areas, memory", PLUGIN_NAME);

    io::printn("[perf_stats] Loaded. /perf ready.");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    io::printn("[perf_stats] Unloaded.");
}
