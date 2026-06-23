// Whisker Optional Plugin — Connection Cap [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Limits how many concurrent client SESSIONS one IP address may have. New
// connections from an address already at the cap are rejected at accept time
// (the ip_guard pattern), before they cost a thread. Optional — drop the
// .dll/.so into plugins/ and restart.
//
// Standalone plugin: see the Plugin Dev Guide (plugins/PLUGIN DEV GUIDE README.md).

module conn_cap;

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

const String PLUGIN_NAME = "Connection Cap";
const ulong PERM_BAN = 4;
const int EVENT_JOIN = 0;
const int EVENT_LEAVE = 1;
const int MAX_IPS = 4096;

struct IpCount { bool used; char[48] ip; int count; }
IpCount[MAX_IPS] table;

PluginAPI* api;
bool  opt_enabled = true;
int   opt_max     = 3;   // max concurrent sessions per IP
ulong rejected    = 0;

fn usz put_str(char[] buf, usz n, String s) {
    foreach (char ch : s) { if (n >= buf.len) break; buf[n] = ch; n++; }
    return n;
}
fn String cstr(char* buf) { int l = 0; while (buf[l] != 0) l++; return l == 0 ? "" : (String)buf[0..l - 1]; }
fn void copy_cstr(String src, char* dst, usz max) {
    usz i = 0; while (i < src.len && i < max) { dst[i] = src[i]; i++; } dst[i] = 0;
}
fn bool is_true(String s) { return s == "true" || s == "1" || s == "yes" || s == "on"; }
fn ulong parse_ulong(String s) {
    ulong v = 0; foreach (char ch : s) { if (ch >= '0' && ch <= '9') v = v * 10 + (ulong)(ch - '0'); } return v;
}

fn IpCount* find_ip(String ip) {
    for (int i = 0; i < MAX_IPS; i++) {
        if (table[i].used && cstr(&table[i].ip[0]) == ip) return &table[i];
    }
    return null;
}
fn IpCount* find_or_add(String ip) {
    IpCount* e = find_ip(ip);
    if (e != null) return e;
    for (int i = 0; i < MAX_IPS; i++) {
        if (!table[i].used) { table[i].used = true; copy_cstr(ip, &table[i].ip[0], 47); table[i].count = 0; return &table[i]; }
    }
    return null;
}

// Accept-thread filter: reject if this IP already holds the cap. Allocation-free.
fn bool conn_filter(String ip) {
    if (!opt_enabled) return false;
    if (ip.len == 0 || ip == "unknown") return false; // can't attribute → allow
    IpCount* e = find_ip(ip);
    if (e != null && e.count >= opt_max) { rejected++; return true; }
    return false;
}

// Count concurrent JOINED sessions per IP (reliable: a join always pairs with a
// leave). Clamp at 0 on decrement — a /reload zeroes the table, so in-flight
// LEAVEs would otherwise underflow.
fn void on_life(void* c, int ev) {
    if (!opt_enabled) return;
    String ip = api.client_get_ip(c);
    if (ip.len == 0 || ip == "unknown") return;
    if (ev == EVENT_JOIN) {
        IpCount* e = find_or_add(ip);
        if (e != null) e.count++;
    } else if (ev == EVENT_LEAVE) {
        IpCount* e = find_ip(ip);
        if (e != null && e.count > 0) e.count--;
    }
}

fn void cmd_capstatus(void* c, String args) {
    int active = 0;
    for (int i = 0; i < MAX_IPS; i++) { if (table[i].used && table[i].count > 0) active++; }
    api.client_send_msg(c, string::tformat("Connection Cap: max %d session(s) per IP. Active IPs: %d. Rejected so far: %d. (%s)",
        opt_max, active, (int)rejected, opt_enabled ? "on" : "off"));
}
fn void w_capstatus(void* c, String a) { @pool_init(mem, 64 * 1024) { cmd_capstatus(c, a); }; }

extern fn void* fopen_c(ZString path, ZString mode) @cname("fopen");
extern fn char* fgets_c(char* buf, CInt size, void* stream) @cname("fgets");
extern fn CInt  fclose_c(void* stream) @cname("fclose");

fn void load_config(ZString path) {
    void* f = fopen_c(path, "r");
    if (f == null) return;
    char[512] line; int section = 0;
    while (fgets_c(&line[0], 512, f) != null) {
        String raw = cstr(&line[0]).trim();
        if (raw.len == 0 || raw[0] == '#') continue;
        if (raw[0] == '[') { section = (raw == "[conn_cap]") ? 1 : 0; continue; }
        if (section != 1) continue;
        usz eq = 0; while (eq < raw.len && raw[eq] != '=') eq++;
        if (eq >= raw.len) continue;
        String k = raw[0..eq - 1].trim();
        String v = raw[eq + 1..].trim();
        if (k == "enabled")     { opt_enabled = is_true(v); }
        else if (k == "max_per_ip") { int x = (int)parse_ulong(v); if (x > 0) opt_max = x; }
    }
    fclose_c(f);
}

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return { "Connection Cap", "1.0.0", "Whisker Community", "Cap concurrent sessions per IP. Optional." };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    for (int i = 0; i < MAX_IPS; i++) table[i].used = false;
    void* probe = fopen_c("config/config.toml", "r");
    if (probe != null) { fclose_c(probe); load_config("config/config.toml"); }
    else { load_config("../config/config.toml"); }
    api.register_conn_filter(&conn_filter, PLUGIN_NAME);
    api.register_lifecycle_hook(&on_life, PLUGIN_NAME);
    api.register_command("capstatus", &w_capstatus, PERM_BAN, "Show connection-cap status", PLUGIN_NAME);
    io::printfn("[conn_cap] Loaded (max %d session(s) per IP).", opt_max);
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    io::printn("[conn_cap] Shutting down.");
}
