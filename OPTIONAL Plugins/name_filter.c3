// Whisker Optional Plugin — Name Filter [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Rejects players whose showname, character, or OOC name matches a blacklist of
// patterns (from a text file). Two actions: 'drop' (their messages silently
// don't go out until they change the name) or 'kick' (disconnect with a reason).
//
// NOTE: the Plugin API has no ban primitive, so this CANNOT ban. The strongest
// action is a kick — pair it with the core /ban for an actual ban. Optional —
// drop the .dll/.so into plugins/ and restart.
//
// Standalone plugin: see the Plugin Dev Guide (plugins/PLUGIN DEV GUIDE README.md).

module name_filter;

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

const String PLUGIN_NAME = "Name Filter";
const int MAX_BAD = 256;
const int MS_CHAR = 2;
const int MS_SHOWNAME = 15;
const int CT_OOC_NAME = 0;

char[48][MAX_BAD] bad; int bad_n; // lower-cased patterns
char[160] msg_buf;
char[512] path_config;

PluginAPI* api;
bool opt_enabled        = true;
bool opt_action_kick    = true;  // true = kick, false = drop (silent block)
bool opt_check_showname = true;
bool opt_check_charname = true;
bool opt_check_oocname  = true;

extern fn void* fopen_c(ZString path, ZString mode) @cname("fopen");
extern fn char* fgets_c(char* buf, CInt size, void* stream) @cname("fgets");
extern fn CInt  fclose_c(void* stream) @cname("fclose");
extern fn CInt  fputs_c(ZString s, void* stream) @cname("fputs");

fn usz put_str(char[] buf, usz n, String s) { foreach (char ch : s) { if (n >= buf.len) break; buf[n] = ch; n++; } return n; }
fn String cstr(char* buf) { int l = 0; while (buf[l] != 0) l++; return l == 0 ? "" : (String)buf[0..l - 1]; }
fn void copy_cstr(String src, char* dst, usz max) { usz i = 0; while (i < src.len && i < max) { dst[i] = src[i]; i++; } dst[i] = 0; }
fn bool is_true(String s) { return s == "true" || s == "1" || s == "yes" || s == "on"; }
fn String lower_copy(String s, char[] buf) {
    usz n = 0;
    foreach (char ch : s) { if (n >= buf.len) break; buf[n] = (ch >= 'A' && ch <= 'Z') ? ch + 32 : ch; n++; }
    return n == 0 ? "" : (String)buf[0..n - 1];
}
fn bool contains(String s, String sub) {
    if (sub.len == 0 || s.len < sub.len) return false;
    for (usz i = 0; i + sub.len <= s.len; i++) {
        bool ok = true;
        for (usz j = 0; j < sub.len; j++) { if (s[i + j] != sub[j]) { ok = false; break; } }
        if (ok) return true;
    }
    return false;
}

fn bool name_bad(String name) {
    if (name.len == 0) return false;
    char[200] lb;
    String low = lower_copy(name, lb[..]);
    for (int i = 0; i < bad_n; i++) { if (contains(low, cstr(&bad[i][0]))) return true; }
    return false;
}

// Take the configured action; always returns true so the offending message is
// consumed (never broadcast).
fn bool act(void* c) {
    if (opt_action_kick) { api.client_kick_msg(c, cstr(&msg_buf[0])); }
    else { api.client_send_msg(c, cstr(&msg_buf[0])); }
    return true;
}

fn bool on_ic(void* c, void* pkt) {
    if (!opt_enabled) return false;
    int fc = api.packet_get_field_count(pkt);
    if (opt_check_showname && fc > MS_SHOWNAME && name_bad(api.packet_get_field(pkt, MS_SHOWNAME))) return act(c);
    if (opt_check_charname) {
        String chr = fc > MS_CHAR ? api.packet_get_field(pkt, MS_CHAR) : api.client_get_char_name(c);
        if (name_bad(chr)) return act(c);
    }
    return false;
}
fn bool on_ooc(void* c, void* pkt) {
    if (!opt_enabled || !opt_check_oocname) return false;
    if (api.packet_get_field_count(pkt) < 1) return false;
    String m = api.packet_get_field(pkt, 1);
    if (m.len > 0 && m[0] == '/') return false; // don't break commands
    if (name_bad(api.packet_get_field(pkt, CT_OOC_NAME))) return act(c);
    return false;
}

fn void load_config() {
    bad_n = 0;
    copy_cstr("Your name contains a blocked word. Change it to continue.", &msg_buf[0], 159);
    void* f = fopen_c((ZString)&path_config[0], "r");
    if (f == null) { write_template(); return; }
    char[512] line;
    while (fgets_c(&line[0], 512, f) != null) {
        String raw = cstr(&line[0]).trim();
        if (raw.len == 0 || raw[0] == '#') continue;
        usz sp = 0; while (sp < raw.len && raw[sp] != ' ' && raw[sp] != '\t') sp++;
        String key = sp == 0 ? raw : raw[0..sp - 1];
        String rest = sp < raw.len ? raw[sp..].trim() : "";
        if (key == "enabled")          { opt_enabled = is_true(rest); }
        else if (key == "action")      { opt_action_kick = (rest == "kick"); }
        else if (key == "check_showname") { opt_check_showname = is_true(rest); }
        else if (key == "check_charname") { opt_check_charname = is_true(rest); }
        else if (key == "check_oocname")  { opt_check_oocname = is_true(rest); }
        else if (key == "message" && rest.len > 0) { copy_cstr(rest, &msg_buf[0], 159); }
        else if (key == "bad" && rest.len > 0 && bad_n < MAX_BAD) {
            char[48] lb; String low = lower_copy(rest, lb[..]);
            copy_cstr(low, &bad[bad_n][0], 47); bad_n++;
        }
    }
    fclose_c(f);
}

fn void write_template() {
    void* f = fopen_c((ZString)&path_config[0], "w");
    if (f == null) return;
    fputs_c("# Whisker Name Filter — reject offensive shownames/characters/OOC names\n", f);
    fputs_c("# Case-insensitive substring match. One pattern per 'bad' line.\n", f);
    fputs_c("#\n", f);
    fputs_c("# action          kick      # 'kick' (disconnect) or 'drop' (silently block their messages)\n", f);
    fputs_c("# bad             slur1     # add the words you want blocked (repeatable)\n", f);
    fputs_c("# check_showname  true\n", f);
    fputs_c("# check_charname  true\n", f);
    fputs_c("# check_oocname   true\n", f);
    fputs_c("# message         Your name contains a blocked word. Change it to continue.\n", f);
    fputs_c("# enabled         true\n", f);
    fputs_c("#\n", f);
    fputs_c("# NOTE: this kicks at most — the Plugin API has no ban. Use the core /ban to ban.\n", f);
    fclose_c(f);
}

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return { "Name Filter", "1.0.0", "Whisker Community", "Reject offensive names (drop/kick). Optional." };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    usz n = 0; n = put_str(path_config[..], n, "config/name_filter.txt"); path_config[n] = 0;
    void* probe = fopen_c((ZString)&path_config[0], "r");
    if (probe != null) { fclose_c(probe); }
    else {
        void* alt = fopen_c("../config/config.toml", "r");
        if (alt != null) { fclose_c(alt); n = 0; n = put_str(path_config[..], n, "../config/name_filter.txt"); path_config[n] = 0; }
    }
    load_config();
    api.register_hook("MS", &on_ic, PLUGIN_NAME);
    api.register_hook("CT", &on_ooc, PLUGIN_NAME);
    io::printfn("[name_filter] Loaded (%d pattern(s), action=%s).", bad_n, opt_action_kick ? "kick" : "drop");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    io::printn("[name_filter] Shutting down.");
}
