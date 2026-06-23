// Whisker Optional Plugin — Modcall Guard [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Rate-limits modcalls (the ZZ packet) per player and suppresses duplicate
// spam, so a single user mashing "Call Mod" can't bury staff in notifications.
// Optional — drop the .dll/.so into plugins/ and restart.
//
// Standalone plugin: see the Plugin Dev Guide (plugins/PLUGIN DEV GUIDE README.md).

module modcall_guard;

import std::io;

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

const String PLUGIN_NAME = "Modcall Guard";
const int MAX_TRACK = 1024;

struct Caller { bool used; int uid; long last; char[64] reason; int rlen; }
Caller[MAX_TRACK] callers;

PluginAPI* api;
bool opt_enabled  = true;
int  opt_cooldown = 30;   // seconds between a player's modcalls
bool opt_dedupe   = true; // suppress an identical reason repeated soon after
bool opt_notify   = true; // tell the player why their modcall was held

extern fn long time_c(void* t) @cname("time");

fn usz put_str(char[] buf, usz n, String s) {
    foreach (char ch : s) { if (n >= buf.len) break; buf[n] = ch; n++; }
    return n;
}
fn usz put_uint(char[] buf, usz n, ulong v) {
    if (v == 0) return put_str(buf, n, "0");
    char[20] tmp; int t = 0;
    while (v > 0) { tmp[t] = (char)('0' + (int)(v % 10)); t++; v /= 10; }
    while (t > 0) { t--; if (n >= buf.len) break; buf[n] = tmp[t]; n++; }
    return n;
}
fn String cstr(char* buf) {
    int len = 0;
    while (buf[len] != 0) len++;
    return len == 0 ? "" : (String)buf[0..len - 1];
}
fn bool is_true(String s) { return s == "true" || s == "1" || s == "yes" || s == "on"; }
fn ulong parse_ulong(String s) {
    ulong v = 0;
    foreach (char ch : s) { if (ch >= '0' && ch <= '9') v = v * 10 + (ulong)(ch - '0'); }
    return v;
}

fn Caller* track(int uid) {
    Caller* free = null;
    for (int i = 0; i < MAX_TRACK; i++) {
        if (callers[i].used && callers[i].uid == uid) return &callers[i];
        if (free == null && !callers[i].used) free = &callers[i];
    }
    if (free != null) { free.used = true; free.uid = uid; free.last = 0; free.rlen = 0; }
    return free;
}

fn bool same_reason(Caller* cl, String reason) {
    if (cl.rlen != (int)reason.len) return false;
    for (int i = 0; i < cl.rlen; i++) { if (cl.reason[i] != reason[i]) return false; }
    return true;
}

fn void store_reason(Caller* cl, String reason) {
    int n = (int)reason.len; if (n > 63) n = 63;
    for (int i = 0; i < n; i++) cl.reason[i] = reason[i];
    cl.rlen = n;
}

fn bool on_modcall(void* c, void* pkt) {
    if (!opt_enabled) return false;
    int  uid    = api.client_get_uid(c);
    long now    = time_c(null);
    String reason = api.packet_get_field_count(pkt) > 0 ? api.packet_get_field(pkt, 0) : "";

    Caller* cl = track(uid);
    if (cl == null) return false; // table full → fail open

    if (cl.last != 0) {
        long elapsed = now - cl.last;
        bool on_cooldown = elapsed < (long)opt_cooldown;
        bool dup = opt_dedupe && same_reason(cl, reason) && elapsed < (long)opt_cooldown * 3;
        if (on_cooldown || dup) {
            if (opt_notify) {
                char[96] m; usz n = 0;
                if (dup && !on_cooldown) {
                    n = put_str(m[..], n, "Duplicate modcall held — staff have already been notified.");
                } else {
                    long wait = (long)opt_cooldown - elapsed; if (wait < 1) wait = 1;
                    n = put_str(m[..], n, "Modcall on cooldown — wait ");
                    n = put_uint(m[..], n, (ulong)wait);
                    n = put_str(m[..], n, "s. Staff have already been alerted.");
                }
                api.client_send_msg(c, (String)m[0..n - 1]);
            }
            return true; // consume → suppress this modcall
        }
    }

    cl.last = now;
    store_reason(cl, reason);
    return false; // allow it through to the core (and any later hooks)
}

// --- config: config/config.toml [modcall_guard] ---
extern fn void* fopen_c(ZString path, ZString mode) @cname("fopen");
extern fn char* fgets_c(char* buf, CInt size, void* stream) @cname("fgets");
extern fn CInt  fclose_c(void* stream) @cname("fclose");

fn void load_config(ZString path) {
    void* f = fopen_c(path, "r");
    if (f == null) return;
    char[512] line; int section = 0;
    while (fgets_c(&line[0], 512, f) != null) {
        String raw = cstr(&line[0]).trim();
        if (raw.len == 0 || raw[0] == '#') continue;
        if (raw[0] == '[') { section = (raw == "[modcall_guard]") ? 1 : 0; continue; }
        if (section != 1) continue;
        usz eq = 0; while (eq < raw.len && raw[eq] != '=') eq++;
        if (eq >= raw.len) continue;
        String k = raw[0..eq - 1].trim();
        String v = raw[eq + 1..].trim();
        if (k == "enabled")          { opt_enabled = is_true(v); }
        else if (k == "cooldown_seconds") { int x = (int)parse_ulong(v); if (x > 0) opt_cooldown = x; }
        else if (k == "dedupe")      { opt_dedupe = is_true(v); }
        else if (k == "notify")      { opt_notify = is_true(v); }
    }
    fclose_c(f);
}

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return { "Modcall Guard", "1.0.0", "Whisker Community", "Rate-limit/dedupe modcalls. Optional." };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    for (int i = 0; i < MAX_TRACK; i++) callers[i].used = false;
    void* probe = fopen_c("config/config.toml", "r");
    if (probe != null) { fclose_c(probe); load_config("config/config.toml"); }
    else { load_config("../config/config.toml"); }
    api.register_hook("ZZ", &on_modcall, PLUGIN_NAME);
    io::printfn("[modcall_guard] Loaded (cooldown=%ds dedupe=%s).", opt_cooldown, opt_dedupe ? "on" : "off");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    io::printn("[modcall_guard] Shutting down.");
}
