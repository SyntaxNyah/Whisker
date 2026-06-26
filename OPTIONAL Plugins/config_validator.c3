// Whisker Optional Plugin — Config Validator [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Sanity-checks your server config at startup and warns about common mistakes —
// a missing characters.txt, a port out of range, WSS turned on without a cert,
// and so on — so a typo surfaces as a clear console warning instead of a confusing
// runtime failure. Drop the compiled .dll / .so into plugins/ and restart.
// Optional.
//
// This source file is provided as a learning exercise. To compile a C3 plugin
// yourself, follow the Plugin Dev Guide: plugins/PLUGIN DEV GUIDE README.md
//
// ============================================================
// What it checks
// ============================================================
//
//   * config.toml is present and has a [server] section + a valid port (1-65535)
//   * characters.txt, music.txt, areas.toml, roles.toml exist (and the first two
//     are non-empty)
//   * if WebSocket is enabled, ws_port is valid
//   * if WSS is enabled, wss_port is valid AND tls_cert_path / tls_key_path are set
//     and point at files that exist
//   * max_players, if present, is a positive number
//
// It only WARNS — it never changes anything or stops the server. Re-run any time
// with /configcheck (mod).
//
// ============================================================
// Why this is an OPTIONAL plugin — and zero passive cost
// ============================================================
//
// The checks are heuristic and a bit opinionated, and a seasoned operator doesn't
// need them — so it's opt-in. It does all its work once at load (and again only
// when a mod types /configcheck); it registers **no packet hooks**, so it has no
// effect on the running server at all.

module config_validator;

import std::io;

// ============================================================
// Whisker plugin interface (standalone) — v4 prefix.
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
}

extern fn void* fopen_c(ZString path, ZString mode) @cname("fopen");
extern fn char* fgets_c(char* buf, CInt size, void* stream) @cname("fgets");
extern fn CInt  fclose_c(void* stream) @cname("fclose");

const String PLUGIN_NAME = "Config Validator";
const ulong  PERM_BAN    = 4;

PluginAPI* api;

// Captured config values.
bool   has_server;
int    cfg_port;
bool   cfg_enable_ws;
int    cfg_ws_port;
bool   cfg_enable_wss;
int    cfg_wss_port;
int    cfg_max_players;
char[256] cfg_tls_cert; int tls_cert_len;
char[256] cfg_tls_key;  int tls_key_len;

int warn_count;

// ============================================================
// Helpers
// ============================================================

fn usz put_str(char[] buf, usz n, String s) {
    foreach (char ch : s) { if (n >= buf.len) break; buf[n] = ch; n++; }
    return n;
}
fn String cstr(char* buf) {
    int len = 0;
    while (buf[len] != 0) len++;
    if (len == 0) return "";
    return (String)buf[0..len - 1];
}
fn bool is_true(String s) { return s == "true" || s == "1" || s == "yes" || s == "on"; }
fn int parse_int(String s) {
    int v = 0; bool have = false;
    foreach (char ch : s) { if (ch >= '0' && ch <= '9') { v = v * 10 + (int)(ch - '0'); have = true; } }
    return have ? v : -1;
}
fn void copy_str(String src, char* dst, int max, int* outlen) {
    int n = (int)src.len; if (n > max) n = max;
    for (int i = 0; i < n; i++) dst[i] = src[i];
    *outlen = n;
}

// "config" if config/config.toml is readable, else "../config".
fn String cfg_dir() {
    void* f = fopen_c("config/config.toml", "r");
    if (f != null) { fclose_c(f); return "config"; }
    return "../config";
}

fn void* open_read(String dir, String name) {
    char[256] p; usz n = 0;
    n = put_str(p[..], n, dir);
    n = put_str(p[..], n, "/");
    n = put_str(p[..], n, name);
    p[n] = 0;
    return fopen_c((ZString)&p[0], "r");
}

fn bool exists_in(String dir, String name) {
    void* f = open_read(dir, name);
    if (f == null) return false;
    fclose_c(f);
    return true;
}

// Non-empty = has at least one non-blank, non-comment line.
fn bool nonempty_in(String dir, String name) {
    void* f = open_read(dir, name);
    if (f == null) return false;
    char[512] line; bool have = false;
    while (fgets_c(&line[0], 512, f) != null) {
        String s = cstr(&line[0]).trim();
        if (s.len > 0 && s[0] != '#') { have = true; break; }
    }
    fclose_c(f);
    return have;
}

// ============================================================
// Read the values we care about out of config.toml.
// ============================================================

fn void read_values(String dir) {
    has_server = false; cfg_port = -1; cfg_enable_ws = false; cfg_ws_port = -1;
    cfg_enable_wss = false; cfg_wss_port = -1; cfg_max_players = -1;
    tls_cert_len = 0; tls_key_len = 0;

    void* f = open_read(dir, "config.toml");
    if (f == null) return;
    char[512] line;
    while (fgets_c(&line[0], 512, f) != null) {
        String raw = cstr(&line[0]).trim();
        if (raw.len == 0 || raw[0] == '#') continue;
        if (raw == "[server]") { has_server = true; continue; }
        if (raw[0] == '[') continue;
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

        if (key == "port")              { cfg_port = parse_int(val); }
        else if (key == "enable_ws")    { cfg_enable_ws = is_true(val); }
        else if (key == "ws_port")      { cfg_ws_port = parse_int(val); }
        else if (key == "enable_wss")   { cfg_enable_wss = is_true(val); }
        else if (key == "wss_port")     { cfg_wss_port = parse_int(val); }
        else if (key == "max_players")  { cfg_max_players = parse_int(val); }
        else if (key == "tls_cert_path") { copy_str(val, &cfg_tls_cert[0], 255, &tls_cert_len); }
        else if (key == "tls_key_path")  { copy_str(val, &cfg_tls_key[0], 255, &tls_key_len); }
    }
    fclose_c(f);
}

// ============================================================
// Reporting — to the console at load, or to a mod on /configcheck.
// ============================================================

fn void report(void* c, bool to_client, String msg) {
    warn_count++;
    if (to_client) { api.client_send_msg(c, msg); }
    else { io::printfn("[config_validator] WARN: %s", msg); }
}

fn bool file_path_ok(char* buf, int len) {
    if (len <= 0) return false;
    void* f = fopen_c((ZString)buf, "r");
    if (f == null) return false;
    fclose_c(f);
    return true;
}

fn void run_checks(void* c, bool to_client) {
    warn_count = 0;
    String dir = cfg_dir();
    read_values(dir);

    if (!exists_in(dir, "config.toml")) { report(c, to_client, "config.toml is missing."); return; }
    if (!has_server) report(c, to_client, "config.toml has no [server] section.");
    if (cfg_port < 1 || cfg_port > 65535) report(c, to_client, "[server] port is missing or out of range (1-65535).");

    if (!exists_in(dir, "characters.txt")) { report(c, to_client, "characters.txt is missing."); }
    else if (!nonempty_in(dir, "characters.txt")) { report(c, to_client, "characters.txt is empty — players will have no characters."); }
    if (!exists_in(dir, "music.txt")) { report(c, to_client, "music.txt is missing."); }
    else if (!nonempty_in(dir, "music.txt")) { report(c, to_client, "music.txt is empty — no music will be available."); }
    if (!exists_in(dir, "areas.toml")) { report(c, to_client, "areas.toml is missing."); }
    if (!exists_in(dir, "roles.toml")) { report(c, to_client, "roles.toml is missing — moderator roles may not load."); }

    if (cfg_enable_ws && (cfg_ws_port < 1 || cfg_ws_port > 65535)) {
        report(c, to_client, "enable_ws is true but ws_port is missing or out of range.");
    }
    if (cfg_enable_wss) {
        if (cfg_wss_port < 1 || cfg_wss_port > 65535) { report(c, to_client, "enable_wss is true but wss_port is missing or out of range."); }
        if (tls_cert_len <= 0) { report(c, to_client, "enable_wss is true but tls_cert_path is not set."); }
        else if (!file_path_ok(&cfg_tls_cert[0], tls_cert_len)) { report(c, to_client, "tls_cert_path is set but the certificate file can't be opened."); }
        if (tls_key_len <= 0) { report(c, to_client, "enable_wss is true but tls_key_path is not set."); }
        else if (!file_path_ok(&cfg_tls_key[0], tls_key_len)) { report(c, to_client, "tls_key_path is set but the key file can't be opened."); }
    }

    if (cfg_max_players == 0) report(c, to_client, "max_players is 0 — nobody will be able to join.");

    if (warn_count == 0) {
        if (to_client) { api.client_send_msg(c, "Config check: no problems found. ✓"); }
        else { io::printn("[config_validator] Config check passed — no problems found."); }
    } else if (to_client) {
        char[80] m; usz n = 0;
        n = put_str(m[..], n, "Config check finished — see the warnings above.");
        api.client_send_msg(c, (String)m[0..n - 1]);
    }
}

fn void cmd_configcheck(void* c, String args) {
    run_checks(c, true);
}

// ============================================================
// Plugin interface (exported)
// ============================================================

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return {
        .name        = "Config Validator",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Warns about common config mistakes at startup. Optional.",
    };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    io::printn("[config_validator] Checking config...");
    run_checks(null, false);
    api.register_command("configcheck", &cmd_configcheck, PERM_BAN, "Re-run the config sanity check (mod)", PLUGIN_NAME);
    io::printn("[config_validator] Loaded. /configcheck ready.");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    io::printn("[config_validator] Unloaded.");
}
