// Whisker Optional Plugin — Penalty Bars [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Command-driven control of the courtroom **health / penalty bars** (the two
// 10-segment bars the judge uses to dock the defense or prosecution). A CM or
// moderator can set a bar to an exact value, dock a single penalty, or lock the
// bars so only staff can move them. Drop the compiled .dll / .so into plugins/
// and restart. Optional — your server runs fine without it.
//
// This source file is provided as a learning exercise. To compile a C3 plugin
// yourself, follow the Plugin Dev Guide: plugins/PLUGIN DEV GUIDE README.md
//
// ============================================================
// What it does
// ============================================================
//
//   /hp                 show both penalty bars (anyone)
//   /hp def <0-10>      set the defense bar      (CM/mod)
//   /hp pro <0-10>      set the prosecution bar  (CM/mod)
//   /penalty def        dock one off the defense bar     (CM/mod)
//   /penalty pro        dock one off the prosecution bar (CM/mod)
//
// With `lock = true` (config), a player who isn't a CM/mod can't move the bars at
// all — useful because the core lets ANY client drag them, which trolls abuse.
//
// ============================================================
// Why this is an OPTIONAL plugin
// ============================================================
//
//   * The bars only mean anything in casing / trial play — a witness penalty, a
//     wrong-answer dock, a "you're out of chances" verdict. Social and freeform
//     servers never touch them, so command control over them is pure noise there.
//   * Pairs with `casing` (which only *logs* bar changes today) and `court_timer`
//     to round out a trial kit. Opt-in: add it on a casing server, skip it
//     everywhere else.
//
// ============================================================
// How it works (implementation notes) — and one honest limit
// ============================================================
//
// Setting a bar emits the AO2 `HP` packet (`HP#bar#value#%`, bar 1 = defense,
// 2 = prosecution, value 0-10) to the area with broadcast_area_raw. The plugin
// also hooks `HP` to keep a per-area cache of the current values in sync with
// normal client-driven changes (so /hp and /penalty stay accurate), and — when
// `lock` is on — to consume bar changes from non-staff. Everything is
// allocation-free; there is no thread.
//
// ⚠️ Late-joiner caveat: the core stores each area's authoritative bar values
// (area.defense_hp / prosecution_hp) and replays them to a client when it joins.
// There is no Plugin-API setter for that stored value, so a bar this plugin sets
// by command updates the live display for everyone PRESENT but not the core's
// stored copy — a player who joins immediately afterwards (before any client
// touches a bar) sees the core's older value until the next change. In normal
// trial play the judge's own client keeps moving the bars (which the core does
// store), so this only shows up in the gap right after a command. It's a display
// nicety, not authoritative state — see the Plugin Dev Guide note on emitting
// packets whose state the core owns. A /reload likewise resets the cache to 10/10
// until the next observed `HP`.

module penalty_bars;

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
// Constants (mirror config::PENALTY_BAR_* in the server)
// ============================================================

const String PLUGIN_NAME = "Penalty Bars";
const int MAX_AREAS      = 128;
const int BAR_DEFENSE     = 1;
const int BAR_PROSECUTION = 2;
const int HP_MIN          = 0;
const int HP_MAX          = 10;

// ============================================================
// Options (config.toml [penalty_bars])
// ============================================================

PluginAPI* api;

bool opt_lock     = false;   // only CM/mod may move the bars (anti-grief)
bool opt_announce = true;    // post an OOC line to the area on a command change

// ============================================================
// Per-area cache of the current bar values (best-effort, see header)
// ============================================================

int[MAX_AREAS] def_hp;
int[MAX_AREAS] pro_hp;

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

fn String side_name(int bar) { return bar == BAR_DEFENSE ? "Defense" : "Prosecution"; }

fn int side_to_bar(String s) {
    if (s == "def" || s == "defense" || s == "d") return BAR_DEFENSE;
    if (s == "pro" || s == "prosecution" || s == "p") return BAR_PROSECUTION;
    return 0;
}

fn bool can_manage(void* c, int area) {
    if (api.client_is_mod(c)) return true;
    return api.area_is_cm(area, api.client_get_uid(c));
}

// Broadcast a plain OOC line to the area (built + escaped on the stack).
fn void area_notice(int area, String text) {
    char[300] b;
    usz n = 0;
    n = put_str(b[..], n, "CT#");
    n = put_escaped(b[..], n, PLUGIN_NAME);
    n = put_str(b[..], n, "#");
    n = put_escaped(b[..], n, text);
    n = put_str(b[..], n, "#1#%");
    api.broadcast_area_raw(area, (String)b[0..n - 1]);
}

// Report a change: to the whole area if announce is on, else just to the actor.
fn void report(void* c, int area, String text) {
    if (opt_announce) { area_notice(area, text); }
    else { api.client_send_msg(c, text); }
}

// ============================================================
// Setting a bar — emit HP + update the cache
// ============================================================

fn void set_bar(int area, int bar, int value) {
    if (value < HP_MIN) value = HP_MIN;
    if (value > HP_MAX) value = HP_MAX;
    if (bar == BAR_DEFENSE) { def_hp[area] = value; } else { pro_hp[area] = value; }

    char[32] b;
    usz n = 0;
    n = put_str(b[..], n, "HP#");
    n = put_int(b[..], n, bar);
    n = put_str(b[..], n, "#");
    n = put_int(b[..], n, value);
    n = put_str(b[..], n, "#%");
    api.broadcast_area_raw(area, (String)b[0..n - 1]);
}

// ============================================================
// HP hook: keep the cache in sync, and (if locked) block non-staff changes
// ============================================================

fn bool on_hp(void* c, void* pkt) {
    int area = api.client_get_area(c);
    if (area < 0 || area >= MAX_AREAS) return false;
    if (api.packet_get_field_count(pkt) < 2) return false;

    if (opt_lock && !can_manage(c, area)) {
        api.client_send_msg(c, "The penalty bars are locked to CMs/moderators here.");
        return true; // block the change
    }

    int bar = api.packet_get_field(pkt, 0).to_int() ?? 0;
    int val = api.packet_get_field(pkt, 1).to_int() ?? -1;
    if (val >= HP_MIN && val <= HP_MAX) {
        if (bar == BAR_DEFENSE) { def_hp[area] = val; }
        else if (bar == BAR_PROSECUTION) { pro_hp[area] = val; }
    }
    return false; // observe only — let the core update + broadcast normally
}

// ============================================================
// Commands
// ============================================================

fn void show_hp(void* c, int area) {
    char[160] m;
    usz n = 0;
    n = put_str(m[..], n, "Penalty bars — Defense: ");
    n = put_int(m[..], n, def_hp[area]);
    n = put_str(m[..], n, "/10, Prosecution: ");
    n = put_int(m[..], n, pro_hp[area]);
    n = put_str(m[..], n, "/10.");
    api.client_send_msg(c, (String)m[0..n - 1]);
}

fn void cmd_hp(void* c, String args) {
    int area = api.client_get_area(c);
    if (area < 0 || area >= MAX_AREAS) { api.client_send_msg(c, "Penalty bars aren't available in this area."); return; }

    String[3] argv;
    int n = api.args_split(args, &argv[0], 3);
    if (n == 0) { show_hp(c, area); return; }

    char[16] lc;
    int lcn = api.to_lower(argv[0], &lc[0], 16);
    int bar = side_to_bar(lcn > 0 ? (String)lc[0..lcn - 1] : "");
    if (bar == 0) { api.client_send_msg(c, "Usage: /hp  (show)  |  /hp def|pro <0-10>  (set)"); return; }

    // Side only, no value -> just show the bars.
    if (n < 2) { show_hp(c, area); return; }

    if (!can_manage(c, area)) { api.client_send_msg(c, "Only a CM or moderator can change the penalty bars."); return; }

    int v = argv[1].to_int() ?? -1;
    if (v < HP_MIN || v > HP_MAX) { api.client_send_msg(c, "Value must be between 0 and 10."); return; }

    set_bar(area, bar, v);

    char[200] m;
    usz mn = 0;
    mn = put_str(m[..], mn, side_name(bar));
    mn = put_str(m[..], mn, " bar set to ");
    mn = put_int(m[..], mn, v);
    mn = put_str(m[..], mn, "/10 (by ");
    mn = put_str(m[..], mn, api.client_display_name(c));
    mn = put_str(m[..], mn, ").");
    report(c, area, (String)m[0..mn - 1]);
}

fn void cmd_penalty(void* c, String args) {
    int area = api.client_get_area(c);
    if (area < 0 || area >= MAX_AREAS) { api.client_send_msg(c, "Penalty bars aren't available in this area."); return; }

    String[2] argv;
    int n = api.args_split(args, &argv[0], 2);
    if (n == 0) { api.client_send_msg(c, "Usage: /penalty def|pro  (docks one off that bar)"); return; }

    char[16] lc;
    int lcn = api.to_lower(argv[0], &lc[0], 16);
    int bar = side_to_bar(lcn > 0 ? (String)lc[0..lcn - 1] : "");
    if (bar == 0) { api.client_send_msg(c, "Usage: /penalty def|pro"); return; }

    if (!can_manage(c, area)) { api.client_send_msg(c, "Only a CM or moderator can dock a penalty."); return; }

    int cur = (bar == BAR_DEFENSE) ? def_hp[area] : pro_hp[area];
    int v = cur - 1;
    if (v < HP_MIN) v = HP_MIN;
    set_bar(area, bar, v);

    char[200] m;
    usz mn = 0;
    mn = put_str(m[..], mn, side_name(bar));
    mn = put_str(m[..], mn, " penalty! ");
    mn = put_str(m[..], mn, api.client_display_name(c));
    mn = put_str(m[..], mn, " docked a bar — now ");
    mn = put_int(m[..], mn, v);
    mn = put_str(m[..], mn, "/10.");
    report(c, area, (String)m[0..mn - 1]);
}

// ============================================================
// Config (config.toml [penalty_bars])
// ============================================================

fn bool is_true(String s) { return s == "true" || s == "1" || s == "yes" || s == "on"; }

fn void read_config() {
    void* f = fopen_c("config/config.toml", "r");
    if (f == null) f = fopen_c("../config/config.toml", "r");
    if (f == null) { io::printn("[penalty_bars] No config.toml found, using defaults."); return; }

    char[512] line;
    bool in_section = false;
    while (fgets_c(&line[0], 512, f) != null) {
        String raw = cstr(&line[0]).trim();
        if (raw.len == 0 || raw[0] == '#') continue;
        if (raw[0] == '[') { in_section = (raw == "[penalty_bars]"); continue; }
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

        if (key == "lock")          { opt_lock = is_true(val); }
        else if (key == "announce") { opt_announce = is_true(val); }
    }
    fclose_c(f);
    io::printn("[penalty_bars] Config loaded from config.toml.");
}

// ============================================================
// Plugin interface (exported)
// ============================================================

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return {
        .name        = "Penalty Bars",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Command control + optional lock for the courtroom penalty bars. Optional — see header.",
    };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    for (int i = 0; i < MAX_AREAS; i++) { def_hp[i] = HP_MAX; pro_hp[i] = HP_MAX; }

    read_config();

    api.register_hook("HP", &on_hp, PLUGIN_NAME);
    api.register_command("hp", &cmd_hp, 0,
        "Penalty bars: /hp (show) | /hp def|pro <0-10> (set, CM/mod)", PLUGIN_NAME);
    api.register_command("penalty", &cmd_penalty, 0,
        "Dock one off a penalty bar: /penalty def|pro (CM/mod)", PLUGIN_NAME);

    io::printfn("[penalty_bars] Loaded. /hp + /penalty ready (lock=%s, announce=%s).",
        opt_lock ? "on" : "off", opt_announce ? "on" : "off");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    io::printn("[penalty_bars] Unloaded.");
}
