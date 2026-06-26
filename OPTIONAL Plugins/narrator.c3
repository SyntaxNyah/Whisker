// Whisker Optional Plugin — Narrator (v8) [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Courtroom storytelling tools for CMs and mods:
//   /narrate <text>   the SERVER posts an IC line as "Narrator"   (area_post_ic)
//   /scene <name>     rename the area for the current scene        (area_set_name)
//
// area_post_ic authors an MS without consuming + rebuilding a player's packet,
// so nobody's pairing is disturbed. Client rendering of a server-authored MS is
// best-effort (same caveat as the TI timer packet), so /narrate ALSO echoes the
// line over OOC as an always-works fallback.
//
// IMPORTANT lifetime note: area_set_name stores the String slice BY REFERENCE
// (like area_set_background / status tags). So /scene copies the name into a
// static buffer that outlives the call, and the plugin RESTORES every area's
// original name in whisker_plugin_shutdown — otherwise, after /reload unloaded
// this .dll, area.name would dangle into freed memory.

module narrator;

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

const String PLUGIN_NAME = "Narrator";
const int    MAX_AREAS   = 64;

PluginAPI* api;
char[64][MAX_AREAS] scene_bufs;   // stable backing for /scene names
String[MAX_AREAS]   orig_names;   // config-owned names, captured at init
int area_n;

fn bool can_narrate(void* c) {
    if (api.client_is_mod(c)) return true;
    return api.area_is_cm(api.client_get_area(c), api.client_get_uid(c));
}

fn void narrate_body(void* c, String args) {
    if (!can_narrate(c)) { api.client_send_msg(c, "Only CMs or mods can narrate here."); return; }
    String text = args.trim();
    if (text.len == 0) { api.client_send_msg(c, "Usage: /narrate <text>"); return; }
    int area = api.client_get_area(c);
    api.area_post_ic(area, "Narrator", "Narrator", text, "wit");
    api.broadcast_area_msg(area, string::tformat("[Narration] %s", text)); // always-works fallback
}
fn void cmd_narrate(void* c, String args) { @pool_init(mem, 64 * 1024) { narrate_body(c, args); }; }

fn void scene_body(void* c, String args) {
    if (!can_narrate(c)) { api.client_send_msg(c, "Only CMs or mods can set the scene."); return; }
    int area = api.client_get_area(c);
    if (area < 0 || area >= MAX_AREAS) return;
    String name = args.trim();
    if (name.len == 0) { api.client_send_msg(c, "Usage: /scene <name>"); return; }

    int len = (int)name.len; if (len > 63) len = 63;
    for (int i = 0; i < len; i++) scene_bufs[area][i] = name[i];
    api.area_set_name(area, (String)scene_bufs[area][0..(usz)len - 1]);

    api.client_send_msg(c, string::tformat("Scene set — new arrivals will see this area as '%s'.", name));
    api.broadcast_area_msg(area, string::tformat("The scene shifts... (now: %s)", name));
}
fn void cmd_scene(void* c, String args) { @pool_init(mem, 64 * 1024) { scene_body(c, args); }; }

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return { .name = "Narrator", .version = "1.0.0", .author = "Whisker Community",
             .description = "/narrate /scene — server-authored IC + area rename. Demo of v8 area_post_ic & area_set_name." };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    area_n = api.get_area_count();
    if (area_n > MAX_AREAS) area_n = MAX_AREAS;
    for (int i = 0; i < area_n; i++) orig_names[i] = api.area_get_name(i); // config-owned, stable
    api.register_command("narrate", &cmd_narrate, 0, "Post a Narrator IC line (CM/mod)", PLUGIN_NAME);
    api.register_command("scene",   &cmd_scene,   0, "Rename the area for the scene (CM/mod)", PLUGIN_NAME);
    io::printn("[narrator] Loaded. /narrate /scene ready.");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    // Restore original names so area.name never dangles into this unloaded .dll.
    for (int i = 0; i < area_n; i++) api.area_set_name(i, orig_names[i]);
    io::printn("[narrator] Unloaded (area names restored).");
}
