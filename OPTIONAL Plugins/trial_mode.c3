// Whisker Optional Plugin — Trial Mode / Gavel [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// "Court is in session." A CM or moderator can put an area into trial mode, after
// which only the people with the floor — CMs, mods, and players the CM has
// explicitly given the floor — may speak IC. Everyone else's IC is held until
// they're recognised. OOC stays open so silenced players can still ask for the
// floor. It's the missing piece for a controlled cross-examination, an orderly
// witness, or a quiet verdict. Drop the compiled .dll / .so into plugins/ and
// restart. Optional — your server runs fine without it.
//
// This source file is provided as a learning exercise. To compile a C3 plugin
// yourself, follow the Plugin Dev Guide: plugins/PLUGIN DEV GUIDE README.md
//
// ============================================================
// What it does
// ============================================================
//
//   /trial on               start trial mode in this area (CM/mod)
//   /trial off              end it — IC is open again (CM/mod)
//   /trial speak <uid>      give a player the floor (CM/mod)
//   /trial unspeak <uid>    take the floor back (CM/mod)
//   /trial                  show whether court is in session and who has the floor
//
// /gavel is a synonym for /trial. CMs and moderators always have the floor; the
// speak list is for everyone else (the witness, a specific lawyer, …).
//
// ============================================================
// Why this is an OPTIONAL plugin
// ============================================================
//
//   * It only makes sense for structured courtroom play — a formal trial, a
//     scripted cross-examination, a moment where one witness should hold the
//     room. On a casual or social server, silencing everyone but a chosen few is
//     exactly the wrong default.
//   * Pairs with `casing` (testimony / WT-CE) and `court_timer` (a visible clock)
//     to make a full trial kit — but a server that runs none of those has no use
//     for a gavel. So it's opt-in: add it if you run trials, skip it otherwise.
//
// ============================================================
// How it works (implementation notes)
// ============================================================
//
// This is a *soft* IC gate, NOT the core mute. While an area is in session, the
// MS (IC) packet hook consumes the message of anyone who isn't a mod, a CM of the
// area, or on that area's speak list, and tells them they're not recognised — it
// returns true (consume) for them and false (pass through) for everyone with the
// floor. Deliberately NOT client_mute: that would clobber the core's real mute
// state (un-muting someone a mod had separately muted on release), and it would
// need a roster to re-apply on join. Gating at the packet means there's no mute
// to track and nothing to undo — turning trial mode off instantly reopens IC.
// State is per-area, lockless, and allocation-free; there is no thread.
//
// Note: state lives only in this plugin, so a /reload clears it — every area
// falls back to "open" (fail-open). Re-run /trial on after a reload if a trial
// was in progress.

module trial_mode;

import std::io;

// ============================================================
// Whisker plugin interface (standalone definitions)
// Must match src/plugin.c3 PluginAPI exactly, field-for-field, in order.
// Copied from an up-to-date optional plugin (poll.c3) — through the v6 tail.
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

// ============================================================
// C interop (config file)
// ============================================================

extern fn void* fopen_c(ZString path, ZString mode) @cname("fopen");
extern fn char* fgets_c(char* buf, CInt size, void* stream) @cname("fgets");
extern fn CInt  fclose_c(void* stream) @cname("fclose");

// ============================================================
// Constants
// ============================================================

const String PLUGIN_NAME = "Trial Mode";
const int MAX_AREAS    = 128;
const int MAX_SPEAKERS = 16;   // designated non-CM speakers per area

// ============================================================
// Options (config.toml [trial_mode])
// ============================================================

PluginAPI* api;

bool opt_announce = true;        // post a notice to the area on session start/end
char[200] cfg_message;           // notice shown to a silenced player

// ============================================================
// Per-area state (lockless POD)
// ============================================================

struct Court {
    bool active;
    int[MAX_SPEAKERS] speakers;
    int speaker_count;
}
Court[MAX_AREAS] court;

fn bool is_speaker(int area, int uid) {
    Court* ct = &court[area];
    for (int i = 0; i < ct.speaker_count; i++) { if (ct.speakers[i] == uid) return true; }
    return false;
}

fn bool add_speaker(int area, int uid) {
    Court* ct = &court[area];
    if (is_speaker(area, uid)) return true;
    if (ct.speaker_count >= MAX_SPEAKERS) return false;
    ct.speakers[ct.speaker_count] = uid;
    ct.speaker_count++;
    return true;
}

fn bool remove_speaker(int area, int uid) {
    Court* ct = &court[area];
    for (int i = 0; i < ct.speaker_count; i++) {
        if (ct.speakers[i] == uid) {
            ct.speakers[i] = ct.speakers[ct.speaker_count - 1];
            ct.speaker_count--;
            return true;
        }
    }
    return false;
}

// ============================================================
// Allocation-free helpers
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

fn usz put_escaped(char[] buf, usz n, String s) {
    foreach (char ch : s) {
        switch (ch) {
            case '#': n = put_str(buf, n, "<num>");
            case '&': n = put_str(buf, n, "<and>");
            case '%': n = put_str(buf, n, "<percent>");
            case '$': n = put_str(buf, n, "<dollar>");
            default:  if (n < buf.len) { buf[n] = ch; n++; }
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

fn void copy_str(String src, char* dst, usz max) {
    usz i = 0;
    while (i < src.len && i < max) { dst[i] = src[i]; i++; }
    dst[i] = 0;
}

fn String silenced_message() {
    String m = cstr(&cfg_message[0]);
    if (m.len == 0) return "Court is in session — you don't have the floor. Ask a CM in OOC to /trial speak you.";
    return m;
}

// Post a plain OOC line to the area (built + escaped on the stack).
fn void area_notice(int area, String text) {
    if (!opt_announce) return;
    char[300] b;
    usz n = 0;
    n = put_str(b[..], n, "CT#");
    n = put_escaped(b[..], n, PLUGIN_NAME);
    n = put_str(b[..], n, "#");
    n = put_escaped(b[..], n, text);
    n = put_str(b[..], n, "#1#%");
    api.broadcast_area_raw(area, (String)b[0..n - 1]);
}

fn bool can_manage(void* c, int area) {
    if (api.client_is_mod(c)) return true;
    return api.area_is_cm(area, api.client_get_uid(c));
}

// ============================================================
// MS (IC) gate — the heart of the plugin
// ============================================================

fn bool on_ic(void* c, void* pkt) {
    int area = api.client_get_area(c);
    if (area < 0 || area >= MAX_AREAS) return false;
    if (!court[area].active) return false;

    // Has the floor? Mods and CMs always do; others must be on the speak list.
    if (api.client_is_mod(c)) return false;
    int uid = api.client_get_uid(c);
    if (api.area_is_cm(area, uid)) return false;
    if (is_speaker(area, uid)) return false;

    // Not recognised — hold the IC line.
    api.client_send_msg(c, silenced_message());
    return true; // consume
}

// ============================================================
// /trial command
// ============================================================

fn void show_status(void* c, int area) {
    Court* ct = &court[area];
    if (!ct.active) {
        api.client_send_msg(c, "Court is adjourned — IC is open. A CM can start a trial with /trial on.");
        return;
    }
    char[300] m;
    usz n = 0;
    n = put_str(m[..], n, "Court is IN SESSION. Floor (besides CMs/mods): ");
    if (ct.speaker_count == 0) {
        n = put_str(m[..], n, "nobody yet");
    } else {
        for (int i = 0; i < ct.speaker_count; i++) {
            if (i > 0) n = put_str(m[..], n, ", ");
            n = put_str(m[..], n, "UID ");
            n = put_int(m[..], n, ct.speakers[i]);
        }
    }
    n = put_str(m[..], n, ".");
    api.client_send_msg(c, (String)m[0..n - 1]);
}

fn void do_grant(void* c, int area, int uid, bool grant) {
    void* t = api.find_client(uid);
    if (t == null) { api.client_send_msg(c, "No player with that UID is online."); return; }
    if (api.client_get_area(t) != area) { api.client_send_msg(c, "That player isn't in this area."); return; }

    if (grant) {
        if (!add_speaker(area, uid)) { api.client_send_msg(c, "The floor is full (max speakers reached)."); return; }
        api.client_send_msg(t, "You have been given the floor — you may speak IC.");
        char[160] m; usz n = 0;
        n = put_str(m[..], n, "Gave the floor to ");
        n = put_str(m[..], n, api.client_display_name(t));
        n = put_str(m[..], n, ".");
        api.client_send_msg(c, (String)m[0..n - 1]);
    } else {
        if (!remove_speaker(area, uid)) { api.client_send_msg(c, "That player didn't have the floor."); return; }
        api.client_send_msg(t, "Your floor has been withdrawn — IC is held until you're recognised again.");
        char[160] m; usz n = 0;
        n = put_str(m[..], n, "Took the floor back from ");
        n = put_str(m[..], n, api.client_display_name(t));
        n = put_str(m[..], n, ".");
        api.client_send_msg(c, (String)m[0..n - 1]);
    }
}

fn void cmd_trial(void* c, String args) {
    int area = api.client_get_area(c);
    if (area < 0 || area >= MAX_AREAS) { api.client_send_msg(c, "Trial mode isn't available in this area."); return; }

    String[3] argv;
    int n = api.args_split(args, &argv[0], 3);

    if (n == 0) { show_status(c, area); return; }

    char[16] lc;
    int lcn = api.to_lower(argv[0], &lc[0], 16);
    String sub = lcn > 0 ? (String)lc[0..lcn - 1] : "";

    if (sub == "status") { show_status(c, area); return; }

    // Everything else mutates the session -> CM/mod only.
    if (!can_manage(c, area)) {
        api.client_send_msg(c, "Only a CM or moderator can run the trial.");
        return;
    }

    Court* ct = &court[area];

    if (sub == "on" || sub == "start") {
        ct.active = true;
        ct.speaker_count = 0;
        area_notice(area, "Court is now in session. Only the floor may speak IC; ask a CM in OOC for the floor.");
        api.client_send_msg(c, "Trial mode ON for this area.");
        return;
    }
    if (sub == "off" || sub == "end" || sub == "adjourn") {
        ct.active = false;
        ct.speaker_count = 0;
        area_notice(area, "Court is adjourned. IC is open again.");
        api.client_send_msg(c, "Trial mode OFF for this area.");
        return;
    }
    if (sub == "speak" || sub == "grant" || sub == "add") {
        if (n < 2) { api.client_send_msg(c, "Usage: /trial speak <uid>"); return; }
        int uid = argv[1].to_int() ?? -1;
        if (uid < 0) { api.client_send_msg(c, "Invalid UID."); return; }
        do_grant(c, area, uid, true);
        return;
    }
    if (sub == "unspeak" || sub == "revoke" || sub == "remove") {
        if (n < 2) { api.client_send_msg(c, "Usage: /trial unspeak <uid>"); return; }
        int uid = argv[1].to_int() ?? -1;
        if (uid < 0) { api.client_send_msg(c, "Invalid UID."); return; }
        do_grant(c, area, uid, false);
        return;
    }

    api.client_send_msg(c, "Usage: /trial on | off | speak <uid> | unspeak <uid> | status");
}

// ============================================================
// Config (config.toml [trial_mode])
// ============================================================

fn bool is_true(String s) { return s == "true" || s == "1" || s == "yes" || s == "on"; }

fn void read_config() {
    void* f = fopen_c("config/config.toml", "r");
    if (f == null) f = fopen_c("../config/config.toml", "r");
    if (f == null) { io::printn("[trial_mode] No config.toml found, using defaults."); return; }

    char[512] line;
    bool in_section = false;
    while (fgets_c(&line[0], 512, f) != null) {
        String raw = cstr(&line[0]).trim();
        if (raw.len == 0 || raw[0] == '#') continue;
        if (raw[0] == '[') { in_section = (raw == "[trial_mode]"); continue; }
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

        if (key == "announce")      { opt_announce = is_true(val); }
        else if (key == "message")  { if (val.len > 0) copy_str(val, &cfg_message[0], 199); }
    }
    fclose_c(f);
    io::printn("[trial_mode] Config loaded from config.toml.");
}

// ============================================================
// Plugin interface (exported)
// ============================================================

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return {
        .name        = "Trial Mode",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Court-in-session IC lockdown — only the floor may speak. Optional — see header.",
    };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    for (int i = 0; i < MAX_AREAS; i++) { court[i].active = false; court[i].speaker_count = 0; }
    cfg_message[0] = 0;

    read_config();

    api.register_hook("MS", &on_ic, PLUGIN_NAME);
    api.register_command("trial", &cmd_trial, 0,
        "Court-in-session IC gate: /trial on|off|speak <uid>|unspeak <uid>|status", PLUGIN_NAME);
    api.register_command("gavel", &cmd_trial, 0, "Alias for /trial", PLUGIN_NAME);

    io::printfn("[trial_mode] Loaded. /trial (and /gavel) ready (announce=%s).",
        opt_announce ? "on" : "off");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    io::printn("[trial_mode] Unloaded.");
}
