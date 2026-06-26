// Whisker Optional Plugin — Discord Join Feed [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Posts a short line to a Discord channel whenever a player connects (and,
// optionally, disconnects) via an incoming webhook — a live "who's coming and
// going" feed for your staff/community channel. Drop the compiled .dll / .so into
// plugins/ and restart. Optional, and inactive until you set a webhook URL.
//
// This source file is provided as a learning exercise. To compile a C3 plugin
// yourself, follow the Plugin Dev Guide: plugins/PLUGIN DEV GUIDE README.md
//
// ============================================================
// Configuration — config/discord_join.txt (auto-created template)
// ============================================================
//
//   webhook_url   https://discord.com/api/webhooks/XXXX/YYYY   # required to activate
//   username      Whisker                                       # name it posts under
//   include_ipid  true                                          # show the caller's IPID
//   relay_leave   false                                         # also post on disconnect
//   mention       <@&ROLEID>                                    # optional role ping
//
// ============================================================
// Why this is a PLUGIN — and the Discord caveats
// ============================================================
//
// A join feed is handy but the wrong default for most servers, and it sends player
// data (IPID, area, player counts, and on leave the character) off your machine to
// Discord under Discord's terms — so it's opt-in, mod-configured, and the webhook
// URL stays server-side. It's a third-party dependency (if Discord is down the feed
// silently stops). On a busy server joins are frequent, so Discord may rate-limit
// the webhook — keep this for small/medium servers or expect dropped posts. See
// `discord_modcall` for the fuller "why you might not want to depend on Discord"
// discussion; this shares its webhook-worker design.
//
// Performance: the JOIN/LEAVE hook builds the post allocation-free and hands it to
// a background worker thread that does the curl — nothing blocks the player or the
// accept path. Shadow (hidden) mods are never announced.

module discord_join;

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

// ============================================================
// C interop — file I/O, curl, threads. libc only (safe on the worker thread).
// ============================================================

extern fn CInt puts(ZString s);
extern fn CInt system(ZString cmd);
extern fn CInt fflush(void* stream);
fn void bg_log(ZString s) { puts(s); fflush(null); }

extern fn void* fopen_c(ZString path, ZString mode) @cname("fopen");
extern fn char* fgets_c(char* buf, CInt size, void* stream) @cname("fgets");
extern fn CInt  fclose_c(void* stream) @cname("fclose");
extern fn CInt  fputs_c(ZString s, void* stream) @cname("fputs");
extern fn CInt  remove_c(ZString path) @cname("remove");

extern fn uint posix_sleep(uint seconds) @cname("sleep") @if(!env::WIN32);
extern fn void win_sleep(uint milliseconds) @cname("Sleep") @if(env::WIN32);

alias RawThreadFn = fn void*(void*);
extern fn CInt   pthread_create(ulong* thread, void* attr, RawThreadFn start, void* arg) @if(!env::WIN32);
extern fn CInt   pthread_detach(ulong thread) @if(!env::WIN32);
extern fn void*  create_thread_win(void* attr, usz stack, RawThreadFn start, void* arg, uint flags, void* id) @cname("CreateThread") @if(env::WIN32);
extern fn CInt   close_handle_win(void* handle) @cname("CloseHandle") @if(env::WIN32);

macro void sleep_sec(uint seconds) {
    $if env::WIN32:
        win_sleep(seconds * 1000);
    $else
        posix_sleep(seconds);
    $endif
}

const String PLUGIN_NAME = "Discord Join Feed";
const int EVENT_JOIN  = 0;
const int EVENT_LEAVE = 1;
const int QUEUE_SLOTS = 16;
const int PAYLOAD_MAX = 2000;

PluginAPI* api;

char[600] cfg_webhook_buf;
char[128] cfg_username_buf;
char[256] cfg_mention_buf;
bool cfg_include_ipid = true;
bool cfg_relay_leave  = false;
bool enabled     = false;
bool opt_running = true;
char[512] path_config;

struct PostSlot { bool ready; char[PAYLOAD_MAX] json; }
PostSlot[QUEUE_SLOTS] queue;
char[512][QUEUE_SLOTS]  slot_path;
char[1280][QUEUE_SLOTS] slot_cmd;

// ============================================================
// Helpers (allocation-free)
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
fn String safe_cap(String s, usz max) {
    if (s.len <= max) return s;
    usz cut = max;
    while (cut > 0 && (s[cut] & 0xC0) == 0x80) cut--;
    if (cut == 0) return "";
    return s[0..cut - 1];
}
fn bool is_true(String s) { return s == "true" || s == "1" || s == "yes" || s == "on"; }
fn bool starts_with(String s, String pre) {
    if (s.len < pre.len) return false;
    for (usz i = 0; i < pre.len; i++) { if (s[i] != pre[i]) return false; }
    return true;
}
fn bool contains(String s, String sub) {
    if (sub.len == 0) return true;
    if (s.len < sub.len) return false;
    for (usz i = 0; i + sub.len <= s.len; i++) {
        bool ok = true;
        for (usz j = 0; j < sub.len; j++) { if (s[i + j] != sub[j]) { ok = false; break; } }
        if (ok) return true;
    }
    return false;
}
fn String first_token(String args) {
    String s = args.trim();
    usz i = 0;
    while (i < s.len && s[i] != ' ' && s[i] != '\t') i++;
    if (i == 0) return s.len == 0 ? "" : s;
    return s[0..i - 1];
}

// Accept only an https Discord webhook with no shell-dangerous bytes.
fn bool valid_webhook_url(String u) {
    if (!starts_with(u, "https://")) return false;
    foreach (char ch : u) {
        if (ch <= 0x20) return false;
        switch (ch) {
            case '"': case '\'': case '`': case '$': case '\\': case '%':
                return false;
            default: break;
        }
    }
    return contains(u, "discord.com/") || contains(u, "discordapp.com/");
}

// ============================================================
// Build the JSON ({"username","content"}) into a queue slot
// ============================================================

fn void enqueue_event(void* c, bool joining) {
    int slot = -1;
    for (int i = 0; i < QUEUE_SLOTS; i++) { if (!queue[i].ready) { slot = i; break; } }
    if (slot < 0) return; // queue full -> drop (best effort)

    int uid     = api.client_get_uid(c);
    int area    = api.client_get_area(c);
    String an   = api.area_get_name(area);
    String ipid = api.client_get_ipid(c);
    String chr  = api.client_get_char_name(c);
    int online  = api.get_player_count();

    usz n = 0;
    char[] b = queue[slot].json[..];
    n = put_str(b, n, "{\"username\":\"");
    n = put_json(b, n, cstr(&cfg_username_buf[0]));
    n = put_str(b, n, "\"");
    String mention = cstr(&cfg_mention_buf[0]);
    n = put_str(b, n, ",\"content\":\"");
    if (joining && mention.len > 0) { n = put_json(b, n, safe_cap(mention, 80)); n = put_str(b, n, " "); }
    n = put_str(b, n, joining ? "**+ connected** — UID " : "**- disconnected** — UID ");
    n = put_uint(b, n, (ulong)uid);
    if (cfg_include_ipid && ipid.len > 0) {
        n = put_str(b, n, " (IPID ");
        n = put_json(b, n, safe_cap(ipid, 40));
        n = put_str(b, n, ")");
    }
    if (!joining && chr.len > 0) {
        n = put_str(b, n, " as ");
        n = put_json(b, n, safe_cap(chr, 40));
    }
    n = put_str(b, n, " in ");
    n = put_json(b, n, safe_cap(an, 60));
    n = put_str(b, n, ". ");
    n = put_uint(b, n, (ulong)online);
    n = put_str(b, n, " online.\"}");

    queue[slot].json[n < (usz)PAYLOAD_MAX ? n : (usz)(PAYLOAD_MAX - 1)] = 0;
    queue[slot].ready = true; // publish last
}

// ============================================================
// Lifecycle hook
// ============================================================

fn void on_life(void* c, int event) {
    if (!enabled) return;
    if (api.client_is_hidden(c)) return; // never announce shadow mods
    if (event == EVENT_JOIN) { enqueue_event(c, true); }
    else if (event == EVENT_LEAVE && cfg_relay_leave) { enqueue_event(c, false); }
}

// ============================================================
// Worker thread — write JSON to a temp file and POST with curl
// ============================================================

fn void* worker_loop(void* arg) {
    sleep_sec(2);
    while (opt_running) {
        for (int i = 0; i < QUEUE_SLOTS; i++) {
            if (!queue[i].ready) continue;
            void* f = fopen_c((ZString)&slot_path[i][0], "w");
            if (f != null) {
                fputs_c((ZString)&queue[i].json[0], f);
                fclose_c(f);
                if (system((ZString)&slot_cmd[i][0]) != 0) {
                    bg_log("[discord_join] WARNING: webhook POST failed (curl non-zero).");
                }
                remove_c((ZString)&slot_path[i][0]);
            }
            queue[i].ready = false;
        }
        sleep_sec(1);
    }
    return null;
}

fn void start_worker() {
    $if env::WIN32:
        void* h = create_thread_win(null, 0, &worker_loop, null, 0, null);
        if (h != null) close_handle_win(h);
    $else
        ulong tid;
        if (pthread_create(&tid, null, &worker_loop, null) == 0) pthread_detach(tid);
    $endif
}

// ============================================================
// Config
// ============================================================

fn void parse_cfg_line(String raw) {
    usz sp = 0;
    while (sp < raw.len && raw[sp] != ' ' && raw[sp] != '\t') sp++;
    String key  = sp == 0 ? raw : raw[0..sp - 1];
    String rest = sp < raw.len ? raw[sp..].trim() : "";
    if (key == "webhook_url")       { copy_cstr(first_token(rest), &cfg_webhook_buf[0], 599); }
    else if (key == "username")     { if (rest.len > 0) copy_cstr(rest, &cfg_username_buf[0], 127); }
    else if (key == "mention")      { copy_cstr(rest, &cfg_mention_buf[0], 255); }
    else if (key == "include_ipid") { cfg_include_ipid = is_true(rest); }
    else if (key == "relay_leave")  { cfg_relay_leave = is_true(rest); }
}

fn void write_template() {
    void* f = fopen_c((ZString)&path_config[0], "w");
    if (f == null) return;
    fputs_c("# Whisker Discord Join Feed — posts on connect/disconnect via a webhook.\n", f);
    fputs_c("# Inactive until webhook_url is a valid https Discord webhook.\n", f);
    fputs_c("# webhook_url   https://discord.com/api/webhooks/XXXX/YYYY\n", f);
    fputs_c("# username      Whisker\n", f);
    fputs_c("# include_ipid  true\n", f);
    fputs_c("# relay_leave   false     # also post when a player disconnects\n", f);
    fputs_c("# mention       <@&ROLEID>\n", f);
    fclose_c(f);
}

fn void load_config(String dir) {
    usz cn = 0;
    cn = put_str(path_config[..], cn, dir);
    cn = put_str(path_config[..], cn, "/discord_join.txt");
    path_config[cn] = 0;

    void* f = fopen_c((ZString)&path_config[0], "r");
    if (f == null) {
        io::printn("[discord_join] No discord_join.txt — writing a template. Set webhook_url to enable.");
        write_template();
        return;
    }
    char[1024] line;
    while (fgets_c(&line[0], 1024, f) != null) {
        String raw = cstr(&line[0]).trim();
        if (raw.len == 0 || raw[0] == '#') continue;
        parse_cfg_line(raw);
    }
    fclose_c(f);
}

fn void build_slots(String dir, String url) {
    for (int i = 0; i < QUEUE_SLOTS; i++) {
        usz pn = 0;
        pn = put_str(slot_path[i][..], pn, dir);
        pn = put_str(slot_path[i][..], pn, "/discord_join_");
        pn = put_uint(slot_path[i][..], pn, (ulong)i);
        pn = put_str(slot_path[i][..], pn, ".json");
        slot_path[i][pn] = 0;

        usz cn = 0;
        cn = put_str(slot_cmd[i][..], cn, "curl -sf --max-time 15 -H \"Content-Type: application/json\" --data-binary @\"");
        cn = put_str(slot_cmd[i][..], cn, cstr(&slot_path[i][0]));
        cn = put_str(slot_cmd[i][..], cn, "\" \"");
        cn = put_str(slot_cmd[i][..], cn, url);
        cn = put_str(slot_cmd[i][..], cn, "\"");
        $if env::WIN32:
            cn = put_str(slot_cmd[i][..], cn, " >nul 2>&1");
        $else
            cn = put_str(slot_cmd[i][..], cn, " >/dev/null 2>&1");
        $endif
        slot_cmd[i][cn] = 0;
    }
}

// ============================================================
// Plugin interface (exported)
// ============================================================

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return {
        .name        = "Discord Join Feed",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Posts connect/disconnect to a Discord webhook. Optional — see header.",
    };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    opt_running = true;
    copy_cstr("Whisker", &cfg_username_buf[0], 127);

    String dir = "config";
    {
        void* a = fopen_c((ZString)"config/config.toml", "r");
        if (a != null) { fclose_c(a); }
        else {
            void* b = fopen_c((ZString)"../config/config.toml", "r");
            if (b != null) { fclose_c(b); dir = "../config"; }
        }
    }

    load_config(dir);

    String url = cstr(&cfg_webhook_buf[0]);
    enabled = valid_webhook_url(url);

    if (enabled) {
        build_slots(dir, url);
        api.register_lifecycle_hook(&on_life, PLUGIN_NAME);
        start_worker();
        io::printfn("[discord_join] Loaded. Posting joins to Discord (ipid=%s, leave=%s).",
            cfg_include_ipid ? "on" : "off", cfg_relay_leave ? "on" : "off");
    } else {
        if (url.len > 0) { io::printn("[discord_join] Loaded but INACTIVE: webhook_url is not a valid https Discord webhook."); }
        else { io::printn("[discord_join] Loaded but inactive: set webhook_url in config/discord_join.txt."); }
    }
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    opt_running = false;
    io::printn("[discord_join] Shutting down.");
}
