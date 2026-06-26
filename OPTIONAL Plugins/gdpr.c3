// Whisker Optional Plugin — GDPR / Player Data [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Helps you answer data requests: dump the data the server currently holds on a
// player, and honour an erasure ("forget me") request by scrubbing that player's
// IPID out of the chat logs. Drop the compiled .dll / .so into plugins/ and
// restart. Optional.
//
// This source file is provided as a learning exercise. To compile a C3 plugin
// yourself, follow the Plugin Dev Guide: plugins/PLUGIN DEV GUIDE README.md
//
// ============================================================
// What it does
// ============================================================
//
//   /gdpr <uid>           dump the live data held on an online player (mod)
//   /gdpr forget <ipid>   record an erasure request AND delete that IPID's lines
//                         from the chat logs (mod)
//
// ============================================================
// Scope & honesty (important)
// ============================================================
//
// A single plugin can only reach what the API exposes plus files it knows the
// format of. So:
//   * /gdpr <uid> reports the live session data: UID, IPID, IP, HDID, character,
//     showname, OOC name, area — i.e. "what we can see about you right now".
//   * /gdpr forget removes that IPID's lines from the `chat_logger` plugin's log
//     files (the main on-disk store of player text) and appends the IPID to
//     config/gdpr_forget.txt as an auditable record of the request.
//
// It does NOT reach the core ban list, other plugins' private files, or anything
// it doesn't know the format of. Treat it as a strong first step, not a complete
// cross-server wipe — finish the job by hand for any other store you keep, and
// tell your players what you retain.
//
// ============================================================
// Why this is an OPTIONAL plugin — and zero passive cost
// ============================================================
//
// Only operators with retention/erasure obligations need it, and the log-scrub
// touches files, so it's opt-in and mod-gated. It registers one command and **no
// packet hooks** — it does nothing until a moderator runs it.

module gdpr;

import std::io;

// ============================================================
// Whisker plugin interface (standalone) — FULL v7 struct (uses client_get_hdid).
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
    GetPluginCountFn         get_plugin_count;
    GetPluginNameFn          get_plugin_name;
    GetPluginVersionFn       get_plugin_version;
    RegisterOutboundFilterFn register_outbound_filter;
    ClientGetHdidFn          client_get_hdid;
    AreaSetHpFn              area_set_hp;
}

// ============================================================
// C interop — file I/O + directory scan (libc + Win32 / POSIX, like plugin.c3).
// ============================================================

extern fn void* fopen_c(ZString path, ZString mode) @cname("fopen");
extern fn char* fgets_c(char* buf, CInt size, void* stream) @cname("fgets");
extern fn CInt  fclose_c(void* stream) @cname("fclose");
extern fn CInt  fputs_c(ZString s, void* stream) @cname("fputs");
extern fn CInt  remove_c(ZString path) @cname("remove");
extern fn CInt  rename_c(ZString old, ZString neww) @cname("rename");

const int MAX_PATH_LEN = 260;
struct Win32FileTime { uint low; uint high; }
struct Win32FindDataA {
    uint               attributes;
    Win32FileTime      creation_time;
    Win32FileTime      last_access_time;
    Win32FileTime      last_write_time;
    uint               file_size_high;
    uint               file_size_low;
    uint               reserved0;
    uint               reserved1;
    char[MAX_PATH_LEN] file_name;
    char[14]           alternate_name;
}
extern fn void* find_first_file_a(char* pattern, Win32FindDataA* data) @cname("FindFirstFileA") @if(env::WIN32);
extern fn int   find_next_file_a(void* handle, Win32FindDataA* data) @cname("FindNextFileA") @if(env::WIN32);
extern fn int   find_close(void* handle) @cname("FindClose") @if(env::WIN32);

extern fn void* popen_c(char* cmd, char* mode) @cname("popen") @if(!env::WIN32);
extern fn int   pclose_c(void* stream) @cname("pclose") @if(!env::WIN32);

const String PLUGIN_NAME = "GDPR";
const ulong  PERM_BAN    = 4;

PluginAPI* api;
char[128] cfg_log_dir;   // chat_logger's directory (default "logs")

// ============================================================
// Helpers
// ============================================================

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
fn String cstr(char* buf) {
    int len = 0;
    while (buf[len] != 0) len++;
    if (len == 0) return "";
    return (String)buf[0..len - 1];
}
fn void copy_str(String src, char* dst, usz max) {
    usz i = 0;
    while (i < src.len && i < max) { dst[i] = src[i]; i++; }
    dst[i] = 0;
}
fn bool contains(String s, String sub) {
    if (sub.len == 0) return false;
    if (s.len < sub.len) return false;
    for (usz i = 0; i + sub.len <= s.len; i++) {
        bool ok = true;
        for (usz j = 0; j < sub.len; j++) { if (s[i + j] != sub[j]) { ok = false; break; } }
        if (ok) return true;
    }
    return false;
}

// ============================================================
// /gdpr <uid> — live data report
// ============================================================

fn void line(void* c, String label, String value) {
    char[400] m; usz n = 0;
    n = put_str(m[..], n, "  ");
    n = put_str(m[..], n, label);
    n = put_str(m[..], n, ": ");
    n = put_str(m[..], n, value.len > 0 ? value : "(none)");
    api.client_send_msg(c, (String)m[0..n - 1]);
}

fn void report_user(void* c, int uid) {
    void* t = api.find_client(uid);
    if (t == null) { api.client_send_msg(c, "No player online with that UID. (This reports LIVE session data only.)"); return; }
    char[80] h; usz hn = 0;
    hn = put_str(h[..], hn, "— Data held on UID ");
    hn = put_int(h[..], hn, uid);
    hn = put_str(h[..], hn, " —");
    api.client_send_msg(c, (String)h[0..hn - 1]);

    line(c, "IPID", api.client_get_ipid(t));
    line(c, "IP", api.client_get_ip(t));
    line(c, "HDID", api.client_get_hdid(t));
    line(c, "Character", api.client_get_char_name(t));
    line(c, "Showname", api.client_get_showname(t));
    line(c, "OOC name", api.client_get_ooc_name(t));
    line(c, "Area", api.area_get_name(api.client_get_area(t)));
    api.client_send_msg(c, "(Persistent stores — chat logs, bans — aren't shown here; use /gdpr forget <ipid> for logs.)");
}

// ============================================================
// /gdpr forget <ipid> — record + scrub the chat logs
// ============================================================

fn void record_request(String ipid) {
    void* f = fopen_c("config/gdpr_forget.txt", "a");
    if (f == null) f = fopen_c("../config/gdpr_forget.txt", "a");
    if (f == null) return;
    char[120] b; usz n = 0;
    n = put_str(b[..], n, ipid);
    n = put_str(b[..], n, "\n");
    b[n] = 0;
    fputs_c((ZString)&b[0], f);
    fclose_c(f);
}

// Remove every line containing `needle` from one log file. Returns lines removed.
fn long redact_file(char* path, String needle) {
    void* in = fopen_c((ZString)path, "r");
    if (in == null) return 0;

    char[600] tmp; int pl = 0;
    while (path[pl] != 0 && pl < 580) { tmp[pl] = path[pl]; pl++; }
    usz tn = (usz)pl;
    tn = put_str(tmp[..], tn, ".tmp");
    tmp[tn] = 0;

    void* out = fopen_c((ZString)&tmp[0], "w");
    if (out == null) { fclose_c(in); return 0; }

    long removed = 0;
    char[1024] ln;
    while (fgets_c(&ln[0], 1024, in) != null) {
        if (contains(cstr(&ln[0]), needle)) { removed++; continue; }
        fputs_c((ZString)&ln[0], out);
    }
    fclose_c(in);
    fclose_c(out);

    if (removed > 0) {
        remove_c((ZString)path);
        rename_c((ZString)&tmp[0], (ZString)path);
    } else {
        remove_c((ZString)&tmp[0]);
    }
    return removed;
}

// Scan the log directory for *.log and redact each. Returns total lines removed.
fn long redact_logs(String needle) {
    String dir = cstr(&cfg_log_dir[0]);
    if (dir.len == 0) dir = "logs";
    long total = 0;

    $if env::WIN32:
        char[512] pattern; usz pn = 0;
        pn = put_str(pattern[..], pn, dir);
        pn = put_str(pattern[..], pn, "\\*.log");
        pattern[pn] = 0;
        Win32FindDataA fd;
        void* h = find_first_file_a(&pattern[0], &fd);
        if ((iptr)h != -1) {
            do {
                char[512] path; usz p = 0;
                p = put_str(path[..], p, dir);
                if (p < 510) { path[p] = '\\'; p++; }
                usz k = 0;
                while (k < MAX_PATH_LEN - 1 && fd.file_name[k] != 0) { if (p < 511) { path[p] = fd.file_name[k]; p++; } k++; }
                path[p] = 0;
                total += redact_file(&path[0], needle);
            } while (find_next_file_a(h, &fd) != 0);
            find_close(h);
        }
    $else
        char[512] cmd; usz cn = 0;
        cn = put_str(cmd[..], cn, "ls -1 \"");
        cn = put_str(cmd[..], cn, dir);
        cn = put_str(cmd[..], cn, "/\"*.log 2>/dev/null");
        cmd[cn] = 0;
        void* pipe = popen_c(&cmd[0], "r".ptr);
        if (pipe != null) {
            char[600] namebuf;
            while (fgets_c(&namebuf[0], 600, pipe) != null) {
                usz len = 0;
                while (len < 599 && namebuf[len] != 0 && namebuf[len] != '\n' && namebuf[len] != '\r') len++;
                if (len < 4) continue;
                namebuf[len] = 0;
                total += redact_file(&namebuf[0], needle);
            }
            pclose_c(pipe);
        }
    $endif

    return total;
}

fn void do_forget(void* c, String ipid) {
    if (ipid.len == 0 || ipid.len > 79) { api.client_send_msg(c, "Usage: /gdpr forget <ipid>"); return; }
    record_request(ipid);

    // Needle that chat_logger writes: "ipid=<ipid>".
    char[96] nbuf; usz nn = 0;
    nn = put_str(nbuf[..], nn, "ipid=");
    nn = put_str(nbuf[..], nn, ipid);
    String needle = (String)nbuf[0..nn - 1];

    long removed = redact_logs(needle);

    char[160] m; usz mn = 0;
    mn = put_str(m[..], mn, "Erasure recorded. Removed ");
    mn = put_int(m[..], mn, (int)removed);
    mn = put_str(m[..], mn, " chat-log line(s) for that IPID. (Other stores need manual handling.)");
    api.client_send_msg(c, (String)m[0..mn - 1]);
}

// ============================================================
// Command dispatch
// ============================================================

fn void cmd_gdpr(void* c, String args) {
    String[3] argv;
    int n = api.args_split(args, &argv[0], 3);
    if (n < 1) { api.client_send_msg(c, "Usage: /gdpr <uid>   |   /gdpr forget <ipid>"); return; }

    char[16] lc; int lcn = api.to_lower(argv[0], &lc[0], 16);
    String sub = lcn > 0 ? (String)lc[0..lcn - 1] : "";

    if (sub == "forget") {
        if (n < 2) { api.client_send_msg(c, "Usage: /gdpr forget <ipid>"); return; }
        do_forget(c, argv[1]);
        return;
    }

    int uid = argv[0].to_int() ?? -1;
    if (uid < 0) { api.client_send_msg(c, "Usage: /gdpr <uid>   |   /gdpr forget <ipid>"); return; }
    report_user(c, uid);
}

// ============================================================
// Config — read chat_logger's [chat_logger] directory so we scrub the right place
// ============================================================

fn void read_config() {
    copy_str("logs", &cfg_log_dir[0], 127);
    void* f = fopen_c("config/config.toml", "r");
    if (f == null) f = fopen_c("../config/config.toml", "r");
    if (f == null) return;
    char[512] line2;
    bool in_section = false;
    while (fgets_c(&line2[0], 512, f) != null) {
        String raw = cstr(&line2[0]).trim();
        if (raw.len == 0 || raw[0] == '#') continue;
        if (raw[0] == '[') { in_section = (raw == "[chat_logger]" || raw == "[gdpr]"); continue; }
        if (!in_section) continue;
        usz eq = 0; bool has_eq = false;
        for (usz i = 0; i < raw.len; i++) { if (raw[i] == '=') { eq = i; has_eq = true; break; } }
        if (!has_eq) continue;
        String key = raw[0..eq - 1].trim();
        String val = raw[eq + 1..].trim();
        usz cut = val.len;
        for (usz i = 0; i < val.len; i++) { if (val[i] == '#') { cut = i; break; } }
        val = (cut == 0) ? "" : val[0..cut - 1];
        val = val.trim();
        if (val.len >= 2 && val[0] == '"' && val[val.len - 1] == '"') val = val[1..val.len - 2];
        if ((key == "directory" || key == "log_dir") && val.len > 0) copy_str(val, &cfg_log_dir[0], 127);
    }
    fclose_c(f);
}

// ============================================================
// Plugin interface (exported)
// ============================================================

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return {
        .name        = "GDPR",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Dump or erase a player's stored data: /gdpr. Optional. Needs the v7 API.",
    };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    read_config();
    api.register_command("gdpr", &cmd_gdpr, PERM_BAN, "Dump (/gdpr <uid>) or erase (/gdpr forget <ipid>) player data", PLUGIN_NAME);
    io::printfn("[gdpr] Loaded. /gdpr ready (log dir: %s).", cstr(&cfg_log_dir[0]));
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    io::printn("[gdpr] Unloaded.");
}
