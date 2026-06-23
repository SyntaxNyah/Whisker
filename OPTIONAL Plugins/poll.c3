// Whisker Optional Plugin — Poll [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Multi-option polls with a live tally, per area or server-wide. A CM/mod starts
// one, players /vote, and the running count is broadcast on each vote. Optional —
// drop the .dll/.so into plugins/ and restart.
//
//   /poll <question> | <opt1> | <opt2> [| ...]   start an area poll (CM/mod)
//   /vote <n>                                     vote in the area poll
//   /pollend                                      close it + show results (CM/mod)
//   /gpoll ... / /gvote <n> / /gpollend           the same, server-wide (mod)
//
// Standalone plugin: see the Plugin Dev Guide (plugins/PLUGIN DEV GUIDE README.md).

module poll;

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

const String PLUGIN_NAME = "Poll";
const ulong PERM_MODIFY_AREA = 16;
const int MAX_AREAS = 128;
const int MAX_OPTS = 8;
const int MAX_VOTERS = 512;

struct Poll {
    bool active;
    char[200] q; int qlen;
    char[64][MAX_OPTS] opts; int[MAX_OPTS] olen; int opt_count;
    int[MAX_OPTS] votes;
    int[MAX_VOTERS] voters; int voter_count;
}
Poll[MAX_AREAS] area_poll;
Poll g_poll;

PluginAPI* api;

fn usz put_str(char[] buf, usz n, String s) { foreach (char ch : s) { if (n >= buf.len) break; buf[n] = ch; n++; } return n; }
fn usz put_uint(char[] buf, usz n, ulong v) {
    if (v == 0) return put_str(buf, n, "0");
    char[20] tmp; int t = 0;
    while (v > 0) { tmp[t] = (char)('0' + (int)(v % 10)); t++; v /= 10; }
    while (t > 0) { t--; if (n >= buf.len) break; buf[n] = tmp[t]; n++; }
    return n;
}
fn void copy_n(char* dst, String s, int max, int* outlen) {
    int n = (int)s.len; if (n > max) n = max;
    for (int i = 0; i < n; i++) dst[i] = s[i];
    *outlen = n;
}
fn int split_pipe(String s, String[] out) {
    int n = 0; usz start = 0;
    for (usz i = 0; i <= s.len; i++) {
        if (i == s.len || s[i] == '|') {
            String seg = i > start ? s[start..i - 1] : "";
            if (n < (int)out.len) { out[n] = seg.trim(); n++; }
            start = i + 1;
        }
    }
    return n;
}

fn bool can_manage_area(void* c) {
    if (api.client_is_mod(c)) return true;
    return api.area_is_cm(api.client_get_area(c), api.client_get_uid(c));
}
fn bool has_voted(Poll* p, int uid) {
    for (int i = 0; i < p.voter_count; i++) { if (p.voters[i] == uid) return true; }
    return false;
}

fn void start_poll(Poll* p, String args) {
    String[10] parts;
    int np = split_pipe(args, parts[..]);
    // question + at least two options
    p.active = false;
    if (np < 3 || parts[0].len == 0) return;
    copy_n(&p.q[0], parts[0], 199, &p.qlen);
    p.opt_count = 0;
    for (int i = 1; i < np && p.opt_count < MAX_OPTS; i++) {
        if (parts[i].len == 0) continue;
        copy_n(&p.opts[p.opt_count][0], parts[i], 63, &p.olen[p.opt_count]);
        p.votes[p.opt_count] = 0;
        p.opt_count++;
    }
    if (p.opt_count < 2) return;
    p.voter_count = 0;
    p.active = true;
}

// Build the tally line into buf; returns length.
fn usz tally(char[] buf, Poll* p, bool final_) {
    usz n = 0;
    n = put_str(buf, n, final_ ? "Poll results: " : "Poll: ");
    n = put_str(buf, n, (String)p.q[0..p.qlen - 1]);
    for (int i = 0; i < p.opt_count; i++) {
        n = put_str(buf, n, "  ");
        n = put_uint(buf, n, (ulong)(i + 1));
        n = put_str(buf, n, ") ");
        n = put_str(buf, n, (String)p.opts[i][0..p.olen[i] - 1]);
        n = put_str(buf, n, ": ");
        n = put_uint(buf, n, (ulong)p.votes[i]);
    }
    return n;
}

fn void announce(Poll* p, int area, bool final_) {
    char[700] buf; usz n = tally(buf[..], p, final_);
    String line = (String)buf[0..n - 1];
    if (area < 0) { api.broadcast_all_msg(line); }
    else { api.broadcast_area_msg(area, line); }
}

fn void do_vote(void* c, Poll* p, int area, String args) {
    if (!p.active) { api.client_send_msg(c, "No poll is running."); return; }
    int n = args.trim().to_int() ?? -1;
    if (n < 1 || n > p.opt_count) { api.client_send_msg(c, "Usage: vote with a valid option number."); return; }
    int uid = api.client_get_uid(c);
    if (has_voted(p, uid)) { api.client_send_msg(c, "You already voted in this poll."); return; }
    p.votes[n - 1]++;
    if (p.voter_count < MAX_VOTERS) { p.voters[p.voter_count] = uid; p.voter_count++; }
    announce(p, area, false);
}

// ---- area poll commands ----
fn void cmd_poll(void* c, String a) {
    int area = api.client_get_area(c);
    if (area < 0 || area >= MAX_AREAS) return;
    Poll* p = &area_poll[area];
    if (a.trim().len == 0) {
        if (p.active) { announce(p, area, false); } else { api.client_send_msg(c, "No poll running. Start: /poll <q> | <a> | <b>"); }
        return;
    }
    if (!can_manage_area(c)) { api.client_send_msg(c, "Only a CM or moderator can start a poll."); return; }
    start_poll(p, a);
    if (!p.active) { api.client_send_msg(c, "Usage: /poll <question> | <option1> | <option2> [| ...]"); return; }
    announce(p, area, false);
}
fn void cmd_vote(void* c, String a) {
    int area = api.client_get_area(c);
    if (area < 0 || area >= MAX_AREAS) return;
    do_vote(c, &area_poll[area], area, a);
}
fn void cmd_pollend(void* c, String a) {
    int area = api.client_get_area(c);
    if (area < 0 || area >= MAX_AREAS) return;
    Poll* p = &area_poll[area];
    if (!p.active) { api.client_send_msg(c, "No poll running."); return; }
    if (!can_manage_area(c)) { api.client_send_msg(c, "Only a CM or moderator can end the poll."); return; }
    announce(p, area, true);
    p.active = false;
}

// ---- global poll commands (mod only) ----
fn void cmd_gpoll(void* c, String a) {
    if (a.trim().len == 0) {
        if (g_poll.active) { announce(&g_poll, -1, false); } else { api.client_send_msg(c, "No global poll running."); }
        return;
    }
    if (!api.client_is_mod(c)) { api.client_send_msg(c, "Only a moderator can start a global poll."); return; }
    start_poll(&g_poll, a);
    if (!g_poll.active) { api.client_send_msg(c, "Usage: /gpoll <question> | <option1> | <option2> [| ...]"); return; }
    announce(&g_poll, -1, false);
}
fn void cmd_gvote(void* c, String a) { do_vote(c, &g_poll, -1, a); }
fn void cmd_gpollend(void* c, String a) {
    if (!g_poll.active) { api.client_send_msg(c, "No global poll running."); return; }
    if (!api.client_is_mod(c)) { api.client_send_msg(c, "Only a moderator can end the global poll."); return; }
    announce(&g_poll, -1, true);
    g_poll.active = false;
}

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return { "Poll", "1.0.0", "Whisker Community", "Area/global polls with live tally. Optional." };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    for (int i = 0; i < MAX_AREAS; i++) area_poll[i].active = false;
    g_poll.active = false;
    api.register_command("poll", &cmd_poll, 0, "Start/show an area poll: /poll <q> | <a> | <b>", PLUGIN_NAME);
    api.register_command("vote", &cmd_vote, 0, "Vote in the area poll: /vote <n>", PLUGIN_NAME);
    api.register_command("pollend", &cmd_pollend, 0, "End the area poll (CM/mod)", PLUGIN_NAME);
    api.register_command("gpoll", &cmd_gpoll, 0, "Start/show a server-wide poll (mod)", PLUGIN_NAME);
    api.register_command("gvote", &cmd_gvote, 0, "Vote in the server-wide poll: /gvote <n>", PLUGIN_NAME);
    api.register_command("gpollend", &cmd_gpollend, 0, "End the server-wide poll (mod)", PLUGIN_NAME);
    io::printn("[poll] Loaded. /poll /vote /pollend (+ /gpoll global) ready.");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    io::printn("[poll] Shutting down.");
}
