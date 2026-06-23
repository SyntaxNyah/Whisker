// Whisker Optional Plugin — Captcha [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Makes a newly-connected player answer a one-line challenge in OOC before they
// can chat. A simple anti-bot / anti-driveby-spam gate. Once an IPID answers
// correctly it's remembered for the rest of the server's run, so regulars are
// challenged at most once. Optional — drop the .dll/.so into plugins/ and
// restart.
//
// Standalone plugin: see the Plugin Dev Guide (plugins/PLUGIN DEV GUIDE README.md).

module captcha;

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

const String PLUGIN_NAME = "Captcha";
const int EVENT_JOIN = 0;
const int EVENT_LEAVE = 1;
const int MAX_PENDING = 1024;
const int MAX_VERIFIED = 8192;

struct Pending { bool used; int uid; char[12] answer; int alen; bool verified; }
Pending[MAX_PENDING] pend;
char[48][MAX_VERIFIED] verified_ipid; int verified_n;

char[160] prompt_buf;
char[24]  word_buf;

PluginAPI* api;
bool opt_enabled = true;
bool opt_math    = true;  // true = random math, false = fixed word
ulong rng = 0x106689D45497FDB5;

extern fn long time_c(void* t) @cname("time");
extern fn void* fopen_c(ZString path, ZString mode) @cname("fopen");
extern fn char* fgets_c(char* buf, CInt size, void* stream) @cname("fgets");
extern fn CInt  fclose_c(void* stream) @cname("fclose");

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
fn bool is_true(String s) { return s == "true" || s == "1" || s == "yes" || s == "on"; }
fn ulong next_rand() { ulong x = rng; x ^= x << 13; x ^= x >> 7; x ^= x << 17; rng = x; return x; }

fn bool ipid_verified(String ipid) {
    for (int i = 0; i < verified_n; i++) { if (cstr(&verified_ipid[i][0]) == ipid) return true; }
    return false;
}
fn void remember_ipid(String ipid) {
    if (ipid.len == 0 || verified_n >= MAX_VERIFIED) return;
    if (ipid_verified(ipid)) return;
    copy_cstr(ipid, &verified_ipid[verified_n][0], 47);
    verified_n++;
}

fn Pending* find_pending(int uid) {
    for (int i = 0; i < MAX_PENDING; i++) { if (pend[i].used && pend[i].uid == uid) return &pend[i]; }
    return null;
}
fn Pending* new_pending(int uid) {
    Pending* p = find_pending(uid);
    if (p == null) { for (int i = 0; i < MAX_PENDING; i++) { if (!pend[i].used) { p = &pend[i]; p.used = true; p.uid = uid; break; } } }
    return p;
}

// Verified if: no pending entry (fail open — e.g. after a /reload) OR the entry
// is marked verified.
fn bool uid_ok(int uid) {
    Pending* p = find_pending(uid);
    return p == null || p.verified;
}

fn void on_life(void* c, int ev) {
    if (!opt_enabled) return;
    int uid = api.client_get_uid(c);
    if (ev == EVENT_LEAVE) { Pending* p = find_pending(uid); if (p != null) p.used = false; return; }
    if (ev != EVENT_JOIN) return;

    String ipid = api.client_get_ipid(c);
    Pending* p = new_pending(uid);
    if (p == null) return;
    if (ipid_verified(ipid)) { p.verified = true; return; }
    p.verified = false;

    if (opt_math) {
        int a = 1 + (int)(next_rand() % 9);
        int b = 1 + (int)(next_rand() % 9);
        char[12] ab; usz an = put_uint(ab[..], 0, (ulong)(a + b)); ab[an] = 0;
        copy_cstr(cstr(&ab[0]), &p.answer[0], 11); p.alen = (int)an;
        char[160] m; usz n = 0;
        n = put_str(m[..], n, "To chat here, answer this in OOC: ");
        n = put_uint(m[..], n, (ulong)a); n = put_str(m[..], n, " + "); n = put_uint(m[..], n, (ulong)b);
        n = put_str(m[..], n, " = ?");
        api.client_send_msg(c, (String)m[0..n - 1]);
    } else {
        copy_cstr(cstr(&word_buf[0]), &p.answer[0], 11); p.alen = (int)cstr(&word_buf[0]).len;
        api.client_send_msg(c, cstr(&prompt_buf[0]));
    }
}

fn bool on_ic(void* c, void* pkt) {
    if (!opt_enabled) return false;
    if (uid_ok(api.client_get_uid(c))) return false;
    api.client_send_msg(c, "Please answer the captcha (in OOC) before chatting.");
    return true; // consume
}

fn bool on_ooc(void* c, void* pkt) {
    if (!opt_enabled) return false;
    int uid = api.client_get_uid(c);
    Pending* p = find_pending(uid);
    if (p == null || p.verified) return false; // already allowed
    if (api.packet_get_field_count(pkt) < 2) return true;
    String ans = api.packet_get_field(pkt, 1).trim();
    String expect = p.alen > 0 ? (String)p.answer[0..p.alen - 1] : "";
    if (ans == expect) {
        p.verified = true;
        remember_ipid(api.client_get_ipid(c));
        api.client_send_msg(c, "Verified — welcome! You can chat now.");
    } else {
        api.client_send_msg(c, "That's not right. Answer the captcha to chat.");
    }
    return true; // consume the answer attempt (don't broadcast it)
}

fn void load_config(ZString path) {
    void* f = fopen_c(path, "r");
    if (f == null) return;
    char[512] line; int section = 0;
    while (fgets_c(&line[0], 512, f) != null) {
        String raw = cstr(&line[0]).trim();
        if (raw.len == 0 || raw[0] == '#') continue;
        if (raw[0] == '[') { section = (raw == "[captcha]") ? 1 : 0; continue; }
        if (section != 1) continue;
        usz eq = 0; while (eq < raw.len && raw[eq] != '=') eq++;
        if (eq >= raw.len) continue;
        String k = raw[0..eq - 1].trim();
        String v = raw[eq + 1..].trim();
        if (v.len >= 2 && v[0] == '"' && v[v.len - 1] == '"') v = v[1..v.len - 2];
        if (k == "enabled")     { opt_enabled = is_true(v); }
        else if (k == "mode")   { opt_math = (v != "word"); }
        else if (k == "word" && v.len > 0)   { copy_cstr(v, &word_buf[0], 23); }
        else if (k == "prompt" && v.len > 0) { copy_cstr(v, &prompt_buf[0], 159); }
    }
    fclose_c(f);
}

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return { "Captcha", "1.0.0", "Whisker Community", "Answer a challenge before chatting. Optional." };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    for (int i = 0; i < MAX_PENDING; i++) pend[i].used = false;
    rng ^= (ulong)time_c(null);
    if (rng == 0) rng = 0x106689D45497FDB5;
    copy_cstr("GREEN", &word_buf[0], 23);
    copy_cstr("To chat here, type the password in OOC.", &prompt_buf[0], 159);
    void* probe = fopen_c("config/config.toml", "r");
    if (probe != null) { fclose_c(probe); load_config("config/config.toml"); }
    else { load_config("../config/config.toml"); }
    api.register_lifecycle_hook(&on_life, PLUGIN_NAME);
    api.register_hook("MS", &on_ic, PLUGIN_NAME);
    api.register_hook("CT", &on_ooc, PLUGIN_NAME);
    io::printfn("[captcha] Loaded (mode=%s).", opt_math ? "math" : "word");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    io::printn("[captcha] Shutting down.");
}
