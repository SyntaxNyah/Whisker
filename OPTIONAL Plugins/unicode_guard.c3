// Whisker Optional Plugin — Unicode Guard [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Defends against "zalgo" / combining-character abuse: messages or shownames
// stacked with dozens of combining diacritics that smear across the screen. Two
// actions: 'block' (the message is held; clean default) or 'strip' (the
// combining marks are removed and the message re-broadcast). Optional — drop the
// .dll/.so into plugins/ and restart.
//
// It targets the common combining block U+0300–U+036F (UTF-8 lead bytes 0xCC /
// 0xCD), which is what virtually all zalgo uses. Normal accented text uses
// precomposed characters and is unaffected.
//
// Standalone plugin: see the Plugin Dev Guide (plugins/PLUGIN DEV GUIDE README.md).

module unicode_guard;

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

const String PLUGIN_NAME = "Unicode Guard";
const int MS_MESSAGE = 4;
const int MS_SHOWNAME = 15;
const int CT_MESSAGE = 1;

char[160] msg_buf;
char[512] path_config;

PluginAPI* api;
bool opt_enabled     = true;
bool opt_strip       = false; // false = block, true = strip + rebuild
int  opt_max         = 4;     // combining marks tolerated before flagging
bool opt_filter_ic   = true;
bool opt_filter_ooc  = true;
bool opt_exempt_mods = true;

extern fn void* fopen_c(ZString path, ZString mode) @cname("fopen");
extern fn char* fgets_c(char* buf, CInt size, void* stream) @cname("fgets");
extern fn CInt  fclose_c(void* stream) @cname("fclose");
extern fn CInt  fputs_c(ZString s, void* stream) @cname("fputs");

fn usz put_str(char[] buf, usz n, String s) { foreach (char ch : s) { if (n >= buf.len) break; buf[n] = ch; n++; } return n; }
fn String cstr(char* buf) { int l = 0; while (buf[l] != 0) l++; return l == 0 ? "" : (String)buf[0..l - 1]; }
fn void copy_cstr(String src, char* dst, usz max) { usz i = 0; while (i < src.len && i < max) { dst[i] = src[i]; i++; } dst[i] = 0; }
fn bool is_true(String s) { return s == "true" || s == "1" || s == "yes" || s == "on"; }
fn ulong parse_ulong(String s) { ulong v = 0; foreach (char ch : s) { if (ch >= '0' && ch <= '9') v = v * 10 + (ulong)(ch - '0'); } return v; }

// Count combining marks (U+0300–036F → UTF-8 lead 0xCC/0xCD + one continuation).
fn int count_combining(String s) {
    int c = 0;
    for (usz i = 0; i < s.len; i++) {
        char b = s[i];
        if (b == 0xCC || b == 0xCD) { c++; i++; } // skip the trailing continuation byte
    }
    return c;
}

// Escape for the wire AND drop combining marks, in one pass.
fn usz put_escaped_stripped(char[] buf, usz n, String s) {
    for (usz i = 0; i < s.len; i++) {
        char ch = s[i];
        if (ch == 0xCC || ch == 0xCD) { i++; continue; } // skip mark + continuation
        switch (ch) {
            case '#': n = put_str(buf, n, "<num>");
            case '&': n = put_str(buf, n, "<and>");
            case '%': n = put_str(buf, n, "<percent>");
            case '$': n = put_str(buf, n, "<dollar>");
            default:  if (n < buf.len) { buf[n] = ch; n++; }
        }
    }
    return n;
}

fn usz build_ms_stripped(char[] buf, void* pkt) {
    int fc = api.packet_get_field_count(pkt);
    usz n = put_str(buf, 0, "MS");
    int upto = fc < 18 ? fc : 18;
    for (int i = 0; i < upto; i++) { n = put_str(buf, n, "#"); n = put_escaped_stripped(buf, n, api.packet_get_field(pkt, i)); }
    for (int i = upto; i < 18; i++) n = put_str(buf, n, "#");
    n = put_str(buf, n, "####");
    for (int i = 18; i < fc; i++) { n = put_str(buf, n, "#"); n = put_escaped_stripped(buf, n, api.packet_get_field(pkt, i)); }
    n = put_str(buf, n, "#%");
    return n;
}
fn usz build_ct_stripped(char[] buf, void* pkt) {
    int fc = api.packet_get_field_count(pkt);
    usz n = put_str(buf, 0, "CT");
    for (int i = 0; i < fc; i++) { n = put_str(buf, n, "#"); n = put_escaped_stripped(buf, n, api.packet_get_field(pkt, i)); }
    n = put_str(buf, n, "#%");
    return n;
}

fn bool on_ic(void* c, void* pkt) {
    if (!opt_enabled || !opt_filter_ic) return false;
    if (opt_exempt_mods && api.client_is_mod(c)) return false;
    int fc = api.packet_get_field_count(pkt);
    String msg  = api.packet_get_field(pkt, MS_MESSAGE);
    String show = fc > MS_SHOWNAME ? api.packet_get_field(pkt, MS_SHOWNAME) : "";
    if (count_combining(msg) <= opt_max && count_combining(show) <= opt_max) return false;
    if (opt_strip) {
        char[2048] pb; usz pn = build_ms_stripped(pb[..], pkt);
        api.broadcast_area_raw(api.client_get_area(c), (String)pb[0..pn - 1]);
        return true;
    }
    api.client_send_msg(c, cstr(&msg_buf[0]));
    return true;
}
fn bool on_ooc(void* c, void* pkt) {
    if (!opt_enabled || !opt_filter_ooc) return false;
    if (opt_exempt_mods && api.client_is_mod(c)) return false;
    if (api.packet_get_field_count(pkt) < 2) return false;
    String m = api.packet_get_field(pkt, CT_MESSAGE);
    if (m.len > 0 && m[0] == '/') return false;
    String name = api.packet_get_field(pkt, 0);
    if (count_combining(m) <= opt_max && count_combining(name) <= opt_max) return false;
    if (opt_strip) {
        char[1024] pb; usz pn = build_ct_stripped(pb[..], pkt);
        api.broadcast_area_raw(api.client_get_area(c), (String)pb[0..pn - 1]);
        return true;
    }
    api.client_send_msg(c, cstr(&msg_buf[0]));
    return true;
}

fn void load_config() {
    copy_cstr("Your message was held — too many combining characters (zalgo).", &msg_buf[0], 159);
    void* f = fopen_c((ZString)&path_config[0], "r");
    if (f == null) { write_template(); return; }
    char[512] line;
    while (fgets_c(&line[0], 512, f) != null) {
        String raw = cstr(&line[0]).trim();
        if (raw.len == 0 || raw[0] == '#') continue;
        usz sp = 0; while (sp < raw.len && raw[sp] != ' ' && raw[sp] != '\t') sp++;
        String key = sp == 0 ? raw : raw[0..sp - 1];
        String rest = sp < raw.len ? raw[sp..].trim() : "";
        if (key == "enabled")        { opt_enabled = is_true(rest); }
        else if (key == "action")    { opt_strip = (rest == "strip"); }
        else if (key == "max_combining") { int x = (int)parse_ulong(rest); if (x >= 0) opt_max = x; }
        else if (key == "filter_ic") { opt_filter_ic = is_true(rest); }
        else if (key == "filter_ooc"){ opt_filter_ooc = is_true(rest); }
        else if (key == "exempt_mods") { opt_exempt_mods = is_true(rest); }
        else if (key == "message" && rest.len > 0) { copy_cstr(rest, &msg_buf[0], 159); }
    }
    fclose_c(f);
}

fn void write_template() {
    void* f = fopen_c((ZString)&path_config[0], "w");
    if (f == null) return;
    fputs_c("# Whisker Unicode Guard — defend against zalgo / combining-char abuse\n", f);
    fputs_c("#\n", f);
    fputs_c("# action         block   # 'block' (clean; default) or 'strip' (remove marks, rebuild line)\n", f);
    fputs_c("# max_combining  4       # combining marks tolerated before a message is flagged\n", f);
    fputs_c("# filter_ic      true\n", f);
    fputs_c("# filter_ooc     true\n", f);
    fputs_c("# exempt_mods    true\n", f);
    fputs_c("# message        Your message was held (zalgo).\n", f);
    fputs_c("# enabled        true\n", f);
    fputs_c("#\n", f);
    fputs_c("# NOTE: 'strip' rebuilds the line, so it loses pairing and isn't seen by\n", f);
    fputs_c("# logging/relay plugins. Prefer 'block' unless you need the cleaned line shown.\n", f);
    fclose_c(f);
}

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return { "Unicode Guard", "1.0.0", "Whisker Community", "Block/strip zalgo combining chars. Optional." };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    usz n = 0; n = put_str(path_config[..], n, "config/unicode_guard.txt"); path_config[n] = 0;
    void* probe = fopen_c((ZString)&path_config[0], "r");
    if (probe != null) { fclose_c(probe); }
    else {
        void* alt = fopen_c("../config/config.toml", "r");
        if (alt != null) { fclose_c(alt); n = 0; n = put_str(path_config[..], n, "../config/unicode_guard.txt"); path_config[n] = 0; }
    }
    load_config();
    api.register_hook("MS", &on_ic, PLUGIN_NAME);
    api.register_hook("CT", &on_ooc, PLUGIN_NAME);
    io::printfn("[unicode_guard] Loaded (max %d combining, action=%s).", opt_max, opt_strip ? "strip" : "block");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    io::printn("[unicode_guard] Shutting down.");
}
