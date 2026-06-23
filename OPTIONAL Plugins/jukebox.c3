// Whisker Optional Plugin — Jukebox [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Two music features in one:
//   /blockdj <uid>   — stop a player from changing the area's music (mod tool)
//   /request <song>  — players queue songs; a mod/CM advances with /skip
// The classic AO "blockdj" plus a request queue. Optional — drop the .dll/.so
// into plugins/ and restart.
//
// Standalone plugin: see the Plugin Dev Guide (plugins/PLUGIN DEV GUIDE README.md).

module jukebox;

import std::io;

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
}

const String PLUGIN_NAME = "Jukebox";
const ulong PERM_MUTE = 1;
const int EVENT_LEAVE = 1;
const int MAX_AREAS = 128;
const int QMAX = 32;
const int MAX_BLOCK = 1024;

struct AreaQ { int head; int count; char[256][QMAX] songs; int[QMAX] uids; }
AreaQ[MAX_AREAS] queues;

struct Blocked { bool used; int uid; }
Blocked[MAX_BLOCK] blocked;

PluginAPI* api;

fn usz put_str(char[] buf, usz n, String s) { foreach (char ch : s) { if (n >= buf.len) break; buf[n] = ch; n++; } return n; }
fn usz put_uint(char[] buf, usz n, ulong v) {
    if (v == 0) return put_str(buf, n, "0");
    char[20] tmp; int t = 0;
    while (v > 0) { tmp[t] = (char)('0' + (int)(v % 10)); t++; v /= 10; }
    while (t > 0) { t--; if (n >= buf.len) break; buf[n] = tmp[t]; n++; }
    return n;
}
fn String cstr(char* buf) { int l = 0; while (buf[l] != 0) l++; return l == 0 ? "" : (String)buf[0..l - 1]; }
fn void copy_cstr(String src, char* dst, usz max) { usz i = 0; while (i < src.len && i < max) { dst[i] = src[i]; i++; } dst[i] = 0; }
fn int first_uid(String args) {
    String s = args.trim(); usz i = 0; while (i < s.len && s[i] != ' ' && s[i] != '\t') i++;
    String tok = i == 0 ? s : s[0..i - 1];
    return tok.to_int() ?? -1;
}

fn bool dj_blocked(int uid) {
    for (int i = 0; i < MAX_BLOCK; i++) { if (blocked[i].used && blocked[i].uid == uid) return true; }
    return false;
}
fn void set_block(int uid, bool on) {
    for (int i = 0; i < MAX_BLOCK; i++) { if (blocked[i].used && blocked[i].uid == uid) { if (!on) blocked[i].used = false; return; } }
    if (!on) return;
    for (int i = 0; i < MAX_BLOCK; i++) { if (!blocked[i].used) { blocked[i].used = true; blocked[i].uid = uid; return; } }
}

// MC (music change) hook — reject a blocked DJ's music change.
fn bool on_mc(void* c, void* pkt) {
    if (!dj_blocked(api.client_get_uid(c))) return false;
    api.client_send_msg(c, "You are blocked from changing the music here.");
    return true; // consume
}

fn void on_life(void* c, int ev) { if (ev == EVENT_LEAVE) set_block(api.client_get_uid(c), false); }

fn void cmd_blockdj(void* c, String a) {
    int uid = first_uid(a);
    if (uid < 0) { api.client_send_msg(c, "Usage: /blockdj <uid>"); return; }
    set_block(uid, true);
    char[48] m; usz n = put_str(m[..], 0, "Blocked DJ for UID "); n = put_uint(m[..], n, (ulong)uid);
    api.client_send_msg(c, (String)m[0..n - 1]);
}
fn void cmd_unblockdj(void* c, String a) {
    int uid = first_uid(a);
    if (uid < 0) { api.client_send_msg(c, "Usage: /unblockdj <uid>"); return; }
    set_block(uid, false);
    char[48] m; usz n = put_str(m[..], 0, "Unblocked DJ for UID "); n = put_uint(m[..], n, (ulong)uid);
    api.client_send_msg(c, (String)m[0..n - 1]);
}

fn void cmd_request(void* c, String a) {
    String song = a.trim();
    if (song.len == 0) { api.client_send_msg(c, "Usage: /request <song>"); return; }
    int area = api.client_get_area(c);
    if (area < 0 || area >= MAX_AREAS) return;
    AreaQ* q = &queues[area];
    if (q.count >= QMAX) { api.client_send_msg(c, "The request queue is full."); return; }
    int slot = (q.head + q.count) % QMAX;
    copy_cstr(song, &q.songs[slot][0], 255);
    q.uids[slot] = api.client_get_uid(c);
    q.count++;
    char[300] m; usz n = put_str(m[..], 0, "Queued (#");
    n = put_uint(m[..], n, (ulong)q.count); n = put_str(m[..], n, "): "); n = put_str(m[..], n, song);
    api.broadcast_area_msg(area, (String)m[0..n - 1]);
}

fn void cmd_skip(void* c, String a) {
    int area = api.client_get_area(c);
    if (area < 0 || area >= MAX_AREAS) return;
    AreaQ* q = &queues[area];
    if (q.count == 0) { api.client_send_msg(c, "The request queue is empty."); return; }
    int slot = q.head;
    String song = cstr(&q.songs[slot][0]);
    int uid = q.uids[slot];
    q.head = (q.head + 1) % QMAX; q.count--;
    api.area_set_song(area, song, uid);
    char[300] m; usz n = put_str(m[..], 0, "Now playing: "); n = put_str(m[..], n, song);
    api.broadcast_area_msg(area, (String)m[0..n - 1]);
}

fn void cmd_queue(void* c, String a) {
    int area = api.client_get_area(c);
    if (area < 0 || area >= MAX_AREAS) return;
    AreaQ* q = &queues[area];
    if (q.count == 0) { api.client_send_msg(c, "The request queue is empty."); return; }
    api.client_send_msg(c, "Request queue:");
    int show = q.count < 10 ? q.count : 10;
    for (int k = 0; k < show; k++) {
        int slot = (q.head + k) % QMAX;
        char[300] m; usz n = put_str(m[..], 0, "  "); n = put_uint(m[..], n, (ulong)(k + 1));
        n = put_str(m[..], n, ". "); n = put_str(m[..], n, cstr(&q.songs[slot][0]));
        api.client_send_msg(c, (String)m[0..n - 1]);
    }
}

fn void cmd_djclear(void* c, String a) {
    int area = api.client_get_area(c);
    if (area < 0 || area >= MAX_AREAS) return;
    queues[area].head = 0; queues[area].count = 0;
    api.client_send_msg(c, "Request queue cleared.");
}

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return { "Jukebox", "1.0.0", "Whisker Community", "blockdj + song request queue. Optional." };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    for (int i = 0; i < MAX_BLOCK; i++) blocked[i].used = false;
    for (int i = 0; i < MAX_AREAS; i++) { queues[i].head = 0; queues[i].count = 0; }
    api.register_hook("MC", &on_mc, PLUGIN_NAME);
    api.register_lifecycle_hook(&on_life, PLUGIN_NAME);
    api.register_command("blockdj", &cmd_blockdj, PERM_MUTE, "Block a player from changing music", PLUGIN_NAME);
    api.register_command("unblockdj", &cmd_unblockdj, PERM_MUTE, "Unblock a player's music control", PLUGIN_NAME);
    api.register_command("request", &cmd_request, 0, "Queue a song request", PLUGIN_NAME);
    api.register_command("queue", &cmd_queue, 0, "Show the request queue", PLUGIN_NAME);
    api.register_command("skip", &cmd_skip, PERM_MUTE, "Play the next queued song", PLUGIN_NAME);
    api.register_command("djclear", &cmd_djclear, PERM_MUTE, "Clear the request queue", PLUGIN_NAME);
    io::printn("[jukebox] Loaded. /blockdj /request /queue /skip ready.");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    io::printn("[jukebox] Shutting down.");
}
