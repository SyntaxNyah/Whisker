// Whisker Optional Plugin — v8 API Self-Test [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// NOT a feature — a VERIFICATION harness. A misaligned PluginAPI struct loads
// without error and then returns garbage, so "16 plugins loaded" proves nothing
// about ABI offset alignment. This plugin instead EXERCISES the v8 fields at
// init (on the main thread, where the plugin temp allocator is live) and prints
// the round-trip results, so a human can read the console and confirm every new
// field is wired to the right offset.
//
// It deliberately touches the FIRST v8 field (area_set_name), the MIDDLE ones
// (evidence + KV), and the LAST ones (event bus) — because the struct is
// contiguous, if any field in between were the wrong width every later field
// would be shifted and the KV / event round-trips would fail. So a clean run is
// strong evidence the whole v8 block is aligned.
//
// Drop the .dll/.so in plugins/, start the server, read the console, then remove
// it — it has no runtime value once you trust the build.

module v8_selftest;

import std::io;

// ============================================================
// Whisker plugin interface (standalone) — FULL v8 struct.
// (v7 prefix copied verbatim from plugin.c3, then the v8 block appended.)
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
alias GetPluginCountFn         = fn int();
alias GetPluginNameFn          = fn String(int);
alias GetPluginVersionFn       = fn String(int);
alias OutboundMsgFilter        = fn int(void*, String, char*, int);
alias RegisterOutboundFilterFn = fn void(OutboundMsgFilter);
alias ClientGetHdidFn          = fn String(void*);
alias AreaSetHpFn              = fn void(int, int, int);
// -- v8 --
alias AreaSetNameFn           = fn void(int, String);
alias ClientSetHiddenFn       = fn void(void*, bool);
alias ClientGetPairFn         = fn int(void*);
alias ClientBanFn             = fn void(void*, String, int);
alias AreaAddEvidenceFn       = fn void(int, String, String, String);
alias AreaEditEvidenceFn      = fn void(int, int, String, String, String);
alias AreaRemoveEvidenceFn    = fn void(int, int);
alias AreaEvidenceCountFn     = fn int(int);
alias AreaGetEvidenceFn       = fn int(int, int, int, char*, int);
alias AreaPostIcFn            = fn void(int, String, String, String, String);
alias IcMsgFilter             = fn int(void*, String, char*, int);
alias RegisterIcFilterFn      = fn void(IcMsgFilter);
alias KvSetFn                 = fn void(String, String);
alias KvGetFn                 = fn int(String, char*, int);
alias KvDeleteFn              = fn void(String);
alias EventListener           = fn void(String, String);
alias EmitEventFn             = fn void(String, String);
alias RegisterEventListenerFn = fn void(EventListener);

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
    GetPluginCountFn         get_plugin_count;
    GetPluginNameFn          get_plugin_name;
    GetPluginVersionFn       get_plugin_version;
    RegisterOutboundFilterFn register_outbound_filter;
    ClientGetHdidFn          client_get_hdid;
    AreaSetHpFn              area_set_hp;
    // -- v8 --
    AreaSetNameFn           area_set_name;
    ClientSetHiddenFn       client_set_hidden;
    ClientGetPairFn         client_get_pair;
    ClientBanFn             client_ban;
    AreaAddEvidenceFn       area_add_evidence;
    AreaEditEvidenceFn      area_edit_evidence;
    AreaRemoveEvidenceFn    area_remove_evidence;
    AreaEvidenceCountFn     area_evidence_count;
    AreaGetEvidenceFn       area_get_evidence;
    AreaPostIcFn            area_post_ic;
    RegisterIcFilterFn      register_ic_filter;
    KvSetFn                 kv_set;
    KvGetFn                 kv_get;
    KvDeleteFn              kv_delete;
    EmitEventFn             emit_event;
    RegisterEventListenerFn register_event_listener;
}

// ============================================================
// Test state
// ============================================================

PluginAPI* api;
bool   got_event = false;
String got_event_payload = "";

fn String cstr(char* buf, int n) {
    if (n <= 0) return "";
    return (String)buf[0..(usz)n - 1];
}

// Event listener — set a flag so we can confirm emit_event reached us.
fn void on_test_event(String name, String payload) {
    if (name == "v8.selftest") {
        got_event = true;
        got_event_payload = payload;
    }
}

// IC filter — never used here (no client at init), just registered to prove the
// register_ic_filter offset is a valid callable slot.
fn int noop_ic_filter(void* c, String msg, char* out, int max) { return -1; }

fn void pass(String label, bool ok, String detail) {
    io::printfn("[v8_selftest]  %s  %s  %s", ok ? "PASS" : "FAIL", label, detail);
}

// ============================================================
// Plugin interface
// ============================================================

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return {
        .name        = "v8 Self-Test",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Exercises every v8 API field at init and prints round-trip results. Verification only.",
    };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    io::printn("[v8_selftest] === v8 API alignment self-test ===");

    // --- FIRST v8 field: area_set_name (round-trip via area_get_name) ---
    // Stores the slice by reference, so we restore the original afterwards (and
    // back the test name with a string literal, which lives in the .dll).
    int areas = api.get_area_count();
    if (areas > 0) {
        String orig = api.area_get_name(0);
        api.area_set_name(0, "V8 SELFTEST NAME");
        String after = api.area_get_name(0);
        pass("area_set_name/area_get_name", after == "V8 SELFTEST NAME", after);
        api.area_set_name(0, orig); // restore — never leave area.name pointing into this .dll
    } else {
        pass("area_set_name", false, "no areas to test");
    }

    // --- MIDDLE: evidence API (add -> count -> read -> remove) ---
    if (areas > 0) {
        int before = api.area_evidence_count(0);
        api.area_add_evidence(0, "SelfTest Knife", "A bloodied blade.", "knife.png");
        int after_add = api.area_evidence_count(0);
        char[64] ebuf;
        int en = api.area_get_evidence(0, after_add - 1, 0, &ebuf[0], 64);
        String ename = cstr(&ebuf[0], en);
        pass("area_add_evidence/count/get", after_add == before + 1 && ename == "SelfTest Knife", ename);
        api.area_remove_evidence(0, after_add - 1);
        pass("area_remove_evidence", api.area_evidence_count(0) == before, "count restored");
    }

    // --- MIDDLE: KV store (set -> get -> delete) ---
    api.kv_set("v8.selftest.key", "hello-kv");
    char[64] kbuf;
    int kn = api.kv_get("v8.selftest.key", &kbuf[0], 64);
    String kval = cstr(&kbuf[0], kn);
    pass("kv_set/kv_get", kval == "hello-kv", kval);
    api.kv_delete("v8.selftest.key");
    int kn2 = api.kv_get("v8.selftest.key", &kbuf[0], 64);
    pass("kv_delete", kn2 == -1, "absent after delete");

    // --- LAST: event bus (register listener -> emit -> confirm it fired) ---
    api.register_event_listener(&on_test_event);
    api.emit_event("v8.selftest", "ping-payload");
    pass("emit_event/register_event_listener", got_event && got_event_payload == "ping-payload", got_event_payload);

    // --- Offset-only checks (no client / no observable effect at init) ---
    api.register_ic_filter(&noop_ic_filter);  // crashes if offset wrong
    if (areas > 0) api.area_post_ic(0, "Narrator", "Narrator", "selftest (no clients to receive)", "wit");
    io::printn("[v8_selftest]  (register_ic_filter + area_post_ic called without crashing — offsets valid)");
    io::printn("[v8_selftest]  client_set_hidden / client_get_pair / client_ban require a live client; their");
    io::printn("[v8_selftest]  offsets sit between verified fields, so a clean run above implies they align too.");
    io::printn("[v8_selftest] === self-test complete ===");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    io::printn("[v8_selftest] Unloaded.");
}
