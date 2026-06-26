// Whisker Optional Plugin — Allowlist (whitelist server) [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Turns the server into an invite-only / whitelist server: while it's enabled,
// ONLY pre-approved IPIDs may join — anyone else is turned away at the door with
// a friendly (non-ban) notice. For private communities, members-only servers, or
// locking things down during a raid. Drop the compiled .dll / .so into plugins/
// and restart. Optional.
//
// This source file is provided as a learning exercise. To compile a C3 plugin
// yourself, follow the Plugin Dev Guide: plugins/PLUGIN DEV GUIDE README.md
//
// ============================================================
// What it does
// ============================================================
//
//   /allow <uid>        add an online player's IPID to the allowlist (mod)
//   /unallow <ipid>     remove an IPID from the allowlist (mod)
//   /allowlist          show on/off state and how many IPIDs are allowed (mod)
//
// The allowlist is stored in config/allowlist.txt (one IPID per line), created
// with a template on first run.
//
// ============================================================
// ⚠️ Enable it ONLY after you've built your list
// ============================================================
//
// `enabled` defaults to FALSE on purpose. If you turn it on with an empty list,
// you lock out EVERYONE (including yourself). Add your regulars first — run the
// server normally, `/allow <uid>` the people who should have access (or paste
// their IPIDs into config/allowlist.txt) — then set `enabled = true` and reload.
//
// ============================================================
// Configuration — config/config.toml [allowlist]
// ============================================================
//
//   enabled   false   master switch (see the warning above)
//   message   ...      the notice an un-listed player sees when turned away
//
// ============================================================
// Why this is an OPTIONAL plugin — and zero hot-path cost
// ============================================================
//
// Most servers want to be open; a whitelist is a specific, deliberate policy, so
// it's opt-in. The gate runs once per *join* (not per packet) — a quick linear
// scan of the allowed set, microseconds at human join rates — and nothing at all
// runs on the IC/OOC path. It complements `lockdown` (auto-learned, temporary)
// and the core `/ban`: this is the curated, always-on version.

module allowlist;

import std::io;

// ============================================================
// Whisker plugin interface (standalone) — full v6 (needs client_kick_msg).
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

extern fn void* fopen_c(ZString path, ZString mode) @cname("fopen");
extern fn char* fgets_c(char* buf, CInt size, void* stream) @cname("fgets");
extern fn CInt  fclose_c(void* stream) @cname("fclose");
extern fn CInt  fputs_c(ZString s, void* stream) @cname("fputs");

const String PLUGIN_NAME = "Allowlist";
const ulong  PERM_BAN    = 4;
const int    MAX_ALLOW   = 16384;
const int    EVENT_JOIN  = 0;

PluginAPI* api;
bool opt_enabled = false;
char[200] cfg_message;

// ============================================================
// The allowed-IPID set
// ============================================================

struct Entry { bool used; char[80] ipid; int len; }
Entry[MAX_ALLOW] allow;
int allow_count;

fn String estr(char* buf, int len) {
    if (len <= 0) return "";
    return (String)buf[0..len - 1];
}

fn bool is_allowed(String ipid) {
    for (int i = 0; i < MAX_ALLOW; i++) {
        if (allow[i].used && estr(&allow[i].ipid[0], allow[i].len) == ipid) return true;
    }
    return false;
}

fn bool add_allow_mem(String ipid) {
    if (ipid.len == 0 || ipid.len > 79) return false;
    if (is_allowed(ipid)) return true;
    for (int i = 0; i < MAX_ALLOW; i++) {
        if (!allow[i].used) {
            allow[i].used = true;
            int n = (int)ipid.len;
            for (int k = 0; k < n; k++) allow[i].ipid[k] = ipid[k];
            allow[i].len = n;
            allow_count++;
            return true;
        }
    }
    return false;
}

fn bool remove_allow_mem(String ipid) {
    bool removed = false;
    for (int i = 0; i < MAX_ALLOW; i++) {
        if (allow[i].used && estr(&allow[i].ipid[0], allow[i].len) == ipid) {
            allow[i].used = false; allow_count--; removed = true;
        }
    }
    return removed;
}

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
fn String kick_reason() {
    String r = cstr(&cfg_message[0]);
    if (r.len == 0) return "This is a members-only server. Ask an admin to be added to the allowlist.";
    return r;
}

// ============================================================
// Persistence — config/allowlist.txt (one IPID per line)
// ============================================================

fn void load_file() {
    void* f = fopen_c("config/allowlist.txt", "r");
    if (f == null) f = fopen_c("../config/allowlist.txt", "r");
    if (f == null) {
        // create a template on first run
        void* w = fopen_c("config/allowlist.txt", "w");
        if (w == null) w = fopen_c("../config/allowlist.txt", "w");
        if (w != null) {
            fputs_c((ZString)"# Whisker allowlist — one IPID per line.\n", w);
            fputs_c((ZString)"# Only these IPIDs may join while [allowlist] enabled = true.\n", w);
            fputs_c((ZString)"# Add live with /allow <uid>, or paste IPIDs (from /baninfo etc.) below.\n", w);
            fclose_c(w);
        }
        io::printn("[allowlist] Created config/allowlist.txt template.");
        return;
    }
    char[256] line;
    while (fgets_c(&line[0], 256, f) != null) {
        String raw = cstr(&line[0]).trim();
        if (raw.len == 0 || raw[0] == '#') continue;
        add_allow_mem(raw);
    }
    fclose_c(f);
    io::printfn("[allowlist] Loaded %d allowed IPID(s).", allow_count);
}

fn void append_file(String ipid) {
    void* f = fopen_c("config/allowlist.txt", "a");
    if (f == null) f = fopen_c("../config/allowlist.txt", "a");
    if (f == null) return;
    char[96] line; usz n = 0;
    n = put_str(line[..], n, ipid);
    n = put_str(line[..], n, "\n");
    line[n] = 0;
    fputs_c((ZString)&line[0], f);
    fclose_c(f);
}

// ============================================================
// JOIN gate
// ============================================================

fn void on_life(void* c, int event) {
    if (event != EVENT_JOIN) return;
    if (!opt_enabled) return;
    String ipid = api.client_get_ipid(c);
    if (is_allowed(ipid)) return;
    api.client_kick_msg(c, kick_reason());
    io::printfn("[allowlist] Turned away non-listed IPID %s.", ipid);
}

// ============================================================
// Commands
// ============================================================

fn void cmd_allow(void* c, String args) {
    int uid = args.trim().to_int() ?? -1;
    if (uid < 0) { api.client_send_msg(c, "Usage: /allow <uid>  (adds that player's IPID)"); return; }
    void* t = api.find_client(uid);
    if (t == null) { api.client_send_msg(c, "No player with that UID is online."); return; }
    String ipid = api.client_get_ipid(t);
    if (is_allowed(ipid)) { api.client_send_msg(c, "That IPID is already on the allowlist."); return; }
    if (!add_allow_mem(ipid)) { api.client_send_msg(c, "The allowlist is full."); return; }
    append_file(ipid);
    char[120] m; usz n = 0;
    n = put_str(m[..], n, "Added ");
    n = put_str(m[..], n, api.client_display_name(t));
    n = put_str(m[..], n, " (IPID ");
    n = put_str(m[..], n, ipid);
    n = put_str(m[..], n, ") to the allowlist.");
    api.client_send_msg(c, (String)m[0..n - 1]);
}

fn void cmd_unallow(void* c, String args) {
    String ipid = args.trim();
    if (ipid.len == 0) { api.client_send_msg(c, "Usage: /unallow <ipid>"); return; }
    if (remove_allow_mem(ipid)) {
        api.client_send_msg(c, "Removed from the in-memory allowlist. (Also delete the line from config/allowlist.txt to make it permanent.)");
    } else {
        api.client_send_msg(c, "That IPID isn't on the allowlist.");
    }
}

fn void cmd_allowlist(void* c, String args) {
    char[120] m; usz n = 0;
    n = put_str(m[..], n, "Allowlist: ");
    n = put_str(m[..], n, opt_enabled ? "ENABLED" : "disabled");
    n = put_str(m[..], n, ", ");
    n = put_int(m[..], n, allow_count);
    n = put_str(m[..], n, " IPID(s) allowed.");
    api.client_send_msg(c, (String)m[0..n - 1]);
}

// ============================================================
// Config
// ============================================================

fn bool is_true(String s) { return s == "true" || s == "1" || s == "yes" || s == "on"; }

fn void read_config() {
    void* f = fopen_c("config/config.toml", "r");
    if (f == null) f = fopen_c("../config/config.toml", "r");
    if (f == null) { io::printn("[allowlist] No config.toml found, using defaults."); return; }
    char[512] line;
    bool in_section = false;
    while (fgets_c(&line[0], 512, f) != null) {
        String raw = cstr(&line[0]).trim();
        if (raw.len == 0 || raw[0] == '#') continue;
        if (raw[0] == '[') { in_section = (raw == "[allowlist]"); continue; }
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
        if (key == "enabled")      { opt_enabled = is_true(val); }
        else if (key == "message") { if (val.len > 0) copy_str(val, &cfg_message[0], 199); }
    }
    fclose_c(f);
}

// ============================================================
// Plugin interface (exported)
// ============================================================

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return {
        .name        = "Allowlist",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Members-only whitelist by IPID. Optional — see header.",
    };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    for (int i = 0; i < MAX_ALLOW; i++) allow[i].used = false;
    allow_count = 0;
    cfg_message[0] = 0;

    read_config();
    load_file();

    api.register_lifecycle_hook(&on_life, PLUGIN_NAME);
    api.register_command("allow", &cmd_allow, PERM_BAN, "Add a player's IPID to the allowlist (mod)", PLUGIN_NAME);
    api.register_command("unallow", &cmd_unallow, PERM_BAN, "Remove an IPID from the allowlist (mod)", PLUGIN_NAME);
    api.register_command("allowlist", &cmd_allowlist, PERM_BAN, "Show allowlist status (mod)", PLUGIN_NAME);

    io::printfn("[allowlist] Loaded. enabled=%s, %d allowed.", opt_enabled ? "ON" : "off", allow_count);
    if (opt_enabled && allow_count == 0) {
        io::printn("[allowlist] WARNING: enabled with an EMPTY list — every join will be turned away!");
    }
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    io::printn("[allowlist] Unloaded.");
}
