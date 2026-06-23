// Whisker Optional Plugin — Discord Modcall Webhook [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Forwards every in-game modcall (the ZZ packet — what a player sends when they
// click "Call Mod") to a Discord channel via an incoming webhook, as a rich
// embed with who called, from where, and (optionally) the last few messages in
// that area so a moderator has context without being in the room. Drop the
// compiled .dll (Windows) / .so (Linux) into your server's plugins/ folder and
// restart. Optional — your server runs fine without it.
//
// This source file is provided as a learning exercise. To compile a C3 plugin
// yourself, follow the Plugin Dev Guide: plugins/PLUGIN DEV GUIDE README.md
//
// ============================================================
// What it sends
// ============================================================
//
// On each modcall the plugin POSTs a Discord embed containing:
//   * Area name            (where the call came from)
//   * UID                  (the caller's session id)
//   * Character            (their AO character)
//   * Showname             (their in-court display name)
//   * OOC name             (their out-of-character name)
//   * IPID                 (hashed IP id; can be turned off for privacy)
//   * The modcall reason   (embed description)
//   * Optionally, the last N messages in that area (configurable count) so the
//     mod sees the context that triggered the call.
// The embed colour is configurable.
//
// The in-game modcall is unaffected — online moderators are still notified the
// normal way. This only ADDS the Discord notification.
//
// ============================================================
// Why this is a PLUGIN, and why you might NOT want to depend on Discord
// ============================================================
//
// Routing modcalls to Discord is genuinely useful — AO moderators are very often
// not staring at the server console, and a Discord ping reaches them on their
// phone. But it is the wrong default for a lot of servers, which is exactly why
// it is an opt-in plugin and not core:
//
//   * It creates a third-party dependency. If Discord is down, rate-limits you,
//     or you delete the webhook, your modcalls silently stop reaching staff. The
//     IN-GAME modcall still works (this plugin never replaces it) — but anyone
//     who *relies* on the Discord side has a single point of failure outside
//     their control. Treat Discord as a convenience, not your only alerting.
//   * It sends player data off your server. Area names, charnames, shownames,
//     OOC names, the message context, and (unless you disable it) the IPID leave
//     your machine and land in Discord's infrastructure, governed by Discord's
//     terms — not yours. Some communities have privacy expectations or
//     obligations that make that a problem. Tell your players, and consider
//     include_ipid = false and include_logs = false if in doubt.
//   * Webhooks are a small secret. Anyone with the URL can post to your channel,
//     so the URL lives in your server-side config, never in the client.
//   * Not every server even has a staff Discord.
//
// So: great for servers that live on Discord, pointless or unwanted for others.
// Opt-in keeps the core neutral and the decision yours.

module discord_modcall;

import std::io;

// ============================================================
// Whisker plugin interface (standalone definitions)
// Must match src/plugin.c3 PluginAPI exactly, field-for-field, in order.
// (v4 prefix, copied verbatim from ip_guard.c3.) This plugin uses register_hook,
// packet_get_field(_count), and the client_* / area_* getters.
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
// C interop — file I/O, curl, sleep, thread. libc only, so it is safe on the
// raw worker thread (no C3 runtime / temp allocator there).
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

// ============================================================
// Constants & limits
// ============================================================

const String PLUGIN_NAME = "Discord Modcall";

const int MAX_AREAS    = 256;   // per-area recent-message ring
const int LOG_RING     = 25;    // recent messages kept per area
const int NAME_MAX     = 40;    // stored speaker name bytes
const int TEXT_MAX     = 200;   // stored message bytes (preview)

const int QUEUE_SLOTS  = 8;     // pending webhook posts
const int PAYLOAD_MAX  = 12000; // max JSON bytes per post (well over Discord's limits)

const int DESC_LOG_BUDGET = 1500; // max bytes of log lines folded into the embed
const int REASON_CAP      = 800;  // max bytes of the modcall reason shown

const int DEFAULT_COLOR = 0xE74C3C; // a red

// MS field index of the message; CT field indices of name + message.
const int MS_MESSAGE  = 4;
const int CT_OOC_NAME = 0;
const int CT_MESSAGE  = 1;

// ============================================================
// Per-area recent-message ring (allocation-free; filled by the MS/CT hooks)
// ============================================================

struct LogMsg {
    char           kind;            // 'I' = IC, 'O' = OOC
    char[NAME_MAX] name; int name_len;
    char[TEXT_MAX] text; int text_len;
}

struct AreaLog {
    LogMsg[LOG_RING] msgs;
    int head;   // next write slot
    int count;  // filled entries (<= LOG_RING)
}

AreaLog[MAX_AREAS] area_logs;

// ============================================================
// Outgoing webhook queue. Producer (ZZ hook on a client thread) builds the JSON
// into a free slot and sets `ready` LAST; the worker thread writes it to a file
// and curls it, then clears `ready`. Lockless/best-effort: two modcalls in the
// exact same instant could pick the same slot — acceptable for a rare, human
// action (matches the codebase's lockless conventions).
// ============================================================

struct PostSlot {
    bool ready;
    char[PAYLOAD_MAX] json;
}

PostSlot[QUEUE_SLOTS] queue;
char[512][QUEUE_SLOTS]  slot_path; // temp file per slot
char[1280][QUEUE_SLOTS] slot_cmd;  // prebuilt curl command per slot

// ============================================================
// Config / options
// ============================================================

PluginAPI* api;

char[600] cfg_webhook_buf;   // the webhook URL (validated)
char[128] cfg_username_buf;  // webhook display name
char[256] cfg_mention_buf;   // optional content ping, e.g. <@&roleid>
int  cfg_color         = DEFAULT_COLOR;
bool cfg_include_logs  = true;
int  cfg_log_count     = 10;
bool cfg_include_ipid  = true;

bool enabled     = false; // true only when a valid webhook URL is configured
bool opt_running = true;

char[512] path_config;
String cfg_dir;

// ============================================================
// Small helpers (allocation-free)
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

// Append `s` JSON-escaped (so it is safe inside a JSON string literal).
fn usz put_json(char[] buf, usz n, String s) {
    foreach (char ch : s) {
        switch (ch) {
            case '"':  n = put_str(buf, n, "\\\"");
            case '\\': n = put_str(buf, n, "\\\\");
            case '\n': n = put_str(buf, n, "\\n");
            case '\r': n = put_str(buf, n, "\\r");
            case '\t': n = put_str(buf, n, "\\t");
            default:
                if (ch < 0x20) {
                    n = put_str(buf, n, "\\u00");
                    n = put_hex2(buf, n, (int)ch);
                } else if (n < buf.len) {
                    buf[n] = ch; n++; // raw byte (UTF-8 multibyte passes through)
                }
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

// Copy up to `max` bytes, but never split a UTF-8 sequence (so escaped output is
// always valid UTF-8 / valid JSON). Returns bytes written.
fn int copy_capped(char* dst, int max, String s) {
    int n = (int)s.len;
    if (n > max) {
        n = max;
        while (n > 0 && (s[n] & 0xC0) == 0x80) n--; // back off a partial tail
    }
    for (int i = 0; i < n; i++) dst[i] = s[i];
    return n;
}

// Return a prefix of `s` of at most `max` bytes, not splitting a UTF-8 sequence.
fn String safe_cap(String s, usz max) {
    if (s.len <= max) return s;
    usz cut = max;
    while (cut > 0 && (s[cut] & 0xC0) == 0x80) cut--;
    if (cut == 0) return "";
    return s[0..cut - 1];
}

fn bool is_true(String s) { return s == "true" || s == "1" || s == "yes" || s == "on"; }

fn ulong parse_ulong(String s) {
    ulong v = 0;
    foreach (char ch : s) { if (ch >= '0' && ch <= '9') v = v * 10 + (ulong)(ch - '0'); }
    return v;
}

fn int hex_val(char ch) {
    if (ch >= '0' && ch <= '9') return ch - '0';
    if (ch >= 'a' && ch <= 'f') return ch - 'a' + 10;
    if (ch >= 'A' && ch <= 'F') return ch - 'A' + 10;
    return -1;
}

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

// ============================================================
// Webhook URL validation + colour parsing
// ============================================================

// Accept only an https Discord webhook with no shell-dangerous bytes. The URL is
// the one attacker-influenced value that reaches the shell (quoted) in the curl
// command, so we reject whitespace, control chars, and the characters that can
// break out of double quotes on cmd.exe / POSIX sh.
fn bool valid_webhook_url(String u) {
    if (!starts_with(u, "https://")) return false;
    foreach (char ch : u) {
        if (ch <= 0x20) return false; // space / control
        switch (ch) {
            case '"': case '\'': case '`': case '$': case '\\': case '%':
                return false;
            default: break;
        }
    }
    return contains(u, "discord.com/") || contains(u, "discordapp.com/");
}

fn int parse_color(String raw) {
    String t = raw.trim();
    if (t.len == 0) return DEFAULT_COLOR;
    usz i = 0;
    bool hex = false;
    if (t[0] == '#') { i = 1; hex = true; }
    else if (t.len >= 2 && t[0] == '0' && (t[1] == 'x' || t[1] == 'X')) { i = 2; hex = true; }

    int v = 0;
    if (hex) {
        bool have = false;
        for (; i < t.len; i++) { int d = hex_val(t[i]); if (d < 0) return DEFAULT_COLOR; v = v * 16 + d; have = true; }
        if (!have) return DEFAULT_COLOR;
    } else {
        bool have = false;
        for (; i < t.len; i++) { if (t[i] < '0' || t[i] > '9') return DEFAULT_COLOR; v = v * 10 + (t[i] - '0'); have = true; }
        if (!have) return DEFAULT_COLOR;
    }
    return v & 0xFFFFFF; // clamp to a 24-bit colour
}

// ============================================================
// Area log ring
// ============================================================

fn void push_log(int area, char kind, String name, String text) {
    if (area < 0 || area >= MAX_AREAS) return;
    if (text.len == 0) return;
    AreaLog* al = &area_logs[area];
    int i = al.head;
    al.msgs[i].kind     = kind;
    al.msgs[i].name_len = copy_capped(&al.msgs[i].name[0], NAME_MAX - 1, name);
    al.msgs[i].text_len = copy_capped(&al.msgs[i].text[0], TEXT_MAX - 1, text);
    al.head = (i + 1) % LOG_RING;
    if (al.count < LOG_RING) al.count++;
}

// ============================================================
// JSON payload builder
// ============================================================

fn usz put_field_str(char[] buf, usz n, bool first, String name, String value) {
    if (!first) n = put_str(buf, n, ",");
    n = put_str(buf, n, "{\"name\":\"");
    n = put_json(buf, n, name);
    n = put_str(buf, n, "\",\"value\":\"");
    // Discord rejects empty field values.
    if (value.len == 0) { n = put_str(buf, n, "—"); }
    else { n = put_json(buf, n, safe_cap(value, 200)); }
    n = put_str(buf, n, "\",\"inline\":true}");
    return n;
}

fn usz put_field_uint(char[] buf, usz n, bool first, String name, ulong value) {
    if (!first) n = put_str(buf, n, ",");
    n = put_str(buf, n, "{\"name\":\"");
    n = put_json(buf, n, name);
    n = put_str(buf, n, "\",\"value\":\"");
    n = put_uint(buf, n, value);
    n = put_str(buf, n, "\",\"inline\":true}");
    return n;
}

fn usz build_payload(char[] buf, int area, String area_name, int uid,
                     String char_name, String showname, String ooc_name,
                     String ipid, String reason) {
    usz n = 0;
    n = put_str(buf, n, "{\"username\":\"");
    n = put_json(buf, n, cstr(&cfg_username_buf[0]));
    n = put_str(buf, n, "\"");

    String mention = cstr(&cfg_mention_buf[0]);
    if (mention.len > 0) {
        n = put_str(buf, n, ",\"content\":\"");
        n = put_json(buf, n, safe_cap(mention, 200));
        n = put_str(buf, n, "\"");
    }

    n = put_str(buf, n, ",\"embeds\":[{\"title\":\"\\uD83D\\uDEA8 Modcall\",\"color\":");
    n = put_uint(buf, n, (ulong)cfg_color);

    // Description: reason, then (optionally) recent area messages in a code block.
    n = put_str(buf, n, ",\"description\":\"**Reason:** ");
    String r = safe_cap(reason, REASON_CAP);
    if (r.len == 0) { n = put_str(buf, n, "_(none given)_"); }
    else { n = put_json(buf, n, r); }

    if (cfg_include_logs && area >= 0 && area < MAX_AREAS && area_logs[area].count > 0) {
        AreaLog* al = &area_logs[area];
        int show = cfg_log_count < al.count ? cfg_log_count : al.count;
        n = put_str(buf, n, "\\n\\n**Recent messages:**\\n```\\n");
        usz logs_start = n;
        for (int k = 0; k < show; k++) {
            if (n - logs_start > (usz)DESC_LOG_BUDGET) break;
            int idx = (al.head - show + k + LOG_RING) % LOG_RING;
            LogMsg* m = &al.msgs[idx];
            n = put_str(buf, n, m.kind == 'I' ? "[IC] " : "[OOC] ");
            if (m.name_len > 0) n = put_json(buf, n, (String)m.name[0..m.name_len - 1]);
            n = put_str(buf, n, ": ");
            if (m.text_len > 0) n = put_json(buf, n, (String)m.text[0..m.text_len - 1]);
            n = put_str(buf, n, "\\n");
        }
        n = put_str(buf, n, "```");
    }
    n = put_str(buf, n, "\"");

    // Structured fields.
    n = put_str(buf, n, ",\"fields\":[");
    n = put_field_str(buf, n, true, "Area", area_name);
    n = put_field_uint(buf, n, false, "UID", (ulong)uid);
    n = put_field_str(buf, n, false, "Character", char_name);
    n = put_field_str(buf, n, false, "Showname", showname);
    n = put_field_str(buf, n, false, "OOC Name", ooc_name);
    if (cfg_include_ipid) n = put_field_str(buf, n, false, "IPID", ipid);
    n = put_str(buf, n, "]");

    n = put_str(buf, n, "}]}");
    return n;
}

// ============================================================
// Packet hooks (never consume — always return false)
// ============================================================

fn bool on_modcall(void* c, void* pkt) {
    if (!enabled) return false;

    int    uid       = api.client_get_uid(c);
    int    area      = api.client_get_area(c);
    String area_name = api.area_get_name(area);
    String char_name = api.client_get_char_name(c);
    String showname  = api.client_get_showname(c);
    String ooc_name  = api.client_get_ooc_name(c);
    String ipid      = api.client_get_ipid(c);
    String reason    = api.packet_get_field_count(pkt) > 0 ? api.packet_get_field(pkt, 0) : "";

    // Claim a free queue slot (best-effort, lockless).
    int slot = -1;
    for (int i = 0; i < QUEUE_SLOTS; i++) { if (!queue[i].ready) { slot = i; break; } }
    if (slot < 0) { bg_log("[discord_modcall] Webhook queue full — dropping a modcall notification."); return false; }

    usz n = build_payload(queue[slot].json[..], area, area_name, uid,
                          char_name, showname, ooc_name, ipid, reason);
    queue[slot].json[n < (usz)PAYLOAD_MAX ? n : (usz)(PAYLOAD_MAX - 1)] = 0;
    queue[slot].ready = true; // publish last
    return false; // let the core notify in-game mods as usual
}

fn bool on_ic(void* c, void* pkt) {
    if (!enabled) return false;
    String msg = api.packet_get_field(pkt, MS_MESSAGE);
    if (msg.len == 0) return false;
    String show = api.client_get_showname(c);
    String name = show.len > 0 ? show : api.client_get_char_name(c);
    push_log(api.client_get_area(c), 'I', name, msg);
    return false;
}

fn bool on_ooc(void* c, void* pkt) {
    if (!enabled) return false;
    String msg = api.packet_get_field(pkt, CT_MESSAGE);
    if (msg.len == 0 || msg[0] == '/') return false; // skip commands
    String name = api.packet_get_field(pkt, CT_OOC_NAME);
    push_log(api.client_get_area(c), 'O', name, msg);
    return false;
}

// ============================================================
// Worker thread — writes the JSON to a file and POSTs with curl. libc only.
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
                    bg_log("[discord_modcall] WARNING: webhook POST failed (curl returned non-zero).");
                }
                // The payload holds player data in plaintext — don't leave it on
                // disk once it has been sent.
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
// Config (config/discord.txt) — "key value" lines, '#' comments.
// ============================================================

fn void parse_cfg_line(String raw) {
    usz sp = 0;
    while (sp < raw.len && raw[sp] != ' ' && raw[sp] != '\t') sp++;
    String key  = sp == 0 ? raw : raw[0..sp - 1];
    String rest = sp < raw.len ? raw[sp..].trim() : "";

    if (key == "webhook_url")        { copy_cstr(first_token(rest), &cfg_webhook_buf[0], 599); }
    else if (key == "username")      { if (rest.len > 0) copy_cstr(rest, &cfg_username_buf[0], 127); }
    else if (key == "mention")       { copy_cstr(rest, &cfg_mention_buf[0], 255); }
    else if (key == "color")         { cfg_color = parse_color(rest); }
    else if (key == "include_logs")  { cfg_include_logs = is_true(rest); }
    else if (key == "include_ipid")  { cfg_include_ipid = is_true(rest); }
    else if (key == "log_count") {
        int v = (int)parse_ulong(rest);
        if (v < 0) v = 0;
        if (v > LOG_RING) v = LOG_RING;
        cfg_log_count = v;
    }
}

fn void load_config() {
    void* f = fopen_c((ZString)&path_config[0], "r");
    if (f == null) {
        io::printn("[discord_modcall] No discord.txt found — writing a template. Set webhook_url to enable.");
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

fn void write_template() {
    void* f = fopen_c((ZString)&path_config[0], "w");
    if (f == null) return;
    fputs_c("# Whisker Discord Modcall webhook\n", f);
    fputs_c("# Uncomment webhook_url and paste your Discord channel's webhook URL\n", f);
    fputs_c("# (Channel -> Edit -> Integrations -> Webhooks -> New/Copy Webhook URL).\n", f);
    fputs_c("# Until a valid webhook_url is set, this plugin does nothing.\n", f);
    fputs_c("#\n", f);
    fputs_c("# webhook_url   https://discord.com/api/webhooks/XXXXX/YYYYY\n", f);
    fputs_c("# username      Whisker Modcall      # name the webhook posts under\n", f);
    fputs_c("# color         #E74C3C              # embed colour (#hex or decimal)\n", f);
    fputs_c("# include_logs  true                 # include recent area messages\n", f);
    fputs_c("# log_count     10                   # how many recent messages (max 25)\n", f);
    fputs_c("# include_ipid  true                 # include the caller's IPID\n", f);
    fputs_c("# mention       <@&ROLEID>           # optional: ping a role on each call\n", f);
    fclose_c(f);
}

// Build the per-slot temp paths + curl commands once, on the main thread.
fn void build_slots(String dir, String url) {
    for (int i = 0; i < QUEUE_SLOTS; i++) {
        usz pn = 0;
        pn = put_str(slot_path[i][..], pn, dir);
        pn = put_str(slot_path[i][..], pn, "/discord_payload_");
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
        .name        = "Discord Modcall",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Forward modcalls to a Discord webhook. Optional — see header.",
    };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    opt_running = true;
    copy_cstr("Whisker Modcall", &cfg_username_buf[0], 127);

    // Resolve config dir like the other plugins: prefer ./config, else ../config.
    String dir = "config";
    {
        char[512] probe; usz pn = 0;
        pn = put_str(probe[..], pn, "config/discord.txt"); probe[pn] = 0;
        char[512] probe2; usz p2 = 0;
        p2 = put_str(probe2[..], p2, "../config/config.toml"); probe2[p2] = 0;
        void* a = fopen_c((ZString)&probe[0], "r");
        if (a != null) { fclose_c(a); }
        else {
            void* b = fopen_c((ZString)&probe2[0], "r");
            if (b != null) { fclose_c(b); dir = "../config"; }
        }
    }
    cfg_dir = dir;

    usz cn = 0;
    cn = put_str(path_config[..], cn, dir);
    cn = put_str(path_config[..], cn, "/discord.txt");
    path_config[cn] = 0;

    load_config();

    String url = cstr(&cfg_webhook_buf[0]);
    enabled = valid_webhook_url(url);

    if (enabled) {
        build_slots(dir, url);
        api.register_hook("ZZ", &on_modcall, PLUGIN_NAME);
        if (cfg_include_logs) {
            api.register_hook("MS", &on_ic,  PLUGIN_NAME);
            api.register_hook("CT", &on_ooc, PLUGIN_NAME);
        }
        start_worker();
        io::printfn("[discord_modcall] Loaded. Forwarding modcalls to Discord (logs=%s ipid=%s).",
            cfg_include_logs ? "on" : "off", cfg_include_ipid ? "on" : "off");
    } else {
        if (url.len > 0) {
            io::printn("[discord_modcall] Loaded but INACTIVE: webhook_url is not a valid https Discord webhook URL.");
        } else {
            io::printn("[discord_modcall] Loaded but inactive: set webhook_url in config/discord.txt to enable.");
        }
    }
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    opt_running = false;
    io::printn("[discord_modcall] Shutting down.");
}
