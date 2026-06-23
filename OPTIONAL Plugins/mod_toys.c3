// Whisker Optional Plugin — Mod Toys [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Light, reversible "punishment" toys a moderator can apply to one player, in
// the tsuserver tradition:
//   /gimp <uid>        replace their messages with random nonsense
//   /disemvowel <uid>  strip the vowels out of their messages
//   /parrot <uid>      echo each message back, doubled and annoying
//   /untoy <uid>       clear any toy
// These rewrite ONLY the targeted player's lines (that line loses pairing and
// isn't seen by logging/relay plugins — fine for a punished user). Optional —
// drop the .dll/.so into plugins/ and restart.
//
// Standalone plugin: see the Plugin Dev Guide (plugins/PLUGIN DEV GUIDE README.md).

module mod_toys;

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

const String PLUGIN_NAME = "Mod Toys";
const ulong PERM_MUTE = 1;
const int EVENT_LEAVE = 1;
const int MAX_TOYS = 256;
const int MS_MESSAGE = 4;
const int CT_MESSAGE = 1;

const int NONE = 0;
const int GIMP = 1;
const int DISEMVOWEL = 2;
const int PARROT = 3;

const String[] GIMP_LINES = {
    "Blah blah blah.",
    "I'm a teapot.",
    "*incoherent mumbling*",
    "Word.",
    "Honk.",
    "I have nothing useful to add.",
    "Mooooo.",
    "Pong.",
    "I like turtles.",
    "...",
};

struct Toy { bool used; int uid; int effect; }
Toy[MAX_TOYS] toys;

PluginAPI* api;
ulong rng = 0x2545F4914F6CDD1D;

extern fn long time_c(void* t) @cname("time");

fn usz put_str(char[] buf, usz n, String s) { foreach (char ch : s) { if (n >= buf.len) break; buf[n] = ch; n++; } return n; }
fn usz put_uint(char[] buf, usz n, ulong v) {
    if (v == 0) return put_str(buf, n, "0");
    char[20] tmp; int t = 0;
    while (v > 0) { tmp[t] = (char)('0' + (int)(v % 10)); t++; v /= 10; }
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
fn ulong next_rand() { ulong x = rng; x ^= x << 13; x ^= x >> 7; x ^= x << 17; rng = x; return x; }

fn Toy* find_toy(int uid) {
    for (int i = 0; i < MAX_TOYS; i++) { if (toys[i].used && toys[i].uid == uid) return &toys[i]; }
    return null;
}
fn void set_toy(int uid, int effect) {
    Toy* t = find_toy(uid);
    if (t == null) {
        for (int i = 0; i < MAX_TOYS; i++) { if (!toys[i].used) { t = &toys[i]; t.used = true; t.uid = uid; break; } }
    }
    if (t != null) t.effect = effect;
}
fn void clear_toy(int uid) {
    Toy* t = find_toy(uid);
    if (t != null) t.used = false;
}

// Produce the toyed text into `out`; returns length.
fn int transform(int effect, String msg, char* out, int cap) {
    int n = 0;
    switch (effect) {
        case GIMP:
            String line = GIMP_LINES[(usz)(next_rand() % (ulong)GIMP_LINES.len)];
            n = (int)line.len; if (n > cap) n = cap;
            for (int i = 0; i < n; i++) out[i] = line[i];
        case DISEMVOWEL:
            foreach (char ch : msg) {
                if (n >= cap) break;
                char l = (ch >= 'A' && ch <= 'Z') ? ch + 32 : ch;
                if (l == 'a' || l == 'e' || l == 'i' || l == 'o' || l == 'u') continue;
                out[n] = ch; n++;
            }
        case PARROT:
            for (int rep = 0; rep < 2; rep++) {
                if (rep > 0 && n < cap) { out[n] = ' '; n++; }
                foreach (char ch : msg) { if (n >= cap) break; out[n] = ch; n++; }
            }
        default:
            n = (int)msg.len; if (n > cap) n = cap;
            for (int i = 0; i < n; i++) out[i] = msg[i];
    }
    return n;
}

fn usz build_pkt(char[] buf, void* pkt, String header, bool ms, int idx, String newval) {
    int fc = api.packet_get_field_count(pkt);
    usz n = put_str(buf, 0, header);
    if (ms) {
        int upto = fc < 18 ? fc : 18;
        for (int i = 0; i < upto; i++) { n = put_str(buf, n, "#"); n = (i == idx) ? put_escaped(buf, n, newval) : put_escaped(buf, n, api.packet_get_field(pkt, i)); }
        for (int i = upto; i < 18; i++) n = put_str(buf, n, "#");
        n = put_str(buf, n, "####");
        for (int i = 18; i < fc; i++) { n = put_str(buf, n, "#"); n = (i == idx) ? put_escaped(buf, n, newval) : put_escaped(buf, n, api.packet_get_field(pkt, i)); }
    } else {
        for (int i = 0; i < fc; i++) { n = put_str(buf, n, "#"); n = (i == idx) ? put_escaped(buf, n, newval) : put_escaped(buf, n, api.packet_get_field(pkt, i)); }
    }
    n = put_str(buf, n, "#%");
    return n;
}

fn bool toy_message(void* c, void* pkt, bool ms) {
    Toy* t = find_toy(api.client_get_uid(c));
    if (t == null || t.effect == NONE) return false;
    int idx = ms ? MS_MESSAGE : CT_MESSAGE;
    String msg = api.packet_get_field(pkt, idx);
    char[600] tb; int tn = transform(t.effect, msg, &tb[0], 599);
    char[2048] pb;
    usz pn = build_pkt(pb[..], pkt, ms ? "MS" : "CT", ms, idx, (String)tb[0..tn - 1]);
    api.broadcast_area_raw(api.client_get_area(c), (String)pb[0..pn - 1]);
    return true; // consume the original
}

fn bool on_ic(void* c, void* pkt) { return toy_message(c, pkt, true); }
fn bool on_ooc(void* c, void* pkt) {
    if (api.packet_get_field_count(pkt) < 2) return false;
    String m = api.packet_get_field(pkt, CT_MESSAGE);
    if (m.len > 0 && m[0] == '/') return false; // don't toy commands
    return toy_message(c, pkt, false);
}

fn void on_life(void* c, int ev) { if (ev == EVENT_LEAVE) clear_toy(api.client_get_uid(c)); }

fn int parse_uid(String args) {
    String s = args.trim();
    usz i = 0; while (i < s.len && s[i] != ' ' && s[i] != '\t') i++;
    String tok = i == 0 ? s : s[0..i - 1];
    return tok.to_int() ?? -1;
}

fn void apply(void* c, String args, int effect, String verb) {
    int uid = parse_uid(args);
    if (uid < 0) { api.client_send_msg(c, "Usage: /<toy> <uid>"); return; }
    void* target = api.find_client(uid);
    if (target == null) { api.client_send_msg(c, "Player not found."); return; }
    set_toy(uid, effect);
    char[96] m; usz n = 0;
    n = put_str(m[..], n, verb);
    n = put_str(m[..], n, " UID ");
    n = put_uint(m[..], n, (ulong)uid);
    n = put_str(m[..], n, ".");
    api.client_send_msg(c, (String)m[0..n - 1]);
}

fn void cmd_gimp(void* c, String a)       { apply(c, a, GIMP, "Gimped"); }
fn void cmd_disemvowel(void* c, String a) { apply(c, a, DISEMVOWEL, "Disemvowelled"); }
fn void cmd_parrot(void* c, String a)     { apply(c, a, PARROT, "Parroted"); }
fn void cmd_untoy(void* c, String a) {
    int uid = parse_uid(a);
    if (uid < 0) { api.client_send_msg(c, "Usage: /untoy <uid>"); return; }
    clear_toy(uid);
    char[64] m; usz n = 0;
    n = put_str(m[..], n, "Cleared toys on UID ");
    n = put_uint(m[..], n, (ulong)uid);
    n = put_str(m[..], n, ".");
    api.client_send_msg(c, (String)m[0..n - 1]);
}

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return { "Mod Toys", "1.0.0", "Whisker Community", "gimp/disemvowel/parrot punishments. Optional." };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    for (int i = 0; i < MAX_TOYS; i++) toys[i].used = false;
    rng ^= (ulong)time_c(null);
    if (rng == 0) rng = 0x2545F4914F6CDD1D;

    api.register_command("gimp", &cmd_gimp, PERM_MUTE, "Replace a player's messages with nonsense", PLUGIN_NAME);
    api.register_command("disemvowel", &cmd_disemvowel, PERM_MUTE, "Strip the vowels from a player's messages", PLUGIN_NAME);
    api.register_command("parrot", &cmd_parrot, PERM_MUTE, "Echo a player's messages back, doubled", PLUGIN_NAME);
    api.register_command("untoy", &cmd_untoy, PERM_MUTE, "Clear any toy on a player", PLUGIN_NAME);
    api.register_hook("MS", &on_ic, PLUGIN_NAME);
    api.register_hook("CT", &on_ooc, PLUGIN_NAME);
    api.register_lifecycle_hook(&on_life, PLUGIN_NAME);
    io::printn("[mod_toys] Loaded. /gimp /disemvowel /parrot /untoy ready.");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    io::printn("[mod_toys] Shutting down.");
}
