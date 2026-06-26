// Whisker Optional Plugin — Court Timer [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Recess / debate countdown timers for an area, shown on the AO2 client's own
// timer widget. A CM or moderator runs /timer 5:00 and every client in the area
// sees a live countdown tick down to zero — perfect for a recess, a debate
// round, a "you have two minutes to present" deadline, or a speedrun clock.
// Drop the compiled .dll / .so into plugins/ and restart. Optional — your server
// runs fine without it.
//
// This source file is provided as a learning exercise. To compile a C3 plugin
// yourself, follow the Plugin Dev Guide: plugins/PLUGIN DEV GUIDE README.md
//
// ============================================================
// What it does
// ============================================================
//
//   /timer <duration> [label]   start a countdown (CM/mod). e.g. /timer 5:00,
//                               /timer 90, /timer 1h30m, /timer 2:30 Recess
//   /timer pause                pause the countdown (CM/mod)
//   /timer resume               resume a paused countdown (CM/mod)
//   /timer stop                 stop and hide the timer (CM/mod)
//   /timer                      show the current timer's remaining time (anyone)
//
// The live countdown renders on the AO2 client's built-in timer widget. The
// plugin also posts a short OOC line on each action (so people on clients that
// don't show the widget still get the info, and so the room sees who started it).
//
// ============================================================
// How the timer reaches the client (the TI packet)
// ============================================================
//
// AO2 has a server->client "TI" packet that drives the client's timer widget:
//
//     TI#<id>#<type>#<value_ms>#%
//
//   id        which of the client's timers (0-4); 0 is the big central one.
//   type      0 = set + start counting DOWN from value_ms (latency-compensated,
//                 the client then runs the countdown itself — we send ONE packet,
//                 no per-second updates)
//             1 = pause and display value_ms
//             2 = show the widget
//             3 = hide the widget
//   value_ms  the time in MILLISECONDS (only sent for types 0 and 1)
//
// Whisker's core never sends TI itself — this plugin emits it directly with
// broadcast_area_raw. That means it depends on the *client* honouring TI: the
// AO2 2.x desktop client renders it; some forks / older or minimal clients /
// webAO themes without a timer widget will simply ignore it. The OOC echo is the
// fallback that always works. (See the README for the full client-support note.)
//
// ============================================================
// Why this is an OPTIONAL plugin
// ============================================================
//
//   * Most areas never need a timer. It's a tool for structured play — formal
//     debates, timed cases, organised recesses — not for casual chat or freeform
//     roleplay, where a ticking clock on screen is just clutter.
//   * It's client-dependent (see above), so on a server whose players mostly use
//     a client/theme without the widget it would be half-invisible anyway.
//   * Pairs naturally with the `casing` plugin: call a /testify cross-examination
//     or a recess and put a visible clock on it. A pure social server has no use
//     for either — so both are opt-in, and you add the ones your server actually
//     runs.
//
// ============================================================
// How it works (implementation notes)
// ============================================================
//
// Per-area timer state (end time / paused remaining) lives in a static array in
// the plugin; the core knows nothing about it. Starting/pausing/stopping just
// emits the matching TI packets to the area. Expiry ("...timer finished.") is
// announced from the CH (keepalive) and MS (IC) packet hooks — NOT a background
// thread — so there's no thread for a /reload to race: every client sends CH
// roughly every 45s even while idle, which is plenty to notice a countdown that
// has reached zero (the client already shows 0:00 itself; the OOC line is just
// the confirmation). A small uid->area roster from the lifecycle hooks lets a
// player who walks INTO an area mid-countdown get the current time pushed to just
// them (on a real area change only, never on every OOC line). All packet building
// is allocation-free (fixed char[] buffers + the *_raw broadcasts), so every code
// path is safe on the server's client threads — see the Threading section of the
// Plugin Dev Guide.
//
// Note: timer state lives only in this plugin, so a /reload clears any running
// timers (the client widgets keep counting locally until they hit zero, but the
// server forgets them). Restart cleanly rather than /reload if a timer is live.

module court_timer;

import std::io;

// ============================================================
// Whisker plugin interface (standalone definitions)
// Must match src/plugin.c3 PluginAPI exactly, field-for-field, in order.
// Copied from an up-to-date optional plugin (poll.c3) — includes every field
// through the v6 tail (client_kick_msg).
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

// ============================================================
// C interop (config file, wall-clock time)
// ============================================================

extern fn void* fopen_c(ZString path, ZString mode) @cname("fopen");
extern fn char* fgets_c(char* buf, CInt size, void* stream) @cname("fgets");
extern fn CInt  fclose_c(void* stream) @cname("fclose");
extern fn long  time_c(void* t) @cname("time");

// ============================================================
// Constants
// ============================================================

const String PLUGIN_NAME = "Court Timer";

// Lifecycle event codes — must match config::PLUGIN_EVENT_* in the server.
const int EVENT_JOIN   = 0;
const int EVENT_LEAVE  = 1;
const int EVENT_UPDATE = 2;

// TI packet type codes (see header).
const int TI_START = 0;   // set + start counting down from value
const int TI_PAUSE = 1;   // pause + display value
const int TI_SHOW  = 2;   // show widget
const int TI_HIDE  = 3;   // hide widget

const int MAX_AREAS   = 128;    // matches the other per-area plugins
const int MAX_PLAYERS = 1024;   // matches the server's client cap
const int DEFAULT_MAX_DURATION = 86400;  // 24h ceiling, in seconds

// ============================================================
// Options (config.toml [court_timer])
// ============================================================

PluginAPI* api;

int  opt_timer_id     = 0;       // which client timer widget (0-4)
bool opt_ooc_echo     = true;    // post an OOC line on each action
int  opt_max_duration = DEFAULT_MAX_DURATION;

// ============================================================
// Per-area timer state (lockless POD, like the other plugins)
// ============================================================

struct Timer {
    bool shown;        // a timer widget is up in this area
    bool running;      // counting down (vs paused)
    long end_unix;     // unix second it reaches 0   (valid when running)
    long remaining;    // seconds left               (valid when paused)
    bool announced;    // expiry already announced
    char[64] label;    // optional name, e.g. "Recess"
    int  label_len;
}
Timer[MAX_AREAS] area_timer;

// uid -> last known area, so we only push a timer to a player who actually
// CHANGED area (UPDATE also fires on character pick and every OOC line).
struct Pres { bool used; int uid; int area; }
Pres[MAX_PLAYERS] pres;

fn Pres* find_pres(int uid) {
    for (int i = 0; i < MAX_PLAYERS; i++) {
        if (pres[i].used && pres[i].uid == uid) return &pres[i];
    }
    return null;
}

fn void add_pres(int uid, int area) {
    if (find_pres(uid) != null) return;
    for (int i = 0; i < MAX_PLAYERS; i++) {
        if (!pres[i].used) { pres[i].used = true; pres[i].uid = uid; pres[i].area = area; return; }
    }
}

// ============================================================
// Allocation-free helpers (safe on any server thread)
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

fn usz put_long(char[] buf, usz n, long v) {
    if (v < 0) { n = put_str(buf, n, "-"); v = -v; }
    if (v == 0) return put_str(buf, n, "0");
    char[24] tmp; int t = 0;
    while (v > 0) { tmp[t] = (char)('0' + (int)(v % 10)); t++; v /= 10; }
    while (t > 0) { t--; if (n >= buf.len) break; buf[n] = tmp[t]; n++; }
    return n;
}

// AO2 wire escaping for any text that goes inside a packet field.
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

// Render seconds as H:MM:SS (hours omitted when zero), e.g. 305 -> "5:05".
fn usz put_clock(char[] buf, usz n, long secs) {
    if (secs < 0) secs = 0;
    long h = secs / 3600;
    long m = (secs % 3600) / 60;
    long s = secs % 60;
    if (h > 0) {
        n = put_long(buf, n, h);
        n = put_str(buf, n, ":");
        if (m < 10) n = put_str(buf, n, "0");
    }
    n = put_long(buf, n, m);
    n = put_str(buf, n, ":");
    if (s < 10) n = put_str(buf, n, "0");
    n = put_long(buf, n, s);
    return n;
}

fn String cstr(char* buf) {
    int len = 0;
    while (buf[len] != 0) len++;
    if (len == 0) return "";
    return (String)buf[0..len - 1];
}

// ============================================================
// Duration parsing: "M:SS", "H:MM:SS", "90", "1h30m", "45s", "2m"  -> seconds
// Returns 0 on anything unparseable or <= 0.
// ============================================================

fn int parse_duration(String s) {
    s = s.trim();
    if (s.len == 0) return 0;

    bool has_colon = false;
    foreach (char ch : s) { if (ch == ':') { has_colon = true; break; } }

    long total = 0;

    if (has_colon) {
        // clock form: split on ':' into up to 3 numeric segments
        long[3] seg;
        int nseg = 0;
        long cur = 0;
        bool any_digit = false;
        foreach (char ch : s) {
            if (ch == ':') {
                if (nseg >= 3) return 0;
                seg[nseg] = cur; nseg++; cur = 0; any_digit = false;
            } else if (ch >= '0' && ch <= '9') {
                cur = cur * 10 + (long)(ch - '0'); any_digit = true;
            } else {
                return 0;
            }
        }
        if (nseg >= 3) return 0;
        if (!any_digit) return 0;
        seg[nseg] = cur; nseg++;
        if (nseg == 2)      { total = seg[0] * 60 + seg[1]; }
        else if (nseg == 3) { total = seg[0] * 3600 + seg[1] * 60 + seg[2]; }
        else                { return 0; }
    } else {
        // unit form (1h30m / 45s) or a plain integer number of seconds
        long cur = 0;
        bool saw_digit = false;
        bool saw_unit  = false;
        foreach (char ch : s) {
            if (ch >= '0' && ch <= '9') {
                cur = cur * 10 + (long)(ch - '0'); saw_digit = true;
            } else if (ch == 'h' || ch == 'H') {
                total += cur * 3600; cur = 0; saw_unit = true;
            } else if (ch == 'm' || ch == 'M') {
                total += cur * 60; cur = 0; saw_unit = true;
            } else if (ch == 's' || ch == 'S') {
                total += cur; cur = 0; saw_unit = true;
            } else {
                return 0;
            }
        }
        if (!saw_digit) return 0;
        total += cur;            // trailing bare number = seconds (also the plain-integer case)
        if (!saw_unit && total == 0) return 0;
    }

    if (total <= 0) return 0;
    if (total > (long)opt_max_duration) total = (long)opt_max_duration;
    return (int)total;
}

// ============================================================
// Sending the TI packet (allocation-free; broadcast or single client)
// ============================================================

// Build "TI#<id>#<type>#<value_ms>#%" (value omitted unless with_value). Returns
// the byte length written into buf.
fn usz build_ti(char[] buf, int type, long value_ms, bool with_value) {
    usz n = 0;
    n = put_str(buf, n, "TI#");
    n = put_int(buf, n, opt_timer_id);
    n = put_str(buf, n, "#");
    n = put_int(buf, n, type);
    if (with_value) {
        n = put_str(buf, n, "#");
        n = put_long(buf, n, value_ms);
    }
    n = put_str(buf, n, "#%");
    return n;
}

fn void area_ti(int area, int type, long value_ms, bool with_value) {
    char[48] b;
    usz n = build_ti(b[..], type, value_ms, with_value);
    api.broadcast_area_raw(area, (String)b[0..n - 1]);
}

fn void client_ti(void* c, int type, long value_ms, bool with_value) {
    char[48] b;
    usz n = build_ti(b[..], type, value_ms, with_value);
    api.client_send_raw(c, (String)b[0..n - 1]);
}

// Post a plain OOC line to the area (built + escaped on the stack).
fn void area_notice(int area, String text) {
    if (!opt_ooc_echo) return;
    char[400] b;
    usz n = 0;
    n = put_str(b[..], n, "CT#");
    n = put_escaped(b[..], n, PLUGIN_NAME);
    n = put_str(b[..], n, "#");
    n = put_escaped(b[..], n, text);
    n = put_str(b[..], n, "#1#%");
    api.broadcast_area_raw(area, (String)b[0..n - 1]);
}

// ============================================================
// Permission: a moderator, or a CM of this area (same model as poll/casing)
// ============================================================

fn bool can_manage(void* c, int area) {
    if (api.client_is_mod(c)) return true;
    return api.area_is_cm(area, api.client_get_uid(c));
}

// ============================================================
// Helpers to compute remaining seconds for an area's timer
// ============================================================

fn long remaining_secs(Timer* t) {
    if (!t.shown) return 0;
    if (!t.running) return t.remaining;
    long r = t.end_unix - time_c(null);
    return r > 0 ? r : 0;
}

fn String timer_label(Timer* t) {
    if (t.label_len <= 0) return "Timer";
    return (String)t.label[0..t.label_len - 1];
}

// ============================================================
// Expiry announcement — driven by packet hooks, not a thread
// ============================================================

fn void check_expiry(int area) {
    if (area < 0 || area >= MAX_AREAS) return;
    Timer* t = &area_timer[area];
    if (!t.shown || !t.running || t.announced) return;
    if (time_c(null) < t.end_unix) return;

    t.announced = true;
    t.running = false;
    t.remaining = 0;

    char[160] m;
    usz n = 0;
    n = put_str(m[..], n, timer_label(t));
    n = put_str(m[..], n, " finished.");
    area_notice(area, (String)m[0..n - 1]);
}

// MS (IC) and CH (keepalive) both just nudge the expiry check for the sender's
// area and pass through untouched. CH guarantees the check still fires in a
// silent room (clients send it ~every 45s even while idle).
fn bool on_tick(void* c, void* pkt) {
    check_expiry(api.client_get_area(c));
    return false; // never consume
}

// ============================================================
// /timer command
// ============================================================

fn void show_status(void* c, int area) {
    Timer* t = &area_timer[area];
    if (!t.shown) {
        api.client_send_msg(c, "No timer in this area. Start one with: /timer 5:00 [label]");
        return;
    }
    long rem = remaining_secs(t);
    char[200] m;
    usz n = 0;
    n = put_str(m[..], n, timer_label(t));
    n = put_str(m[..], n, ": ");
    n = put_clock(m[..], n, rem);
    n = put_str(m[..], n, t.running ? " remaining (running)." : " (paused).");
    api.client_send_msg(c, (String)m[0..n - 1]);
}

fn void do_start(void* c, int area, String rest) {
    // rest = "<duration> [label]" — first token is the duration, the remainder
    // (if any) is a free-text label.
    String dur_tok = rest;
    String label = "";
    for (usz i = 0; i < rest.len; i++) {
        if (rest[i] == ' ') {
            dur_tok = rest[0..i - 1];
            label = rest[i + 1..].trim();
            break;
        }
    }

    int secs = parse_duration(dur_tok);
    if (secs <= 0) {
        api.client_send_msg(c, "Usage: /timer <duration> [label]   e.g. /timer 5:00, /timer 90, /timer 1h30m Recess");
        return;
    }

    Timer* t = &area_timer[area];
    t.shown = true;
    t.running = true;
    t.end_unix = time_c(null) + (long)secs;
    t.remaining = (long)secs;
    t.announced = false;
    if (label.len > 0) {
        copy_n(&t.label[0], label, 63, &t.label_len);
    } else {
        t.label_len = 0;
    }

    // Show the widget, then start the local countdown (latency-compensated client-side).
    area_ti(area, TI_SHOW, 0, false);
    area_ti(area, TI_START, (long)secs * 1000, true);

    char[200] m;
    usz n = 0;
    n = put_str(m[..], n, timer_label(t));
    n = put_str(m[..], n, " started: ");
    n = put_clock(m[..], n, (long)secs);
    n = put_str(m[..], n, " (");
    n = put_str(m[..], n, api.client_display_name(c));
    n = put_str(m[..], n, ").");
    area_notice(area, (String)m[0..n - 1]);
}

fn void do_pause(void* c, int area) {
    Timer* t = &area_timer[area];
    if (!t.shown || !t.running) { api.client_send_msg(c, "No running timer to pause."); return; }
    long rem = remaining_secs(t);
    t.running = false;
    t.remaining = rem;
    area_ti(area, TI_PAUSE, rem * 1000, true);

    char[160] m;
    usz n = 0;
    n = put_str(m[..], n, timer_label(t));
    n = put_str(m[..], n, " paused at ");
    n = put_clock(m[..], n, rem);
    n = put_str(m[..], n, ".");
    area_notice(area, (String)m[0..n - 1]);
}

fn void do_resume(void* c, int area) {
    Timer* t = &area_timer[area];
    if (!t.shown || t.running) { api.client_send_msg(c, "No paused timer to resume."); return; }
    if (t.remaining <= 0) { api.client_send_msg(c, "Timer has already finished."); return; }
    t.running = true;
    t.announced = false;
    t.end_unix = time_c(null) + t.remaining;
    area_ti(area, TI_START, t.remaining * 1000, true);

    char[160] m;
    usz n = 0;
    n = put_str(m[..], n, timer_label(t));
    n = put_str(m[..], n, " resumed: ");
    n = put_clock(m[..], n, t.remaining);
    n = put_str(m[..], n, " remaining.");
    area_notice(area, (String)m[0..n - 1]);
}

fn void do_stop(void* c, int area) {
    Timer* t = &area_timer[area];
    if (!t.shown) { api.client_send_msg(c, "No timer in this area."); return; }
    t.shown = false;
    t.running = false;
    t.remaining = 0;
    t.label_len = 0;
    area_ti(area, TI_HIDE, 0, false);
    area_notice(area, "Timer stopped.");
}

fn void copy_n(char* dst, String s, int max, int* outlen) {
    int n = (int)s.len; if (n > max) n = max;
    for (int i = 0; i < n; i++) dst[i] = s[i];
    *outlen = n;
}

fn void cmd_timer(void* c, String args) {
    int area = api.client_get_area(c);
    if (area < 0 || area >= MAX_AREAS) { api.client_send_msg(c, "Timers aren't available in this area."); return; }

    String a = args.trim();

    // No args -> show status (anyone may look).
    if (a.len == 0) { show_status(c, area); return; }

    // Split the first word off (the subcommand or the duration).
    String first = a;
    String rest = "";
    for (usz i = 0; i < a.len; i++) {
        if (a[i] == ' ') { first = a[0..i - 1]; rest = a[i + 1..].trim(); break; }
    }

    // Lower-case the first word for sub-command matching.
    char[16] lc;
    int lcn = api.to_lower(first, &lc[0], 16);
    String sub = (String)lc[0..lcn - 1];

    if (sub == "status") { show_status(c, area); return; }

    // Everything past here mutates the timer -> CM/mod only.
    if (!can_manage(c, area)) {
        api.client_send_msg(c, "Only a CM or moderator can control the area timer.");
        return;
    }

    if (sub == "pause")  { do_pause(c, area);  return; }
    if (sub == "resume" || sub == "start") { do_resume(c, area); return; }
    if (sub == "stop" || sub == "off" || sub == "hide" || sub == "cancel") { do_stop(c, area); return; }

    // Otherwise treat the whole argument as "<duration> [label]".
    do_start(c, area, a);
}

// ============================================================
// Lifecycle: keep uid->area current, and sync a timer to anyone who walks in
// ============================================================

fn void on_lifecycle(void* c, int event) {
    int uid = api.client_get_uid(c);
    if (uid < 0) return;

    switch (event) {
        case EVENT_JOIN:
            add_pres(uid, api.client_get_area(c));

        case EVENT_LEAVE:
            Pres* p = find_pres(uid);
            if (p != null) p.used = false;

        case EVENT_UPDATE:
            Pres* p2 = find_pres(uid);
            if (p2 == null) { add_pres(uid, api.client_get_area(c)); return; }
            int newarea = api.client_get_area(c);
            if (newarea == p2.area) return;   // not an area change (char pick / OOC line)
            p2.area = newarea;
            // Push the new area's live timer to just this client.
            if (newarea < 0 || newarea >= MAX_AREAS) return;
            Timer* t = &area_timer[newarea];
            if (!t.shown) return;
            long rem = remaining_secs(t);
            if (rem <= 0) return;
            client_ti(c, TI_SHOW, 0, false);
            client_ti(c, t.running ? TI_START : TI_PAUSE, rem * 1000, true);

        default:
            break;
    }
}

// ============================================================
// Config (config.toml [court_timer])
// ============================================================

fn bool is_true(String s) { return s == "true" || s == "1" || s == "yes" || s == "on"; }

fn int parse_uint(String s) {
    int v = 0;
    foreach (char ch : s) { if (ch >= '0' && ch <= '9') v = v * 10 + (int)(ch - '0'); }
    return v;
}

fn void read_config() {
    void* f = fopen_c("config/config.toml", "r");
    if (f == null) f = fopen_c("../config/config.toml", "r");
    if (f == null) { io::printn("[court_timer] No config.toml found, using defaults."); return; }

    char[512] line;
    bool in_section = false;
    while (fgets_c(&line[0], 512, f) != null) {
        String raw = cstr(&line[0]).trim();
        if (raw.len == 0 || raw[0] == '#') continue;
        if (raw[0] == '[') { in_section = (raw == "[court_timer]"); continue; }
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
        if (val.len >= 2 && val[0] == '"' && val[val.len - 1] == '"') val = val[1..val.len - 2];

        if (key == "timer_id") {
            int v = parse_uint(val);
            if (v >= 0 && v <= 4) opt_timer_id = v;
        } else if (key == "ooc_echo") {
            opt_ooc_echo = is_true(val);
        } else if (key == "max_duration_seconds") {
            int v = parse_uint(val);
            if (v > 0) opt_max_duration = v;
        }
    }
    fclose_c(f);
    io::printn("[court_timer] Config loaded from config.toml.");
}

// ============================================================
// Plugin interface (exported)
// ============================================================

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return {
        .name        = "Court Timer",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Area recess/debate countdown timers (AO2 TI widget). Optional — see header.",
    };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    for (int i = 0; i < MAX_AREAS; i++)  { area_timer[i].shown = false; area_timer[i].label_len = 0; }
    for (int i = 0; i < MAX_PLAYERS; i++) pres[i].used = false;

    read_config();

    api.register_command("timer", &cmd_timer, 0,
        "Area countdown timer: /timer <5:00|90|1h30m> [label] | pause | resume | stop", PLUGIN_NAME);

    // Drive expiry announcements without a background thread.
    api.register_hook("CH", &on_tick, PLUGIN_NAME);
    api.register_hook("MS", &on_tick, PLUGIN_NAME);

    // Track presence so a player entering an area mid-countdown sees the clock.
    api.register_lifecycle_hook(&on_lifecycle, PLUGIN_NAME);

    io::printfn("[court_timer] Loaded. /timer ready (widget id %d, ooc_echo=%s).",
        opt_timer_id, opt_ooc_echo ? "on" : "off");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    // Hide any live widgets so a /reload doesn't leave a frozen clock on screen.
    for (int i = 0; i < MAX_AREAS; i++) {
        if (area_timer[i].shown) {
            area_ti(i, TI_HIDE, 0, false);
            area_timer[i].shown = false;
        }
    }
    io::printn("[court_timer] Unloaded.");
}
