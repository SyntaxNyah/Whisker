// Whisker Optional Plugin — Status Feed [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Periodically writes a status.json (player count, per-area players/status/CMs)
// for a website to read, and can optionally POST it to a webhook — as a short
// Discord message if the URL is a Discord webhook, or as the raw JSON to any
// other endpoint. Optional — drop the .dll/.so into plugins/ and restart.
//
// Standalone plugin: see the Plugin Dev Guide (plugins/PLUGIN DEV GUIDE README.md).

module status_feed;

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

const String PLUGIN_NAME = "Status Feed";

char[256] server_name;
char[512] file_path;       // where status.json is written
char[600] webhook_url;
char[512] discord_path;    // temp file for the discord payload
char[1280] cmd_raw;        // curl POST status.json
char[1280] cmd_discord;    // curl POST discord payload
char[16384] status_buf;
char[4096]  discord_buf;

PluginAPI* api;
bool opt_enabled    = true;
int  opt_interval   = 30;
bool has_webhook    = false;
bool webhook_discord = false;
bool opt_running    = true;

extern fn CInt  system(ZString cmd);
extern fn CInt  fflush(void* stream);
extern fn void* fopen_c(ZString path, ZString mode) @cname("fopen");
extern fn char* fgets_c(char* buf, CInt size, void* stream) @cname("fgets");
extern fn CInt  fclose_c(void* stream) @cname("fclose");
extern fn CInt  fputs_c(ZString s, void* stream) @cname("fputs");
extern fn long  time_c(void* t) @cname("time");
extern fn uint posix_sleep(uint seconds) @cname("sleep") @if(!env::WIN32);
extern fn void win_sleep(uint milliseconds) @cname("Sleep") @if(env::WIN32);
alias RawThreadFn = fn void*(void*);
extern fn CInt   pthread_create(ulong* thread, void* attr, RawThreadFn start, void* arg) @if(!env::WIN32);
extern fn CInt   pthread_detach(ulong thread) @if(!env::WIN32);
extern fn void*  create_thread_win(void* attr, usz stack, RawThreadFn start, void* arg, uint flags, void* id) @cname("CreateThread") @if(env::WIN32);
extern fn CInt   close_handle_win(void* handle) @cname("CloseHandle") @if(env::WIN32);
macro void sleep_sec(uint s) { $if env::WIN32: win_sleep(s * 1000); $else posix_sleep(s); $endif }

fn usz put_str(char[] buf, usz n, String s) { foreach (char ch : s) { if (n >= buf.len) break; buf[n] = ch; n++; } return n; }
fn usz put_uint(char[] buf, usz n, ulong v) {
    if (v == 0) return put_str(buf, n, "0");
    char[20] tmp; int t = 0;
    while (v > 0) { tmp[t] = (char)('0' + (int)(v % 10)); t++; v /= 10; }
    while (t > 0) { t--; if (n >= buf.len) break; buf[n] = tmp[t]; n++; }
    return n;
}
fn usz put_hex2(char[] buf, usz n, int v) {
    String hex = "0123456789abcdef";
    if (n < buf.len) { buf[n] = hex[(v >> 4) & 0xF]; n++; }
    if (n < buf.len) { buf[n] = hex[v & 0xF]; n++; }
    return n;
}
fn usz put_json(char[] buf, usz n, String s) {
    foreach (char ch : s) {
        switch (ch) {
            case '"':  n = put_str(buf, n, "\\\"");
            case '\\': n = put_str(buf, n, "\\\\");
            case '\n': n = put_str(buf, n, "\\n");
            case '\r': n = put_str(buf, n, "\\r");
            case '\t': n = put_str(buf, n, "\\t");
            default:
                if (ch < 0x20) { n = put_str(buf, n, "\\u00"); n = put_hex2(buf, n, (int)ch); }
                else if (n < buf.len) { buf[n] = ch; n++; }
        }
    }
    return n;
}
fn String cstr(char* buf) { int l = 0; while (buf[l] != 0) l++; return l == 0 ? "" : (String)buf[0..l - 1]; }
fn void copy_cstr(String src, char* dst, usz max) { usz i = 0; while (i < src.len && i < max) { dst[i] = src[i]; i++; } dst[i] = 0; }
fn bool is_true(String s) { return s == "true" || s == "1" || s == "yes" || s == "on"; }
fn ulong parse_ulong(String s) { ulong v = 0; foreach (char ch : s) { if (ch >= '0' && ch <= '9') v = v * 10 + (ulong)(ch - '0'); } return v; }
fn bool contains(String s, String sub) {
    if (sub.len == 0 || s.len < sub.len) return false;
    for (usz i = 0; i + sub.len <= s.len; i++) {
        bool ok = true;
        for (usz j = 0; j < sub.len; j++) { if (s[i + j] != sub[j]) { ok = false; break; } }
        if (ok) return true;
    }
    return false;
}
fn bool starts_with(String s, String p) {
    if (s.len < p.len) return false;
    for (usz i = 0; i < p.len; i++) { if (s[i] != p[i]) return false; }
    return true;
}
fn bool safe_url(String u) {
    if (!starts_with(u, "https://")) return false;
    foreach (char ch : u) {
        if (ch <= 0x20) return false;
        switch (ch) { case '"': case '\'': case '`': case '$': case '\\': case '%': return false; default: break; }
    }
    return true;
}

fn usz build_status(char[] buf) {
    usz n = put_str(buf, 0, "{\"name\":\"");
    n = put_json(buf, n, cstr(&server_name[0]));
    n = put_str(buf, n, "\",\"players\":");
    n = put_uint(buf, n, (ulong)api.get_player_count());
    n = put_str(buf, n, ",\"updated\":");
    n = put_uint(buf, n, (ulong)time_c(null));
    n = put_str(buf, n, ",\"areas\":[");
    int ac = api.get_area_count();
    for (int i = 0; i < ac; i++) {
        if (i > 0) n = put_str(buf, n, ",");
        int st = api.area_get_status(i); if (st < 0) st = 0;
        n = put_str(buf, n, "{\"name\":\"");
        n = put_json(buf, n, api.area_get_name(i));
        n = put_str(buf, n, "\",\"players\":");
        n = put_uint(buf, n, (ulong)api.get_area_player_count(i));
        n = put_str(buf, n, ",\"status\":");
        n = put_uint(buf, n, (ulong)st);
        n = put_str(buf, n, ",\"cms\":");
        n = put_uint(buf, n, (ulong)api.area_cm_count(i));
        n = put_str(buf, n, "}");
        if (n > buf.len - 200) break;
    }
    n = put_str(buf, n, "]}");
    return n;
}

fn usz build_discord(char[] buf) {
    usz n = put_str(buf, 0, "{\"content\":\"**");
    n = put_json(buf, n, cstr(&server_name[0]));
    n = put_str(buf, n, "** — ");
    n = put_uint(buf, n, (ulong)api.get_player_count());
    n = put_str(buf, n, " online");
    int ac = api.get_area_count();
    for (int i = 0; i < ac; i++) {
        int pc = api.get_area_player_count(i);
        if (pc <= 0) continue;
        n = put_str(buf, n, "\\n• ");
        n = put_json(buf, n, api.area_get_name(i));
        n = put_str(buf, n, ": ");
        n = put_uint(buf, n, (ulong)pc);
        if (n > 1800) break;
    }
    n = put_str(buf, n, "\"}");
    return n;
}

fn void* feed_loop(void* arg) {
    sleep_sec(3);
    while (opt_running) {
        usz n = build_status(status_buf[..]);
        status_buf[n < (usz)16384 ? n : 16383] = 0;
        void* f = fopen_c((ZString)&file_path[0], "w");
        if (f != null) { fputs_c((ZString)&status_buf[0], f); fclose_c(f); }

        if (has_webhook) {
            if (webhook_discord) {
                usz dn = build_discord(discord_buf[..]);
                discord_buf[dn < (usz)4096 ? dn : 4095] = 0;
                void* df = fopen_c((ZString)&discord_path[0], "w");
                if (df != null) { fputs_c((ZString)&discord_buf[0], df); fclose_c(df); system((ZString)&cmd_discord[0]); }
            } else {
                system((ZString)&cmd_raw[0]);
            }
        }
        fflush(null);
        sleep_sec((uint)opt_interval);
    }
    return null;
}

fn void build_curl(char[1280]* dst, String payload_path) {
    usz n = 0;
    n = put_str((*dst)[..], n, "curl -sf --max-time 15 -H \"Content-Type: application/json\" --data-binary @\"");
    n = put_str((*dst)[..], n, payload_path);
    n = put_str((*dst)[..], n, "\" \"");
    n = put_str((*dst)[..], n, cstr(&webhook_url[0]));
    n = put_str((*dst)[..], n, "\"");
    $if env::WIN32:
        n = put_str((*dst)[..], n, " >nul 2>&1");
    $else
        n = put_str((*dst)[..], n, " >/dev/null 2>&1");
    $endif
    (*dst)[n] = 0;
}

fn void load_config(ZString path) {
    void* f = fopen_c(path, "r");
    if (f == null) return;
    char[512] line; int section = 0;
    while (fgets_c(&line[0], 512, f) != null) {
        String raw = cstr(&line[0]).trim();
        if (raw.len == 0 || raw[0] == '#') continue;
        if (raw[0] == '[') {
            if (raw == "[status_feed]") { section = 1; }
            else if (raw == "[server]") { section = 2; }
            else { section = 0; }
            continue;
        }
        if (section == 0) continue;
        usz eq = 0; while (eq < raw.len && raw[eq] != '=') eq++;
        if (eq >= raw.len) continue;
        String k = raw[0..eq - 1].trim();
        String v = raw[eq + 1..].trim();
        if (v.len >= 2 && v[0] == '"' && v[v.len - 1] == '"') v = v[1..v.len - 2];
        if (section == 2) { if (k == "name") copy_cstr(v, &server_name[0], 255); continue; }
        // [status_feed]
        if (k == "enabled")            { opt_enabled = is_true(v); }
        else if (k == "interval_seconds") { int x = (int)parse_ulong(v); if (x > 0) opt_interval = x; }
        else if (k == "file" && v.len > 0) { copy_cstr(v, &file_path[0], 511); }
        else if (k == "webhook_url" && v.len > 0) { copy_cstr(v, &webhook_url[0], 599); }
    }
    fclose_c(f);
}

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return { "Status Feed", "1.0.0", "Whisker Community", "Write status.json / webhook. Optional." };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    opt_running = true;
    copy_cstr("Whisker Server", &server_name[0], 255);
    copy_cstr("status.json", &file_path[0], 511);
    copy_cstr("status_feed_discord.json", &discord_path[0], 511);

    void* probe = fopen_c("config/config.toml", "r");
    if (probe != null) { fclose_c(probe); load_config("config/config.toml"); }
    else { load_config("../config/config.toml"); }

    String url = cstr(&webhook_url[0]);
    has_webhook = url.len > 0 && safe_url(url);
    webhook_discord = has_webhook && (contains(url, "discord.com/") || contains(url, "discordapp.com/"));
    if (url.len > 0 && !has_webhook) {
        io::printn("[status_feed] webhook_url ignored — must be a plain https URL with no shell-special characters.");
    }
    if (has_webhook) { build_curl(&cmd_raw, cstr(&file_path[0])); build_curl(&cmd_discord, cstr(&discord_path[0])); }

    if (!opt_enabled) { io::printn("[status_feed] Loaded but disabled."); return true; }

    $if env::WIN32:
        void* h = create_thread_win(null, 0, &feed_loop, null, 0, null);
        if (h != null) close_handle_win(h);
    $else
        ulong tid;
        if (pthread_create(&tid, null, &feed_loop, null) == 0) pthread_detach(tid);
    $endif
    io::printfn("[status_feed] Loaded. Writing '%s' every %ds%s.",
        (ZString)&file_path[0], opt_interval, has_webhook ? (webhook_discord ? " (+ Discord webhook)" : " (+ webhook)") : "");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    opt_running = false;
    io::printn("[status_feed] Shutting down.");
}
