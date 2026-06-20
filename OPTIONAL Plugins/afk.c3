// Whisker Optional Plugin — AFK [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Marks idle / away players as AFK and shows it where other players look:
// next to their name in /ga and /gas, and (if the player_list plugin is also
// installed) on the 2.11 player-list widget. Drop the compiled .dll / .so into
// plugins/ and restart. Optional — your server runs fine without it.
//
// This source file is provided as a learning exercise. To compile a C3 plugin
// yourself, follow the Plugin Dev Guide: plugins/PLUGIN DEV GUIDE README.md
//
// ============================================================
// What it does
// ============================================================
//
//   * Auto-AFK: a player who hasn't typed for `timeout_seconds` is marked AFK.
//   * Manual:  /afk marks you AFK immediately.
//   * Return:  typing anything (IC or OOC) clears your AFK automatically.
//   * Shows AFK as a "[AFK]" tag after the player's name in /ga and /gas (via a
//     generic per-client status tag the core renders — so it stays correct even
//     after a /reload), and on the 2.11 player list when player_list is loaded.
//
// ============================================================
// Why this is an OPTIONAL plugin (and why everything is a toggle)
// ============================================================
//
// AFK is genuinely divisive. Plenty of communities think /afk is pointless —
// "you can already tell someone's gone when they stop talking" — and don't want
// an auto-timer quietly tagging lurkers, which is normal behaviour on a lot of
// AO servers. Others love a clear away indicator. So Whisker ships it as opt-in,
// and every part is configurable in config.toml under [afk]:
//
//   auto_afk            true   # the inactivity timer (turn OFF to keep ONLY /afk)
//   timeout_seconds     300    # idle time before auto-AFK
//   manual_command      true   # the /afk command itself
//   playerlist_indicator true  # show [AFK] on the 2.11 player list (needs player_list)
//   gas_indicator       true   # show [AFK] in /ga and /gas
//   announce            false  # broadcast "X is now AFK / back" to the area
//   label               [AFK]  # the tag text
//
// You can run auto-AFK only, manual /afk only, both, or neither — and pick which
// surfaces show the tag. The whole thing is off until you install the plugin.
//
// ============================================================
// How it works (implementation notes)
// ============================================================
//
// A small roster (uid -> last-activity / is-afk) is kept, driven by the core's
// lifecycle hooks (JOIN/LEAVE) so even a silent lurker is tracked from the
// moment they join. MS (IC) and CT (OOC) packet hooks update last-activity and
// clear AFK on any input — they NEVER consume the packet (return false), so
// chat and commands are untouched. An optional background thread runs the
// inactivity timer and keeps the player-list tag refreshed. The /gas tag uses
// the core's per-client status tag (set via the PluginAPI); the player-list tag
// is a PU packet folded into the OOC-name field (the 2.11 list has no dedicated
// status field). State is lockless, matching the rest of the server.
//
// Note: AFK state lives only in this plugin, so a /reload clears it — everyone
// shows not-AFK until the timer re-fires (the same limitation player_list has).

module afk;

import std::io;

// ============================================================
// Whisker plugin interface (standalone definitions)
// Must match src/plugin.c3 PluginAPI exactly, field-for-field, in order.
// The two v5 fields at the very end (client_set/get_status_tag) are what the
// /gas indicator uses.
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
}

// ============================================================
// C interop (config file, threads, sleep, time)
// ============================================================

extern fn CInt puts(ZString s);
extern fn CInt fflush(void* stream);
extern fn void* fopen_c(ZString path, ZString mode) @cname("fopen");
extern fn char* fgets_c(char* buf, CInt size, void* stream) @cname("fgets");
extern fn CInt fclose_c(void* stream) @cname("fclose");
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

fn void bg_log(ZString s) { puts(s); fflush(null); }

// ============================================================
// Constants
// ============================================================

const String PLUGIN_NAME = "AFK";

// Lifecycle event codes — must match config::PLUGIN_EVENT_* in the server.
const int EVENT_JOIN   = 0;
const int EVENT_LEAVE  = 1;
const int EVENT_UPDATE = 2;

// PU player-list data types (AO2 2.11) — must match player_list / the client.
const int PU_OOC_NAME = 0;

const int MAX_PLAYERS  = 1024;  // matches the server's client cap
const int MAX_NAME     = 64;
const int BG_TICK_SEC  = 5;     // background scan / re-assert interval

// ============================================================
// Options (config.toml [afk])
// ============================================================

PluginAPI* api;

bool opt_auto_afk            = true;
uint opt_timeout             = 300;
bool opt_manual_command      = true;
bool opt_playerlist_ind      = true;
bool opt_gas_ind             = true;
bool opt_announce            = false;
bool opt_running             = true;

// Label text, kept in a static buffer so the String we hand to
// client_set_status_tag stays valid for the whole process (the core stores the
// slice, it does not copy).
char[32] cfg_label;

// ============================================================
// Roster
// ============================================================
//
// One entry per joined player. Lockless and POD, matching the rest of the
// server: client-thread hooks write last_activity / is_afk while the background
// thread reads them. On un-AFK we write last_activity BEFORE clearing is_afk,
// and the timer reads last_activity first, so a torn read can only cause a
// harmless one-tick flicker, never a stuck-AFK.

struct Entry {
    bool used;
    int  uid;
    long last_activity;
    bool is_afk;
}

Entry[MAX_PLAYERS] roster;
int afk_count;

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
            roster[i].is_afk        = false;
            return &roster[i];
        }
    }
    return null;
}

// ============================================================
// Small allocation-free helpers (safe on any thread)
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

fn void copy_str(String src, char* dst, usz max) {
    usz i = 0;
    while (i < src.len && i < max) { dst[i] = src[i]; i++; }
    dst[i] = 0;
}

fn String label() { return cstr(&cfg_label[0]); }

// ============================================================
// Display: status tag (/gas) + player-list PU + announce
// ============================================================
//
// All allocation-free so they are safe from the background thread too.

// Player-list update: set the row's OOC-name field to "<ooc> <label>" (AFK) or
// the bare "<ooc>" (back). Broadcast to everyone; clients without the 2.11 list
// (or without player_list installed) ignore it. uid/ooc come from the client.
fn void send_pu_name(void* c, int uid, bool afk) {
    String ooc = api.client_get_ooc_name(c);
    char[256] buf; usz n = 0;
    n = put_str(buf[..], n, "PU#");
    n = put_int(buf[..], n, uid);
    n = put_str(buf[..], n, "#");
    n = put_int(buf[..], n, PU_OOC_NAME);
    n = put_str(buf[..], n, "#");
    n = put_escaped(buf[..], n, ooc);
    if (afk) {
        if (ooc.len > 0) n = put_str(buf[..], n, " ");
        n = put_escaped(buf[..], n, label());
    }
    n = put_str(buf[..], n, "#%");
    api.broadcast_all_raw((String)buf[0..n - 1]);
}

// Area broadcast of a plain OOC notice, built on the stack (no temp allocator).
fn void announce(void* c, bool afk) {
    if (!opt_announce) return;
    String name = api.client_display_name(c);
    int area = api.client_get_area(c);
    char[320] buf; usz n = 0;
    n = put_str(buf[..], n, "CT#");
    n = put_escaped(buf[..], n, PLUGIN_NAME);
    n = put_str(buf[..], n, "#");
    n = put_escaped(buf[..], n, name);
    n = put_str(buf[..], n, afk ? " is now AFK." : " is back.");
    n = put_str(buf[..], n, "#1#%");
    api.broadcast_area_raw(area, (String)buf[0..n - 1]);
}

// Apply the AFK display (tag + player list + announce) for a client.
fn void show_afk(void* c, int uid) {
    if (c == null) return;
    if (opt_gas_ind)        api.client_set_status_tag(c, label());
    if (opt_playerlist_ind) send_pu_name(c, uid, true);
    announce(c, true);
}

// Clear the AFK display.
fn void show_back(void* c, int uid) {
    if (c == null) return;
    if (opt_gas_ind)        api.client_set_status_tag(c, "");
    if (opt_playerlist_ind) send_pu_name(c, uid, false);
    announce(c, false);
}

// ============================================================
// AFK transitions
// ============================================================

fn void set_afk(void* c, Entry* e) {
    if (e == null || e.is_afk) return;
    e.is_afk = true;
    afk_count++;
    show_afk(c, e.uid);
}

// Called from the activity hooks. Writes last_activity FIRST (before clearing
// is_afk) so the timer thread can never observe afk + stale-idle together.
fn void mark_active(void* c, Entry* e) {
    if (e == null) return;
    e.last_activity = time_c(null);
    if (e.is_afk) {
        e.is_afk = false;
        if (afk_count > 0) afk_count--;
        show_back(c, e.uid);
    }
}

// ============================================================
// Packet hooks (MS = IC, CT = OOC) — "typing"
// ============================================================
//
// CRITICAL: these MUST return false. Returning true would CONSUME the packet,
// silently eating every IC / OOC message (and command) on the server. We only
// observe; we never consume.
//
// A command (e.g. /afk, /gas) also arrives as CT, so running any command counts
// as activity and clears your AFK — intentional: you are at the keyboard. For
// /afk specifically the CT hook clears AFK, then command dispatch re-sets it, so
// the net result is still AFK.

fn bool on_typing(void* c, void* pkt) {
    int uid = api.client_get_uid(c);
    if (uid >= 0) mark_active(c, find_entry(uid));
    return false; // never consume
}

// ============================================================
// /afk command
// ============================================================

fn void cmd_afk(void* c, String args) {
    int uid = api.client_get_uid(c);
    Entry* e = find_entry(uid);
    if (e == null) { api.client_send_msg(c, "AFK: you must be in the courtroom first."); return; }
    if (e.is_afk) {
        api.client_send_msg(c, "You are already marked AFK. Type anything to return.");
        return;
    }
    set_afk(c, e);
    api.client_send_msg(c, "You are now marked AFK. Type anything to return.");
}

// ============================================================
// Lifecycle hooks
// ============================================================

fn void on_lifecycle(void* c, int event) {
    int uid = api.client_get_uid(c);
    if (uid < 0) return;

    switch (event) {
        case EVENT_JOIN:
            alloc_entry(uid); // start tracking from join (idle lurkers count)
        case EVENT_LEAVE:
            Entry* e = find_entry(uid);
            if (e != null) {
                if (e.is_afk && afk_count > 0) afk_count--;
                e.used = false;
            }
        case EVENT_UPDATE:
            // Character / area / OOC-name changed. If they're AFK, re-assert the
            // player-list tag (player_list may have just re-sent the bare OOC
            // name on an name change, clearing our marker).
            Entry* e2 = find_entry(uid);
            if (e2 != null && e2.is_afk && opt_playerlist_ind) send_pu_name(c, uid, true);
        default:
            break;
    }
}

// ============================================================
// Background thread — inactivity timer + player-list re-assert
// ============================================================

fn void* background_loop(void* arg) {
    while (opt_running) {
        sleep_sec(BG_TICK_SEC);
        long now = time_c(null);

        for (int i = 0; i < MAX_PLAYERS; i++) {
            if (!roster[i].used) continue;

            // Auto-AFK: read last_activity first (torn-read safety).
            if (opt_auto_afk && !roster[i].is_afk) {
                long idle = now - roster[i].last_activity;
                if (idle >= (long)opt_timeout) {
                    void* c = api.find_client(roster[i].uid);
                    if (c != null) set_afk(c, &roster[i]);
                }
            }
        }

        // Keep the player-list tag alive for AFK players (covers a rare OOC-name
        // change racing player_list's own update). Only when something is AFK.
        if (opt_playerlist_ind && afk_count > 0) {
            for (int i = 0; i < MAX_PLAYERS; i++) {
                if (roster[i].used && roster[i].is_afk) {
                    void* c = api.find_client(roster[i].uid);
                    if (c != null) send_pu_name(c, roster[i].uid, true);
                }
            }
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
// Config (config.toml [afk])
// ============================================================

fn void read_config() {
    void* f = fopen_c("config/config.toml", "r");
    if (f == null) f = fopen_c("../config/config.toml", "r");
    if (f == null) {
        io::printn("[afk] No config.toml found, using defaults.");
        return;
    }

    char[512] line;
    bool in_afk = false;
    while (fgets_c(&line[0], 512, f) != null) {
        String raw = cstr(&line[0]).trim();
        if (raw.len == 0 || raw[0] == '#') continue;

        if (raw[0] == '[') {
            in_afk = (raw == "[afk]" || raw == "[AFK]");
            continue;
        }
        if (!in_afk) continue;

        usz eq = 0;
        bool has_eq = false;
        for (usz i = 0; i < raw.len; i++) { if (raw[i] == '=') { eq = i; has_eq = true; break; } }
        if (!has_eq) continue;
        String key = raw[0..eq - 1].trim();
        String val = raw[eq + 1..].trim();
        // Strip an inline '#' comment (TOML allows `key = value  # note`).
        usz cut = val.len;
        for (usz i = 0; i < val.len; i++) { if (val[i] == '#') { cut = i; break; } }
        val = (cut == 0) ? "" : val[0..cut - 1];
        val = val.trim();
        // Strip surrounding quotes from string values.
        if (val.len >= 2 && val[0] == '"' && val[val.len - 1] == '"') val = val[1..val.len - 2];

        if (key == "auto_afk")                  { opt_auto_afk = is_true(val); }
        else if (key == "timeout_seconds")      { uint v = parse_uint(val); if (v > 0) opt_timeout = v; }
        else if (key == "manual_command")       { opt_manual_command = is_true(val); }
        else if (key == "playerlist_indicator") { opt_playerlist_ind = is_true(val); }
        else if (key == "gas_indicator")        { opt_gas_ind = is_true(val); }
        else if (key == "announce")             { opt_announce = is_true(val); }
        else if (key == "label")                { if (val.len > 0) copy_str(val, &cfg_label[0], 31); }
    }
    fclose_c(f);
    io::printn("[afk] Config loaded from config.toml.");
}

fn bool is_true(String s) { return s == "true" || s == "1" || s == "yes" || s == "on"; }

fn uint parse_uint(String s) {
    uint v = 0;
    foreach (char ch : s) { if (ch >= '0' && ch <= '9') v = v * 10 + (uint)(ch - '0'); }
    return v;
}

// ============================================================
// Plugin interface (exported)
// ============================================================

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return {
        .name        = "AFK",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Away-from-keyboard indicator (auto + /afk). Optional — see header.",
    };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    opt_running = true;
    afk_count = 0;
    for (int i = 0; i < MAX_PLAYERS; i++) roster[i].used = false;

    copy_str("[AFK]", &cfg_label[0], 31); // default label
    read_config();

    // Track presence so even silent lurkers are tracked from join.
    api.register_lifecycle_hook(&on_lifecycle, PLUGIN_NAME);

    // Activity tracking / un-AFK is needed by both auto and manual modes.
    if (opt_auto_afk || opt_manual_command) {
        api.register_hook("MS", &on_typing, PLUGIN_NAME);
        api.register_hook("CT", &on_typing, PLUGIN_NAME);
    }

    if (opt_manual_command) {
        api.register_command("afk", &cmd_afk, 0, "Mark yourself AFK (type to return)", PLUGIN_NAME);
    }

    // The background thread runs the inactivity timer and the player-list
    // re-assert; start it if either needs it.
    if (opt_auto_afk || opt_playerlist_ind) {
        start_background();
    }

    io::printfn("[afk] Loaded. auto=%s (%ds) manual=%s gas=%s playerlist=%s announce=%s",
        opt_auto_afk ? "on" : "off", (int)opt_timeout,
        opt_manual_command ? "on" : "off", opt_gas_ind ? "on" : "off",
        opt_playerlist_ind ? "on" : "off", opt_announce ? "on" : "off");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    opt_running = false;
    // Clear any status tags we set so a /reload doesn't leave a stale "[AFK]"
    // stuck on a still-connected player.
    if (opt_gas_ind) {
        for (int i = 0; i < MAX_PLAYERS; i++) {
            if (roster[i].used && roster[i].is_afk) {
                void* c = api.find_client(roster[i].uid);
                if (c != null) api.client_set_status_tag(c, "");
            }
        }
    }
    io::printn("[afk] Unloaded.");
}
