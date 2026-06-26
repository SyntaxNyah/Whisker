// Whisker AO2 Server — Plugin System
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The plugin system is the answer to AO server fragmentation.
// Instead of forking the whole server to add features, write
// a plugin. Plugins are shared libraries (.so / .dll) that
// export a standard interface. Drop them in plugins/ and they
// load at startup.
//
// Plugin Development Guide: see plugins/README.md
//
// == Plugin Interface ==
//
// Every plugin must export these C-callable functions:
//
//   whisker_plugin_info()     → returns name, version, author
//   whisker_plugin_init(api)  → called once at startup
//   whisker_plugin_shutdown() → called on server shutdown
//
// Plugins can:
//   - Register new OOC commands
//   - Hook into packet processing (before/after)
//   - Send messages to clients
//   - Access server state through the API
//
// Plugins CANNOT modify core server code. This is by design.
// If you need something the API doesn't expose, open an issue.

module whisker::plugin;

import whisker::client;
import whisker::protocol;
import whisker::plugin_services;
import std::io;

// ============================================================
// C interop — shared library loading (platform-conditional)
// ============================================================

// Shared library loading — Windows
extern fn void* load_library_a(char* path) @cname("LoadLibraryA") @if(env::WIN32);
extern fn void* get_proc_address(void* handle, char* name) @cname("GetProcAddress") @if(env::WIN32);
extern fn int free_library(void* handle) @cname("FreeLibrary") @if(env::WIN32);

// Shared library loading — POSIX
extern fn void* dlopen(char* path, int flags) @if(!env::WIN32);
extern fn void* dlsym(void* handle, char* name) @if(!env::WIN32);
extern fn int dlclose(void* handle) @if(!env::WIN32);
extern fn char* dlerror() @if(!env::WIN32);

const int RTLD_NOW = 2;

// Directory scanning — Windows (Win32 FindFirstFile).
// We deliberately do NOT use _popen("dir")/_pclose here: under the debug CRT
// (ucrtbased) _pclose can trip a breakpoint and take the whole server down
// during the plugin scan. FindFirstFile enumerates the directory directly —
// no child process, no pipe, no CRT pclose.
const int MAX_PATH_LEN = 260;

struct Win32FileTime {
    uint low;
    uint high;
}

// Mirrors WIN32_FIND_DATAA exactly (field order + sizes must match).
struct Win32FindDataA {
    uint               attributes;
    Win32FileTime      creation_time;
    Win32FileTime      last_access_time;
    Win32FileTime      last_write_time;
    uint               file_size_high;
    uint               file_size_low;
    uint               reserved0;
    uint               reserved1;
    char[MAX_PATH_LEN] file_name;        // cFileName (null-terminated)
    char[14]           alternate_name;   // cAlternateFileName
}

extern fn void* find_first_file_a(char* pattern, Win32FindDataA* data) @cname("FindFirstFileA") @if(env::WIN32);
extern fn int   find_next_file_a(void* handle, Win32FindDataA* data) @cname("FindNextFileA") @if(env::WIN32);
extern fn int   find_close(void* handle) @cname("FindClose") @if(env::WIN32);

// Directory scanning — POSIX (popen("ls") works fine here)
extern fn void* popen(char* cmd, char* mode) @if(!env::WIN32);
extern fn int pclose(void* stream) @if(!env::WIN32);
extern fn char* fgets(char* buf, int n, void* stream) @if(!env::WIN32);

// ============================================================
// Plugin export function pointer types
// ============================================================

alias PluginInfoFn     = fn PluginInfo();
alias PluginInitFn     = fn void(PluginAPI*);
alias PluginShutdownFn = fn void();

// ============================================================
// Plugin info — what the plugin tells us about itself
// ============================================================

struct PluginInfo {
    String name;
    String version;
    String author;
    String description;
}

// ============================================================
// Handler types — plugins register these
// ============================================================

// Command handler. Client pointer is void* for ABI compatibility
// with standalone plugins (.dll/.so).
alias CommandHandler = fn void(void* client, String args);

// Packet hook. Returns true to consume the packet (stop processing).
// Both pointers are void* for standalone plugin compatibility.
alias PacketHook = fn bool(void* client, void* packet);

// ============================================================
// Plugin API function pointer types
// ============================================================
//
// These define the function signatures for the PluginAPI struct.
// The server fills these in with wrapper functions during init.
// Standalone plugins call these to interact with the server.

// -- Registration --
alias ApiRegisterCommandFn = fn void(String name, CommandHandler handler, ulong perms, String desc, String plugin_name);
alias ApiRegisterHookFn    = fn void(String header, PacketHook hook, String plugin_name);

// -- Server operations --
alias ApiFindClientFn        = fn void*(int uid);
alias ApiBroadcastAreaMsgFn  = fn void(int area_id, String msg);
alias ApiBroadcastAreaRawFn  = fn void(int area_id, String data);
alias ApiBroadcastArupFn     = fn void(int arup_type);
alias ApiGetAreaCountFn      = fn int();

// -- Area operations --
alias ApiAreaIsCmFn         = fn bool(int area_id, int uid);
alias ApiAreaAddCmFn        = fn void(int area_id, int uid);
alias ApiAreaRemoveCmFn     = fn void(int area_id, int uid);
alias ApiAreaCmCountFn      = fn int(int area_id);
alias ApiAreaClearCmsFn     = fn void(int area_id);
alias ApiAreaUninviteFn     = fn void(int area_id, int uid);
alias ApiAreaSetStatusFn    = fn void(int area_id, int status);
alias ApiAreaGetStatusFn    = fn int(int area_id);
alias ApiAreaGetNameFn      = fn String(int area_id);
alias ApiAreaSetSongFn      = fn void(int area_id, String song, int player_uid);
alias ApiForceMoveFn        = fn void(void* client, int new_area_id);

// -- Client operations --
alias ApiClientSendMsgFn     = fn void(void* client, String msg);
alias ApiClientSendRawFn     = fn void(void* client, String data);
alias ApiClientGetUidFn      = fn int(void* client);
alias ApiClientGetAreaFn     = fn int(void* client);
alias ApiClientIsModFn       = fn bool(void* client);
alias ApiClientDisplayNameFn = fn String(void* client);
alias ApiClientGetCharIdFn   = fn int(void* client);
alias ApiClientGetShownameFn = fn String(void* client);
alias ApiClientGetCharNameFn = fn String(void* client);
alias ApiClientIsJoinedFn    = fn bool(void* client);
alias ApiClientSetPositionFn = fn void(void* client, String pos);

// -- Extended API (v2) --
// New fields appended at the end for backwards compatibility.
// Existing plugins compiled against v1 still work — they just
// don't see these fields.

// Broadcasting to all players
alias ApiBroadcastAllMsgFn   = fn void(String msg);
alias ApiBroadcastAllRawFn   = fn void(String data);

// Player counts
alias ApiGetPlayerCountFn      = fn int();
alias ApiGetAreaPlayerCountFn  = fn int(int area_id);

// Client identity
alias ApiClientGetIpidFn       = fn String(void* client);

// Packet field access (for hooks)
alias ApiPacketGetFieldFn      = fn String(void* packet, int index);
alias ApiPacketGetFieldCountFn = fn int(void* packet);

// Moderation from plugins
alias ApiClientKickFn          = fn void(void* client);
alias ApiClientMuteFn          = fn void(void* client);
alias ApiClientUnmuteFn        = fn void(void* client);

// Area background
alias ApiAreaGetBackgroundFn   = fn String(int area_id);
alias ApiAreaSetBackgroundFn   = fn void(int area_id, String bg);

// Area lock
alias ApiAreaGetLockFn         = fn int(int area_id);
alias ApiAreaSetLockFn         = fn void(int area_id, int lock_state);
alias ApiAreaInviteFn          = fn void(int area_id, int uid);

// Argument splitting — quote-aware tokenizer for command handlers.
// Plugin command handlers still receive the raw `String args` (the handler
// ABI is frozen), but this helper lets a plugin split it into a list the
// same way built-in commands do, without re-implementing the parser.
// Fills `out` (a caller-provided String buffer) and returns the token count.
alias ApiArgsSplitFn           = fn int(String args, String* out, int max);

// ASCII lower-casing — saves plugins from hand-rolling the `'A'..'Z' -> +32`
// loop just to compare user input case-insensitively. Like args_split it writes
// into a buffer the plugin owns (rather than returning an allocated String), so
// the result has no lifetime tied to the server's temp allocator. Copies `s`
// into `out` with every A–Z byte shifted to a–z, capped at `max` bytes, and
// returns how many bytes were written. Non-letters — digits, punctuation, and
// UTF-8 multibyte bytes — are copied through unchanged.
alias ApiToLowerFn             = fn int(String s, char* out, int max);

// -- Lifecycle hooks (v3) --
//
// Packet hooks (above) only fire when a client SENDS a packet. That leaves
// two blind spots a stateful plugin can't work around:
//   1. Disconnects produce no packet — a socket just closes — so a packet
//      hook can never see a client leave.
//   2. The desktop client only sends a keepalive every 45 seconds, so any
//      reaction driven by incoming packets can lag badly in a quiet room.
//
// Lifecycle hooks close both gaps: the server calls them directly at the
// moments a client joins, leaves, or changes visible state. This is the
// piece that makes a live player-list plugin possible. The event codes are
// config::PLUGIN_EVENT_JOIN / LEAVE / UPDATE; see the "Lifecycle Hooks"
// section of the Plugin Dev Guide for a complete worked example.
//
// One handler receives every event — switch on `event` to tell them apart.
// The client pointer is void* for standalone-plugin ABI safety; pass it
// straight back into the client_* API calls to read UID, character, area,
// OOC name, hidden state, and so on.
alias ApiLifecycleHook           = fn void(void* client, int event);
alias ApiRegisterLifecycleHookFn = fn void(ApiLifecycleHook hook, String plugin_name);

// Two client getters that v1/v2 lacked but lifecycle-driven plugins need:
//   client_get_ooc_name : the client's current OOC display name ("" if unset).
//   client_is_hidden    : true when the client holds the SHADOW permission
//                         and should be omitted from public player lists.
alias ApiClientGetOocNameFn      = fn String(void* client);
alias ApiClientIsHiddenFn        = fn bool(void* client);

// -- Connection filtering + raw IP + role-gated broadcast (v4) --
//
// SAME append-only ABI rule (see the note on the PluginAPI struct below): all
// three are added at the very end, so plugins compiled against v1/v2/v3 never
// read them and keep working untouched.
//
// These three exist for connection-level access control (the optional
// `ip_guard` plugin: IP / CIDR / ASN / country blocking) but are deliberately
// general primitives, not one plugin's private hooks:
//
//   client_get_ip      : the client's RAW IP address — IPv4 dotted-quad
//                        ("a.b.c.d") or IPv6 hex ("2001:db8::1"), or "unknown"
//                        when it couldn't be read. Every earlier API only ever
//                        exposed the *hashed* IPID (client_get_ipid); a plugin
//                        that wants to reason about CIDR ranges, geolocation, or
//                        ASNs needs the real address, which lives in the client
//                        but was never surfaced. Both families are supported
//                        (see extract_peer_ip in server.c3); proxy-header IPs
//                        (X-Forwarded-For / CF-Connecting-IP) pass through
//                        verbatim and may be either family.
//
//   register_conn_filter : subscribe a predicate that the server calls for every
//                        inbound connection, at accept time, BEFORE a handler
//                        thread (and its 256 KB pool) is spawned — the same spot
//                        the built-in IPID ban check runs. The filter receives
//                        the raw IP and returns true to REJECT the connection
//                        (socket closed immediately) or false to allow it. This
//                        is what lets an optional plugin drop abusive
//                        datacenters / countries without the connection ever
//                        costing a thread. It MUST be cheap and allocation-free
//                        (it runs on the accept loop): do O(log n) lookups, not
//                        network calls or broadcasts.
//
//   broadcast_perm_raw : send a pre-built wire packet to every connected client
//                        whose permissions include ALL bits of `perms` (e.g.
//                        commands::PERM_BAN). Mirrors the core `broadcast`, but
//                        role-gated — for staff-only notifications such as
//                        ip_guard's "a blocked range tried to connect" alert.
//                        Deliver these OFF the accept path (e.g. from a plugin
//                        timer/thread): it scans the whole client list.
alias ApiClientGetIpFn        = fn String(void* client);
alias ApiConnectionFilter     = fn bool(String ip);
alias ApiRegisterConnFilterFn = fn void(ApiConnectionFilter filter, String plugin_name);
alias ApiBroadcastPermRawFn   = fn void(String data, ulong perms);

// -- Per-client status tag (v5) --
//
// A short display tag a plugin can attach to a client (e.g. "[AFK]", "[REC]").
// The core renders it after the player's name in /ga and /gas; nothing else in
// the core reads it. Generic on purpose — any plugin can use it. "" clears it.
// (The optional `afk` plugin uses this for its /gas marker — a core-rendered
// tag stays correct across /reload, unlike a plugin re-implementing /gas from a
// roster that a reload would empty.)
alias ApiClientSetStatusTagFn = fn void(void* client, String tag);
alias ApiClientGetStatusTagFn = fn String(void* client);

// -- Custom-reason kick (v6) --
//
// Disconnect a client showing a custom KK reason, instead of the fixed message
// client_kick uses. Generic — any plugin wanting a meaningful disconnect reason
// (e.g. the `lockdown` plugin's "server in lockdown, not a ban, try again
// later") uses this. Sends KK#<message>#% and marks the client disconnected.
alias ApiClientKickMsgFn = fn void(void* client, String message);

// -- Plugin enumeration, outbound filter, HDID, HP setter (v7) --
//
// SAME append-only ABI rule. These let a plugin (a) enumerate the OTHER loaded
// plugins — get_plugin_count / get_plugin_name / get_plugin_version — for a
// `/plugins` readout (the optional `plugin_health` plugin); (b) transform every
// outbound OOC server message via register_outbound_filter, the only hook on
// *outbound* text (the optional `terse_mode` plugin shortens built-in replies with
// it); (c) read the raw HDID (hardware id), the way client_get_ipid exposes the
// hashed IP; and (d) set a penalty bar through area_set_hp so the change is stored
// in core area state and replayed to late joiners (unlike emitting a raw HP packet,
// which only updates the live display). The outbound filter writes into a caller
// buffer — fn int(void* client, String input, char* out, int max) -> byte length —
// and MUST be allocation-free. It returns < 0 to leave the message unchanged (the
// cheap pass-through case), or the number of bytes written to `out` otherwise.
alias ApiGetPluginCountFn         = fn int();
alias ApiGetPluginNameFn          = fn String(int);
alias ApiGetPluginVersionFn       = fn String(int);
alias ApiOutboundMsgFilter        = fn int(void*, String, char*, int);
alias ApiRegisterOutboundFilterFn = fn void(ApiOutboundMsgFilter);
alias ApiClientGetHdidFn          = fn String(void*);
alias ApiAreaSetHpFn              = fn void(int, int, int);

// -- Area rename, hidden toggle, pair read, real ban, evidence API, IC posting
//    + IC filter, KV store, event bus (v8) --
//
// SAME append-only ABI rule: every field below is added at the very end of
// PluginAPI (after area_set_hp), so plugins compiled against v1–v7 stop reading
// at area_set_hp and never touch these — they keep working with no recompile.
//
//   area_set_name      : rename an area in core state. NOTE: area names only go
//                        out in the SM list at handshake, so this persists for
//                        NEW joiners but does not live-rename clients already
//                        connected (the inverse of area_set_hp). Document the
//                        caveat in any "scene title" plugin.
//   client_set_hidden  : set/clear the SHADOW visibility marker that
//                        client_is_hidden reports and player lists honour. It is
//                        a visibility flag ONLY — it grants no moderator
//                        capability (nothing in core gates an action on SHADOW).
//   client_get_pair    : the client's persistent pair partner UID
//                        (force_pair_uid), or config::NO_PAIR (-1) if unpaired.
//   client_ban         : a REAL ban (not just a kick) — adds the client's
//                        IPID+HDID to the core ban list for `duration_sec`
//                        seconds (0 = permanent), sends KB, and disconnects.
//   area_*_evidence    : add / edit / remove / count / read the area evidence
//                        list and rebroadcast LE. get_evidence writes a field
//                        (0=name, 1=description, 2=image) into a caller buffer
//                        and returns its length, or -1 if the id is out of range
//                        (caller-buffer = no temp-allocator lifetime issue).
//   area_post_ic       : the server authors an IC (MS) line into an area as a
//                        character — for narrators, macros, testimony replay —
//                        WITHOUT consuming + rebuilding a player's packet (so no
//                        pairing is lost). Like the TI timer packet, client
//                        rendering of a server-authored MS is best-effort; the
//                        OOC path (broadcast_area_msg) is the always-works
//                        fallback.
//   register_ic_filter : transform the IC message text (MS field 4) of every
//                        relayed line before broadcast, rewriting ONLY that
//                        field so all pairing fields survive — the lossless
//                        censor / translate primitive the v7 outbound filter
//                        (OOC only) could not provide. Same contract: write into
//                        `out`, return the length or < 0 to pass through; must be
//                        allocation-free.
//   kv_set/get/delete  : a shared persistent string store (economy, profiles,
//                        streaks) so plugins stop hand-rolling file I/O. kv_get
//                        writes into a caller buffer and returns its length (or
//                        -1 if absent). Survives /reload.
//   emit_event +
//   register_event_listener : synchronous inter-plugin pub/sub for composition.
//                        A listener runs inside emit_event on the caller's
//                        thread, so the payload is valid for the call. Cleared on
//                        /reload.
alias ApiAreaSetNameFn           = fn void(int, String);
alias ApiClientSetHiddenFn       = fn void(void*, bool);
alias ApiClientGetPairFn         = fn int(void*);
alias ApiClientBanFn             = fn void(void*, String, int);
alias ApiAreaAddEvidenceFn       = fn void(int, String, String, String);
alias ApiAreaEditEvidenceFn      = fn void(int, int, String, String, String);
alias ApiAreaRemoveEvidenceFn    = fn void(int, int);
alias ApiAreaEvidenceCountFn     = fn int(int);
alias ApiAreaGetEvidenceFn       = fn int(int, int, int, char*, int);
alias ApiAreaPostIcFn            = fn void(int, String, String, String, String);
alias ApiIcMsgFilter             = fn int(void*, String, char*, int);
alias ApiRegisterIcFilterFn      = fn void(ApiIcMsgFilter);
alias ApiKvSetFn                 = fn void(String, String);
alias ApiKvGetFn                 = fn int(String, char*, int);
alias ApiKvDeleteFn              = fn void(String);
alias ApiEventListener           = fn void(String, String);
alias ApiEmitEventFn             = fn void(String, String);
alias ApiRegisterEventListenerFn = fn void(ApiEventListener);

//   register_timer     : run a callback every N milliseconds from a single core
//                        timer thread (started at boot). /reload-safe: the thread
//                        holds a lock while firing, so a reload's teardown waits
//                        for any in-flight callback before unloading. The callback
//                        runs on the timer thread (no plugin/server temp), so it
//                        MUST be allocation-free or wrap its body in @pool_init,
//                        and MUST NOT trigger /reload or re-register a timer.
alias ApiTimerFn                 = fn void();
alias ApiRegisterTimerFn         = fn void(int, ApiTimerFn);

// ============================================================
// Plugin API — passed to plugins during init
// ============================================================
//
// This struct is the bridge between standalone plugins and the
// server. Each field is a function pointer that the server fills
// in during initialization. Plugins store the API pointer and
// call these functions to interact with Whisker.

struct PluginAPI {
    // Registration
    ApiRegisterCommandFn  register_command;
    ApiRegisterHookFn     register_hook;

    // Server
    ApiFindClientFn       find_client;
    ApiBroadcastAreaMsgFn broadcast_area_msg;
    ApiBroadcastAreaRawFn broadcast_area_raw;
    ApiBroadcastArupFn    broadcast_arup;
    ApiGetAreaCountFn     get_area_count;

    // Area
    ApiAreaIsCmFn         area_is_cm;
    ApiAreaAddCmFn        area_add_cm;
    ApiAreaRemoveCmFn     area_remove_cm;
    ApiAreaCmCountFn      area_cm_count;
    ApiAreaClearCmsFn     area_clear_cms;
    ApiAreaUninviteFn     area_uninvite;
    ApiAreaSetStatusFn    area_set_status;
    ApiAreaGetStatusFn    area_get_status;
    ApiAreaGetNameFn      area_get_name;
    ApiAreaSetSongFn      area_set_song;
    ApiForceMoveFn        force_move;

    // Client
    ApiClientSendMsgFn     client_send_msg;
    ApiClientSendRawFn     client_send_raw;
    ApiClientGetUidFn      client_get_uid;
    ApiClientGetAreaFn     client_get_area;
    ApiClientIsModFn       client_is_mod;
    ApiClientDisplayNameFn client_display_name;
    ApiClientGetCharIdFn   client_get_char_id;
    ApiClientGetShownameFn client_get_showname;
    ApiClientGetCharNameFn client_get_char_name;
    ApiClientIsJoinedFn    client_is_joined;
    ApiClientSetPositionFn client_set_position;

    // Extended API (v2) — appended for backwards compatibility
    ApiBroadcastAllMsgFn     broadcast_all_msg;
    ApiBroadcastAllRawFn     broadcast_all_raw;
    ApiGetPlayerCountFn      get_player_count;
    ApiGetAreaPlayerCountFn  get_area_player_count;
    ApiClientGetIpidFn       client_get_ipid;
    ApiPacketGetFieldFn      packet_get_field;
    ApiPacketGetFieldCountFn packet_get_field_count;
    ApiClientKickFn          client_kick;
    ApiClientMuteFn          client_mute;
    ApiClientUnmuteFn        client_unmute;
    ApiAreaGetBackgroundFn   area_get_background;
    ApiAreaSetBackgroundFn   area_set_background;
    ApiAreaGetLockFn         area_get_lock;
    ApiAreaSetLockFn         area_set_lock;
    ApiAreaInviteFn          area_invite;

    // Appended after the v2 block — see the ABI note above. Existing
    // compiled plugins never read this field, so they keep working.
    ApiArgsSplitFn           args_split;

    // Appended after args_split — same append-only ABI rule. Plugins compiled
    // before to_lower existed stop reading at args_split and never touch it.
    ApiToLowerFn             to_lower;

    // Appended after to_lower (v3) — lifecycle hooks plus the two getters
    // they rely on. SAME append-only ABI rule: every field above keeps its
    // exact offset, so plugins compiled against v1/v2 (which declare a shorter
    // PluginAPI) stop reading at to_lower and never touch these. Existing
    // compiled .dll/.so plugins therefore keep working with no recompile.
    ApiRegisterLifecycleHookFn register_lifecycle_hook;
    ApiClientGetOocNameFn      client_get_ooc_name;
    ApiClientIsHiddenFn        client_is_hidden;

    // Appended after the v3 block (v4) — raw-IP access, the accept-time
    // connection filter, and a role-gated raw broadcast. SAME append-only ABI
    // rule: plugins compiled against v1/v2/v3 stop reading at client_is_hidden
    // and never touch these three, so every shipped .dll/.so keeps working with
    // no recompile.
    ApiClientGetIpFn           client_get_ip;
    ApiRegisterConnFilterFn    register_conn_filter;
    ApiBroadcastPermRawFn      broadcast_perm_raw;

    // Appended after the v4 block (v5) — a per-client status tag the core
    // renders in /ga and /gas. SAME append-only ABI rule. Plugins compiled
    // against v1–v4 stop reading at broadcast_perm_raw and never touch these two.
    ApiClientSetStatusTagFn    client_set_status_tag;
    ApiClientGetStatusTagFn    client_get_status_tag;

    // Appended after the v5 block (v6) — custom-reason kick. SAME append-only
    // ABI rule: client_kick_msg is now the current tail, so the next new field
    // goes AFTER it — never insert or reorder. Plugins compiled against v1–v5
    // stop reading at client_get_status_tag and never touch this one.
    ApiClientKickMsgFn         client_kick_msg;

    // Appended after the v6 block (v7) — plugin enumeration, an outbound
    // server-message filter, raw HDID, and a penalty-bar setter. SAME append-only
    // ABI rule: client_kick_msg keeps its exact offset, so plugins compiled against
    // v1–v6 stop reading there and never touch these. New fields MUST always be
    // added AFTER area_set_hp — never inserted.
    ApiGetPluginCountFn         get_plugin_count;
    ApiGetPluginNameFn          get_plugin_name;
    ApiGetPluginVersionFn       get_plugin_version;
    ApiRegisterOutboundFilterFn register_outbound_filter;
    ApiClientGetHdidFn          client_get_hdid;
    ApiAreaSetHpFn              area_set_hp;

    // Appended after the v7 block (v8) — area rename, hidden toggle, pair read,
    // real ban, the evidence API, server-authored IC, the IC message filter, the
    // shared KV store, and the event bus. SAME append-only ABI rule: area_set_hp
    // keeps its exact offset, so plugins compiled against v1–v7 stop reading
    // there and never touch these. New fields MUST always be added AFTER
    // register_event_listener — never inserted or reordered.
    ApiAreaSetNameFn            area_set_name;
    ApiClientSetHiddenFn        client_set_hidden;
    ApiClientGetPairFn          client_get_pair;
    ApiClientBanFn              client_ban;
    ApiAreaAddEvidenceFn        area_add_evidence;
    ApiAreaEditEvidenceFn       area_edit_evidence;
    ApiAreaRemoveEvidenceFn     area_remove_evidence;
    ApiAreaEvidenceCountFn      area_evidence_count;
    ApiAreaGetEvidenceFn        area_get_evidence;
    ApiAreaPostIcFn             area_post_ic;
    ApiRegisterIcFilterFn       register_ic_filter;
    ApiKvSetFn                  kv_set;
    ApiKvGetFn                  kv_get;
    ApiKvDeleteFn               kv_delete;
    ApiEmitEventFn              emit_event;
    ApiRegisterEventListenerFn  register_event_listener;
    ApiRegisterTimerFn          register_timer;  // current tail — next field goes AFTER this
}

// ============================================================
// Registered plugin command
// ============================================================

struct PluginCommand {
    String         name;
    CommandHandler handler;
    ulong          required_perms;
    String         description;
    String         plugin_name;
}

// ============================================================
// Registered packet hook
// ============================================================

struct PluginPacketHook {
    String     header;  // which packet header to hook ("MS", "CT", etc.)
    PacketHook hook;
    String     plugin_name;
}

// ============================================================
// Registered lifecycle hook
// ============================================================

struct PluginLifecycleHook {
    ApiLifecycleHook hook;
    String           plugin_name;
}

// ============================================================
// Registered connection filter (v4)
// ============================================================
//
// Called for every inbound connection at accept time (see on_connection and
// server::handle_new_connection). The filter returns true to REJECT.

struct PluginConnFilter {
    ApiConnectionFilter filter;
    String              plugin_name;
}

// ============================================================
// Plugin Manager
// ============================================================

const int MAX_PLUGINS         = 64;
const int MAX_PLUGIN_COMMANDS = 256;
const int MAX_PLUGIN_HOOKS    = 256;

struct PluginManager {
    PluginInfo[MAX_PLUGINS]              plugins;
    int                                   plugin_count;

    PluginCommand[MAX_PLUGIN_COMMANDS]   commands;
    int                                   command_count;

    PluginPacketHook[MAX_PLUGIN_HOOKS]   hooks;
    int                                   hook_count;

    PluginLifecycleHook[MAX_PLUGIN_HOOKS] lifecycle_hooks;
    int                                    lifecycle_hook_count;

    PluginConnFilter[MAX_PLUGIN_HOOKS]    conn_filters;
    int                                    conn_filter_count;

    // Runtime handles for hot reload
    void*[MAX_PLUGINS]                   handles;       // dlopen/LoadLibrary handles
    PluginShutdownFn[MAX_PLUGINS]        shutdown_fns;  // Shutdown callbacks
}

fn PluginManager new_manager() {
    PluginManager pm;
    pm.plugin_count = 0;
    pm.command_count = 0;
    pm.hook_count = 0;
    pm.lifecycle_hook_count = 0;
    pm.conn_filter_count = 0;
    return pm;
}

// ============================================================
// Plugin loading — scan directory and load shared libraries
// ============================================================

fn void load_all(PluginManager* pm, PluginAPI* api, String directory) {
    io::printfn("[plugins] Scanning '%s' for plugins...", directory);

    // List plugin files in the directory. Windows: FindFirstFile *.dll
    // (no child process). POSIX: ls -1 *.so via popen.
    $if env::WIN32:
        Win32FindDataA find_data;
        // Win32 needs a null-terminated pattern — tformat_zstr (not tformat,
        // which leaves the slice unterminated and made FindFirstFile fail).
        ZString pattern = string::tformat_zstr("%s\\*.dll", directory);
        void* handle = find_first_file_a((char*)pattern, &find_data);
        if ((iptr)handle != -1) { // INVALID_HANDLE_VALUE
            char[512] path_buf;
            do {
                usz len = 0;
                while (len < MAX_PATH_LEN - 1 && find_data.file_name[len] != 0) len++;
                if (len >= 4) {
                    // FindFirstFile gives just the name — build "<dir>\<name>"
                    // into a null-terminated buffer for LoadLibraryA.
                    usz pl = 0;
                    foreach (char ch : directory) { if (pl < 500) path_buf[pl++] = ch; }
                    if (pl < 510) path_buf[pl++] = '\\';
                    for (usz i = 0; i < len && pl < 511; i++) path_buf[pl++] = find_data.file_name[i];
                    path_buf[pl] = 0; // null-terminate for C interop
                    load_single(pm, api, (String)path_buf[0..pl - 1]);
                }
            } while (find_next_file_a(handle, &find_data) != 0);
            find_close(handle);
        }
    $else
        String cmd = string::tformat("ls -1 \"%s/\"*.so 2>/dev/null", directory);
        void* pipe = popen(cmd.ptr, "r".ptr);
        if (pipe != null) {
            char[256] name_buf;
            while (fgets(&name_buf[0], 256, pipe) != null) {
                // Trim trailing newline/whitespace and null-terminate.
                // dlopen reads C strings (until \0), so terminate the buffer.
                usz len = 0;
                while (len < 255 && name_buf[len] != 0 && name_buf[len] != '\n' && name_buf[len] != '\r') len++;
                if (len < 4) continue;
                name_buf[len] = 0;
                // ls gives full relative paths (dir/file.so).
                String full_path = (String)name_buf[0..len - 1];
                load_single(pm, api, full_path);
            }
            pclose(pipe);
        }
    $endif

    io::printfn("[plugins] %d plugins loaded, %d commands registered, %d hooks registered.",
        pm.plugin_count, pm.command_count, pm.hook_count);
}

// Load a single shared library plugin from the given path.
fn void load_single(PluginManager* pm, PluginAPI* api, String path) {
    if (pm.plugin_count >= MAX_PLUGINS) {
        io::printfn("[plugins] Max plugins (%d) reached, skipping: %s", MAX_PLUGINS, path);
        return;
    }

    // Open the shared library
    $if env::WIN32:
        void* handle = load_library_a(path.ptr);
    $else
        void* handle = dlopen(path.ptr, RTLD_NOW);
    $endif

    if (handle == null) {
        $if env::WIN32:
            io::printfn("[plugins] Failed to load: %s", path);
        $else
            char* err = dlerror();
            if (err != null) {
                usz err_len = 0;
                while (err_len < 512 && err[err_len] != 0) err_len++;
                if (err_len > 0) {
                    io::printfn("[plugins] Failed to load: %s (%s)", path, (String)err[0..err_len - 1]);
                } else {
                    io::printfn("[plugins] Failed to load: %s", path);
                }
            } else {
                io::printfn("[plugins] Failed to load: %s", path);
            }
        $endif
        return;
    }

    // Look up required exported functions
    $if env::WIN32:
        void* info_ptr     = get_proc_address(handle, "whisker_plugin_info".ptr);
        void* init_ptr     = get_proc_address(handle, "whisker_plugin_init".ptr);
        void* shutdown_ptr = get_proc_address(handle, "whisker_plugin_shutdown".ptr);
    $else
        void* info_ptr     = dlsym(handle, "whisker_plugin_info".ptr);
        void* init_ptr     = dlsym(handle, "whisker_plugin_init".ptr);
        void* shutdown_ptr = dlsym(handle, "whisker_plugin_shutdown".ptr);
    $endif

    if (info_ptr == null || init_ptr == null) {
        io::printfn("[plugins] '%s' missing required exports (whisker_plugin_info / whisker_plugin_init).", path);
        $if env::WIN32:
            free_library(handle);
        $else
            dlclose(handle);
        $endif
        return;
    }

    // Get plugin metadata
    PluginInfoFn info_fn = (PluginInfoFn)info_ptr;
    PluginInfo info = info_fn();

    // Store handle and shutdown callback
    int idx = pm.plugin_count;
    pm.handles[idx]      = handle;
    pm.shutdown_fns[idx] = shutdown_ptr != null ? (PluginShutdownFn)shutdown_ptr : null;

    // Initialize the plugin — it registers commands and hooks via the API
    PluginInitFn init_fn = (PluginInitFn)init_ptr;
    init_fn(api);

    // Register plugin info
    pm.plugins[idx] = info;
    pm.plugin_count++;

    io::printfn("[plugins] Loaded: %s v%s by %s", info.name, info.version, info.author);
}

// ============================================================
// Plugin unloading and hot reload
// ============================================================

// Unload all plugins: clear every callback path, call shutdown, close handles.
//
// ORDER MATTERS. Every registry below holds function pointers INTO the plugin
// libraries, so they must all be emptied BEFORE any dlclose — otherwise a path
// can fire into freed code. This is critical for the v8 timer: the core timer
// thread fires every 100ms (proactively), so leaving its registry populated
// across dlclose reliably crashes (illegal instruction). plugin_services::
// clear_registrations() clears the timers UNDER their lock, so it also blocks
// until any in-flight tick finishes. The reactive registries (commands / hooks /
// lifecycle / conn filters / outbound / IC / events) are cleared here too; their
// races are narrower (they only fire on client activity) but the same rule is
// correct. NOTE: a worker thread already INSIDE a plugin handler when a reload
// begins is a pre-existing, separate race the server does not quiesce — keep
// reloads to quiet moments, exactly as before.
fn void unload_all(PluginManager* pm) {
    // 1. Sever every call-into-plugin path first, while the code is still mapped.
    pm.command_count        = 0;
    pm.hook_count           = 0;
    pm.lifecycle_hook_count = 0;
    pm.conn_filter_count    = 0;
    client::clear_outbound_filters();      // v7 outbound filters (in client.c3)
    plugin_services::clear_registrations(); // v8 timers (locked) + events + IC filters

    // 2. Now it is safe to run each plugin's shutdown — nothing will dispatch
    //    into them, and they may still call read-only / setter API (e.g. the
    //    narrator example restores area names here).
    for (int i = 0; i < pm.plugin_count; i++) {
        if (pm.shutdown_fns[i] != null) {
            io::printfn("[plugins] Shutting down: %s", pm.plugins[i].name);
            pm.shutdown_fns[i]();
        }
    }

    // 3. Close all library handles.
    for (int i = 0; i < pm.plugin_count; i++) {
        if (pm.handles[i] != null) {
            $if env::WIN32:
                free_library(pm.handles[i]);
            $else
                dlclose(pm.handles[i]);
            $endif
            pm.handles[i] = null;
        }
        pm.shutdown_fns[i] = null;
    }

    pm.plugin_count = 0;
    io::printn("[plugins] All plugins unloaded.");
}

// Hot-reload: unload everything, then re-scan and re-load.
fn void reload_all(PluginManager* pm, PluginAPI* api, String directory) {
    io::printn("[plugins] --- Hot reload started ---");
    unload_all(pm);
    load_all(pm, api, directory);
    io::printn("[plugins] --- Hot reload complete ---");
}

// ============================================================
// Plugin dispatch — called by the server
// ============================================================

// Check if any plugin wants to handle this command.
// Returns true if a plugin consumed it.
fn bool on_command(PluginManager* pm, client::Client* c, String cmd_name, String args) {
    for (int i = 0; i < pm.command_count; i++) {
        if (pm.commands[i].name == cmd_name) {
            // Permission check
            if (pm.commands[i].required_perms != 0 &&
                !c.has_permission(pm.commands[i].required_perms)) {
                c.send_server_message("No permission.");
                return true;
            }

            pm.commands[i].handler(c, args);
            return true;
        }
    }
    return false;
}

// Check if any plugin wants to intercept this packet.
// Returns true if a plugin consumed it (stop processing).
fn bool on_packet(PluginManager* pm, client::Client* c, protocol::Packet* pkt) {
    for (int i = 0; i < pm.hook_count; i++) {
        if (pm.hooks[i].header == pkt.header) {
            if (pm.hooks[i].hook(c, pkt)) {
                return true; // Consumed
            }
        }
    }
    return false;
}

// Fire a lifecycle event to every registered lifecycle hook.
// The server calls this at join / leave / state-change points (see the
// server::notify_client_* helpers). `event` is a config::PLUGIN_EVENT_*
// code. Unlike packet hooks, lifecycle hooks never consume — every
// registered plugin sees every event.
fn void fire_lifecycle(PluginManager* pm, client::Client* c, int event) {
    for (int i = 0; i < pm.lifecycle_hook_count; i++) {
        pm.lifecycle_hooks[i].hook(c, event);
    }
}

// Ask every registered connection filter whether this inbound IP should be
// rejected. Returns true as soon as ANY filter says "block" (short-circuit),
// so the caller can close the socket before spending a thread on it. Called
// from server::handle_new_connection on the accept path — when no plugin has
// registered a filter (conn_filter_count == 0) this is a single comparison and
// zero iterations, i.e. no cost on the hot path for servers without the plugin.
// `ip` is the raw client address (already proxy-resolved by the caller).
fn bool on_connection(PluginManager* pm, String ip) {
    for (int i = 0; i < pm.conn_filter_count; i++) {
        if (pm.conn_filters[i].filter(ip)) {
            return true; // Rejected
        }
    }
    return false;
}
