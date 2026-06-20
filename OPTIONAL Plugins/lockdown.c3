// Whisker Optional Plugin — Lockdown [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A moderator "known players only" switch. While lockdown is ON, any IPID that
// has NEVER joined before is turned away with a friendly "not a ban, try again
// later" notice; everyone who has joined before still gets in. It's a blunt door
// to slam shut during an incident so a bad actor can't keep cycling fresh
// IPs/IPIDs to bypass bans, without locking out your regulars.
//
// Drop the compiled .dll / .so into plugins/ and restart. Optional — your server
// runs fine without it, and not every server wants a lockdown switch.
//
// This source file is provided as a learning exercise. To compile a C3 plugin
// yourself, follow the Plugin Dev Guide: plugins/PLUGIN DEV GUIDE README.md
//
// ============================================================
// How it works
// ============================================================
//
//   * The plugin remembers every IPID that successfully joins, in a persistent
//     file (config/lockdown_known.txt) — your "known players" allowlist. It
//     learns automatically as people play; you don't curate it by hand.
//   * /lockdown on   — only known IPIDs may join. New IPIDs get the lockdown
//                      notice and are disconnected (NOT banned, NOT remembered).
//   * /lockdown off  — back to normal; everyone can join again.
//   * /lockdown status — show whether it's on, time left, and how many IPIDs are
//                        known (so you don't lock yourself out — see below).
//   * /lockdown purge  — wipe the known-IPID list entirely (start fresh).
//   * Optional auto-off timer: /lockdown on 30m turns itself off after 30 min.
//   * When lockdown toggles, a notice is sent in OOC to MODERATORS ONLY.
//
// IMPORTANT — let it learn first. The allowlist only contains IPIDs that joined
// *while this plugin was installed*. If you enable lockdown immediately after
// installing it, the list is empty and you will lock out everyone, including
// your regulars. Install it, let people play for a while, check /lockdown status
// shows a healthy count, then use it. /lockdown on always reports the count it is
// about to enforce as a safety check.
//
// ============================================================
// Why this is an OPTIONAL plugin
// ============================================================
//
// A "known IPIDs only" lockdown is a heavy, situational tool. Private/whitelisted
// servers don't need it; many public servers never want it; and it WILL turn away
// genuine first-time visitors while it's on (that's the point, but it's not for
// everyone). IPID is a per-IP hash, so it's coarse by design — a returning player
// on a new network looks "new." So it ships as opt-in: slam the door when you
// need it, and it doesn't exist for servers that don't.
//
// This complements, not replaces, the core ban list (still the tool for "ban
// this user") and the optional ip_guard plugin ("block this network/country").
//
// ============================================================
// Implementation notes
// ============================================================
//
// One lifecycle JOIN hook does both jobs: gate (during lockdown, kick unknown
// IPIDs with a custom reason via the v6 client_kick_msg) and learn (record new
// IPIDs). Gating at JOIN — not at the raw socket — is deliberate: KK with a
// custom reason is reliably shown post-join, which is what makes the "not a ban"
// message actually reach the user. Volumetric abuse is the core's job (per-IP
// connection rate-limit + flood autoban) and ip_guard's, not lockdown's.
//
// The known set is append-only + linear scan, lockless like the rest of the
// server. A background thread handles the auto-off timer.

module lockdown;

import std::io;

// ============================================================
// Whisker plugin interface (standalone definitions)
// Must match src/plugin.c3 PluginAPI exactly, field-for-field, in order.
// The v6 field client_kick_msg at the very end is what the gate uses.
// ============================================================

struct PluginInfo {
    String name;
    String version;
    String author;
    String description;
}

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

// Extended API (v2)
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

// Lifecycle hooks (v3)
alias LifecycleHook           = fn void(void*, int);
alias RegisterLifecycleHookFn = fn void(LifecycleHook, String);
alias ClientGetOocNameFn      = fn String(void*);
alias ClientIsHiddenFn        = fn bool(void*);

// Connection filtering + raw IP + role-gated broadcast (v4)
alias ClientGetIpFn         = fn String(void*);
alias ConnectionFilter      = fn bool(String);
alias RegisterConnFilterFn  = fn void(ConnectionFilter, String);
alias BroadcastPermRawFn    = fn void(String, ulong);

// Per-client status tag (v5)
alias ClientSetStatusTagFn  = fn void(void*, String);
alias ClientGetStatusTagFn  = fn String(void*);

// Custom-reason kick (v6)
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

    // Extended API (v2)
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

    // Lifecycle hooks + supporting getters (v3)
    RegisterLifecycleHookFn register_lifecycle_hook;
    ClientGetOocNameFn      client_get_ooc_name;
    ClientIsHiddenFn        client_is_hidden;

    // Connection filtering + raw IP + role-gated broadcast (v4)
    ClientGetIpFn         client_get_ip;
    RegisterConnFilterFn  register_conn_filter;
    BroadcastPermRawFn    broadcast_perm_raw;

    // Per-client status tag (v5)
    ClientSetStatusTagFn  client_set_status_tag;
    ClientGetStatusTagFn  client_get_status_tag;

    // Custom-reason kick (v6)
    ClientKickMsgFn       client_kick_msg;
}

// ============================================================
// C interop
// ============================================================

extern fn CInt puts(ZString s);
extern fn CInt fflush(void* stream);
extern fn void* fopen_c(ZString path, ZString mode) @cname("fopen");
extern fn char* fgets_c(char* buf, CInt size, void* stream) @cname("fgets");
extern fn CInt fclose_c(void* stream) @cname("fclose");
extern fn CInt fputs_c(ZString s, void* stream) @cname("fputs");
extern fn long time_c(void* t) @cname("time");

extern fn uint posix_sleep(uint seconds) @cname("sleep") @if(!env::WIN32);
extern fn void win_sleep(uint milliseconds) @cname("Sleep") @if(env::WIN32);

alias RawThreadFn = fn void*(void*);
extern fn CInt   pthread_create(ulong* thread, void* attr, RawThreadFn start, void* arg) @if(!env::WIN32);
extern fn CInt   pthread_detach(ulong thread) @if(!env::WIN32);
extern fn void*  create_thread_win(void* attr, usz stack, RawThreadFn start, void* arg, uint flags, void* id) @cname("CreateThread") @if(env::WIN32);
extern fn CInt   close_handle_win(void* handle) @cname("CloseHandle") @if(env::WIN32);

macro void sleep_sec(uint seconds) {
    $if env::WIN32:
        win_sleep(seconds * 1000);
    $else
        posix_sleep(seconds);
    $endif
}

// ============================================================
// Constants
// ============================================================

const String PLUGIN_NAME = "Lockdown";
const int    EVENT_JOIN  = 0;

const ulong PERM_BAN  = 4;   // commands::PERM_BAN (default gate)

const int MAX_KNOWN   = 131072; // known IPIDs cap (static BSS, lazily paged)
const int IPID_BUF    = 24;     // an IPID hex string + null (<= 16 chars used)
const int BG_TICK_SEC = 5;
const usz POOL        = 1024 * 64; // temp-allocator scope size for the command

// ============================================================
// State
// ============================================================

PluginAPI* api;

bool  ld_active   = false;
long  ld_expiry   = 0;     // unix time when auto-off fires; 0 = indefinite
bool  ld_running  = true;

// Options ([lockdown] in config.toml)
ulong opt_permission   = PERM_BAN;
uint  opt_default_dur  = 0;      // /lockdown on with no duration: 0 = indefinite
bool  opt_announce     = true;   // mods-only OOC notice on toggle
bool  opt_persist      = true;   // save known IPIDs to disk

char[256] cfg_message;           // kick notice for blocked new IPIDs
char[256] path_known;            // resolved known-IPID file path

// Known-IPID allowlist — append-only, linear scan (lockless).
char[IPID_BUF][MAX_KNOWN] known;
int known_n;

// ============================================================
// Small helpers (allocation-free)
// ============================================================

fn usz put_str(char[] buf, usz n, String s) {
    foreach (char ch : s) { if (n >= buf.len) break; buf[n] = ch; n++; }
    return n;
}

fn usz put_int(char[] buf, usz n, long v) {
    if (v < 0) { n = put_str(buf, n, "-"); v = -v; }
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

fn bool is_true(String s) { return s == "true" || s == "1" || s == "yes" || s == "on"; }

// ============================================================
// Known-IPID set
// ============================================================

fn bool is_known(String ipid) {
    for (int i = 0; i < known_n; i++) {
        if (cstr(&known[i][0]) == ipid) return true;
    }
    return false;
}

// Record a new IPID (append, bump count last) and persist it. Caller has already
// checked it isn't known.
fn void add_known(String ipid) {
    if (known_n >= MAX_KNOWN) return;
    if (ipid.len >= (usz)IPID_BUF) return;
    copy_str(ipid, &known[known_n][0], IPID_BUF - 1);
    known_n++; // publish last
    if (opt_persist) {
        void* f = fopen_c((ZString)&path_known[0], "a");
        if (f != null) {
            char[40] line; usz n = 0;
            n = put_str(line[..], n, ipid);
            n = put_str(line[..], n, "\n");
            line[n] = 0;
            fputs_c((ZString)&line[0], f);
            fclose_c(f);
        }
    }
}

fn void load_known() {
    known_n = 0;
    void* f = fopen_c((ZString)&path_known[0], "r");
    if (f == null) return;
    char[64] line;
    while (fgets_c(&line[0], 64, f) != null && known_n < MAX_KNOWN) {
        String s = cstr(&line[0]).trim();
        if (s.len == 0 || s.len >= (usz)IPID_BUF) continue;
        copy_str(s, &known[known_n][0], IPID_BUF - 1);
        known_n++;
    }
    fclose_c(f);
}

fn void purge_known() {
    known_n = 0;
    if (opt_persist) {
        void* f = fopen_c((ZString)&path_known[0], "w"); // truncate
        if (f != null) fclose_c(f);
    }
}

// ============================================================
// Mods-only OOC notice (role-gated, stack-built, any thread)
// ============================================================

fn void notify_mods(String message) {
    if (!opt_announce) return;
    char[320] buf; usz n = 0;
    n = put_str(buf[..], n, "CT#");
    n = put_escaped(buf[..], n, PLUGIN_NAME);
    n = put_str(buf[..], n, "#");
    n = put_escaped(buf[..], n, message);
    n = put_str(buf[..], n, "#1#%");
    api.broadcast_perm_raw((String)buf[0..n - 1], opt_permission);
}

// ============================================================
// Lifecycle JOIN hook — gate unknown IPIDs + learn known ones
// ============================================================

fn void on_lifecycle(void* c, int event) {
    if (event != EVENT_JOIN) return;
    String ipid = api.client_get_ipid(c);
    if (ipid.len == 0) return;

    if (ld_active && !is_known(ipid)) {
        // New IPID during lockdown: turn away with the notice; do NOT record.
        api.client_kick_msg(c, cstr(&cfg_message[0]));
        return;
    }

    if (!is_known(ipid)) add_known(ipid);
}

// ============================================================
// Activation helpers
// ============================================================

fn void activate(long duration_sec) {
    ld_active = true;
    ld_expiry = duration_sec > 0 ? time_c(null) + duration_sec : 0;

    char[256] msg; usz n = 0;
    n = put_str(msg[..], n, "LOCKDOWN ENABLED — only known players can join (");
    n = put_int(msg[..], n, (long)known_n);
    n = put_str(msg[..], n, " known IPIDs).");
    if (duration_sec > 0) {
        n = put_str(msg[..], n, " Auto-off in ");
        n = put_int(msg[..], n, duration_sec / 60);
        n = put_str(msg[..], n, "m.");
    }
    notify_mods((String)msg[0..n - 1]);
}

fn void deactivate(String why) {
    ld_active = false;
    ld_expiry = 0;
    char[160] msg; usz n = 0;
    n = put_str(msg[..], n, "Lockdown disabled");
    if (why.len > 0) { n = put_str(msg[..], n, " ("); n = put_str(msg[..], n, why); n = put_str(msg[..], n, ")"); }
    n = put_str(msg[..], n, " — the server is open again.");
    notify_mods((String)msg[0..n - 1]);
}

// Parse a duration token ("30", "30s", "5m", "2h", "1d"). 0 if none/invalid.
fn long parse_duration(String s) {
    if (s.len == 0) return 0;
    long v = 0;
    usz i = 0;
    while (i < s.len && s[i] >= '0' && s[i] <= '9') { v = v * 10 + (long)(s[i] - '0'); i++; }
    if (i == 0) return 0;
    if (i >= s.len) return v; // bare number = seconds
    char u = s[i];
    if (u >= 'A' && u <= 'Z') u += 32;
    switch (u) {
        case 's': return v;
        case 'm': return v * 60;
        case 'h': return v * 3600;
        case 'd': return v * 86400;
        default:  return v;
    }
}

// ============================================================
// /lockdown command (runs on a client thread — tformat is OK here)
// ============================================================

fn void cmd_lockdown(void* c, String args) {
    String a = args.trim();
    // First whitespace-separated token = subcommand.
    usz sp = 0;
    while (sp < a.len && a[sp] != ' ' && a[sp] != '\t') sp++;
    String sub = sp == 0 ? a : a[0..sp - 1];
    String rest = sp < a.len ? a[sp + 1..].trim() : "";

    if (sub == "on") {
        long dur = rest.len > 0 ? parse_duration(rest) : (long)opt_default_dur;
        activate(dur);
        api.client_send_msg(c, string::tformat(
            "Lockdown ON — %d known IPID(s) will be allowed; new IPIDs are turned away. (Make sure that count covers your regulars.)",
            known_n));
        if (dur > 0) api.client_send_msg(c, string::tformat("Will auto-disable in %ds.", dur));
        return;
    }
    if (sub == "off") {
        deactivate("by moderator");
        api.client_send_msg(c, "Lockdown OFF — the server is open to everyone again.");
        return;
    }
    if (sub == "purge") {
        int before = known_n;
        purge_known();
        api.client_send_msg(c, string::tformat("Purged the known-IPID list (%d removed). It will re-learn as players join.", before));
        return;
    }
    if (sub == "status" || sub.len == 0) {
        if (ld_active) {
            if (ld_expiry > 0) {
                long left = ld_expiry - time_c(null);
                if (left < 0) left = 0;
                api.client_send_msg(c, string::tformat("Lockdown: ON, auto-off in %ds. %d known IPID(s).", left, known_n));
            } else {
                api.client_send_msg(c, string::tformat("Lockdown: ON (indefinite). %d known IPID(s).", known_n));
            }
        } else {
            api.client_send_msg(c, string::tformat("Lockdown: OFF. %d known IPID(s) learned so far.", known_n));
        }
        return;
    }

    api.client_send_msg(c, "Usage: /lockdown on [duration] | off | status | purge");
}

// Command handlers run on the server's per-client thread, where this plugin's
// OWN temp allocator is not initialised — so the string::tformat calls in
// cmd_lockdown would panic. This wrapper opens a temp-allocator scope around it
// (the same approach casing.c3 uses). The JOIN hook and background thread below
// are allocation-free, so only the command needs wrapping.
fn void w_lockdown(void* c, String a) {
    @pool_init(mem, POOL) { cmd_lockdown(c, a); };
}

// ============================================================
// Background thread — auto-off timer
// ============================================================

fn void* background_loop(void* arg) {
    while (ld_running) {
        sleep_sec(BG_TICK_SEC);
        if (ld_active && ld_expiry > 0 && time_c(null) >= ld_expiry) {
            deactivate("timer expired");
        }
    }
    return null;
}

fn void start_background() {
    $if env::WIN32:
        void* h = create_thread_win(null, 0, &background_loop, null, 0, null);
        if (h != null) close_handle_win(h);
    $else
        ulong tid;
        if (pthread_create(&tid, null, &background_loop, null) == 0) pthread_detach(tid);
    $endif
}

// ============================================================
// Config (config.toml [lockdown])
// ============================================================

fn void read_config(String dir) {
    char[300] path; usz pn = 0;
    pn = put_str(path[..], pn, dir);
    pn = put_str(path[..], pn, "/config.toml");
    path[pn] = 0;

    void* f = fopen_c((ZString)&path[0], "r");
    if (f == null) return;

    char[512] line;
    bool in_ld = false;
    while (fgets_c(&line[0], 512, f) != null) {
        String raw = cstr(&line[0]).trim();
        if (raw.len == 0 || raw[0] == '#') continue;
        if (raw[0] == '[') { in_ld = (raw == "[lockdown]" || raw == "[Lockdown]"); continue; }
        if (!in_ld) continue;

        usz eq = 0; bool has_eq = false;
        for (usz i = 0; i < raw.len; i++) { if (raw[i] == '=') { eq = i; has_eq = true; break; } }
        if (!has_eq) continue;
        String key = raw[0..eq - 1].trim();
        String val = raw[eq + 1..].trim();
        // Strip inline '#' comment.
        usz cut = val.len;
        for (usz i = 0; i < val.len; i++) { if (val[i] == '#') { cut = i; break; } }
        val = (cut == 0) ? "" : val[0..cut - 1];
        val = val.trim();
        if (val.len >= 2 && val[0] == '"' && val[val.len - 1] == '"') val = val[1..val.len - 2];

        if (key == "permission")            { opt_permission = parse_ulong(val); }
        else if (key == "default_duration") { opt_default_dur = (uint)parse_duration(val); }
        else if (key == "announce")         { opt_announce = is_true(val); }
        else if (key == "persist")          { opt_persist = is_true(val); }
        else if (key == "message")          { if (val.len > 0) copy_str(val, &cfg_message[0], 255); }
    }
    fclose_c(f);
}

fn ulong parse_ulong(String s) {
    ulong v = 0;
    foreach (char ch : s) { if (ch >= '0' && ch <= '9') v = v * 10 + (ulong)(ch - '0'); }
    return v;
}

fn bool file_exists(ZString path) {
    void* f = fopen_c(path, "r");
    if (f == null) return false;
    fclose_c(f);
    return true;
}

// ============================================================
// Plugin interface (exported)
// ============================================================

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return {
        .name        = "Lockdown",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Mod 'known players only' lockdown switch. Optional — see header.",
    };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    ld_running = true;
    ld_active = false;
    known_n = 0;

    copy_str("The server is in LOCKDOWN right now. This is NOT a ban — only returning players can connect at the moment. Please try again later.",
        &cfg_message[0], 255);

    // Resolve config dir (./config when run from root, ../config from out/).
    String dir = "config";
    if (!file_exists("config/config.toml")) {
        if (file_exists("../config/config.toml")) dir = "../config";
    }
    read_config(dir);

    // Known-IPID file lives next to the config.
    usz pn = 0;
    pn = put_str(path_known[..], pn, dir);
    pn = put_str(path_known[..], pn, "/lockdown_known.txt");
    path_known[pn] = 0;
    load_known();

    api.register_lifecycle_hook(&on_lifecycle, PLUGIN_NAME);
    api.register_command("lockdown", &w_lockdown, opt_permission,
        "Toggle known-players-only lockdown (on/off/status/purge)", PLUGIN_NAME);

    start_background();

    io::printfn("[lockdown] Loaded. %d known IPIDs, permission=%d, announce=%s, persist=%s.",
        known_n, (int)opt_permission, opt_announce ? "on" : "off", opt_persist ? "on" : "off");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    ld_running = false;
    io::printn("[lockdown] Unloaded.");
}
