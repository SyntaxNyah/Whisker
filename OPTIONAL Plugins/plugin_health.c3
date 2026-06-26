// Whisker Optional Plugin — Plugin Health [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Lists the plugins currently loaded on the server, with version, so anyone can
// see at a glance what's running — handy for support ("what plugins do you have?")
// and for confirming a drop-in actually loaded. Uses the v7 plugin-enumeration API
// (get_plugin_count / get_plugin_name / get_plugin_version). Drop the compiled
// .dll / .so into plugins/ and restart. Optional.
//
// This source file is provided as a learning exercise. To compile a C3 plugin
// yourself, follow the Plugin Dev Guide: plugins/PLUGIN DEV GUIDE README.md
//
// ============================================================
// What it does
// ============================================================
//
//   /plugins     list every loaded plugin and its version
//
// ============================================================
// Why this is an OPTIONAL plugin — and zero passive cost
// ============================================================
//
// Most servers don't need an in-game plugin list, so it's opt-in. It registers one
// command and **no packet hooks**, so it does nothing until someone types
// /plugins; it reads the loaded-plugin table on demand and prints it.
//
// API note: this needs the v7 plugin-enumeration calls. A plugin compiled against
// an OLDER server (pre-v7) would read past that server's PluginAPI and must not be
// used there — but every Whisker with the v7 API runs it fine.

module plugin_health;

import std::io;

// ============================================================
// Whisker plugin interface (standalone) — FULL v7 struct.
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
// v7
alias GetPluginCountFn         = fn int();
alias GetPluginNameFn          = fn String(int);
alias GetPluginVersionFn       = fn String(int);
alias OutboundMsgFilter        = fn int(void*, String, char*, int);
alias RegisterOutboundFilterFn = fn void(OutboundMsgFilter);
alias ClientGetHdidFn          = fn String(void*);
alias AreaSetHpFn              = fn void(int, int, int);

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
    // v7
    GetPluginCountFn         get_plugin_count;
    GetPluginNameFn          get_plugin_name;
    GetPluginVersionFn       get_plugin_version;
    RegisterOutboundFilterFn register_outbound_filter;
    ClientGetHdidFn          client_get_hdid;
    AreaSetHpFn              area_set_hp;
}

const String PLUGIN_NAME = "Plugin Health";
PluginAPI* api;

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

fn void cmd_plugins(void* c, String args) {
    int count = api.get_plugin_count();
    char[80] h; usz hn = 0;
    hn = put_str(h[..], hn, "— Loaded plugins (");
    hn = put_int(h[..], hn, count);
    hn = put_str(h[..], hn, ") —");
    api.client_send_msg(c, (String)h[0..hn - 1]);

    if (count == 0) { api.client_send_msg(c, "(none)"); return; }

    for (int i = 0; i < count; i++) {
        char[160] m; usz n = 0;
        n = put_int(m[..], n, i + 1);
        n = put_str(m[..], n, ". ");
        n = put_str(m[..], n, api.get_plugin_name(i));
        n = put_str(m[..], n, " v");
        n = put_str(m[..], n, api.get_plugin_version(i));
        api.client_send_msg(c, (String)m[0..n - 1]);
    }
}

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return {
        .name        = "Plugin Health",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Lists loaded plugins: /plugins. Optional. Needs the v7 API.",
    };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    api.register_command("plugins", &cmd_plugins, 0, "List loaded plugins and versions", PLUGIN_NAME);
    io::printn("[plugin_health] Loaded. /plugins ready.");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    io::printn("[plugin_health] Unloaded.");
}
