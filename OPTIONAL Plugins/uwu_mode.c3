// Whisker Optional Plugin — UwU Mode [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A FUN demo of the v8 `register_ic_filter` hook: the lossless IC chat-text
// rewriter. Each player opts in with /uwu; their IC messages are then uwu-ified
// (r/l -> w) for everyone in the room — and because the filter rewrites ONLY
// MS field 4, all pairing/emote/shout fields survive untouched (the thing a
// consume+rebuild plugin could never do). Everyone else types normally.
//
// The filter is allocation-free (it runs in the MS broadcast path on a worker
// thread), so it does NOT need an @pool_init wrapper — it only ever writes bytes
// into the caller's buffer. Drop the .dll/.so in plugins/ and restart. Optional.

module uwu_mode;

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

const String PLUGIN_NAME = "UwU Mode";
const int    EVENT_LEAVE = 1;
const int    MAX_PLAYERS = 1024;

PluginAPI* api;
int[MAX_PLAYERS] opted;
int opted_count;

fn bool is_opted(int uid) {
    for (int i = 0; i < opted_count; i++) { if (opted[i] == uid) return true; }
    return false;
}

// The IC filter: allocation-free, writes bytes into `out`. Returns -1 to pass
// the message through untouched (the free path for anyone not opted in).
fn int uwu_filter(void* c, String input, char* out, int max) {
    int uid = api.client_get_uid(c);
    if (uid < 0 || !is_opted(uid)) return -1;

    int o = 0;
    for (usz i = 0; i < input.len && o < max; i++) {
        char ch = input[i];
        if (ch == 'r' || ch == 'l') { out[o] = 'w'; o++; }
        else if (ch == 'R' || ch == 'L') { out[o] = 'W'; o++; }
        else { out[o] = ch; o++; }
    }
    return o;
}

// /uwu — toggle. Only string literals + api calls, so no @pool_init needed.
fn void cmd_uwu(void* c, String args) {
    int uid = api.client_get_uid(c);
    if (uid < 0) return;
    if (is_opted(uid)) {
        for (int i = 0; i < opted_count; i++) {
            if (opted[i] == uid) { opted[i] = opted[opted_count - 1]; opted_count--; break; }
        }
        api.client_send_msg(c, "UwU mode OFF. You sound normal again.");
    } else {
        if (opted_count < MAX_PLAYERS) { opted[opted_count] = uid; opted_count++; }
        api.client_send_msg(c, "UwU mode ON >w< youw IC chat is now adowabwe.");
    }
}

fn void on_life(void* c, int event) {
    if (event != EVENT_LEAVE) return;
    int uid = api.client_get_uid(c);
    if (uid < 0) return;
    for (int i = 0; i < opted_count; i++) {
        if (opted[i] == uid) { opted[i] = opted[opted_count - 1]; opted_count--; return; }
    }
}

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return { .name = "UwU Mode", .version = "1.0.0", .author = "Whisker Community",
             .description = "Per-player uwu-ifier. Demo of the v8 register_ic_filter hook. Needs the v8 API." };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    opted_count = 0;
    api.register_ic_filter(&uwu_filter);
    api.register_lifecycle_hook(&on_life, PLUGIN_NAME);
    api.register_command("uwu", &cmd_uwu, 0, "Toggle uwu-ifying your own IC chat", PLUGIN_NAME);
    io::printn("[uwu_mode] Loaded. /uwu ready (IC filter registered).");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    io::printn("[uwu_mode] Unloaded.");
}
