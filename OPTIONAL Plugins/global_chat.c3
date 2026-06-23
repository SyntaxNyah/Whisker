// Whisker Optional Plugin — Global Chat + PMs [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Adds cross-area social tooling: a server-wide global OOC channel (/g),
// one-to-one private messages (/pm), and a per-player mute for the global
// channel (/toggleglobal). Drop the compiled .dll (Windows) / .so (Linux) into
// your server's plugins/ folder and restart. Optional — your server runs fine
// without it.
//
// This source file is provided as a learning exercise. To compile a C3 plugin
// yourself, follow the Plugin Dev Guide: plugins/PLUGIN DEV GUIDE README.md
//
// ============================================================
// What it does
// ============================================================
//
//   /g <message>        Send an OOC message to EVERY area on the server.
//                       Shows as "[Global] <name>: <message>".
//   /pm <uid> <message> Privately message one player by UID. Both sides see a
//                       "[PM from …]" / "[PM to …]" line; nobody else does.
//   /toggleglobal       Hide or show the global channel for yourself. While
//                       hidden you stop receiving /g messages (you can still
//                       send them).
//
// ============================================================
// Design note — why a roster, and the one core gap it works around
// ============================================================
//
// To honour /toggleglobal, /g must deliver to each recipient individually so it
// can skip the ones who muted — `broadcast_all_msg` can't filter per-player. But
// the Plugin API has no "enumerate all clients" call (only find_client(uid)).
// So this plugin keeps its OWN small roster of online UIDs, built from the
// lifecycle JOIN/LEAVE hooks, and resolves uid -> client with find_client at
// send time. It deliberately stores UIDs (ints), never client pointers — a
// stored pointer to a disconnected client is a use-after-free, whereas
// find_client is null-guarded by the core.
//
// A clean fix upstream would be a `client_get_by_index` / iterate-all getter
// appended to PluginAPI; until then the roster pattern (shared with player_list
// and afk) is the way. Limitation: a /reload empties the roster (and everyone's
// mute state), so right after a reload /g reaches only players the plugin has
// re-seen. To shrink that window the plugin also re-adds a player to the roster
// on their next MS / CT / CH packet, so activity (or a keepalive) re-tracks them
// within seconds — but a silent lurker on a client that sends no keepalive could
// miss global messages until they next speak. This matches the documented
// reload limitation of player_list / afk.

module global_chat;

import std::io;

// ============================================================
// Whisker plugin interface (standalone definitions)
// Must match src/plugin.c3 PluginAPI exactly, field-for-field, in order.
// This is the v4 prefix (copied verbatim from ip_guard.c3); this plugin uses
// register_command, register_hook, register_lifecycle_hook, find_client,
// client_send_msg, client_get_uid and client_display_name.
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
}

// ============================================================
// Constants & state
// ============================================================

const String PLUGIN_NAME = "Global Chat";

// Lifecycle event codes — must match config::PLUGIN_EVENT_* in the server.
const int EVENT_JOIN   = 0;
const int EVENT_LEAVE  = 1;
const int EVENT_UPDATE = 2;

const int MAX_MEMBERS = 1024; // matches the server's client cap

struct Member {
    bool used;
    int  uid;
    bool muted; // hid the global channel via /toggleglobal
}

Member[MAX_MEMBERS] members;
PluginAPI* api;

// ============================================================
// Roster helpers (lockless, matching the rest of the server)
// ============================================================

fn Member* find_member(int uid) {
    for (int i = 0; i < MAX_MEMBERS; i++) {
        if (members[i].used && members[i].uid == uid) return &members[i];
    }
    return null;
}

fn Member* ensure_member(int uid) {
    Member* m = find_member(uid);
    if (m != null) return m;
    for (int i = 0; i < MAX_MEMBERS; i++) {
        if (!members[i].used) {
            members[i].used  = true;
            members[i].uid   = uid;
            members[i].muted = false;
            return &members[i];
        }
    }
    return null; // roster full
}

fn void remove_member(int uid) {
    for (int i = 0; i < MAX_MEMBERS; i++) {
        if (members[i].used && members[i].uid == uid) { members[i].used = false; return; }
    }
}

// ============================================================
// Allocation-free string building (safe on the per-client threads)
// ============================================================

fn usz put_str(char[] buf, usz n, String s) {
    foreach (char ch : s) { if (n >= buf.len) break; buf[n] = ch; n++; }
    return n;
}

// Split "first rest..." → first token + the untouched remainder. Used by /pm so
// the message keeps its spaces and needs no quoting (args_split would break it).
struct Split2 { String first; String rest; }

fn Split2 split_first(String args) {
    String s = args.trim();
    Split2 r;
    if (s.len == 0) { r.first = ""; r.rest = ""; return r; }
    usz i = 0;
    while (i < s.len && s[i] != ' ' && s[i] != '\t') i++;
    r.first = s[0..i - 1];
    while (i < s.len && (s[i] == ' ' || s[i] == '\t')) i++;
    r.rest = i < s.len ? s[i..] : "";
    return r;
}

// ============================================================
// Lifecycle + activity tracking
// ============================================================

fn void on_lifecycle(void* c, int event) {
    int uid = api.client_get_uid(c);
    switch (event) {
        case EVENT_JOIN:   ensure_member(uid);
        case EVENT_UPDATE: ensure_member(uid);
        case EVENT_LEAVE:  remove_member(uid);
        default: break;
    }
}

// Any packet from a client re-confirms they are online — this is what re-tracks
// players after a /reload (which clears the roster). Never consumes.
fn bool on_activity(void* c, void* pkt) {
    ensure_member(api.client_get_uid(c));
    return false;
}

// ============================================================
// Commands
// ============================================================

fn void cmd_g(void* c, String args) {
    String msg = args.trim();
    if (msg.len == 0) {
        api.client_send_msg(c, "Usage: /g <message>  — sends to every area on the server.");
        return;
    }

    int sender_uid = api.client_get_uid(c);
    ensure_member(sender_uid);

    char[512] buf; usz n = 0;
    n = put_str(buf[..], n, "[Global] ");
    n = put_str(buf[..], n, api.client_display_name(c));
    n = put_str(buf[..], n, ": ");
    n = put_str(buf[..], n, msg);
    String line = (String)buf[0..n - 1];

    // Deliver to every tracked, non-muted player except the sender…
    for (int i = 0; i < MAX_MEMBERS; i++) {
        if (!members[i].used) continue;
        if (members[i].uid == sender_uid) continue;
        if (members[i].muted) continue;
        void* t = api.find_client(members[i].uid);
        if (t != null) api.client_send_msg(t, line);
    }
    // …and always echo to the sender so they see it went out (even if muted).
    api.client_send_msg(c, line);
}

fn void cmd_pm(void* c, String args) {
    Split2 sp = split_first(args);
    if (sp.first.len == 0) {
        api.client_send_msg(c, "Usage: /pm <uid> <message>");
        return;
    }
    int target_uid = sp.first.to_int() ?? -1;
    if (target_uid < 0) {
        api.client_send_msg(c, "Invalid UID. Usage: /pm <uid> <message>  (see /getarea for UIDs)");
        return;
    }
    String msg = sp.rest.trim();
    if (msg.len == 0) {
        api.client_send_msg(c, "Usage: /pm <uid> <message>");
        return;
    }

    void* t = api.find_client(target_uid);
    if (t == null) {
        api.client_send_msg(c, "Player not found (they may have disconnected).");
        return;
    }

    // To the recipient.
    char[512] b1; usz n1 = 0;
    n1 = put_str(b1[..], n1, "[PM from ");
    n1 = put_str(b1[..], n1, api.client_display_name(c));
    n1 = put_str(b1[..], n1, "]: ");
    n1 = put_str(b1[..], n1, msg);
    api.client_send_msg(t, (String)b1[0..n1 - 1]);

    // Confirmation back to the sender.
    char[512] b2; usz n2 = 0;
    n2 = put_str(b2[..], n2, "[PM to ");
    n2 = put_str(b2[..], n2, api.client_display_name(t));
    n2 = put_str(b2[..], n2, "]: ");
    n2 = put_str(b2[..], n2, msg);
    api.client_send_msg(c, (String)b2[0..n2 - 1]);
}

fn void cmd_toggleglobal(void* c, String args) {
    Member* m = ensure_member(api.client_get_uid(c));
    if (m == null) { api.client_send_msg(c, "Global roster is full — try again later."); return; }
    m.muted = !m.muted;
    api.client_send_msg(c, m.muted
        ? "Global chat hidden — you will not see /g messages. Use /toggleglobal again to show it."
        : "Global chat shown — you will see /g messages again.");
}

// ============================================================
// Plugin interface (exported)
// ============================================================

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return {
        .name        = "Global Chat",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Global /g chat, /pm private messages, /toggleglobal. Optional — see header.",
    };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    for (int i = 0; i < MAX_MEMBERS; i++) members[i].used = false;

    api.register_command("g", &cmd_g, 0, "Global chat: send to every area", PLUGIN_NAME);
    api.register_command("pm", &cmd_pm, 0, "Private message a player: /pm <uid> <message>", PLUGIN_NAME);
    api.register_command("toggleglobal", &cmd_toggleglobal, 0, "Hide/show global (/g) chat for yourself", PLUGIN_NAME);

    // Roster: built from JOIN/LEAVE, repaired on any packet (survives /reload).
    api.register_lifecycle_hook(&on_lifecycle, PLUGIN_NAME);
    api.register_hook("MS", &on_activity, PLUGIN_NAME);
    api.register_hook("CT", &on_activity, PLUGIN_NAME);
    api.register_hook("CH", &on_activity, PLUGIN_NAME);

    io::printn("[global_chat] Loaded. /g, /pm, /toggleglobal ready.");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    io::printn("[global_chat] Shutting down.");
}
