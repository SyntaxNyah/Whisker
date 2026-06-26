// Whisker Optional Plugin — Funbox [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A little box of casual randomiser commands for the area: a coin flip, a Magic
// 8-Ball, a "pick one of these" chooser, and a playing-card draw. Pure fun — drop
// the compiled .dll / .so into plugins/ and restart. Optional; your server runs
// fine without it.
//
// This source file is provided as a learning exercise. To compile a C3 plugin
// yourself, follow the Plugin Dev Guide: plugins/PLUGIN DEV GUIDE README.md
//
// ============================================================
// What it does
// ============================================================
//
//   /coinflip               flip a coin — Heads or Tails (shown to the area)
//   /8ball <question>       ask the Magic 8-Ball a yes/no question
//   /choose a | b | c       pick one of the listed options at random
//   /draw                   draw a random card from a 52-card deck
//
// Every result is broadcast to the area so the table can see it.
//
// ============================================================
// Why this is an OPTIONAL plugin — and zero performance cost
// ============================================================
//
// These are gameplay toys, not part of the AO2 protocol. A pure courtroom or
// serious-RP server doesn't want `/8ball` noise; a social or game server loves it.
// So it's opt-in. There is **no passive cost**: the plugin registers four
// commands and **no packet hooks**, so it does literally nothing until someone
// types one of its commands — it never touches the IC/OOC hot path. Results are
// built allocation-free on the stack.

module funbox;

import std::io;

// ============================================================
// Whisker plugin interface (standalone definitions)
// Must match src/plugin.c3 PluginAPI exactly, field-for-field, in order.
// This is the v4 prefix (copied from roll.c3) — funbox only calls a handful of
// fields near the top, so declaring up to v4 is plenty.
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

const String PLUGIN_NAME = "Funbox";

PluginAPI* api;

// ============================================================
// PRNG — xorshift64, same approach as roll.c3.
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

fn int rand_below(int n) {
    if (n <= 1) return 0;
    return (int)(next_rand() % (ulong)n);
}

// ============================================================
// Allocation-free string helpers
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

// ============================================================
// /coinflip
// ============================================================

fn void cmd_coinflip(void* c, String args) {
    char[160] b; usz n = 0;
    n = put_str(b[..], n, api.client_display_name(c));
    n = put_str(b[..], n, " flips a coin: ");
    n = put_str(b[..], n, (next_rand() & 1) == 0 ? "Heads!" : "Tails!");
    api.broadcast_area_msg(api.client_get_area(c), (String)b[0..n - 1]);
}

// ============================================================
// /8ball
// ============================================================

const String[] EIGHTBALL = {
    "It is certain.", "Without a doubt.", "Yes, definitely.", "You may rely on it.",
    "As I see it, yes.", "Most likely.", "Outlook good.", "Signs point to yes.",
    "Reply hazy, try again.", "Ask again later.", "Better not tell you now.",
    "Cannot predict now.", "Concentrate and ask again.", "Don't count on it.",
    "My reply is no.", "My sources say no.", "Outlook not so good.", "Very doubtful.",
};

fn void cmd_8ball(void* c, String args) {
    String q = args.trim();
    if (q.len == 0) { api.client_send_msg(c, "Ask the Magic 8-Ball a yes/no question: /8ball <question>"); return; }
    String answer = EIGHTBALL[rand_below((int)EIGHTBALL.len)];

    char[400] b; usz n = 0;
    n = put_str(b[..], n, "Magic 8-Ball — ");
    n = put_str(b[..], n, api.client_display_name(c));
    n = put_str(b[..], n, " asks: \"");
    // cap the echoed question so the line can't be huge
    String qq = q.len > 200 ? q[0..199] : q;
    n = put_str(b[..], n, qq);
    n = put_str(b[..], n, "\" — ");
    n = put_str(b[..], n, answer);
    api.broadcast_area_msg(api.client_get_area(c), (String)b[0..n - 1]);
}

// ============================================================
// /choose a | b | c
// ============================================================

fn void cmd_choose(void* c, String args) {
    String s = args.trim();
    if (s.len == 0) { api.client_send_msg(c, "Usage: /choose option1 | option2 | option3 ..."); return; }

    // Split on '|', remembering each non-empty option's bounds, and pick one.
    // We do a two-pass: count valid options, then walk to the chosen index — so
    // there's no allocation and no need to store slices.
    int count = 0;
    usz start = 0;
    for (usz i = 0; i <= s.len; i++) {
        if (i == s.len || s[i] == '|') {
            String seg = i > start ? s[start..i - 1] : "";
            if (seg.trim().len > 0) count++;
            start = i + 1;
        }
    }
    if (count < 2) { api.client_send_msg(c, "Give at least two options: /choose tea | coffee"); return; }

    int pick = rand_below(count);
    String chosen = "";
    int idx = 0;
    start = 0;
    for (usz i = 0; i <= s.len; i++) {
        if (i == s.len || s[i] == '|') {
            String seg = (i > start ? s[start..i - 1] : "").trim();
            if (seg.len > 0) {
                if (idx == pick) { chosen = seg; break; }
                idx++;
            }
            start = i + 1;
        }
    }

    char[300] b; usz n = 0;
    n = put_str(b[..], n, api.client_display_name(c));
    n = put_str(b[..], n, " asks me to choose… ");
    String cc = chosen.len > 200 ? chosen[0..199] : chosen;
    n = put_str(b[..], n, cc);
    api.broadcast_area_msg(api.client_get_area(c), (String)b[0..n - 1]);
}

// ============================================================
// /draw — a card from a 52-card deck
// ============================================================

const String[] RANKS = {
    "Ace", "2", "3", "4", "5", "6", "7", "8", "9", "10", "Jack", "Queen", "King",
};
const String[] SUITS = { "Hearts", "Diamonds", "Clubs", "Spades" };

fn void cmd_draw(void* c, String args) {
    int card = rand_below(52);
    String rank = RANKS[card % 13];
    String suit = SUITS[(card / 13) % 4];

    char[160] b; usz n = 0;
    n = put_str(b[..], n, api.client_display_name(c));
    n = put_str(b[..], n, " draws: ");
    n = put_str(b[..], n, rank);
    n = put_str(b[..], n, " of ");
    n = put_str(b[..], n, suit);
    n = put_str(b[..], n, ".");
    api.broadcast_area_msg(api.client_get_area(c), (String)b[0..n - 1]);
}

// ============================================================
// Plugin interface (exported)
// ============================================================

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return {
        .name        = "Funbox",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Casual randomisers: /coinflip /8ball /choose /draw. Optional.",
    };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;

    ulong seed = (ulong)time_c(null) ^ 0x9E3779B97F4A7C15;
    if (seed == 0) seed = 0x9E3779B97F4A7C15;
    rng_state = seed;
    next_rand(); next_rand(); next_rand();

    api.register_command("coinflip", &cmd_coinflip, 0, "Flip a coin (shown to the area)", PLUGIN_NAME);
    api.register_command("8ball", &cmd_8ball, 0, "Ask the Magic 8-Ball: /8ball <question>", PLUGIN_NAME);
    api.register_command("choose", &cmd_choose, 0, "Pick one at random: /choose a | b | c", PLUGIN_NAME);
    api.register_command("draw", &cmd_draw, 0, "Draw a random playing card", PLUGIN_NAME);

    io::printn("[funbox] Loaded. /coinflip /8ball /choose /draw ready.");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    io::printn("[funbox] Unloaded.");
}
