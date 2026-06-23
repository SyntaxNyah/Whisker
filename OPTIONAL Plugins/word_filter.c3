// Whisker Optional Plugin — Word Filter [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Filters a configurable word blacklist out of IC/OOC chat. Two modes:
//   block  — the offending message never goes out (clean; the default).
//   censor — the matched words are replaced with **** and the message is
//            re-broadcast. NOTE: a censored line is consumed + rebuilt, so it
//            loses the core's pairing insertion for that one line, and other
//            hooks (chat_logger, discord_modcall) don't see it. Use 'block'
//            unless you specifically need the message to still appear.
// Optional escalation: auto-mute repeat offenders. Optional — drop the .dll/.so
// into plugins/ and restart.
//
// Standalone plugin: see the Plugin Dev Guide (plugins/PLUGIN DEV GUIDE README.md).

module word_filter;

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

const String PLUGIN_NAME = "Word Filter";
const int MAX_BAD = 512;
const int MAX_VIOL = 1024;
const int MS_MESSAGE = 4;
const int CT_MESSAGE = 1;

char[48][MAX_BAD] bad; int bad_n; // lower-cased
char[160] msg_buf;
char[512] path_config;

struct Viol { bool used; int uid; int count; long first; }
Viol[MAX_VIOL] viols;

PluginAPI* api;
bool opt_enabled     = true;
bool opt_censor      = false; // false = block, true = censor (rebuild)
bool opt_filter_ic   = true;
bool opt_filter_ooc  = true;
bool opt_exempt_mods = true;
bool opt_escalate    = false;
int  opt_threshold   = 3;
int  opt_window      = 30;

extern fn long time_c(void* t) @cname("time");
extern fn void* fopen_c(ZString path, ZString mode) @cname("fopen");
extern fn char* fgets_c(char* buf, CInt size, void* stream) @cname("fgets");
extern fn CInt  fclose_c(void* stream) @cname("fclose");
extern fn CInt  fputs_c(ZString s, void* stream) @cname("fputs");

fn usz put_str(char[] buf, usz n, String s) { foreach (char ch : s) { if (n >= buf.len) break; buf[n] = ch; n++; } return n; }
fn usz put_escaped(char[] buf, usz n, String s) {
    foreach (char ch : s) {
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
fn String cstr(char* buf) { int l = 0; while (buf[l] != 0) l++; return l == 0 ? "" : (String)buf[0..l - 1]; }
fn void copy_cstr(String src, char* dst, usz max) { usz i = 0; while (i < src.len && i < max) { dst[i] = src[i]; i++; } dst[i] = 0; }
fn bool is_true(String s) { return s == "true" || s == "1" || s == "yes" || s == "on"; }
fn ulong parse_ulong(String s) { ulong v = 0; foreach (char ch : s) { if (ch >= '0' && ch <= '9') v = v * 10 + (ulong)(ch - '0'); } return v; }
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

fn bool has_bad(String msg) {
    if (msg.len == 0 || bad_n == 0) return false;
    char[300] lb;
    String low = lower_copy(msg, lb[..]);
    for (int i = 0; i < bad_n; i++) { if (contains(low, cstr(&bad[i][0]))) return true; }
    return false;
}

// Copy msg into out, asterisking every blacklisted word (case-insensitive).
fn int do_censor(String msg, char* out, int cap) {
    int n = (int)msg.len; if (n > cap) n = cap;
    for (int i = 0; i < n; i++) out[i] = msg[i];
    char[300] lb; int ll = 0;
    for (int i = 0; i < n && ll < 300; i++) { char ch = msg[i]; lb[ll] = (ch >= 'A' && ch <= 'Z') ? ch + 32 : ch; ll++; }
    for (int w = 0; w < bad_n; w++) {
        String pat = cstr(&bad[w][0]);
        int pl = (int)pat.len;
        if (pl == 0 || pl > ll) continue;
        for (int i = 0; i + pl <= ll; i++) {
            bool match = true;
            for (int j = 0; j < pl; j++) { if (lb[i + j] != pat[j]) { match = false; break; } }
            if (match) { for (int j = 0; j < pl; j++) out[i + j] = '*'; }
        }
    }
    return n;
}

// Rebuild an MS packet replacing field `idx` (casing's reconstruction: pad to 18
// client fields + 4 empty pairing fields + any trailing fields).
fn usz build_ms(char[] buf, void* pkt, int idx, String newval) {
    int fc = api.packet_get_field_count(pkt);
    usz n = put_str(buf, 0, "MS");
    int upto = fc < 18 ? fc : 18;
    for (int i = 0; i < upto; i++) {
        n = put_str(buf, n, "#");
        n = (i == idx) ? put_escaped(buf, n, newval) : put_escaped(buf, n, api.packet_get_field(pkt, i));
    }
    for (int i = upto; i < 18; i++) n = put_str(buf, n, "#");
    n = put_str(buf, n, "####");
    for (int i = 18; i < fc; i++) {
        n = put_str(buf, n, "#");
        n = (i == idx) ? put_escaped(buf, n, newval) : put_escaped(buf, n, api.packet_get_field(pkt, i));
    }
    n = put_str(buf, n, "#%");
    return n;
}

// Rebuild a CT (OOC) packet replacing field `idx`.
fn usz build_ct(char[] buf, void* pkt, int idx, String newval) {
    int fc = api.packet_get_field_count(pkt);
    usz n = put_str(buf, 0, "CT");
    for (int i = 0; i < fc; i++) {
        n = put_str(buf, n, "#");
        n = (i == idx) ? put_escaped(buf, n, newval) : put_escaped(buf, n, api.packet_get_field(pkt, i));
    }
    n = put_str(buf, n, "#%");
    return n;
}

fn Viol* vslot(int uid) {
    Viol* free = null;
    for (int i = 0; i < MAX_VIOL; i++) {
        if (viols[i].used && viols[i].uid == uid) return &viols[i];
        if (free == null && !viols[i].used) free = &viols[i];
    }
    if (free != null) { free.used = true; free.uid = uid; free.count = 0; free.first = 0; }
    return free;
}

// Returns true if the player should be auto-muted now.
fn bool escalate(void* c) {
    if (!opt_escalate) return false;
    Viol* v = vslot(api.client_get_uid(c));
    if (v == null) return false;
    long now = time_c(null);
    if (v.first == 0 || now - v.first > (long)opt_window) { v.first = now; v.count = 0; }
    v.count++;
    if (v.count >= opt_threshold) {
        v.count = 0; v.first = 0;
        api.client_mute(c);
        api.client_send_msg(c, "You have been auto-muted for repeated filtered messages.");
        return true;
    }
    return false;
}

fn bool handle(void* c, void* pkt, bool is_ic) {
    if (opt_exempt_mods && api.client_is_mod(c)) return false;
    int idx = is_ic ? MS_MESSAGE : CT_MESSAGE;
    String msg = api.packet_get_field(pkt, idx);
    if (!has_bad(msg)) return false;

    escalate(c); // counts the violation; may auto-mute

    if (opt_censor) {
        char[300] cb; int cn = do_censor(msg, &cb[0], 299);
        char[2048] pb;
        usz pn = is_ic ? build_ms(pb[..], pkt, idx, (String)cb[0..cn - 1])
                       : build_ct(pb[..], pkt, idx, (String)cb[0..cn - 1]);
        api.broadcast_area_raw(api.client_get_area(c), (String)pb[0..pn - 1]);
        return true; // consume the original
    }
    api.client_send_msg(c, cstr(&msg_buf[0]));
    return true; // block
}

fn bool on_ic(void* c, void* pkt) {
    if (!opt_enabled || !opt_filter_ic) return false;
    return handle(c, pkt, true);
}
fn bool on_ooc(void* c, void* pkt) {
    if (!opt_enabled || !opt_filter_ooc) return false;
    if (api.packet_get_field_count(pkt) < 2) return false;
    String m = api.packet_get_field(pkt, CT_MESSAGE);
    if (m.len > 0 && m[0] == '/') return false; // never touch commands
    return handle(c, pkt, false);
}

fn void load_config() {
    bad_n = 0;
    copy_cstr("Your message was blocked by the word filter.", &msg_buf[0], 159);
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
        else if (key == "mode")      { opt_censor = (rest == "censor"); }
        else if (key == "filter_ic") { opt_filter_ic = is_true(rest); }
        else if (key == "filter_ooc"){ opt_filter_ooc = is_true(rest); }
        else if (key == "exempt_mods") { opt_exempt_mods = is_true(rest); }
        else if (key == "escalate")  { opt_escalate = is_true(rest); }
        else if (key == "threshold") { int x = (int)parse_ulong(rest); if (x > 0) opt_threshold = x; }
        else if (key == "window_seconds") { int x = (int)parse_ulong(rest); if (x > 0) opt_window = x; }
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
    fputs_c("# Whisker Word Filter — block or censor a word blacklist in chat\n", f);
    fputs_c("# Case-insensitive substring match. One word per 'bad' line.\n", f);
    fputs_c("#\n", f);
    fputs_c("# mode          block     # 'block' (clean; default) or 'censor' (****, rebuilds the line)\n", f);
    fputs_c("# bad           badword1  # add the words to filter (repeatable)\n", f);
    fputs_c("# filter_ic     true\n", f);
    fputs_c("# filter_ooc    true\n", f);
    fputs_c("# exempt_mods   true\n", f);
    fputs_c("# escalate      false     # auto-mute repeat offenders\n", f);
    fputs_c("# threshold     3         # violations within the window before a mute\n", f);
    fputs_c("# window_seconds 30\n", f);
    fputs_c("# message       Your message was blocked by the word filter.\n", f);
    fputs_c("# enabled       true\n", f);
    fputs_c("#\n", f);
    fputs_c("# NOTE: 'censor' rebuilds the message, so that line loses pairing and is not\n", f);
    fputs_c("# seen by logging/relay plugins. Prefer 'block' unless you need the line shown.\n", f);
    fclose_c(f);
}

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return { "Word Filter", "1.0.0", "Whisker Community", "Block/censor a word blacklist. Optional." };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    for (int i = 0; i < MAX_VIOL; i++) viols[i].used = false;
    usz n = 0; n = put_str(path_config[..], n, "config/word_filter.txt"); path_config[n] = 0;
    void* probe = fopen_c((ZString)&path_config[0], "r");
    if (probe != null) { fclose_c(probe); }
    else {
        void* alt = fopen_c("../config/config.toml", "r");
        if (alt != null) { fclose_c(alt); n = 0; n = put_str(path_config[..], n, "../config/word_filter.txt"); path_config[n] = 0; }
    }
    load_config();
    api.register_hook("MS", &on_ic, PLUGIN_NAME);
    api.register_hook("CT", &on_ooc, PLUGIN_NAME);
    io::printfn("[word_filter] Loaded (%d word(s), mode=%s escalate=%s).",
        bad_n, opt_censor ? "censor" : "block", opt_escalate ? "on" : "off");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    io::printn("[word_filter] Shutting down.");
}
