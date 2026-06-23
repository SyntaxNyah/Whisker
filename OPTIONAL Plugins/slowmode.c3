// Whisker Optional Plugin — Slowmode [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Per-area IC slow mode. When a room's message rate spikes (or a mod turns it on),
// IC messages are spaced out so slow/webAO clients can keep up instead of falling
// behind or skipping. Two behaviours when a message comes too fast:
//   throttle (default): the extra message is dropped with a "slow down" notice.
//   queue (experimental): extra messages are held and released one per `gap`.
// Optional — drop the .dll/.so into plugins/ and restart.
//
// Standalone plugin: see the Plugin Dev Guide (plugins/PLUGIN DEV GUIDE README.md).

module slowmode;

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
alias ClientSetStatusTagFn  = fn void(void*, String);
alias ClientGetStatusTagFn  = fn String(void*);
alias ClientKickMsgFn       = fn void(void*, String);

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
    ClientSetStatusTagFn  client_set_status_tag;
    ClientGetStatusTagFn  client_get_status_tag;
    ClientKickMsgFn       client_kick_msg;
}

const String PLUGIN_NAME = "Slowmode";
const ulong PERM_MODIFY_AREA = 16;
const int MAX_AREAS = 128;
const int QMAX = 24;
const int QSLOT = 768;

struct AreaSlow {
    long window_start; int count;   // rate tracking
    long slow_until;                // auto-slowmode expiry
    bool manual_on; long manual_until;
    long last_allowed;              // throttle spacing
    long last_release;              // queue release spacing
    int qhead; int qcount;
    char[QSLOT][QMAX] q; int[QMAX] qlen;
}
AreaSlow[MAX_AREAS] areas;

PluginAPI* api;
bool opt_enabled    = true;
bool opt_auto       = true;
int  opt_trigger    = 10;  // messages...
int  opt_window     = 5;   // ...within this many seconds triggers slowmode
int  opt_gap        = 2;   // seconds between allowed IC messages while active
int  opt_duration   = 30;  // how long auto-slowmode stays on
bool opt_queue      = false;
bool opt_running    = true;

extern fn long time_c(void* t) @cname("time");
extern fn void* fopen_c(ZString path, ZString mode) @cname("fopen");
extern fn char* fgets_c(char* buf, CInt size, void* stream) @cname("fgets");
extern fn CInt  fclose_c(void* stream) @cname("fclose");
extern fn uint posix_sleep(uint seconds) @cname("sleep") @if(!env::WIN32);
extern fn void win_sleep(uint milliseconds) @cname("Sleep") @if(env::WIN32);
alias RawThreadFn = fn void*(void*);
extern fn CInt   pthread_create(ulong* thread, void* attr, RawThreadFn start, void* arg) @if(!env::WIN32);
extern fn CInt   pthread_detach(ulong thread) @if(!env::WIN32);
extern fn void*  create_thread_win(void* attr, usz stack, RawThreadFn start, void* arg, uint flags, void* id) @cname("CreateThread") @if(env::WIN32);
extern fn CInt   close_handle_win(void* handle) @cname("CloseHandle") @if(env::WIN32);
macro void sleep_sec(uint s) { $if env::WIN32: win_sleep(s * 1000); $else posix_sleep(s); $endif }

fn usz put_str(char[] buf, usz n, String s) { foreach (char ch : s) { if (n >= buf.len) break; buf[n] = ch; n++; } return n; }
fn usz put_uint(char[] buf, usz n, ulong v) {
    if (v == 0) return put_str(buf, n, "0");
    char[20] tmp; int t = 0;
    while (v > 0) { tmp[t] = (char)('0' + (int)(v % 10)); t++; v /= 10; }
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
fn String cstr(char* buf) { int l = 0; while (buf[l] != 0) l++; return l == 0 ? "" : (String)buf[0..l - 1]; }
fn bool is_true(String s) { return s == "true" || s == "1" || s == "yes" || s == "on"; }
fn ulong parse_ulong(String s) { ulong v = 0; foreach (char ch : s) { if (ch >= '0' && ch <= '9') v = v * 10 + (ulong)(ch - '0'); } return v; }

// Rebuild the incoming MS as an outgoing packet (unchanged), for the queue.
fn usz build_ms_asis(char[] buf, void* pkt) {
    int fc = api.packet_get_field_count(pkt);
    usz n = put_str(buf, 0, "MS");
    int upto = fc < 18 ? fc : 18;
    for (int i = 0; i < upto; i++) { n = put_str(buf, n, "#"); n = put_escaped(buf, n, api.packet_get_field(pkt, i)); }
    for (int i = upto; i < 18; i++) n = put_str(buf, n, "#");
    n = put_str(buf, n, "####");
    for (int i = 18; i < fc; i++) { n = put_str(buf, n, "#"); n = put_escaped(buf, n, api.packet_get_field(pkt, i)); }
    n = put_str(buf, n, "#%");
    return n;
}

fn bool active(AreaSlow* a, long now) {
    if (a.manual_on) {
        if (a.manual_until != 0 && now >= a.manual_until) { a.manual_on = false; return now < a.slow_until; }
        return true;
    }
    return now < a.slow_until;
}

fn bool on_ic(void* c, void* pkt) {
    if (!opt_enabled) return false;
    int area = api.client_get_area(c);
    if (area < 0 || area >= MAX_AREAS) return false;
    AreaSlow* a = &areas[area];
    long now = time_c(null);

    // rate tracking → maybe trigger auto-slowmode
    if (now - a.window_start > (long)opt_window) { a.window_start = now; a.count = 0; }
    a.count++;
    if (opt_auto && a.count > opt_trigger) { a.slow_until = now + (long)opt_duration; }

    if (!active(a, now)) { a.last_allowed = now; return false; }

    if (opt_queue) {
        // Hold every message while active so order is preserved; the background
        // thread releases one per `gap`.
        if (a.qcount >= QMAX) { api.client_send_msg(c, "Slow mode: the queue is full, message dropped."); return true; }
        int slot = (a.qhead + a.qcount) % QMAX;
        usz pn = build_ms_asis(a.q[slot][..], pkt);
        a.qlen[slot] = (int)(pn < (usz)QSLOT ? pn : (usz)QSLOT);
        a.qcount++;
        return true; // consume; released later
    }

    // throttle: allow if spaced, else drop with a notice
    if (now - a.last_allowed >= (long)opt_gap) { a.last_allowed = now; return false; }
    long wait = (long)opt_gap - (now - a.last_allowed); if (wait < 1) wait = 1;
    char[80] m; usz n = 0;
    n = put_str(m[..], n, "Slow mode is on — wait ");
    n = put_uint(m[..], n, (ulong)wait);
    n = put_str(m[..], n, "s.");
    api.client_send_msg(c, (String)m[0..n - 1]);
    return true; // consume
}

// Background thread: release queued messages, spaced by `gap`.
fn void* release_loop(void* arg) {
    while (opt_running) {
        long now = time_c(null);
        for (int area = 0; area < MAX_AREAS; area++) {
            AreaSlow* a = &areas[area];
            if (a.qcount > 0 && now - a.last_release >= (long)opt_gap) {
                int slot = a.qhead;
                int len = a.qlen[slot];
                if (len > 0) api.broadcast_area_raw(area, (String)a.q[slot][0..len - 1]);
                a.qhead = (a.qhead + 1) % QMAX;
                a.qcount--;
                a.last_release = now;
            }
        }
        sleep_sec(1);
    }
    return null;
}

fn void start_release() {
    $if env::WIN32:
        void* h = create_thread_win(null, 0, &release_loop, null, 0, null);
        if (h != null) close_handle_win(h);
    $else
        ulong tid;
        if (pthread_create(&tid, null, &release_loop, null) == 0) pthread_detach(tid);
    $endif
}

fn void cmd_slowmode(void* c, String args) {
    int area = api.client_get_area(c);
    if (area < 0 || area >= MAX_AREAS) { api.client_send_msg(c, "Slowmode: bad area."); return; }
    AreaSlow* a = &areas[area];
    String s = args.trim();
    long now = time_c(null);
    if (s.len == 0 || s == "status") {
        bool act = active(a, now);
        char[96] m; usz n = 0;
        n = put_str(m[..], n, "Slow mode: ");
        n = put_str(m[..], n, act ? "ON" : "off");
        n = put_str(m[..], n, ", gap ");
        n = put_uint(m[..], n, (ulong)opt_gap);
        n = put_str(m[..], n, "s, queued ");
        n = put_uint(m[..], n, (ulong)a.qcount);
        api.client_send_msg(c, (String)m[0..n - 1]);
        return;
    }
    if (s == "off") {
        a.manual_on = false; a.manual_until = 0; a.slow_until = 0;
        api.client_send_msg(c, "Slow mode turned off for this area.");
        return;
    }
    // "on" or "on <seconds>" or "<seconds>"
    String num = s;
    if (s.len >= 2 && s[0] == 'o' && s[1] == 'n') { num = s.len > 2 ? s[2..].trim() : ""; }
    a.manual_on = true;
    ulong sec = parse_ulong(num);
    a.manual_until = sec > 0 ? now + (long)sec : 0; // 0 = until /slowmode off
    api.client_send_msg(c, "Slow mode turned on for this area.");
}

fn void load_config(ZString path) {
    void* f = fopen_c(path, "r");
    if (f == null) return;
    char[512] line; int section = 0;
    while (fgets_c(&line[0], 512, f) != null) {
        String raw = cstr(&line[0]).trim();
        if (raw.len == 0 || raw[0] == '#') continue;
        if (raw[0] == '[') { section = (raw == "[slowmode]") ? 1 : 0; continue; }
        if (section != 1) continue;
        usz eq = 0; while (eq < raw.len && raw[eq] != '=') eq++;
        if (eq >= raw.len) continue;
        String k = raw[0..eq - 1].trim();
        String v = raw[eq + 1..].trim();
        if (k == "enabled")           { opt_enabled = is_true(v); }
        else if (k == "auto")         { opt_auto = is_true(v); }
        else if (k == "trigger_count"){ int x = (int)parse_ulong(v); if (x > 0) opt_trigger = x; }
        else if (k == "trigger_window") { int x = (int)parse_ulong(v); if (x > 0) opt_window = x; }
        else if (k == "gap_seconds")  { int x = (int)parse_ulong(v); if (x > 0) opt_gap = x; }
        else if (k == "duration_seconds") { int x = (int)parse_ulong(v); if (x > 0) opt_duration = x; }
        else if (k == "queue")        { opt_queue = is_true(v); }
    }
    fclose_c(f);
}

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return { "Slowmode", "1.0.0", "Whisker Community", "Per-area IC slow mode. Optional." };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    opt_running = true;
    void* probe = fopen_c("config/config.toml", "r");
    if (probe != null) { fclose_c(probe); load_config("config/config.toml"); }
    else { load_config("../config/config.toml"); }
    api.register_hook("MS", &on_ic, PLUGIN_NAME);
    api.register_command("slowmode", &cmd_slowmode, PERM_MODIFY_AREA, "Toggle/inspect area slow mode", PLUGIN_NAME);
    if (opt_queue) start_release();
    io::printfn("[slowmode] Loaded (auto=%s gap=%ds mode=%s).", opt_auto ? "on" : "off", opt_gap, opt_queue ? "queue" : "throttle");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    opt_running = false;
    io::printn("[slowmode] Shutting down.");
}
