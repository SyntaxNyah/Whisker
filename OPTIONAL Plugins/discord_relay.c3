// Whisker Optional Plugin — Discord Relay [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Two-way bridge between AO2 areas and a Discord channel:
//   OUTBOUND (solid): mirror IC and/or OOC of chosen areas (or the whole server)
//     to a Discord channel via a webhook. Each message posts under the player's
//     name.
//   INBOUND (experimental): a Discord bot reads a channel and relays messages
//     back into a chosen area as OOC, so people can talk from Discord.
// Everything is opt-in and configurable. Optional — drop the .dll/.so into
// plugins/ and restart.
//
// Standalone plugin: see the Plugin Dev Guide (plugins/PLUGIN DEV GUIDE README.md).

module discord_relay;

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

const String PLUGIN_NAME = "Discord Relay";
const int MS_MESSAGE = 4;
const int MS_SHOWNAME = 15;
const int CT_OOC_NAME = 0;
const int CT_MESSAGE = 1;

const int QSLOTS = 16;
const int PAYLOAD = 4096;
const int MAX_RELAY_AREAS = 64;

struct Post { bool ready; char[PAYLOAD] json; }
Post[QSLOTS] queue;
char[512][QSLOTS]  slot_path;
char[1024][QSLOTS] slot_cmd;

// config
char[600] webhook_url;
char[512] path_config;
bool opt_relay_ic  = true;
bool opt_relay_ooc = true;
bool opt_relay_all = false;
int[MAX_RELAY_AREAS] relay_areas; int relay_area_n;

// inbound (experimental)
char[120] bot_token;
char[40]  channel_id;
int  inbound_area = 0;
bool inbound_enabled = false;
ulong last_id = 0;
char[2048] poll_cmd_base;     // prebuilt, after=<id> appended each poll
char[512]  inbound_tmp;
char[65536] resp_buf;

PluginAPI* api;
bool out_enabled = false;
bool opt_running = true;

extern fn CInt  system(ZString cmd);
extern fn CInt  fflush(void* stream);
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
macro void sleep_sec(uint s) { $if env::WIN32: win_sleep(s * 1000); $else posix_sleep(s); $endif }

fn usz put_str(char[] buf, usz n, String s) { foreach (char ch : s) { if (n >= buf.len) break; buf[n] = ch; n++; } return n; }
fn usz put_uint(char[] buf, usz n, ulong v) {
    if (v == 0) return put_str(buf, n, "0");
    char[24] tmp; int t = 0;
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
fn String safe_cap(String s, usz max) {
    if (s.len <= max) return s;
    usz cut = max;
    while (cut > 0 && (s[cut] & 0xC0) == 0x80) cut--;
    return cut == 0 ? "" : s[0..cut - 1];
}
fn bool starts_with(String s, String p) {
    if (s.len < p.len) return false;
    for (usz i = 0; i < p.len; i++) { if (s[i] != p[i]) return false; }
    return true;
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
// Reject shell-dangerous bytes (these strings reach system() quoted).
fn bool shell_safe(String u) {
    foreach (char ch : u) {
        if (ch <= 0x20) return false;
        switch (ch) { case '"': case '\'': case '`': case '$': case '\\': case '%': return false; default: break; }
    }
    return true;
}

fn bool area_relayed(int area) {
    if (opt_relay_all) return true;
    for (int i = 0; i < relay_area_n; i++) { if (relay_areas[i] == area) return true; }
    return false;
}

// ---- OUTBOUND ----
fn void enqueue(String name, String area, String tag, String msg) {
    int slot = -1;
    for (int i = 0; i < QSLOTS; i++) { if (!queue[i].ready) { slot = i; break; } }
    if (slot < 0) return; // queue full → drop
    usz n = put_str(queue[slot].json[..], 0, "{\"username\":\"");
    n = put_json(queue[slot].json[..], n, safe_cap(name, 60));
    n = put_str(queue[slot].json[..], n, " [");
    n = put_json(queue[slot].json[..], n, safe_cap(area, 40));
    n = put_str(queue[slot].json[..], n, "/");
    n = put_str(queue[slot].json[..], n, tag);
    n = put_str(queue[slot].json[..], n, "]\",\"content\":\"");
    n = put_json(queue[slot].json[..], n, safe_cap(msg, 1800));
    n = put_str(queue[slot].json[..], n, "\"}");
    queue[slot].json[n < (usz)PAYLOAD ? n : (usz)(PAYLOAD - 1)] = 0;
    queue[slot].ready = true; // publish last
}

fn bool on_ic(void* c, void* pkt) {
    if (!out_enabled || !opt_relay_ic) return false;
    int area = api.client_get_area(c);
    if (!area_relayed(area)) return false;
    String msg = api.packet_get_field(pkt, MS_MESSAGE);
    if (msg.len == 0) return false;
    int fc = api.packet_get_field_count(pkt);
    String show = fc > MS_SHOWNAME ? api.packet_get_field(pkt, MS_SHOWNAME) : "";
    String name = show.len > 0 ? show : api.client_get_char_name(c);
    enqueue(name, api.area_get_name(area), "IC", msg);
    return false; // never consume — relay is additive
}
fn bool on_ooc(void* c, void* pkt) {
    if (!out_enabled || !opt_relay_ooc) return false;
    if (api.packet_get_field_count(pkt) < 2) return false;
    String msg = api.packet_get_field(pkt, CT_MESSAGE);
    if (msg.len == 0 || msg[0] == '/') return false; // skip commands
    int area = api.client_get_area(c);
    if (!area_relayed(area)) return false;
    enqueue(api.packet_get_field(pkt, CT_OOC_NAME), api.area_get_name(area), "OOC", msg);
    return false;
}

// ---- INBOUND (experimental) ----
// Read a JSON string value at `pos` (just past the opening quote) into out,
// decoding the common escapes. Returns bytes written; sets *endp past closing ".
fn int read_json_str(String s, usz pos, char* out, int cap, usz* endp) {
    int n = 0;
    usz i = pos;
    while (i < s.len) {
        char ch = s[i];
        if (ch == '"') { i++; break; }
        if (ch == '\\' && i + 1 < s.len) {
            char e = s[i + 1];
            char put = e;
            switch (e) {
                case 'n': put = ' ';
                case 'r': put = ' ';
                case 't': put = ' ';
                case '"': put = '"';
                case '\\': put = '\\';
                case '/': put = '/';
                default: put = e; // \uXXXX etc. left as the following char (best-effort)
            }
            if (n < cap) { out[n] = put; n++; }
            i += 2;
            continue;
        }
        if (n < cap) { out[n] = ch; n++; }
        i++;
    }
    *endp = i;
    return n;
}

fn long find_from(String s, usz from, String pat) {
    if (pat.len == 0 || s.len < pat.len) return -1;
    for (usz i = from; i + pat.len <= s.len; i++) {
        bool ok = true;
        for (usz j = 0; j < pat.len; j++) { if (s[i + j] != pat[j]) { ok = false; break; } }
        if (ok) return (long)i;
    }
    return -1;
}

// Find the next message-object id: `{"id":"` whose '{' follows '[' or ','.
fn long find_msg(String s, usz from, ulong* id, usz* after) {
    usz i = from;
    while (true) {
        long m = find_from(s, i, `{"id":"`);
        if (m < 0) return -1;
        long p = (long)m - 1;
        while (p >= 0 && (s[p] == ' ' || s[p] == '\n' || s[p] == '\r' || s[p] == '\t')) p--;
        if (p < 0 || s[p] == '[' || s[p] == ',') {
            usz vp = (usz)m + 7; // past {"id":"
            ulong v = 0;
            while (vp < s.len && s[vp] >= '0' && s[vp] <= '9') { v = v * 10 + (ulong)(s[vp] - '0'); vp++; }
            *id = v; *after = vp;
            return m;
        }
        i = (usz)m + 1;
    }
}

fn void process_inbound(String resp) {
    usz i = 0;
    ulong max_id = last_id;
    int relayed = 0;
    while (relayed < 20) {
        ulong id; usz after;
        long m = find_msg(resp, i, &id, &after);
        if (m < 0) break;
        // segment for this message = [after .. next message start)
        ulong nid; usz nafter;
        long next = find_msg(resp, after, &nid, &nafter);
        usz seg_end = next < 0 ? resp.len : (usz)next;
        String seg = after < seg_end ? resp[after..seg_end - 1] : "";

        if (id > last_id) {
            bool is_webhook = contains(seg, `"webhook_id"`);
            long cpos = find_from(seg, 0, `"content":"`);
            if (!is_webhook && cpos >= 0) {
                char[600] cbuf; usz cend;
                int cn = read_json_str(seg, (usz)cpos + 11, &cbuf[0], 599, &cend);
                char[80] ubuf; int un = 0;
                long upos = find_from(seg, 0, `"username":"`);
                if (upos >= 0) { usz uend; un = read_json_str(seg, (usz)upos + 12, &ubuf[0], 79, &uend); }
                if (cn > 0) {
                    char[800] line; usz ln = 0;
                    ln = put_str(line[..], ln, "[Discord] ");
                    if (un > 0) { ln = put_str(line[..], ln, (String)ubuf[0..un - 1]); }
                    else { ln = put_str(line[..], ln, "?"); }
                    ln = put_str(line[..], ln, ": ");
                    ln = put_str(line[..], ln, (String)cbuf[0..cn - 1]);
                    api.broadcast_area_msg(inbound_area, (String)line[0..ln - 1]);
                    relayed++;
                }
            }
            if (id > max_id) max_id = id;
        }
        if (next < 0) break;
        i = (usz)next;
    }
    if (max_id > last_id) last_id = max_id;
}

fn void poll_inbound() {
    // Build the poll command with the current cursor.
    char[2200] cmd; usz n = 0;
    n = put_str(cmd[..], n, cstr(&poll_cmd_base[0]));
    if (last_id > 0) { n = put_str(cmd[..], n, "&after="); n = put_uint(cmd[..], n, last_id); }
    n = put_str(cmd[..], n, "\" -o \"");
    n = put_str(cmd[..], n, cstr(&inbound_tmp[0]));
    n = put_str(cmd[..], n, "\"");
    $if env::WIN32: n = put_str(cmd[..], n, " >nul 2>&1");
    $else n = put_str(cmd[..], n, " >/dev/null 2>&1"); $endif
    cmd[n] = 0;
    if (system((ZString)&cmd[0]) != 0) return;

    // Read the response file into resp_buf.
    void* f = fopen_c((ZString)&inbound_tmp[0], "r");
    if (f == null) return;
    usz total = 0;
    char[4096] chunk;
    while (fgets_c(&chunk[0], 4096, f) != null && total < 65000) {
        usz cl = 0; while (cl < 4095 && chunk[cl] != 0) cl++;
        for (usz k = 0; k < cl && total < 65535; k++) { resp_buf[total] = chunk[k]; total++; }
    }
    fclose_c(f);
    if (total == 0) return;
    process_inbound((String)resp_buf[0..total - 1]);
}

fn void* worker(void* arg) {
    sleep_sec(3);
    int since_poll = 0;
    while (opt_running) {
        // drain outbound queue
        for (int i = 0; i < QSLOTS; i++) {
            if (!queue[i].ready) continue;
            void* f = fopen_c((ZString)&slot_path[i][0], "w");
            if (f != null) {
                fputs_c((ZString)&queue[i].json[0], f);
                fclose_c(f);
                system((ZString)&slot_cmd[i][0]);
                remove_c((ZString)&slot_path[i][0]);
            }
            queue[i].ready = false;
        }
        // poll inbound every ~3s
        if (inbound_enabled) {
            since_poll++;
            if (since_poll >= 3) { since_poll = 0; poll_inbound(); }
        }
        fflush(null);
        sleep_sec(1);
    }
    return null;
}

fn void build_slots() {
    for (int i = 0; i < QSLOTS; i++) {
        usz pn = 0;
        pn = put_str(slot_path[i][..], pn, "discord_relay_");
        pn = put_uint(slot_path[i][..], pn, (ulong)i);
        pn = put_str(slot_path[i][..], pn, ".json");
        slot_path[i][pn] = 0;
        usz cn = 0;
        cn = put_str(slot_cmd[i][..], cn, "curl -sf --max-time 15 -H \"Content-Type: application/json\" --data-binary @\"");
        cn = put_str(slot_cmd[i][..], cn, cstr(&slot_path[i][0]));
        cn = put_str(slot_cmd[i][..], cn, "\" \"");
        cn = put_str(slot_cmd[i][..], cn, cstr(&webhook_url[0]));
        cn = put_str(slot_cmd[i][..], cn, "\"");
        $if env::WIN32: cn = put_str(slot_cmd[i][..], cn, " >nul 2>&1");
        $else cn = put_str(slot_cmd[i][..], cn, " >/dev/null 2>&1"); $endif
        slot_cmd[i][cn] = 0;
    }
}

fn void build_poll_base() {
    usz n = 0;
    n = put_str(poll_cmd_base[..], n, "curl -sf --max-time 15 -H \"Authorization: Bot ");
    n = put_str(poll_cmd_base[..], n, cstr(&bot_token[0]));
    n = put_str(poll_cmd_base[..], n, "\" \"https://discord.com/api/v10/channels/");
    n = put_str(poll_cmd_base[..], n, cstr(&channel_id[0]));
    n = put_str(poll_cmd_base[..], n, "/messages?limit=10");
    poll_cmd_base[n] = 0;
    copy_cstr("discord_relay_in.json", &inbound_tmp[0], 511);
}

fn void load_config() {
    void* f = fopen_c((ZString)&path_config[0], "r");
    if (f == null) { write_template(); return; }
    char[1024] line;
    while (fgets_c(&line[0], 1024, f) != null) {
        String raw = cstr(&line[0]).trim();
        if (raw.len == 0 || raw[0] == '#') continue;
        usz sp = 0; while (sp < raw.len && raw[sp] != ' ' && raw[sp] != '\t') sp++;
        String key = sp == 0 ? raw : raw[0..sp - 1];
        String rest = sp < raw.len ? raw[sp..].trim() : "";
        if (key == "webhook_url")    { copy_cstr(rest, &webhook_url[0], 599); }
        else if (key == "relay_ic")  { opt_relay_ic = is_true(rest); }
        else if (key == "relay_ooc") { opt_relay_ooc = is_true(rest); }
        else if (key == "relay_all") { opt_relay_all = is_true(rest); }
        else if (key == "relay_area"){ int a = (int)parse_ulong(rest); if (relay_area_n < MAX_RELAY_AREAS) { relay_areas[relay_area_n] = a; relay_area_n++; } }
        else if (key == "bot_token") { copy_cstr(rest, &bot_token[0], 119); }
        else if (key == "channel_id"){ copy_cstr(rest, &channel_id[0], 39); }
        else if (key == "inbound_area") { inbound_area = (int)parse_ulong(rest); }
        else if (key == "inbound_enabled") { inbound_enabled = is_true(rest); }
    }
    fclose_c(f);
}

fn void write_template() {
    void* f = fopen_c((ZString)&path_config[0], "w");
    if (f == null) return;
    fputs_c("# Whisker Discord Relay\n", f);
    fputs_c("# --- OUTBOUND (server -> Discord, via webhook) ---\n", f);
    fputs_c("# webhook_url   https://discord.com/api/webhooks/XXX/YYY\n", f);
    fputs_c("# relay_ic      true       # mirror IC messages\n", f);
    fputs_c("# relay_ooc     true       # mirror OOC messages\n", f);
    fputs_c("# relay_all     false      # relay every area...\n", f);
    fputs_c("# relay_area    0          # ...or list specific area indices (repeatable)\n", f);
    fputs_c("#\n", f);
    fputs_c("# --- INBOUND (Discord -> server, experimental; needs a bot) ---\n", f);
    fputs_c("# inbound_enabled true\n", f);
    fputs_c("# bot_token     YOUR_BOT_TOKEN     # bot needs the MESSAGE CONTENT intent\n", f);
    fputs_c("# channel_id    123456789012345678 # the Discord channel to read\n", f);
    fputs_c("# inbound_area  0                  # area index Discord messages appear in (OOC)\n", f);
    fclose_c(f);
}

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return { "Discord Relay", "1.0.0", "Whisker Community", "Two-way Discord <-> area chat relay. Optional." };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    opt_running = true;
    usz n = 0; n = put_str(path_config[..], n, "config/discord_relay.txt"); path_config[n] = 0;
    void* probe = fopen_c((ZString)&path_config[0], "r");
    if (probe != null) { fclose_c(probe); }
    else {
        void* alt = fopen_c("../config/config.toml", "r");
        if (alt != null) { fclose_c(alt); n = 0; n = put_str(path_config[..], n, "../config/discord_relay.txt"); path_config[n] = 0; }
    }
    load_config();

    String url = cstr(&webhook_url[0]);
    out_enabled = url.len > 0 && starts_with(url, "https://") && shell_safe(url)
        && (contains(url, "discord.com/") || contains(url, "discordapp.com/"));

    String tok = cstr(&bot_token[0]);
    String chan = cstr(&channel_id[0]);
    bool inbound_ok = inbound_enabled && tok.len > 0 && chan.len > 0 && shell_safe(tok) && shell_safe(chan);
    inbound_enabled = inbound_ok;

    if (out_enabled) {
        build_slots();
        api.register_hook("MS", &on_ic, PLUGIN_NAME);
        api.register_hook("CT", &on_ooc, PLUGIN_NAME);
    }
    if (inbound_enabled) build_poll_base();

    if (out_enabled || inbound_enabled) {
        $if env::WIN32:
            void* h = create_thread_win(null, 0, &worker, null, 0, null);
            if (h != null) close_handle_win(h);
        $else
            ulong tid;
            if (pthread_create(&tid, null, &worker, null) == 0) pthread_detach(tid);
        $endif
        io::printfn("[discord_relay] Loaded (outbound=%s inbound=%s).",
            out_enabled ? "on" : "off", inbound_enabled ? "on" : "off");
    } else {
        io::printn("[discord_relay] Loaded but inactive — set webhook_url (outbound) and/or bot_token+channel_id (inbound) in config/discord_relay.txt.");
    }
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    opt_running = false;
    io::printn("[discord_relay] Shutting down.");
}
