// Whisker Optional Plugin — Objection-Spam Guard [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Rate-limits courtroom shouts — OBJECTION! / HOLD IT! / TAKE THAT! and custom
// interjections. Spamming the objection button is one of the most disruptive
// things a troll can do (the shout animation + sting cuts over everyone), and
// it's also just *annoying*. This holds a player who fires too many shouts in a
// short window; ordinary dialogue (no shout) is never touched. Drop the compiled
// .dll / .so into plugins/ and restart. Optional.
//
// This source file is provided as a learning exercise. To compile a C3 plugin
// yourself, follow the Plugin Dev Guide: plugins/PLUGIN DEV GUIDE README.md
//
// ============================================================
// Configuration — config/config.toml [objection_guard]
// ============================================================
//
//   enabled          true   master switch
//   max_shouts       3      shouts allowed within the window
//   window_seconds   10     the sliding window
//   exempt_mods      true   moderators bypass the limit
//
// ============================================================
// Why this is an OPTIONAL plugin — and (almost) zero cost
// ============================================================
//
// Shouts are a normal, fun part of AO — most of the time you WANT them, so a cap
// is opt-in (it's a relief valve for when someone abuses it, exactly as you noted
// it "can annoy people"). The hook reads one field of the `MS` packet and returns
// instantly for any message that carries no shout (`shout_mod` 0/empty), so
// normal IC chat pays only a single integer comparison; the rate check is an O(1)
// table lookup, allocation-free.
//
// Note: a held shout consumes the whole IC message it rode in on (a shout and its
// line are one `MS` packet — there is no way to drop just the animation without
// rebuilding the packet and losing pairing; see the Plugin Dev Guide). So the
// guard only ever drops the *spammy shout* messages, never plain dialogue.

module objection_guard;

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
extern fn long  time_c(void* t) @cname("time");

const String PLUGIN_NAME = "Objection-Spam Guard";
const int MAX_TRACK = 512;
const int SHOUT_FIELD = 10;   // MS field 10 = shout_mod (see handle_ms)

PluginAPI* api;

bool opt_enabled     = true;
int  opt_max         = 3;
int  opt_window      = 10;
bool opt_exempt_mods = true;

// ============================================================
// Sliding-window limiter (per uid)
// ============================================================

struct Track { bool used; int uid; long window_start; int count; }
Track[MAX_TRACK] tracks;

fn Track* get_track(int uid, long now) {
    Track* reuse = null;
    for (int i = 0; i < MAX_TRACK; i++) {
        if (tracks[i].used && tracks[i].uid == uid) return &tracks[i];
        if (reuse == null) {
            if (!tracks[i].used) { reuse = &tracks[i]; }
            else if (now - tracks[i].window_start > (long)opt_window) { reuse = &tracks[i]; }
        }
    }
    if (reuse != null) {
        reuse.used = true; reuse.uid = uid; reuse.window_start = now; reuse.count = 0;
        return reuse;
    }
    return null;
}

fn bool over_limit(int uid) {
    long now = time_c(null);
    Track* t = get_track(uid, now);
    if (t == null) return false;
    if (now - t.window_start >= (long)opt_window) { t.window_start = now; t.count = 0; }
    t.count++;
    return t.count > opt_max;
}

// ============================================================
// MS hook — only counts messages that carry a shout
// ============================================================

fn bool on_ms(void* c, void* pkt) {
    if (!opt_enabled) return false;
    if (api.packet_get_field_count(pkt) <= SHOUT_FIELD) return false;

    String shout = api.packet_get_field(pkt, SHOUT_FIELD);
    if (shout.len == 0 || shout == "0") return false; // no objection — ignore

    if (opt_exempt_mods && api.client_is_mod(c)) return false;
    int uid = api.client_get_uid(c);
    if (uid < 0) return false;

    if (over_limit(uid)) {
        api.client_send_msg(c, "Easy on the objections — you're shouting too fast.");
        return true; // consume the shouting message
    }
    return false;
}

// ============================================================
// Config
// ============================================================

fn bool is_true(String s) { return s == "true" || s == "1" || s == "yes" || s == "on"; }
fn int parse_uint(String s) {
    int v = 0;
    foreach (char ch : s) { if (ch >= '0' && ch <= '9') v = v * 10 + (int)(ch - '0'); }
    return v;
}
fn String cstr(char* buf) {
    int len = 0;
    while (buf[len] != 0) len++;
    if (len == 0) return "";
    return (String)buf[0..len - 1];
}

fn void read_config() {
    void* f = fopen_c("config/config.toml", "r");
    if (f == null) f = fopen_c("../config/config.toml", "r");
    if (f == null) { io::printn("[objection_guard] No config.toml found, using defaults."); return; }
    char[512] line;
    bool in_section = false;
    while (fgets_c(&line[0], 512, f) != null) {
        String raw = cstr(&line[0]).trim();
        if (raw.len == 0 || raw[0] == '#') continue;
        if (raw[0] == '[') { in_section = (raw == "[objection_guard]"); continue; }
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
        if (key == "enabled")             { opt_enabled = is_true(val); }
        else if (key == "max_shouts")     { int v = parse_uint(val); if (v > 0) opt_max = v; }
        else if (key == "window_seconds") { int v = parse_uint(val); if (v > 0) opt_window = v; }
        else if (key == "exempt_mods")    { opt_exempt_mods = is_true(val); }
    }
    fclose_c(f);
    io::printn("[objection_guard] Config loaded from config.toml.");
}

// ============================================================
// Plugin interface (exported)
// ============================================================

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return {
        .name        = "Objection-Spam Guard",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Rate-limits courtroom shouts/objections. Optional.",
    };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    for (int i = 0; i < MAX_TRACK; i++) tracks[i].used = false;
    read_config();
    api.register_hook("MS", &on_ms, PLUGIN_NAME);
    io::printfn("[objection_guard] Loaded. enabled=%s max=%d/%ds exempt_mods=%s",
        opt_enabled ? "on" : "off", opt_max, opt_window, opt_exempt_mods ? "y" : "n");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    io::printn("[objection_guard] Unloaded.");
}
