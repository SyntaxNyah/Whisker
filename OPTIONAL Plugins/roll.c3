// Whisker Optional Plugin — Roll (tabletop dice) [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Adds dice-rolling commands for tabletop / DnD-style play on top of the AO2
// courtroom: /roll <NdS[+/-M]> rolls dice and shows the result to the whole
// area, /rollp does the same but privately (only you see it). Drop the compiled
// .dll (Windows) / .so (Linux) into your server's plugins/ folder and restart.
// Optional — your server runs fine without it.
//
// This source file is provided as a learning exercise. To compile a C3 plugin
// yourself, follow the Plugin Dev Guide: plugins/PLUGIN DEV GUIDE README.md
//
// ============================================================
// What it does
// ============================================================
//
//   /roll              Roll 1d20 (default), shown to the area.
//   /roll 2d6          Roll two six-sided dice.
//   /roll 3d6+2        Roll three d6 and add 2.
//   /roll 1d20-1       Roll a d20 and subtract 1.
//   /rollp <dice>      Same grammar, but the result is sent only to you
//                      (a "private" / GM roll).
//
// The roll is broadcast to the area as an OOC server line, e.g.
//   "Phoenix rolls 2d6+3: [4, 5] + 3 = 12"
// so the table can see and trust every roll.
//
// ============================================================
// Why this is a PLUGIN, not core
// ============================================================
//
// Dice are a gameplay feature, not part of the AO2 protocol. Plenty of servers
// are pure courtroom or social spaces where dice would just be noise, and an
// uncapped roller is a spam vector. So it lives in an optional plugin: tabletop
// and DnD servers drop it in; everyone else never sees it. Rolls are capped
// (see MAX_DICE / MAX_SIDES) so a single command can't flood the area.

module roll;

import std::io;

// ============================================================
// Whisker plugin interface (standalone definitions)
// Must match src/plugin.c3 PluginAPI exactly, field-for-field, in order. This
// is the v4 prefix (copied verbatim from ip_guard.c3) — a plugin only has to
// declare the fields up to the last one it calls; the server's later fields
// (v5/v6) are simply never read. roll calls only a handful near the top.
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
// Constants / limits
// ============================================================

const String PLUGIN_NAME = "Roll";

const int MAX_DICE  = 100;   // most dice in a single roll (anti-spam)
const int MAX_SIDES = 1000;  // most sides per die
const int MAX_SHOWN = 30;    // individual dice listed before we summarise

PluginAPI* api;

// ============================================================
// PRNG — xorshift64. Seeded once at init from the clock; advanced per die.
// Lockless global state: two simultaneous rolls might share a step, which only
// affects randomness slightly — there is nothing security-sensitive here.
// ============================================================

ulong rng_state = 0x9E3779B97F4A7C15;

extern fn long time_c(void* t) @cname("time");

fn ulong next_rand() {
    ulong x = rng_state;
    x ^= x << 13;
    x ^= x >> 7;
    x ^= x << 17;
    rng_state = x;
    return x;
}

// One die in 1..sides.
fn int roll_die(int sides) {
    if (sides <= 1) return 1;
    return 1 + (int)(next_rand() % (ulong)sides);
}

// ============================================================
// Allocation-free string building (safe on the server's per-client threads,
// where this plugin's own temp allocator isn't initialised — see the Threading
// section of the Plugin Dev Guide).
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

fn usz put_int(char[] buf, usz n, long v) {
    if (v < 0) {
        if (n < buf.len) { buf[n] = '-'; n++; }
        return put_uint(buf, n, (ulong)(-v));
    }
    return put_uint(buf, n, (ulong)v);
}

// ============================================================
// Dice spec parsing — "NdS", "dS", "NdS+M", "NdS-M"
// ============================================================

struct Dice {
    bool ok;
    int  count;
    int  sides;
    int  mod;
}

fn Dice parse_dice(String input) {
    Dice d;
    d.ok = false; d.count = 1; d.sides = 0; d.mod = 0;

    String s = input.trim();
    if (s.len == 0) return d;

    usz i = 0;

    // Optional dice count (defaults to 1 when omitted, e.g. "d20").
    int count = 0; bool have_count = false;
    while (i < s.len && s[i] >= '0' && s[i] <= '9') {
        count = count * 10 + (s[i] - '0');
        have_count = true;
        if (count > 1000000) return d;
        i++;
    }

    // Required 'd'/'D'.
    if (i >= s.len || (s[i] != 'd' && s[i] != 'D')) return d;
    i++;

    // Required side count.
    int sides = 0; bool have_sides = false;
    while (i < s.len && s[i] >= '0' && s[i] <= '9') {
        sides = sides * 10 + (s[i] - '0');
        have_sides = true;
        if (sides > 1000000) return d;
        i++;
    }
    if (!have_sides) return d;

    // Optional +/- modifier.
    int mod = 0;
    if (i < s.len && (s[i] == '+' || s[i] == '-')) {
        int sign = s[i] == '-' ? -1 : 1;
        i++;
        int m = 0; bool have_m = false;
        while (i < s.len && s[i] >= '0' && s[i] <= '9') {
            m = m * 10 + (s[i] - '0');
            have_m = true;
            if (m > 1000000) return d;
            i++;
        }
        if (!have_m) return d;
        mod = sign * m;
    }

    // Reject trailing garbage ("2d6 foo").
    if (i != s.len) return d;

    d.count = have_count ? count : 1;
    d.sides = sides;
    d.mod   = mod;
    d.ok    = true;
    return d;
}

// ============================================================
// The roll itself
// ============================================================

fn void do_roll(void* c, String args, bool private_roll) {
    // No argument → default to a single d20.
    Dice d = parse_dice(args.trim().len == 0 ? "1d20" : args);
    if (!d.ok) {
        api.client_send_msg(c, "Usage: /roll <NdS[+/-M]>  —  e.g. /roll 2d6+3, /roll d20, /roll 4d10-2");
        return;
    }
    if (d.count < 1 || d.count > MAX_DICE) {
        char[96] e; usz en = 0;
        en = put_str(e[..], en, "Roll: dice count must be 1..");
        en = put_uint(e[..], en, (ulong)MAX_DICE); e[en] = 0;
        api.client_send_msg(c, (String)e[0..en - 1]);
        return;
    }
    if (d.sides < 1 || d.sides > MAX_SIDES) {
        char[96] e; usz en = 0;
        en = put_str(e[..], en, "Roll: die sides must be 1..");
        en = put_uint(e[..], en, (ulong)MAX_SIDES); e[en] = 0;
        api.client_send_msg(c, (String)e[0..en - 1]);
        return;
    }

    char[640] buf; usz n = 0;
    n = put_str(buf[..], n, api.client_display_name(c));
    n = put_str(buf[..], n, private_roll ? " privately rolls " : " rolls ");
    n = put_uint(buf[..], n, (ulong)d.count);
    n = put_str(buf[..], n, "d");
    n = put_uint(buf[..], n, (ulong)d.sides);
    if (d.mod != 0) {
        n = put_str(buf[..], n, d.mod > 0 ? "+" : "-");
        n = put_uint(buf[..], n, (ulong)(d.mod > 0 ? d.mod : -d.mod));
    }
    n = put_str(buf[..], n, ": [");

    long total = 0;
    for (int k = 0; k < d.count; k++) {
        int r = roll_die(d.sides);
        total += r;
        if (k < MAX_SHOWN) {
            if (k > 0) n = put_str(buf[..], n, ", ");
            n = put_uint(buf[..], n, (ulong)r);
        } else if (k == MAX_SHOWN) {
            n = put_str(buf[..], n, ", …");
        }
    }
    n = put_str(buf[..], n, "]");

    if (d.mod != 0) {
        n = put_str(buf[..], n, d.mod > 0 ? " + " : " - ");
        n = put_uint(buf[..], n, (ulong)(d.mod > 0 ? d.mod : -d.mod));
        total += d.mod;
    }
    n = put_str(buf[..], n, " = ");
    n = put_int(buf[..], n, total);

    String msg = (String)buf[0..n - 1];
    if (private_roll) {
        api.client_send_msg(c, msg);
    } else {
        api.broadcast_area_msg(api.client_get_area(c), msg);
    }
}

fn void cmd_roll(void* c, String a)  { do_roll(c, a, false); }
fn void cmd_rollp(void* c, String a) { do_roll(c, a, true); }

// ============================================================
// Plugin interface (exported)
// ============================================================

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return {
        .name        = "Roll",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Tabletop dice: /roll and /rollp. Optional — see header.",
    };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;

    // Seed the PRNG from the clock; never leave it zero (xorshift(0) == 0).
    ulong seed = (ulong)time_c(null) ^ 0x9E3779B97F4A7C15;
    if (seed == 0) seed = 0x9E3779B97F4A7C15;
    rng_state = seed;
    // Stir a little so two servers started in the same second diverge fast.
    next_rand(); next_rand(); next_rand();

    api.register_command("roll",  &cmd_roll,  0, "Roll dice, e.g. /roll 2d6+3 (shown to the area)", PLUGIN_NAME);
    api.register_command("rollp", &cmd_rollp, 0, "Roll dice privately (only you see the result)",   PLUGIN_NAME);

    io::printn("[roll] Loaded. /roll and /rollp ready.");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    io::printn("[roll] Shutting down.");
}
