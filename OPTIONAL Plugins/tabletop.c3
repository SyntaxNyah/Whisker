// Whisker Optional Plugin — Tabletop [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Tabletop / DnD helpers that build on the `roll` plugin: a per-area initiative
// tracker for combat order, ability-score generation, and advantage /
// disadvantage d20 rolls. Drop the compiled .dll / .so into plugins/ and restart.
// Optional — your server runs fine without it.
//
// This source file is provided as a learning exercise. To compile a C3 plugin
// yourself, follow the Plugin Dev Guide: plugins/PLUGIN DEV GUIDE README.md
//
// ============================================================
// What it does
// ============================================================
//
//   /initadd <name> [value]   add a combatant (rolls d20 if no value given)
//   /init                     show the current initiative order
//   /next                     advance to the next combatant's turn
//   /initremove <name>        remove a combatant
//   /initclear                clear the encounter
//   /statroll                 roll ability scores (4d6 drop lowest, ×6)
//   /adv [mod]                roll a d20 with ADVANTAGE  (best of two, +mod)
//   /dis [mod]                roll a d20 with DISADVANTAGE (worst of two, +mod)
//
// Everything is shown to the area so the table can follow along.
//
// ============================================================
// Why this is an OPTIONAL plugin — and zero passive cost
// ============================================================
//
// Like `roll`, these are gameplay tools, not protocol — only a tabletop / DnD
// server wants them, so they're opt-in. The plugin registers **commands only and
// no packet hooks**, so it costs nothing until a command is typed; it never sees
// the IC/OOC hot path. Pair it with `roll` for general dice.

module tabletop;

import std::io;

// ============================================================
// Whisker plugin interface (standalone definitions) — v4 prefix (from roll.c3).
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

const String PLUGIN_NAME = "Tabletop";
const int MAX_AREAS  = 128;
const int MAX_COMBAT = 24;     // combatants per encounter
const int NAME_CAP   = 28;

PluginAPI* api;

// ============================================================
// PRNG — xorshift64, same as roll.c3.
// ============================================================

ulong rng_state = 0x9E3779B97F4A7C15;
extern fn long time_c(void* t) @cname("time");

fn ulong next_rand() {
    ulong x = rng_state;
    x ^= x << 13; x ^= x >> 7; x ^= x << 17;
    rng_state = x;
    return x;
}
fn int roll_die(int sides) {
    if (sides <= 1) return 1;
    return 1 + (int)(next_rand() % (ulong)sides);
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
fn void copy_n(char* dst, String s, int max, int* outlen) {
    int n = (int)s.len; if (n > max) n = max;
    for (int i = 0; i < n; i++) dst[i] = s[i];
    *outlen = n;
}

// ============================================================
// Per-area initiative tracker, kept sorted descending by init.
// ============================================================

struct Combatant {
    bool used;
    char[NAME_CAP] name;
    int  namelen;
    int  init;
}
struct Tracker {
    Combatant[MAX_COMBAT] list;
    int count;
    int turn;   // index of whose turn it is; -1 = encounter not started
}
Tracker[MAX_AREAS] track;

fn String cname(Combatant* cm) {
    if (cm.namelen <= 0) return "?";
    return (String)cm.name[0..cm.namelen - 1];
}

// Insert keeping the list sorted highest-init-first (ties keep insertion order).
fn bool add_combatant(int area, String name, int init) {
    Tracker* t = &track[area];
    if (t.count >= MAX_COMBAT) return false;
    int pos = t.count;
    while (pos > 0 && t.list[pos - 1].init < init) {
        t.list[pos] = t.list[pos - 1];
        pos--;
    }
    t.list[pos].used = true;
    copy_n(&t.list[pos].name[0], name, NAME_CAP - 1, &t.list[pos].namelen);
    t.list[pos].init = init;
    t.count++;
    return true;
}

// ============================================================
// Initiative commands
// ============================================================

fn void show_init(void* c, int area) {
    Tracker* t = &track[area];
    if (t.count == 0) { api.client_send_msg(c, "No encounter. Add combatants with /initadd <name> [value]."); return; }
    char[600] b; usz n = 0;
    n = put_str(b[..], n, "Initiative:");
    for (int i = 0; i < t.count; i++) {
        n = put_str(b[..], n, i == t.turn ? "  ▶ " : "  ");
        n = put_int(b[..], n, i + 1);
        n = put_str(b[..], n, ") ");
        n = put_str(b[..], n, cname(&t.list[i]));
        n = put_str(b[..], n, " (");
        n = put_int(b[..], n, t.list[i].init);
        n = put_str(b[..], n, ")");
    }
    api.broadcast_area_msg(area, (String)b[0..n - 1]);
}

fn void cmd_initadd(void* c, String args) {
    int area = api.client_get_area(c);
    if (area < 0 || area >= MAX_AREAS) return;

    String[3] argv;
    int an = api.args_split(args, &argv[0], 3);
    if (an < 1) { api.client_send_msg(c, "Usage: /initadd <name> [value]  (rolls d20 if no value)"); return; }

    String name = argv[0];
    int init = an >= 2 ? (argv[1].to_int() ?? -9999) : roll_die(20);
    if (init == -9999) { api.client_send_msg(c, "Initiative value must be a number."); return; }

    if (!add_combatant(area, name, init)) { api.client_send_msg(c, "The encounter is full."); return; }

    char[200] b; usz bn = 0;
    bn = put_str(b[..], bn, "Added ");
    bn = put_str(b[..], bn, name.len > 40 ? name[0..39] : name);
    bn = put_str(b[..], bn, " to initiative at ");
    bn = put_int(b[..], bn, init);
    bn = put_str(b[..], bn, ".");
    api.broadcast_area_msg(area, (String)b[0..bn - 1]);
}

fn void cmd_next(void* c, String args) {
    int area = api.client_get_area(c);
    if (area < 0 || area >= MAX_AREAS) return;
    Tracker* t = &track[area];
    if (t.count == 0) { api.client_send_msg(c, "No encounter to advance. /initadd first."); return; }

    t.turn++;
    bool wrapped = false;
    if (t.turn >= t.count) { t.turn = 0; wrapped = true; }

    char[200] b; usz n = 0;
    if (wrapped) n = put_str(b[..], n, "(Top of the order) ");
    n = put_str(b[..], n, "Now up: ");
    n = put_str(b[..], n, cname(&t.list[t.turn]));
    n = put_str(b[..], n, " (init ");
    n = put_int(b[..], n, t.list[t.turn].init);
    n = put_str(b[..], n, ").");
    api.broadcast_area_msg(area, (String)b[0..n - 1]);
}

fn void cmd_initremove(void* c, String args) {
    int area = api.client_get_area(c);
    if (area < 0 || area >= MAX_AREAS) return;
    Tracker* t = &track[area];

    String[2] argv;
    int an = api.args_split(args, &argv[0], 2);
    if (an < 1) { api.client_send_msg(c, "Usage: /initremove <name>"); return; }

    char[40] lc; int lcn = api.to_lower(argv[0], &lc[0], 40);
    String want = lcn > 0 ? (String)lc[0..lcn - 1] : "";

    for (int i = 0; i < t.count; i++) {
        char[40] nlc; int nln = api.to_lower(cname(&t.list[i]), &nlc[0], 40);
        String have = nln > 0 ? (String)nlc[0..nln - 1] : "";
        if (have == want) {
            for (int j = i; j < t.count - 1; j++) t.list[j] = t.list[j + 1];
            t.count--;
            if (t.turn >= t.count) t.turn = t.count - 1;
            api.broadcast_area_msg(area, "Removed a combatant from initiative.");
            return;
        }
    }
    api.client_send_msg(c, "No combatant by that name.");
}

fn void cmd_initclear(void* c, String args) {
    int area = api.client_get_area(c);
    if (area < 0 || area >= MAX_AREAS) return;
    track[area].count = 0;
    track[area].turn = -1;
    api.broadcast_area_msg(area, "Initiative cleared.");
}

fn void cmd_init(void* c, String args) {
    int area = api.client_get_area(c);
    if (area < 0 || area >= MAX_AREAS) return;
    show_init(c, area);
}

// ============================================================
// /statroll — 4d6 drop lowest, six times
// ============================================================

fn void cmd_statroll(void* c, String args) {
    char[300] b; usz n = 0;
    n = put_str(b[..], n, api.client_display_name(c));
    n = put_str(b[..], n, " rolls stats (4d6 drop lowest): ");
    int total = 0;
    for (int s = 0; s < 6; s++) {
        int lowest = 7; int sum = 0;
        for (int d = 0; d < 4; d++) {
            int r = roll_die(6);
            sum += r;
            if (r < lowest) lowest = r;
        }
        sum -= lowest;
        total += sum;
        if (s > 0) n = put_str(b[..], n, ", ");
        n = put_int(b[..], n, sum);
    }
    n = put_str(b[..], n, "  (total ");
    n = put_int(b[..], n, total);
    n = put_str(b[..], n, ")");
    api.broadcast_area_msg(api.client_get_area(c), (String)b[0..n - 1]);
}

// ============================================================
// /adv and /dis — roll two d20, take the better / worse, +mod
// ============================================================

fn void do_d20_pair(void* c, String args, bool advantage) {
    int mod = 0;
    String s = args.trim();
    if (s.len > 0) {
        // Accept "+3", "-1", or "3".
        String m = s;
        if (s[0] == '+') m = s[1..];
        mod = m.to_int() ?? 0;
    }

    int a = roll_die(20);
    int d = roll_die(20);
    int chosen = advantage ? (a > d ? a : d) : (a < d ? a : d);

    char[240] b; usz n = 0;
    n = put_str(b[..], n, api.client_display_name(c));
    n = put_str(b[..], n, advantage ? " rolls with ADVANTAGE: [" : " rolls with DISADVANTAGE: [");
    n = put_int(b[..], n, a);
    n = put_str(b[..], n, ", ");
    n = put_int(b[..], n, d);
    n = put_str(b[..], n, "] → ");
    n = put_int(b[..], n, chosen);
    if (mod != 0) {
        n = put_str(b[..], n, mod > 0 ? " + " : " - ");
        n = put_int(b[..], n, mod > 0 ? mod : -mod);
        n = put_str(b[..], n, " = ");
        n = put_int(b[..], n, chosen + mod);
    }
    api.broadcast_area_msg(api.client_get_area(c), (String)b[0..n - 1]);
}

fn void cmd_adv(void* c, String a) { do_d20_pair(c, a, true); }
fn void cmd_dis(void* c, String a) { do_d20_pair(c, a, false); }

// ============================================================
// Plugin interface (exported)
// ============================================================

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return {
        .name        = "Tabletop",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "DnD helpers: initiative tracker, /statroll, /adv, /dis. Optional.",
    };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    for (int i = 0; i < MAX_AREAS; i++) { track[i].count = 0; track[i].turn = -1; }

    ulong seed = (ulong)time_c(null) ^ 0x9E3779B97F4A7C15;
    if (seed == 0) seed = 0x9E3779B97F4A7C15;
    rng_state = seed;
    next_rand(); next_rand(); next_rand();

    api.register_command("init", &cmd_init, 0, "Show the initiative order", PLUGIN_NAME);
    api.register_command("initadd", &cmd_initadd, 0, "Add a combatant: /initadd <name> [value]", PLUGIN_NAME);
    api.register_command("next", &cmd_next, 0, "Advance to the next turn", PLUGIN_NAME);
    api.register_command("initremove", &cmd_initremove, 0, "Remove a combatant: /initremove <name>", PLUGIN_NAME);
    api.register_command("initclear", &cmd_initclear, 0, "Clear the encounter", PLUGIN_NAME);
    api.register_command("statroll", &cmd_statroll, 0, "Roll ability scores (4d6 drop lowest ×6)", PLUGIN_NAME);
    api.register_command("adv", &cmd_adv, 0, "d20 with advantage: /adv [mod]", PLUGIN_NAME);
    api.register_command("dis", &cmd_dis, 0, "d20 with disadvantage: /dis [mod]", PLUGIN_NAME);

    io::printn("[tabletop] Loaded. /init /initadd /next /statroll /adv /dis ready.");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    io::printn("[tabletop] Unloaded.");
}
