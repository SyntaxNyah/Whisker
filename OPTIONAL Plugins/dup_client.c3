// Whisker Optional Plugin — Duplicate-Client Detector [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Flags (never blocks) when the same IPID joins many times in a short window —
// the signature of a reconnect-spammer, a misbehaving client stuck in a join
// loop, or someone opening a pile of sessions. Staff get a quiet heads-up so they
// can look, without anyone being turned away. Drop the compiled .dll / .so into
// plugins/ and restart. Optional.
//
// This source file is provided as a learning exercise. To compile a C3 plugin
// yourself, follow the Plugin Dev Guide: plugins/PLUGIN DEV GUIDE README.md
//
// ============================================================
// Configuration — config/config.toml [dup_client]
// ============================================================
//
//   enabled            true   master switch
//   threshold          4      joins by one IPID within the window that trip it
//   window_seconds     60     the sliding window
//   cooldown_seconds   120    min gap between alerts about the same IPID
//   alert_permission   4      which permission bit sees the alert (4 = ban)
//
// ============================================================
// Why this is an OPTIONAL plugin — and (almost) zero cost
// ============================================================
//
// Lots of people legitimately reconnect (flaky wifi, client restarts), so this is
// a hint, not a verdict — and it's noise on a server that isn't seeing reconnect
// abuse, so it's opt-in (and alert-only — pair it with `conn_cap` / `ip_guard` /
// `/ban` to actually act). It runs once per *join*, an O(1) update on a small
// per-IPID table; nothing runs on the IC/OOC path.

module dup_client;

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
extern fn long  time_c(void* t) @cname("time");

const String PLUGIN_NAME = "Duplicate-Client Detector";
const ulong  PERM_BAN    = 4;
const int    MAX_TRACK   = 1024;
const int    EVENT_JOIN  = 0;

PluginAPI* api;
bool  opt_enabled    = true;
int   opt_threshold  = 4;
int   opt_window     = 60;
int   opt_cooldown   = 120;
ulong opt_alert_perm = PERM_BAN;

// ============================================================
// Per-IPID sliding window
// ============================================================

struct Track { bool used; char[80] ipid; int ipidlen; long window_start; int count; long last_alert; }
Track[MAX_TRACK] tracks;

fn String tstr(char* buf, int len) {
    if (len <= 0) return "";
    return (String)buf[0..len - 1];
}

fn Track* get_track(String ipid, long now) {
    Track* reuse = null;
    for (int i = 0; i < MAX_TRACK; i++) {
        if (tracks[i].used && tstr(&tracks[i].ipid[0], tracks[i].ipidlen) == ipid) return &tracks[i];
        if (reuse == null) {
            if (!tracks[i].used) { reuse = &tracks[i]; }
            else if (now - tracks[i].window_start > (long)opt_window && now - tracks[i].last_alert > (long)opt_cooldown) { reuse = &tracks[i]; }
        }
    }
    if (reuse != null) {
        reuse.used = true;
        int n = (int)ipid.len; if (n > 79) n = 79;
        for (int k = 0; k < n; k++) reuse.ipid[k] = ipid[k];
        reuse.ipidlen = n;
        reuse.window_start = now; reuse.count = 0; reuse.last_alert = 0;
        return reuse;
    }
    return null;
}

// ============================================================
// Helpers
// ============================================================

fn usz put_str(char[] buf, usz n, String s) {
    foreach (char ch : s) { if (n >= buf.len) break; buf[n] = ch; n++; }
    return n;
}
fn usz put_int(char[] buf, usz n, int v) {
    if (v < 0) { n = put_str(buf, n, "-"); v = -v; }
    if (v == 0) return put_str(buf, n, "0");
    char[12] tmp; int t = 0;
    while (v > 0) { tmp[t] = (char)('0' + (v % 10)); t++; v /= 10; }
    while (t > 0) { t--; if (n >= buf.len) break; buf[n] = tmp[t]; n++; }
    return n;
}
fn usz put_escaped(char[] buf, usz n, String s) {
    foreach (char ch : s) {
        switch (ch) {
            case '#': n = put_str(buf, n, "<num>");
            case '&': n = put_str(buf, n, "<and>");
            case '%': n = put_str(buf, n, "<percent>");
            case '$': n = put_str(buf, n, "<dollar>");
            default:  if (n < buf.len) { buf[n] = ch; n++; }
        }
    }
    return n;
}
fn String cstr(char* buf) {
    int len = 0;
    while (buf[len] != 0) len++;
    if (len == 0) return "";
    return (String)buf[0..len - 1];
}
fn bool is_true(String s) { return s == "true" || s == "1" || s == "yes" || s == "on"; }
fn int parse_int(String s) {
    int v = 0;
    foreach (char ch : s) { if (ch >= '0' && ch <= '9') v = v * 10 + (int)(ch - '0'); }
    return v;
}

fn void alert_staff(String ipid, int count) {
    char[256] b; usz n = 0;
    n = put_str(b[..], n, "CT#");
    n = put_escaped(b[..], n, PLUGIN_NAME);
    n = put_str(b[..], n, "#[Duplicate Client] IPID ");
    n = put_escaped(b[..], n, ipid);
    n = put_str(b[..], n, " joined ");
    n = put_int(b[..], n, count);
    n = put_str(b[..], n, " times in ");
    n = put_int(b[..], n, opt_window);
    n = put_str(b[..], n, "s (allowed, not blocked).#1#%");
    api.broadcast_perm_raw((String)b[0..n - 1], opt_alert_perm);
}

// ============================================================
// JOIN hook
// ============================================================

fn void on_life(void* c, int event) {
    if (event != EVENT_JOIN || !opt_enabled) return;
    String ipid = api.client_get_ipid(c);
    if (ipid.len == 0) return;
    long now = time_c(null);
    Track* t = get_track(ipid, now);
    if (t == null) return;
    if (now - t.window_start >= (long)opt_window) { t.window_start = now; t.count = 0; }
    t.count++;
    if (t.count >= opt_threshold && now - t.last_alert >= (long)opt_cooldown) {
        t.last_alert = now;
        alert_staff(ipid, t.count);
        io::printfn("[dup_client] IPID %s joined %d times in %ds.", ipid, t.count, opt_window);
    }
}

// ============================================================
// Config
// ============================================================

fn void read_config() {
    void* f = fopen_c("config/config.toml", "r");
    if (f == null) f = fopen_c("../config/config.toml", "r");
    if (f == null) { io::printn("[dup_client] No config.toml found, using defaults."); return; }
    char[512] line;
    bool in_section = false;
    while (fgets_c(&line[0], 512, f) != null) {
        String raw = cstr(&line[0]).trim();
        if (raw.len == 0 || raw[0] == '#') continue;
        if (raw[0] == '[') { in_section = (raw == "[dup_client]"); continue; }
        if (!in_section) continue;
        usz eq = 0; bool has_eq = false;
        for (usz i = 0; i < raw.len; i++) { if (raw[i] == '=') { eq = i; has_eq = true; break; } }
        if (!has_eq) continue;
        String key = raw[0..eq - 1].trim();
        String val = raw[eq + 1..].trim();
        usz cut = val.len;
        for (usz i = 0; i < val.len; i++) { if (val[i] == '#') { cut = i; break; } }
        val = (cut == 0) ? "" : val[0..cut - 1];
        val = val.trim();
        if (key == "enabled")             { opt_enabled = is_true(val); }
        else if (key == "threshold")      { int v = parse_int(val); if (v > 0) opt_threshold = v; }
        else if (key == "window_seconds") { int v = parse_int(val); if (v > 0) opt_window = v; }
        else if (key == "cooldown_seconds") { int v = parse_int(val); if (v > 0) opt_cooldown = v; }
        else if (key == "alert_permission") { int v = parse_int(val); if (v > 0) opt_alert_perm = (ulong)v; }
    }
    fclose_c(f);
    io::printn("[dup_client] Config loaded from config.toml.");
}

// ============================================================
// Plugin interface (exported)
// ============================================================

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return {
        .name        = "Duplicate-Client Detector",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Flags an IPID that joins many times fast (no block). Optional.",
    };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    for (int i = 0; i < MAX_TRACK; i++) tracks[i].used = false;
    read_config();
    api.register_lifecycle_hook(&on_life, PLUGIN_NAME);
    io::printfn("[dup_client] Loaded. enabled=%s threshold=%d/%ds cooldown=%ds",
        opt_enabled ? "on" : "off", opt_threshold, opt_window, opt_cooldown);
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    io::printn("[dup_client] Unloaded.");
}
