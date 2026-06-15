// Whisker Optional Plugin — Player List [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Implements the Attorney Online 2.11 **player list**: the live roster the
// 2.11 desktop client shows in the top-left of the courtroom (when the theme
// provides it). Inspired by the player lists in Akashi and Nyathena.
//
// Drop the compiled .dll (Windows) or .so (Linux) into your server's
// plugins/ folder and restart. No configuration needed.
//
// This source file is provided as a learning exercise — if you want to try
// compiling a C3 plugin yourself, follow the Plugin Dev Guide:
//   plugins/PLUGIN DEV GUIDE README.md
//
// ============================================================
// What it does
// ============================================================
//
// When a player joins, the server tells every 2.11 client to add them to the
// list; when they pick a character, change area, or set an OOC name, the list
// updates; when they leave, they are removed. Shadow mods (the SHADOW role,
// "hidden from player lists") receive the list but are never shown on it.
//
// It speaks two AO2 2.11 packets (see docs/AO2_PROTOCOL.md):
//   PR#<uid>#<0=add|1=remove>#%
//   PU#<uid>#<0=ooc_name|1=character|2=showname|3=area>#<data>#%
// Clients older than 2.11 simply ignore unknown headers, so installing this
// is safe even on a mixed-version server — it just does nothing for them.
//
// ============================================================
// Why this is an OPTIONAL plugin (and not built into the core)
// ============================================================
//
// A player list is genuinely divisive, which is exactly why Whisker ships it
// as an opt-in plugin rather than core behaviour:
//
//   * Privacy / lurking. Many AO communities consider it normal to watch a
//     case quietly. A public roster exposes every spectator by name, which
//     some servers (and players) specifically do not want.
//   * Roleplay immersion. Some servers prefer presence to be felt in-character
//     only — no out-of-character meta sidebar listing who is in the room.
//   * Moderation style. On some servers only mods should see who is present;
//     a client-side list that shows everyone to everyone changes that.
//   * Lightweight servers. The feature adds a small broadcast on every join,
//     leave, character swap, area move, and name change. Tiny, but a minimal
//     server may simply not want it.
//   * Client/theme dependent. The list only appears on 2.11+ clients whose
//     theme defines the widget, so for many users it does nothing anyway.
//
// Servers that DO want it just drop in the plugin. Servers that don't, don't.
// That is the whole philosophy of Whisker: features live in plugins, so no
// one has to fork the server (or accept a feature they dislike) to get — or
// avoid — something like this.
//
// ============================================================
// How it works (implementation notes)
// ============================================================
//
// The plugin keeps a small in-memory roster of who is currently listed. It is
// driven entirely by the core's lifecycle hooks (config::PLUGIN_EVENT_*),
// which fire exactly when a client joins, leaves, or changes visible state —
// the events a plain packet hook can't see (a disconnect sends no packet, and
// the client keepalive is only every 45s). See the "Lifecycle Hooks" section
// of the Plugin Dev Guide for the API this is built on.
//
// State is intentionally lockless, matching the rest of the server (the core's
// own broadcast/client-list code doesn't lock either). Worst case under a rare
// race is a duplicated or missing list row — cosmetic, never a crash.

module player_list;

import std::io;

// ============================================================
// Whisker plugin interface (standalone definitions)
// ============================================================
//
// Must match the server's src/plugin.c3 PluginAPI exactly, field-for-field,
// in order. Function-pointer fields we never call still have to be declared
// so the ones we DO call land at the right struct offset. The lifecycle hook
// + two getters at the very end are the v3 additions this plugin relies on.

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

// Lifecycle hooks (v3) — what this plugin is built on.
alias LifecycleHook           = fn void(void*, int);
alias RegisterLifecycleHookFn = fn void(LifecycleHook, String);
alias ClientGetOocNameFn      = fn String(void*);
alias ClientIsHiddenFn        = fn bool(void*);

struct PluginAPI {
    // Registration
    RegisterCommandFn   register_command;
    RegisterHookFn      register_hook;

    // Server
    FindClientFn        find_client;
    BroadcastAreaMsgFn  broadcast_area_msg;
    BroadcastAreaRawFn  broadcast_area_raw;
    BroadcastArupFn     broadcast_arup;
    GetAreaCountFn      get_area_count;

    // Area
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

    // Client
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

    // Lifecycle hooks + supporting getters (v3) — appended, ABI-safe.
    RegisterLifecycleHookFn register_lifecycle_hook;
    ClientGetOocNameFn      client_get_ooc_name;
    ClientIsHiddenFn        client_is_hidden;
}

// ============================================================
// Constants
// ============================================================

// Roster capacity. Matches the server's hard client cap (MAX_SERVER_CLIENTS),
// so the list can never overflow before the server itself does.
const int MAX_PLAYERS  = 1024;

// Per-field snapshot buffer. Character folders and OOC names are short (the
// server caps OOC names at 30), so 64 (including the null terminator) is ample
// and truncation never happens in practice.
const int MAX_NAME     = 64;

// PR update types (AO2 2.11 — must match the client / Akashi).
const int PR_ADD       = 0;
const int PR_REMOVE    = 1;

// PU data-field types (AO2 2.11 — must match the client / Akashi).
const int PU_OOC_NAME  = 0;
const int PU_CHARACTER = 1;
const int PU_SHOWNAME   = 2;  // not tracked server-side yet; reserved
const int PU_AREA       = 3;

// Lifecycle event codes — must match config::PLUGIN_EVENT_* in the server.
const int EVENT_JOIN   = 0;
const int EVENT_LEAVE  = 1;
const int EVENT_UPDATE = 2;

// ============================================================
// Roster
// ============================================================
//
// One entry per currently-listed player. char_name / ooc_name are stored as
// null-terminated snapshots so UPDATE can diff against them and only broadcast
// real changes (the OOC-name hook in particular fires on every OOC line).

struct Entry {
    bool used;
    int  uid;
    char[MAX_NAME] char_name;
    char[MAX_NAME] ooc_name;
    int  area_id;
}

Entry[MAX_PLAYERS] roster;
PluginAPI* api;

// ============================================================
// Roster helpers
// ============================================================

fn Entry* find_entry(int uid) {
    for (int i = 0; i < MAX_PLAYERS; i++) {
        if (roster[i].used && roster[i].uid == uid) return &roster[i];
    }
    return null;
}

fn Entry* alloc_entry(int uid) {
    for (int i = 0; i < MAX_PLAYERS; i++) {
        if (!roster[i].used) {
            roster[i].used         = true;
            roster[i].uid          = uid;
            roster[i].char_name[0] = 0;
            roster[i].ooc_name[0]  = 0;
            roster[i].area_id      = 0;
            return &roster[i];
        }
    }
    return null; // Full — this player just won't be listed.
}

// Copy a String into a null-terminated buffer, capped at MAX_NAME - 1.
fn void store(char* dst, String src) {
    int max = MAX_NAME - 1;
    int n = (int)src.len < max ? (int)src.len : max;
    for (int i = 0; i < n; i++) dst[i] = src[i];
    dst[n] = 0;
}

// Read a null-terminated buffer back as a String (view, no allocation).
fn String load(char* buf) {
    int len = 0;
    while (buf[len] != 0) len++;
    if (len == 0) return "";
    return (String)buf[0..len - 1];
}

// ============================================================
// Packet building
// ============================================================

// IMPORTANT — no temp allocator here. A plugin gets its OWN copy of the C3
// runtime, and its temp allocator is NOT initialised on the server's per-client
// threads, so dstring::temp() / string::tformat() panic ("Use @pool_init()...").
// Every packet is therefore built into a stack buffer with manual formatting
// and handed to the API send functions as a slice view, which they copy
// synchronously. No allocator, no thread-local state — safe on any thread.

// Append a String to buf at offset n (bounds-checked). Returns the new offset.
fn usz put_str(char[] buf, usz n, String s) {
    foreach (char ch : s) {
        if (n >= buf.len) break;
        buf[n] = ch;
        n++;
    }
    return n;
}

// Append a non-negative integer's decimal digits. Returns the new offset.
fn usz put_int(char[] buf, usz n, int v) {
    if (v < 0) {
        n = put_str(buf, n, "-");
        v = -v;
    }
    if (v == 0) return put_str(buf, n, "0");

    char[12] tmp;
    int t = 0;
    while (v > 0) {
        tmp[t] = (char)('0' + (v % 10));
        t++;
        v /= 10;
    }
    while (t > 0) {
        t--;
        if (n >= buf.len) break;
        buf[n] = tmp[t];
        n++;
    }
    return n;
}

// Append s with AO2 wire escaping (# & % $). Returns the new offset.
fn usz put_escaped(char[] buf, usz n, String s) {
    foreach (char ch : s) {
        switch (ch) {
            case '#':  n = put_str(buf, n, "<num>");
            case '&':  n = put_str(buf, n, "<and>");
            case '%':  n = put_str(buf, n, "<percent>");
            case '$':  n = put_str(buf, n, "<dollar>");
            default:
                if (n < buf.len) { buf[n] = ch; n++; }
        }
    }
    return n;
}

// Send a fully-built packet to one client (target != null) or everyone (null).
fn void dispatch_raw(void* target, String pkt) {
    if (target == null) {
        api.broadcast_all_raw(pkt);
    } else {
        api.client_send_raw(target, pkt);
    }
}

// PR#<uid>#<type>#%   (uid/type are integers — no escaping needed)
fn void send_pr(void* target, int uid, int type) {
    char[32] buf;
    usz n = 0;
    n = put_str(buf[..], n, "PR#");
    n = put_int(buf[..], n, uid);
    n = put_str(buf[..], n, "#");
    n = put_int(buf[..], n, type);
    n = put_str(buf[..], n, "#%");
    dispatch_raw(target, (String)buf[0..n - 1]);
}

// PU#<uid>#<type>#<data>#%   (string data is escaped — it can be a player name)
fn void send_pu(void* target, int uid, int type, String data) {
    char[1024] buf;
    usz n = 0;
    n = put_str(buf[..], n, "PU#");
    n = put_int(buf[..], n, uid);
    n = put_str(buf[..], n, "#");
    n = put_int(buf[..], n, type);
    n = put_str(buf[..], n, "#");
    n = put_escaped(buf[..], n, data);
    n = put_str(buf[..], n, "#%");
    dispatch_raw(target, (String)buf[0..n - 1]);
}

// PU with an integer payload (e.g. the area index) — no escaping needed.
fn void send_pu_int(void* target, int uid, int type, int value) {
    char[64] buf;
    usz n = 0;
    n = put_str(buf[..], n, "PU#");
    n = put_int(buf[..], n, uid);
    n = put_str(buf[..], n, "#");
    n = put_int(buf[..], n, type);
    n = put_str(buf[..], n, "#");
    n = put_int(buf[..], n, value);
    n = put_str(buf[..], n, "#%");
    dispatch_raw(target, (String)buf[0..n - 1]);
}

// Emit a full "add this player" sequence for one roster entry: the PR add
// followed by each known field. target == null broadcasts to everyone; a
// non-null target sends only to that client (used to seed a newcomer).
fn void emit_entry(void* target, Entry* e) {
    send_pr(target, e.uid, PR_ADD);
    send_pu(target, e.uid, PU_CHARACTER, load(&e.char_name[0]));
    send_pu_int(target, e.uid, PU_AREA, e.area_id);

    String ooc = load(&e.ooc_name[0]);
    if (ooc.len > 0) {
        send_pu(target, e.uid, PU_OOC_NAME, ooc);
    }
    // PU_SHOWNAME (type 2) is intentionally omitted: Whisker doesn't track a
    // persistent showname yet, so the client falls back to the character name.
}

// Snapshot a client's current visible state into a roster entry.
fn void snapshot(Entry* e, void* client) {
    store(&e.char_name[0], api.client_get_char_name(client));
    store(&e.ooc_name[0], api.client_get_ooc_name(client));
    e.area_id = api.client_get_area(client);
}

// ============================================================
// Lifecycle handling
// ============================================================

fn void handle_join(void* client) {
    int uid = api.client_get_uid(client);
    if (uid < 0) return;

    // Seed the newcomer with everyone already listed. Even a hidden joiner
    // (a shadow mod) gets the full list — they just won't be added to it.
    for (int i = 0; i < MAX_PLAYERS; i++) {
        if (!roster[i].used) continue;
        if (roster[i].uid == uid) continue;
        emit_entry(client, &roster[i]);
    }

    // Hidden clients are never announced to anyone.
    if (api.client_is_hidden(client)) return;

    Entry* e = alloc_entry(uid);
    if (e == null) return; // Roster full; silently skip listing this player.
    snapshot(e, client);

    // Announce the newcomer to everyone (the broadcast includes the newcomer,
    // so they see themselves in the list too — matching AO behaviour).
    emit_entry(null, e);
}

fn void handle_leave(void* client) {
    int uid = api.client_get_uid(client);
    Entry* e = find_entry(uid);
    if (e == null) return; // Never listed (hidden, or roster was full).
    send_pr(null, uid, PR_REMOVE);
    e.used = false;
}

fn void handle_update(void* client) {
    int uid = api.client_get_uid(client);
    if (uid < 0) return;

    Entry* e = find_entry(uid);
    if (e == null) return; // Not listed (hidden or pre-join) — nothing to do.

    // Diff each field against the stored snapshot; broadcast only real changes
    // so the frequent OOC-name event doesn't spam the network.
    String cur_char = api.client_get_char_name(client);
    if (load(&e.char_name[0]) != cur_char) {
        store(&e.char_name[0], cur_char);
        send_pu(null, uid, PU_CHARACTER, cur_char);
    }

    int cur_area = api.client_get_area(client);
    if (cur_area != e.area_id) {
        e.area_id = cur_area;
        send_pu_int(null, uid, PU_AREA, cur_area);
    }

    String cur_ooc = api.client_get_ooc_name(client);
    if (load(&e.ooc_name[0]) != cur_ooc) {
        store(&e.ooc_name[0], cur_ooc);
        send_pu(null, uid, PU_OOC_NAME, cur_ooc);
    }
}

fn void on_lifecycle(void* client, int event) {
    switch (event) {
        case EVENT_JOIN:   handle_join(client);
        case EVENT_LEAVE:  handle_leave(client);
        case EVENT_UPDATE: handle_update(client);
        default:           break;
    }
}

// ============================================================
// Plugin interface (exported)
// ============================================================

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return {
        .name        = "Player List",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "AO2 2.11 live player list (PR/PU). Optional — see header.",
    };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;

    // Start from a clean roster (matters on hot reload).
    for (int i = 0; i < MAX_PLAYERS; i++) roster[i].used = false;

    api.register_lifecycle_hook(&on_lifecycle, "Player List");

    io::printn("[player_list] Player list plugin loaded (AO2 2.11 PR/PU).");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    io::printn("[player_list] Player list plugin unloaded.");
}
