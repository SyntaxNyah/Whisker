// Whisker Optional Plugin — Idle Kick [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Disconnects players who have been silent for too long, to free up slots on a
// busy or capped server. A player who hasn't sent IC, OOC, or a music/area
// change in `timeout_seconds` is (optionally warned, then) kicked with a friendly
// "this is not a ban, reconnect any time" notice. Drop the compiled .dll / .so
// into plugins/ and restart. Optional — your server runs fine without it.
//
// This source file is provided as a learning exercise. To compile a C3 plugin
// yourself, follow the Plugin Dev Guide: plugins/PLUGIN DEV GUIDE README.md
//
// ============================================================
// What it does
// ============================================================
//
//   * Tracks the last time each player did something (typed IC/OOC, changed
//     music or area). A keepalive alone does NOT count — that's the whole point.
//   * After `timeout_seconds` of silence, the player is disconnected with a
//     custom, non-ban reason (so the AO2 client shows a clear message).
//   * Optionally warns the player `warn_seconds` before the kick, so anyone still
//     watching can type one thing to stay.
//   * Moderators and (optionally) area CMs are exempt — someone running or
//     overseeing a case is doing their job even while quiet.
//
// /idlekick   (moderator only) shows the current settings and how many players
//             are being tracked.
//
// ============================================================
// Why this is an OPTIONAL plugin (and pairs with `afk`)
// ============================================================
//
// Disconnecting idle players is the right call for some servers and the wrong
// call for others, which is exactly why it's opt-in rather than core behaviour:
//
//   * Lurking is normal on a lot of AO servers. Plenty of people leave a client
//     open for hours to watch cases or hang out in a quiet room — kicking them is
//     hostile on a server that isn't slot-constrained.
//   * It only earns its keep when slots are scarce — a small/popular server
//     bumping its player cap, or one running `conn_cap`. On a half-empty server
//     it just annoys regulars.
//   * The timeout is entirely server-specific. Thirty minutes is fine for a
//     busy hub; a slow roleplay server might idle for an hour between lines.
//
// Relationship to `afk`: `afk` only *labels* an away player ("[AFK]"); it never
// removes them. `idle_kick` actually frees the slot. Many servers run `afk`
// (gentle, informational) and never want `idle_kick` (forceful) — so they're
// separate plugins. Run `afk` for the indicator, add `idle_kick` only when you
// genuinely need the capacity back. (They don't share state: a player marked AFK
// is kicked by `idle_kick` on the same silence rule as anyone else.)
//
// ============================================================
// How it works (implementation notes — no background thread)
// ============================================================
//
// A small uid->last-activity roster is driven by the lifecycle JOIN/LEAVE hooks
// (so even a silent lurker is tracked from the moment they join). MS / CT / MC
// packet hooks refresh last-activity (and clear any pending warning) — they
// return false, so they never consume chat or commands. The actual idle check is
// driven by the CH (keepalive) hook rather than a spawned thread: the desktop
// client sends CH roughly every 45s even while completely idle, which is ample
// granularity for a minutes-long timeout — and doing the disconnect inside that
// hook means it runs on the player's OWN server thread, the safest place to close
// a connection. There is therefore no background thread for a /reload to race.
// All work is allocation-free (fixed char[] buffers), per the Threading section
// of the Plugin Dev Guide.
//
// Note: the roster lives only in this plugin, so a /reload empties it. To stay
// fail-safe, the CH hook re-adds any client it doesn't recognise with a FRESH
// timer, so a reload never instantly kicks anyone — everyone simply gets a clean
// `timeout_seconds` window starting from the reload.

module idle_kick;

import std::io;

// ============================================================
// Whisker plugin interface (standalone definitions)
// Must match src/plugin.c3 PluginAPI exactly, field-for-field, in order.
// Copied from an up-to-date optional plugin (poll.c3) — includes every field
// through the v6 tail (client_kick_msg, which this plugin uses).
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

const String PLUGIN_NAME = "Idle Kick";

const int EVENT_JOIN   = 0;
const int EVENT_LEAVE  = 1;
const int EVENT_UPDATE = 2;

const int MAX_PLAYERS = 1024;   // matches the server's client cap

// ============================================================
// Options (config.toml [idle_kick])
// ============================================================

PluginAPI* api;

bool opt_enabled     = true;
int  opt_timeout     = 1800;    // seconds of silence before a kick (30 min)
int  opt_warn        = 60;      // warn this many seconds before the kick (0 = off)
bool opt_exempt_mods = true;
bool opt_exempt_cms  = true;

// Kick reason, kept in a static buffer so the String stays valid for the whole
// process (client_kick_msg sends it immediately, but a static is the safe habit).
char[256] cfg_message;

// ============================================================
// Roster (lockless POD)
// ============================================================

struct Entry {
    bool used;
    int  uid;
    long last_activity;
    bool warned;
}
Entry[MAX_PLAYERS] roster;

fn Entry* find_entry(int uid) {
    for (int i = 0; i < MAX_PLAYERS; i++) {
        if (roster[i].used && roster[i].uid == uid) return &roster[i];
    }
    return null;
}

fn Entry* alloc_entry(int uid) {
    for (int i = 0; i < MAX_PLAYERS; i++) {
        if (!roster[i].used) {
            roster[i].used          = true;
            roster[i].uid           = uid;
            roster[i].last_activity = time_c(null);
            roster[i].warned        = false;
            return &roster[i];
        }
    }
    return null;
}

// ============================================================
// Allocation-free helpers
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

fn String cstr(char* buf) {
    int len = 0;
    while (buf[len] != 0) len++;
    if (len == 0) return "";
    return (String)buf[0..len - 1];
}

fn void copy_str(String src, char* dst, usz max) {
    usz i = 0;
    while (i < src.len && i < max) { dst[i] = src[i]; i++; }
    dst[i] = 0;
}

fn String kick_reason() {
    String r = cstr(&cfg_message[0]);
    if (r.len == 0) return "Disconnected for inactivity. This is not a ban — reconnect any time.";
    return r;
}

// ============================================================
// Activity tracking
// ============================================================

fn void mark_active(int uid) {
    Entry* e = find_entry(uid);
    if (e == null) { alloc_entry(uid); return; }
    e.last_activity = time_c(null);
    e.warned = false;            // reset the warning so a returning-then-idle player is warned again
}

// MS (IC), CT (OOC), MC (music / area change) all count as "doing something".
// Never consume — return false.
fn bool on_activity(void* c, void* pkt) {
    int uid = api.client_get_uid(c);
    if (uid >= 0) mark_active(uid);
    return false;
}

// ============================================================
// The idle check — driven by the CH keepalive (not a thread)
// ============================================================

fn void send_warning(void* c, long secs_left) {
    if (secs_left < 1) secs_left = 1;
    char[160] m;
    usz n = 0;
    n = put_str(m[..], n, "You will be disconnected for inactivity in ");
    n = put_int(m[..], n, (int)secs_left);
    n = put_str(m[..], n, "s. Type anything to stay.");
    api.client_send_msg(c, (String)m[0..n - 1]);
}

fn bool on_keepalive(void* c, void* pkt) {
    if (!opt_enabled) return false;

    int uid = api.client_get_uid(c);
    if (uid < 0) return false;

    Entry* e = find_entry(uid);
    if (e == null) { alloc_entry(uid); return false; } // reload fail-safe: fresh timer

    // Exemptions: never kick a mod, or (optionally) a CM of the current area.
    if (opt_exempt_mods && api.client_is_mod(c)) return false;
    if (opt_exempt_cms && api.area_is_cm(api.client_get_area(c), uid)) return false;

    long idle = time_c(null) - e.last_activity;

    if (idle >= (long)opt_timeout) {
        String reason = kick_reason();
        e.used = false;                    // stop tracking before the socket goes away
        api.client_kick_msg(c, reason);
        io::printfn("[idle_kick] Disconnected UID %d after %ds idle.", uid, (int)idle);
        return true;                       // consume — this client is leaving
    }

    if (opt_warn > 0 && !e.warned) {
        long warn_at = (long)opt_timeout - (long)opt_warn;
        if (warn_at < 0) warn_at = 0;
        if (idle >= warn_at) {
            e.warned = true;
            send_warning(c, (long)opt_timeout - idle);
        }
    }
    return false;
}

// ============================================================
// Lifecycle
// ============================================================

fn void on_lifecycle(void* c, int event) {
    int uid = api.client_get_uid(c);
    if (uid < 0) return;
    switch (event) {
        case EVENT_JOIN:
            alloc_entry(uid);
        case EVENT_LEAVE:
            Entry* e = find_entry(uid);
            if (e != null) e.used = false;
        default:
            break;
    }
}

// ============================================================
// /idlekick — moderator status readout
// ============================================================

fn void cmd_idlekick(void* c, String args) {
    if (!api.client_is_mod(c)) { api.client_send_msg(c, "Only a moderator can use /idlekick."); return; }

    int tracked = 0;
    for (int i = 0; i < MAX_PLAYERS; i++) { if (roster[i].used) tracked++; }

    char[200] m;
    usz n = 0;
    n = put_str(m[..], n, "Idle Kick: ");
    n = put_str(m[..], n, opt_enabled ? "ON" : "OFF");
    n = put_str(m[..], n, ", timeout ");
    n = put_int(m[..], n, opt_timeout);
    n = put_str(m[..], n, "s, warn ");
    n = put_int(m[..], n, opt_warn);
    n = put_str(m[..], n, "s, exempt mods=");
    n = put_str(m[..], n, opt_exempt_mods ? "y" : "n");
    n = put_str(m[..], n, " cms=");
    n = put_str(m[..], n, opt_exempt_cms ? "y" : "n");
    n = put_str(m[..], n, ", tracking ");
    n = put_int(m[..], n, tracked);
    n = put_str(m[..], n, " player(s).");
    api.client_send_msg(c, (String)m[0..n - 1]);
}

// ============================================================
// Config (config.toml [idle_kick])
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
    if (f == null) { io::printn("[idle_kick] No config.toml found, using defaults."); return; }

    char[512] line;
    bool in_section = false;
    while (fgets_c(&line[0], 512, f) != null) {
        String raw = cstr(&line[0]).trim();
        if (raw.len == 0 || raw[0] == '#') continue;
        if (raw[0] == '[') { in_section = (raw == "[idle_kick]"); continue; }
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

        if (key == "enabled")            { opt_enabled = is_true(val); }
        else if (key == "timeout_seconds") { int v = parse_uint(val); if (v > 0) opt_timeout = v; }
        else if (key == "warn_seconds")    { opt_warn = parse_uint(val); }
        else if (key == "exempt_mods")     { opt_exempt_mods = is_true(val); }
        else if (key == "exempt_cms")      { opt_exempt_cms = is_true(val); }
        else if (key == "message")         { if (val.len > 0) copy_str(val, &cfg_message[0], 255); }
    }
    fclose_c(f);

    // A warning longer than the timeout makes no sense — clamp it off.
    if (opt_warn >= opt_timeout) opt_warn = 0;

    io::printn("[idle_kick] Config loaded from config.toml.");
}

// ============================================================
// Plugin interface (exported)
// ============================================================

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return {
        .name        = "Idle Kick",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Disconnects long-idle players to free slots. Optional — see header.",
    };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    for (int i = 0; i < MAX_PLAYERS; i++) roster[i].used = false;
    copy_str("Disconnected for inactivity. This is not a ban — reconnect any time.", &cfg_message[0], 255);

    read_config();

    // Presence tracking (so silent lurkers are tracked from join).
    api.register_lifecycle_hook(&on_lifecycle, PLUGIN_NAME);

    // Activity = IC / OOC / music-or-area change. Keepalive does NOT count.
    api.register_hook("MS", &on_activity, PLUGIN_NAME);
    api.register_hook("CT", &on_activity, PLUGIN_NAME);
    api.register_hook("MC", &on_activity, PLUGIN_NAME);

    // The idle check rides the keepalive — fires even in a silent room, and the
    // kick lands on the client's own thread.
    api.register_hook("CH", &on_keepalive, PLUGIN_NAME);

    api.register_command("idlekick", &cmd_idlekick, 0, "Show idle-kick settings (mod)", PLUGIN_NAME);

    io::printfn("[idle_kick] Loaded. enabled=%s timeout=%ds warn=%ds exempt(mods=%s,cms=%s)",
        opt_enabled ? "on" : "off", opt_timeout, opt_warn,
        opt_exempt_mods ? "y" : "n", opt_exempt_cms ? "y" : "n");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    io::printn("[idle_kick] Unloaded.");
}
