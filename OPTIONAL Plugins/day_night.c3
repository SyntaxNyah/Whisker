// Whisker Optional Plugin — Day/Night Cycle [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Automatically swaps area backgrounds by the real-world clock — a daytime
// courtroom in the morning, a sunset one in the evening, a night one after dark.
// Define as many periods as you like; the plugin switches each configured area's
// background when the clock crosses into a new period. Drop the compiled .dll /
// .so into plugins/ and restart. Optional.
//
// This source file is provided as a learning exercise. To compile a C3 plugin
// yourself, follow the Plugin Dev Guide: plugins/PLUGIN DEV GUIDE README.md
//
// ============================================================
// Configuration — config/day_night.txt (auto-created template)
// ============================================================
//
//   enabled      true
//   utc_offset   0              # hours to add to UTC for your local time (e.g. -5)
//   period  6   gs4-courtroom   # from 06:00, use this background
//   period  18  gs4-courtroom-night
//   area    0                   # apply to area 0 (repeat for more; omit = ALL areas)
//
// The active period is the one with the latest start hour at or before "now"
// (wrapping past midnight). Backgrounds must exist on the client side — this only
// tells the client which background NAME to show.
//
// ============================================================
// Why this is an OPTIONAL plugin — and (almost) zero cost
// ============================================================
//
// Ambient theming is a nicety only some servers want, and it depends on having
// matching day/night backgrounds, so it's opt-in. It uses **no background thread**:
// it rides the CH keepalive (and MS) and only acts when the clock actually crosses
// into a new period (a couple of times a day), comparing two integers per packet.
// Each switch uses the core's `area_set_background` (which stores the change and
// broadcasts it), so a late joiner gets the right background too.

module day_night;

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
extern fn CInt  fputs_c(ZString s, void* stream) @cname("fputs");
extern fn long  time_c(void* t) @cname("time");

const String PLUGIN_NAME = "Day/Night Cycle";
const int MAX_PERIODS = 12;
const int MAX_AREAS   = 128;

PluginAPI* api;
bool opt_enabled = true;
int  opt_utc_offset = 0;

struct Period { int hour; char[64] bg; int bglen; }
Period[MAX_PERIODS] periods;
int period_count;

int[MAX_AREAS] area_list;   // explicit areas, or empty = all
int area_list_count;

int last_applied = -1;

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
fn String pstr(Period* p) { if (p.bglen <= 0) return ""; return (String)p.bg[0..p.bglen - 1]; }

fn int local_hour() {
    long epoch = time_c(null);
    long h = epoch / 3600 + (long)opt_utc_offset;
    h = ((h % 24) + 24) % 24;
    return (int)h;
}

// The active period index for a given hour: the latest start hour <= now,
// wrapping to the latest-of-the-day if none qualifies.
fn int current_period(int hour) {
    if (period_count == 0) return -1;
    int best = -1; int best_hour = -1;
    int latest = 0; int latest_hour = -1;
    for (int i = 0; i < period_count; i++) {
        if (periods[i].hour > latest_hour) { latest_hour = periods[i].hour; latest = i; }
        if (periods[i].hour <= hour && periods[i].hour > best_hour) { best_hour = periods[i].hour; best = i; }
    }
    return best >= 0 ? best : latest;
}

fn void apply_period(int idx) {
    if (idx < 0 || idx >= period_count) return;
    String bg = pstr(&periods[idx]);
    if (bg.len == 0) return;
    if (area_list_count > 0) {
        for (int i = 0; i < area_list_count; i++) {
            int a = area_list[i];
            if (a >= 0 && a < api.get_area_count()) api.area_set_background(a, bg);
        }
    } else {
        int n = api.get_area_count();
        for (int a = 0; a < n; a++) api.area_set_background(a, bg);
    }
}

fn void tick() {
    if (!opt_enabled || period_count == 0) return;
    int idx = current_period(local_hour());
    if (idx != last_applied) {
        last_applied = idx;
        apply_period(idx);
    }
}

// ============================================================
// Hooks (observe only — drive the clock check, never consume)
// ============================================================

fn bool on_packet(void* c, void* pkt) {
    tick();
    return false;
}

// ============================================================
// /daynight status
// ============================================================

fn void cmd_daynight(void* c, String args) {
    if (!opt_enabled) { api.client_send_msg(c, "Day/Night cycle is disabled."); return; }
    if (period_count == 0) { api.client_send_msg(c, "No periods configured."); return; }
    int idx = current_period(local_hour());
    char[160] m; usz n = 0;
    n = put_str(m[..], n, "Current period background: ");
    n = put_str(m[..], n, idx >= 0 ? pstr(&periods[idx]) : "(none)");
    api.client_send_msg(c, (String)m[0..n - 1]);
}

// ============================================================
// Config
// ============================================================

fn void add_period(int hour, String bg) {
    if (period_count >= MAX_PERIODS || bg.len == 0) return;
    if (hour < 0) hour = 0;
    if (hour > 23) hour = 23;
    periods[period_count].hour = hour;
    int n = (int)bg.len; if (n > 63) n = 63;
    for (int i = 0; i < n; i++) periods[period_count].bg[i] = bg[i];
    periods[period_count].bglen = n;
    period_count++;
}

fn int parse_int_signed(String s) {
    int v = 0; bool neg = false; bool have = false;
    foreach (char ch : s) {
        if (ch == '-' && !have) { neg = true; }
        else if (ch >= '0' && ch <= '9') { v = v * 10 + (int)(ch - '0'); have = true; }
    }
    if (!have) return 0;
    return neg ? -v : v;
}

fn void read_config() {
    void* f = fopen_c("config/day_night.txt", "r");
    if (f == null) f = fopen_c("../config/day_night.txt", "r");
    if (f == null) {
        void* w = fopen_c("config/day_night.txt", "w");
        if (w == null) w = fopen_c("../config/day_night.txt", "w");
        if (w != null) {
            fputs_c("# Whisker Day/Night Cycle — auto-swap area backgrounds by the clock.\n", w);
            fputs_c("# '#' starts a comment. Reload needs a restart (state is in-memory).\n", w);
            fputs_c("enabled     true\n", w);
            fputs_c("utc_offset  0       # hours to add to UTC for your local time\n", w);
            fputs_c("# period <hour 0-23> <background-name>  (repeat; backgrounds must exist client-side)\n", w);
            fputs_c("# period 6  gs4-courtroom\n", w);
            fputs_c("# period 18 gs4-courtroom-night\n", w);
            fputs_c("# area <index>   # apply to these areas only (repeat); omit for ALL areas\n", w);
            fclose_c(w);
        }
        io::printn("[day_night] Created config/day_night.txt template (no periods set — inactive).");
        return;
    }
    char[256] line;
    while (fgets_c(&line[0], 256, f) != null) {
        String raw = cstr(&line[0]).trim();
        if (raw.len == 0 || raw[0] == '#') continue;
        usz sp = 0;
        while (sp < raw.len && raw[sp] != ' ' && raw[sp] != '\t') sp++;
        String key = sp == 0 ? raw : raw[0..sp - 1];
        String rest = sp < raw.len ? raw[sp..].trim() : "";

        if (key == "enabled") { opt_enabled = is_true(rest); }
        else if (key == "utc_offset") { opt_utc_offset = parse_int_signed(rest); }
        else if (key == "area") {
            int a = parse_int_signed(rest);
            if (a >= 0 && area_list_count < MAX_AREAS) { area_list[area_list_count] = a; area_list_count++; }
        }
        else if (key == "period") {
            // rest = "<hour> <background>"
            usz s2 = 0;
            while (s2 < rest.len && rest[s2] != ' ' && rest[s2] != '\t') s2++;
            String hs = s2 == 0 ? rest : rest[0..s2 - 1];
            String bg = s2 < rest.len ? rest[s2..].trim() : "";
            add_period(parse_int_signed(hs), bg);
        }
    }
    fclose_c(f);
    io::printfn("[day_night] Config: %d period(s), %d explicit area(s), utc_offset=%d, enabled=%s.",
        period_count, area_list_count, opt_utc_offset, opt_enabled ? "on" : "off");
}

// ============================================================
// Plugin interface (exported)
// ============================================================

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return {
        .name        = "Day/Night Cycle",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Auto-swaps area backgrounds by the real-world clock. Optional.",
    };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    period_count = 0;
    area_list_count = 0;
    last_applied = -1;
    read_config();

    // Drive the clock check off the keepalive (fires even in a quiet room) and IC.
    api.register_hook("CH", &on_packet, PLUGIN_NAME);
    api.register_hook("MS", &on_packet, PLUGIN_NAME);
    api.register_command("daynight", &cmd_daynight, 0, "Show the current day/night background", PLUGIN_NAME);

    io::printn("[day_night] Loaded. /daynight ready.");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    io::printn("[day_night] Unloaded.");
}
