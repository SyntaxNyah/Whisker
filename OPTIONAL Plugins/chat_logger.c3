// Whisker Optional Plugin — Chat Logger [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Appends every IC (in-character) and OOC message to per-area log files on disk
// for moderation / audit. Drop the compiled .dll (Windows) / .so (Linux) into
// your server's plugins/ folder and restart. Optional — your server runs fine
// without it.
//
// This source file is provided as a learning exercise. To compile a C3 plugin
// yourself, follow the Plugin Dev Guide: plugins/PLUGIN DEV GUIDE README.md
//
// ============================================================
// What it does
// ============================================================
//
// Hooks the MS (IC) and CT (OOC) packets and writes a one-line record per
// message into logs/area<idx>_<name>.log, e.g.
//
//   [2026-06-23 14:05:01 UTC] [Courtroom 1] IC uid=5 ipid=ab12cd34 char=Phoenix show=Nick: Objection!
//   [2026-06-23 14:05:10 UTC] [Courtroom 1] OOC uid=5 ipid=ab12cd34 name=PhoenixFan: brb one sec
//
// Each area gets its own file so a moderator can read one room's history without
// wading through the whole server. Files are append-only and flushed per line,
// so a crash never loses what was already written.
//
//   * OOC lines that start with "/" (commands) are NEVER logged — this is
//     deliberate, so a mistyped "/login <password>" can't leak into the logs.
//   * The IPID (not the raw IP) is recorded, matching the core ban system; you
//     can turn it off with include_ipid = false for stricter privacy.
//
// ============================================================
// Why this is a PLUGIN, not core
// ============================================================
//
// Persistent chat logging is a policy choice, not a default. Many AO / RP
// communities consider logging every line (and tying it to an IPID) invasive,
// and some have privacy obligations that make silent logging a problem; others
// simply don't want the disk usage. Whoever runs the server should choose it
// consciously, so it ships as an opt-in plugin rather than always-on core
// behaviour. Tell your players if you enable it.

module chat_logger;

import std::io;

// ============================================================
// Whisker plugin interface (standalone definitions)
// Must match src/plugin.c3 PluginAPI exactly, field-for-field, in order.
// (v4 prefix, copied verbatim from ip_guard.c3.)
// ============================================================

struct PluginInfo {
    String name;
    String version;
    String author;
    String description;
}

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

// Extended API (v2)
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

// Lifecycle hooks (v3)
alias LifecycleHook           = fn void(void*, int);
alias RegisterLifecycleHookFn = fn void(LifecycleHook, String);
alias ClientGetOocNameFn      = fn String(void*);
alias ClientIsHiddenFn        = fn bool(void*);

// Connection filtering + raw IP + role-gated broadcast (v4)
alias ClientGetIpFn         = fn String(void*);
alias ConnectionFilter      = fn bool(String);
alias RegisterConnFilterFn  = fn void(ConnectionFilter, String);
alias BroadcastPermRawFn    = fn void(String, ulong);

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

    // Extended API (v2)
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

    // Lifecycle hooks + supporting getters (v3)
    RegisterLifecycleHookFn register_lifecycle_hook;
    ClientGetOocNameFn      client_get_ooc_name;
    ClientIsHiddenFn        client_is_hidden;

    // Connection filtering + raw IP + role-gated broadcast (v4)
    ClientGetIpFn         client_get_ip;
    RegisterConnFilterFn  register_conn_filter;
    BroadcastPermRawFn    broadcast_perm_raw;
}

// ============================================================
// C interop (file I/O, time, mkdir) — safe on any thread, no C3 runtime needed
// ============================================================

extern fn void* fopen_c(ZString path, ZString mode) @cname("fopen");
extern fn char* fgets_c(char* buf, CInt size, void* stream) @cname("fgets");
extern fn CInt  fputs_c(ZString s, void* stream) @cname("fputs");
extern fn CInt  fclose_c(void* stream) @cname("fclose");
extern fn long  time_c(void* t) @cname("time");

extern fn CInt mkdir_win(ZString path) @cname("_mkdir") @if(env::WIN32);
extern fn CInt mkdir_posix(ZString path, uint mode) @cname("mkdir") @if(!env::WIN32);

fn void make_dir(ZString path) {
    $if env::WIN32:
        (void)mkdir_win(path);
    $else
        (void)mkdir_posix(path, 0o755);
    $endif
}

// ============================================================
// Constants / options
// ============================================================

const String PLUGIN_NAME = "Chat Logger";

PluginAPI* api;

bool      opt_enabled      = true;
bool      opt_log_ic       = true;
bool      opt_log_ooc      = true;
bool      opt_include_ipid = true;
char[256] logdir;          // resolved log directory (null-terminated)

// MS field index of the message text; CT field indices of name + message.
// (See the AO2 protocol reference — fields are returned already decoded.)
const int MS_MESSAGE   = 4;
const int CT_OOC_NAME  = 0;
const int CT_MESSAGE   = 1;

// ============================================================
// Small string helpers (allocation-free, any thread)
// ============================================================

fn usz put_str(char[] buf, usz n, String s) {
    foreach (char ch : s) { if (n >= buf.len) break; buf[n] = ch; n++; }
    return n;
}

fn usz put_uint(char[] buf, usz n, ulong v) {
    if (v == 0) return put_str(buf, n, "0");
    char[20] tmp; int t = 0;
    while (v > 0) { tmp[t] = (char)('0' + (int)(v % 10)); t++; v /= 10; }
    while (t > 0) { t--; if (n >= buf.len) break; buf[n] = tmp[t]; n++; }
    return n;
}

// Zero-padded fixed-width unsigned (for the timestamp).
fn usz put_pad(char[] buf, usz n, long v, int width) {
    char[20] tmp; int t = 0;
    long x = v < 0 ? 0 : v;
    if (x == 0) { tmp[0] = '0'; t = 1; }
    else { while (x > 0) { tmp[t] = (char)('0' + (int)(x % 10)); t++; x /= 10; } }
    for (int p = t; p < width; p++) { if (n < buf.len) { buf[n] = '0'; n++; } }
    while (t > 0) { t--; if (n < buf.len) { buf[n] = tmp[t]; n++; } }
    return n;
}

// Copy text but flatten newlines/tabs to spaces, so one message is always one
// log line (AO2 messages shouldn't contain these, but be defensive).
fn usz put_clean(char[] buf, usz n, String s) {
    foreach (char ch : s) {
        if (n >= buf.len) break;
        buf[n] = (ch == '\n' || ch == '\r' || ch == '\t') ? ' ' : ch;
        n++;
    }
    return n;
}

// Copy text keeping only filename-safe bytes (everything else → '_'), capped.
fn usz put_sanitized(char[] buf, usz n, String s, int maxchars) {
    int written = 0;
    foreach (char ch : s) {
        if (written >= maxchars) break;
        if (n >= buf.len) break;
        bool ok = (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z')
               || (ch >= '0' && ch <= '9') || ch == '-' || ch == '_';
        buf[n] = ok ? ch : '_';
        n++; written++;
    }
    return n;
}

fn String cstr(char* buf) {
    int len = 0;
    while (buf[len] != 0) len++;
    if (len == 0) return "";
    return (String)buf[0..len - 1];
}

fn void copy_cstr(String src, char* dst, usz max) {
    usz i = 0;
    while (i < src.len && i < max) { dst[i] = src[i]; i++; }
    dst[i] = 0;
}

// "[YYYY-MM-DD HH:MM:SS UTC]" computed from the epoch with pure arithmetic
// (civil-from-days). No libc localtime/strftime, so there is no shared static
// struct to race between client threads.
fn usz put_timestamp(char[] buf, usz n) {
    long epoch = time_c(null);
    long days = epoch / 86400;
    long secs = epoch % 86400;
    if (secs < 0) { secs += 86400; days -= 1; }

    long z   = days + 719468;
    long era = (z >= 0 ? z : z - 146096) / 146097;
    long doe = z - era * 146097;
    long yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    long y   = yoe + era * 400;
    long doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    long mp  = (5 * doy + 2) / 153;
    long d   = doy - (153 * mp + 2) / 5 + 1;
    long m   = mp < 10 ? mp + 3 : mp - 9;
    if (m <= 2) y += 1;

    long hh = secs / 3600;
    long mm = (secs % 3600) / 60;
    long ss = secs % 60;

    n = put_str(buf, n, "[");
    n = put_pad(buf, n, y, 4);  n = put_str(buf, n, "-");
    n = put_pad(buf, n, m, 2);  n = put_str(buf, n, "-");
    n = put_pad(buf, n, d, 2);  n = put_str(buf, n, " ");
    n = put_pad(buf, n, hh, 2); n = put_str(buf, n, ":");
    n = put_pad(buf, n, mm, 2); n = put_str(buf, n, ":");
    n = put_pad(buf, n, ss, 2);
    n = put_str(buf, n, " UTC]");
    return n;
}

// ============================================================
// Writing
// ============================================================

// One fopen("a")/fputs/fclose per line: simple, and flushed immediately so a
// crash never loses prior lines. Concurrent appends to the SAME area file come
// from independent handles across client threads — atomic under POSIX O_APPEND,
// best-effort on Windows, so under very heavy same-area traffic an occasional
// interleaved line is possible. That matches the codebase's lockless tradeoffs;
// we accept it rather than add a lock on the message path.
fn void write_line(int area_idx, String area_name, char* zline) {
    char[320] path; usz pn = 0;
    pn = put_str(path[..], pn, cstr(&logdir[0]));
    pn = put_str(path[..], pn, "/area");
    pn = put_uint(path[..], pn, (ulong)area_idx);
    pn = put_str(path[..], pn, "_");
    pn = put_sanitized(path[..], pn, area_name, 40);
    pn = put_str(path[..], pn, ".log");
    path[pn] = 0;

    void* f = fopen_c((ZString)&path[0], "a");
    if (f == null) return;
    fputs_c((ZString)zline, f);
    fclose_c(f);
}

// Null-terminate a freshly built line buffer (appending '\n' if room).
fn void finish_line(char[] buf, usz n) {
    if (n < buf.len) { buf[n] = '\n'; n++; }
    if (n < buf.len) { buf[n] = 0; } else { buf[buf.len - 1] = 0; }
}

// ============================================================
// Packet hooks (never consume — always return false)
// ============================================================

fn bool on_ic(void* c, void* pkt) {
    if (!opt_enabled || !opt_log_ic) return false;

    String msg = api.packet_get_field(pkt, MS_MESSAGE);
    if (msg.len == 0) return false; // sprite-only / blank line — nothing to log

    int    area      = api.client_get_area(c);
    String area_name = api.area_get_name(area);

    char[768] line; usz n = 0;
    n = put_timestamp(line[..], n);
    n = put_str(line[..], n, " [");
    n = put_clean(line[..], n, area_name);
    n = put_str(line[..], n, "] IC uid=");
    n = put_uint(line[..], n, (ulong)api.client_get_uid(c));
    if (opt_include_ipid) {
        n = put_str(line[..], n, " ipid=");
        n = put_str(line[..], n, api.client_get_ipid(c));
    }
    n = put_str(line[..], n, " char=");
    n = put_clean(line[..], n, api.client_get_char_name(c));
    n = put_str(line[..], n, " show=");
    n = put_clean(line[..], n, api.client_get_showname(c));
    n = put_str(line[..], n, ": ");
    n = put_clean(line[..], n, msg);
    finish_line(line[..], n);
    write_line(area, area_name, &line[0]);
    return false;
}

fn bool on_ooc(void* c, void* pkt) {
    if (!opt_enabled || !opt_log_ooc) return false;

    String msg = api.packet_get_field(pkt, CT_MESSAGE);
    if (msg.len == 0) return false;
    if (msg[0] == '/') return false; // command — never logged (may carry secrets)

    String name      = api.packet_get_field(pkt, CT_OOC_NAME);
    int    area      = api.client_get_area(c);
    String area_name = api.area_get_name(area);

    char[768] line; usz n = 0;
    n = put_timestamp(line[..], n);
    n = put_str(line[..], n, " [");
    n = put_clean(line[..], n, area_name);
    n = put_str(line[..], n, "] OOC uid=");
    n = put_uint(line[..], n, (ulong)api.client_get_uid(c));
    if (opt_include_ipid) {
        n = put_str(line[..], n, " ipid=");
        n = put_str(line[..], n, api.client_get_ipid(c));
    }
    n = put_str(line[..], n, " name=");
    n = put_clean(line[..], n, name);
    n = put_str(line[..], n, ": ");
    n = put_clean(line[..], n, msg);
    finish_line(line[..], n);
    write_line(area, area_name, &line[0]);
    return false;
}

// ============================================================
// Config (config/config.toml, [chat_logger] section)
// ============================================================

fn bool is_true(String s) { return s == "true" || s == "1" || s == "yes" || s == "on"; }

fn void load_config(String cfg_path) {
    void* f = fopen_c((ZString)cfg_path.ptr, "r");
    if (f == null) return; // keep defaults

    char[512] line;
    int section = 0; // 0 = other, 1 = [chat_logger]
    while (fgets_c(&line[0], 512, f) != null) {
        String raw = cstr(&line[0]).trim();
        if (raw.len == 0 || raw[0] == '#') continue;

        if (raw[0] == '[') {
            section = (raw == "[chat_logger]") ? 1 : 0;
            continue;
        }
        if (section != 1) continue;

        usz eq = 0;
        while (eq < raw.len && raw[eq] != '=') eq++;
        if (eq >= raw.len) continue;
        String key = raw[0..eq - 1].trim();
        String val = raw[eq + 1..].trim();
        // Strip surrounding quotes from a string value.
        if (val.len >= 2 && val[0] == '"' && val[val.len - 1] == '"') val = val[1..val.len - 2];

        if (key == "enabled")      { opt_enabled = is_true(val); }
        else if (key == "log_ic")  { opt_log_ic = is_true(val); }
        else if (key == "log_ooc") { opt_log_ooc = is_true(val); }
        else if (key == "include_ipid") { opt_include_ipid = is_true(val); }
        else if (key == "directory" && val.len > 0) { copy_cstr(val, &logdir[0], 200); }
    }
    fclose_c(f);
}

// ============================================================
// Plugin interface (exported)
// ============================================================

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return {
        .name        = "Chat Logger",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Logs IC/OOC chat to per-area files. Optional — see header.",
    };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;

    // Default log directory.
    copy_cstr("logs", &logdir[0], 200);

    // Resolve config.toml the way server_advertiser / ip_guard do: prefer
    // ./config, fall back to ../config (when the server runs from out/). The log
    // directory is taken relative to the same base so logs land beside config.
    String base = "";
    void* probe = fopen_c("config/config.toml", "r");
    if (probe != null) { fclose_c(probe); base = ""; load_config("config/config.toml"); }
    else {
        probe = fopen_c("../config/config.toml", "r");
        if (probe != null) { fclose_c(probe); base = "../"; load_config("../config/config.toml"); }
    }

    // Re-root the (possibly default/relative) directory under the base, then
    // make sure it exists.
    if (base.len > 0) {
        char[256] rooted; usz rn = 0;
        rn = put_str(rooted[..], rn, base);
        rn = put_str(rooted[..], rn, cstr(&logdir[0]));
        rooted[rn] = 0;
        copy_cstr(cstr(&rooted[0]), &logdir[0], 200);
    }
    make_dir((ZString)&logdir[0]);

    if (opt_enabled) {
        if (opt_log_ic)  api.register_hook("MS", &on_ic,  PLUGIN_NAME);
        if (opt_log_ooc) api.register_hook("CT", &on_ooc, PLUGIN_NAME);
        io::printfn("[chat_logger] Loaded. Logging to '%s/' (ic=%s ooc=%s ipid=%s).",
            (ZString)&logdir[0],
            opt_log_ic ? "on" : "off", opt_log_ooc ? "on" : "off",
            opt_include_ipid ? "on" : "off");
    } else {
        io::printn("[chat_logger] Loaded but disabled (enabled=false in [chat_logger]). No logging.");
    }
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    io::printn("[chat_logger] Shutting down.");
}
