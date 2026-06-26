// Whisker Optional Plugin — Mod Tools (v8) [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Three staff utilities that each demo a v8 field:
//   /ghost              toggle your own visibility   (client_set_hidden / client_is_hidden)
//   /realban <uid> <seconds> [reason]   a REAL timed ban, not a kick  (client_ban)
//   /kvclear <key>      delete a plugin KV entry     (kv_delete)
//
// All three are staff-gated in-handler (api.client_is_mod) and registered with
// required_perms = 0, so the plugin doesn't have to hardcode core permission
// bits. Handlers that format text wrap their work in @pool_init (worker-thread
// temp-allocator rule).

module mod_tools;

import std::io;

// === Whisker v8 PluginAPI (standalone copy — see plugin.c3 for the canonical) ==
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
    RegisterCommandFn   register_command;     RegisterHookFn      register_hook;
    FindClientFn        find_client;          BroadcastAreaMsgFn  broadcast_area_msg;
    BroadcastAreaRawFn  broadcast_area_raw;   BroadcastArupFn     broadcast_arup;
    GetAreaCountFn      get_area_count;        AreaIsCmFn          area_is_cm;
    AreaAddCmFn         area_add_cm;           AreaRemoveCmFn      area_remove_cm;
    AreaCmCountFn       area_cm_count;         AreaClearCmsFn      area_clear_cms;
    AreaUninviteFn      area_uninvite;         AreaSetStatusFn     area_set_status;
    AreaGetStatusFn     area_get_status;       AreaGetNameFn       area_get_name;
    AreaSetSongFn       area_set_song;         ForceMoveFn         force_move;
    ClientSendMsgFn     client_send_msg;       ClientSendRawFn     client_send_raw;
    ClientGetUidFn      client_get_uid;        ClientGetAreaFn     client_get_area;
    ClientIsModFn       client_is_mod;         ClientDisplayNameFn client_display_name;
    ClientGetCharIdFn   client_get_char_id;    ClientGetShownameFn client_get_showname;
    ClientGetCharNameFn client_get_char_name;  ClientIsJoinedFn    client_is_joined;
    ClientSetPositionFn client_set_position;   BroadcastAllMsgFn   broadcast_all_msg;
    BroadcastAllRawFn   broadcast_all_raw;     GetPlayerCountFn    get_player_count;
    GetAreaPlayerCountFn get_area_player_count; ClientGetIpidFn    client_get_ipid;
    PacketGetFieldFn    packet_get_field;      PacketGetFieldCountFn packet_get_field_count;
    ClientKickFn        client_kick;           ClientMuteFn        client_mute;
    ClientUnmuteFn      client_unmute;         AreaGetBackgroundFn area_get_background;
    AreaSetBackgroundFn area_set_background;   AreaGetLockFn       area_get_lock;
    AreaSetLockFn       area_set_lock;         AreaInviteFn        area_invite;
    ArgsSplitFn         args_split;            ToLowerFn           to_lower;
    RegisterLifecycleHookFn register_lifecycle_hook; ClientGetOocNameFn client_get_ooc_name;
    ClientIsHiddenFn    client_is_hidden;      ClientGetIpFn       client_get_ip;
    RegisterConnFilterFn register_conn_filter; BroadcastPermRawFn  broadcast_perm_raw;
    ClientSetStatusTagFn client_set_status_tag; ClientGetStatusTagFn client_get_status_tag;
    ClientKickMsgFn     client_kick_msg;       GetPluginCountFn    get_plugin_count;
    GetPluginNameFn     get_plugin_name;       GetPluginVersionFn  get_plugin_version;
    RegisterOutboundFilterFn register_outbound_filter; ClientGetHdidFn client_get_hdid;
    AreaSetHpFn         area_set_hp;
    // -- v8 --
    AreaSetNameFn       area_set_name;         ClientSetHiddenFn   client_set_hidden;
    ClientGetPairFn     client_get_pair;       ClientBanFn         client_ban;
    AreaAddEvidenceFn   area_add_evidence;     AreaEditEvidenceFn  area_edit_evidence;
    AreaRemoveEvidenceFn area_remove_evidence; AreaEvidenceCountFn area_evidence_count;
    AreaGetEvidenceFn   area_get_evidence;     AreaPostIcFn        area_post_ic;
    RegisterIcFilterFn  register_ic_filter;    KvSetFn             kv_set;
    KvGetFn             kv_get;                KvDeleteFn          kv_delete;
    EmitEventFn         emit_event;            RegisterEventListenerFn register_event_listener;
}
// ================================================================================

const String PLUGIN_NAME = "Mod Tools";
PluginAPI* api;

fn void ghost_body(void* c) {
    if (!api.client_is_mod(c)) { api.client_send_msg(c, "Staff only."); return; }
    bool hidden = api.client_is_hidden(c);
    api.client_set_hidden(c, !hidden);
    api.client_send_msg(c, hidden
        ? "Ghost mode OFF — you're visible in player lists again."
        : "Ghost mode ON — you're hidden from public player lists (this grants no extra powers).");
}
fn void cmd_ghost(void* c, String args) { @pool_init(mem, 64 * 1024) { ghost_body(c); }; }

fn void realban_body(void* c, String args) {
    if (!api.client_is_mod(c)) { api.client_send_msg(c, "Staff only."); return; }
    String[8] toks;
    int n = api.args_split(args, &toks[0], 8);
    if (n < 2) {
        api.client_send_msg(c, "Usage: /realban <uid> <seconds> [reason]   (0 seconds = permanent)");
        return;
    }
    int uid  = toks[0].to_int() ?? -1;
    int secs = toks[1].to_int() ?? -1;
    if (uid < 0 || secs < 0) { api.client_send_msg(c, "Bad uid or seconds."); return; }
    void* target = api.find_client(uid);
    if (target == null) { api.client_send_msg(c, "Player not found."); return; }
    String reason = n >= 3 ? toks[2] : "Banned by moderator.";
    api.client_ban(target, reason, secs);
    api.client_send_msg(c, string::tformat("Banned UID %d for %d second(s). Reason: %s", uid, secs, reason));
}
fn void cmd_realban(void* c, String args) { @pool_init(mem, 64 * 1024) { realban_body(c, args); }; }

fn void kvclear_body(void* c, String args) {
    if (!api.client_is_mod(c)) { api.client_send_msg(c, "Staff only."); return; }
    String key = args.trim();
    if (key.len == 0) { api.client_send_msg(c, "Usage: /kvclear <key>"); return; }
    api.kv_delete(key);
    api.client_send_msg(c, string::tformat("Deleted KV key '%s'.", key));
}
fn void cmd_kvclear(void* c, String args) { @pool_init(mem, 64 * 1024) { kvclear_body(c, args); }; }

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return { .name = "Mod Tools", .version = "1.0.0", .author = "Whisker Community",
             .description = "/ghost /realban /kvclear — staff utilities demoing v8 client_set_hidden, client_ban, kv_delete." };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    api.register_command("ghost",   &cmd_ghost,   0, "Toggle your visibility in player lists (staff)", PLUGIN_NAME);
    api.register_command("realban", &cmd_realban, 0, "Real timed ban: /realban <uid> <seconds> [reason] (staff)", PLUGIN_NAME);
    api.register_command("kvclear", &cmd_kvclear, 0, "Delete a plugin KV key (staff)", PLUGIN_NAME);
    io::printn("[mod_tools] Loaded. /ghost /realban /kvclear ready.");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    io::printn("[mod_tools] Unloaded.");
}
