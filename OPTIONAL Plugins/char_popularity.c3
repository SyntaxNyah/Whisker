// Whisker Optional Plugin — Character Popularity [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Tracks which characters get used most on your server and shows a leaderboard.
// A bit of fun community analytics — see whether everyone's a Phoenix main, or
// which custom characters are catching on. Drop the compiled .dll / .so into
// plugins/ and restart. Optional.
//
// This source file is provided as a learning exercise. To compile a C3 plugin
// yourself, follow the Plugin Dev Guide: plugins/PLUGIN DEV GUIDE README.md
//
// ============================================================
// What it does
// ============================================================
//
//   /charpop [N]      show the top N most-used characters (default 10)
//
// A character scores one point each time someone switches TO it. Counts persist
// across clean restarts in config/char_popularity.txt.
//
// ============================================================
// Why this is an OPTIONAL plugin — and (almost) zero cost
// ============================================================
//
// It's a vanity stat — lovely for a community server, pointless for a private or
// utility one, and some communities would rather not tally behaviour at all, so
// it's opt-in. It uses **no packet hooks**: it rides the core's lifecycle UPDATE
// event and only does work on a genuine *character change* (it diffs each
// player's last character, so the per-OOC-line firing of UPDATE costs a single
// string compare). Nothing runs on the IC/OOC broadcast path.

module char_popularity;

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

const String PLUGIN_NAME = "Character Popularity";
const int EVENT_JOIN   = 0;
const int EVENT_LEAVE  = 1;
const int EVENT_UPDATE = 2;
const int MAX_PLAYERS  = 1024;
const int MAX_CHARS    = 1024;
const int NAME_CAP     = 63;

PluginAPI* api;

// Per-uid last-seen character (diff source).
struct Seen { bool used; int uid; char[64] last; int len; }
Seen[MAX_PLAYERS] seen;

// charname -> count.
struct CharCount { bool used; char[64] name; int len; long count; }
CharCount[MAX_CHARS] counts;

// ============================================================
// Helpers
// ============================================================

fn usz put_str(char[] buf, usz n, String s) {
    foreach (char ch : s) { if (n >= buf.len) break; buf[n] = ch; n++; }
    return n;
}
fn usz put_long(char[] buf, usz n, long v) {
    if (v < 0) { n = put_str(buf, n, "-"); v = -v; }
    if (v == 0) return put_str(buf, n, "0");
    char[24] tmp; int t = 0;
    while (v > 0) { tmp[t] = (char)('0' + (int)(v % 10)); t++; v /= 10; }
    while (t > 0) { t--; if (n >= buf.len) break; buf[n] = tmp[t]; n++; }
    return n;
}
fn String nstr(char* buf, int len) {
    if (len <= 0) return "";
    return (String)buf[0..len - 1];
}
fn String cstr(char* buf) {
    int len = 0;
    while (buf[len] != 0) len++;
    if (len == 0) return "";
    return (String)buf[0..len - 1];
}

fn Seen* seen_for(int uid) {
    for (int i = 0; i < MAX_PLAYERS; i++) { if (seen[i].used && seen[i].uid == uid) return &seen[i]; }
    return null;
}
fn Seen* seen_alloc(int uid) {
    for (int i = 0; i < MAX_PLAYERS; i++) {
        if (!seen[i].used) { seen[i].used = true; seen[i].uid = uid; seen[i].len = 0; return &seen[i]; }
    }
    return null;
}

fn void bump(String name) {
    if (name.len == 0 || name.len > NAME_CAP) return;
    for (int i = 0; i < MAX_CHARS; i++) {
        if (counts[i].used && nstr(&counts[i].name[0], counts[i].len) == name) { counts[i].count++; return; }
    }
    for (int i = 0; i < MAX_CHARS; i++) {
        if (!counts[i].used) {
            counts[i].used = true;
            int n = (int)name.len;
            for (int k = 0; k < n; k++) counts[i].name[k] = name[k];
            counts[i].len = n;
            counts[i].count = 1;
            return;
        }
    }
}

// ============================================================
// Lifecycle — count genuine character changes
// ============================================================

fn void on_life(void* c, int event) {
    int uid = api.client_get_uid(c);
    if (uid < 0) return;
    switch (event) {
        case EVENT_JOIN:
            seen_alloc(uid);
        case EVENT_LEAVE:
            Seen* s = seen_for(uid);
            if (s != null) s.used = false;
        case EVENT_UPDATE:
            Seen* s2 = seen_for(uid);
            if (s2 == null) { s2 = seen_alloc(uid); if (s2 == null) return; }
            String cur = api.client_get_char_name(c);
            if (cur.len == 0) return;
            String old = nstr(&s2.last[0], s2.len);
            if (old == cur) return;            // not a real change
            int k = (int)cur.len; if (k > 63) k = 63;
            for (int i = 0; i < k; i++) s2.last[i] = cur[i];
            s2.len = k;
            bump(cur);
        default:
            break;
    }
}

// ============================================================
// /charpop — top N
// ============================================================

fn void cmd_charpop(void* c, String args) {
    int topn = args.trim().len == 0 ? 10 : (args.trim().to_int() ?? 10);
    if (topn < 1) topn = 1;
    if (topn > 20) topn = 20;

    // Count how many distinct characters we have.
    int distinct = 0;
    for (int i = 0; i < MAX_CHARS; i++) { if (counts[i].used) distinct++; }
    if (distinct == 0) { api.client_send_msg(c, "No character data yet."); return; }
    if (topn > distinct) topn = distinct;

    api.client_send_msg(c, "— Most-used characters —");

    bool[MAX_CHARS] taken;
    for (int i = 0; i < MAX_CHARS; i++) taken[i] = false;

    for (int rank = 0; rank < topn; rank++) {
        long best = -1; int bi = -1;
        for (int i = 0; i < MAX_CHARS; i++) {
            if (!counts[i].used || taken[i]) continue;
            if (counts[i].count > best) { best = counts[i].count; bi = i; }
        }
        if (bi < 0) break;
        taken[bi] = true;

        char[120] m; usz n = 0;
        n = put_long(m[..], n, (long)(rank + 1));
        n = put_str(m[..], n, ". ");
        n = put_str(m[..], n, nstr(&counts[bi].name[0], counts[bi].len));
        n = put_str(m[..], n, " — ");
        n = put_long(m[..], n, counts[bi].count);
        api.client_send_msg(c, (String)m[0..n - 1]);
    }
}

// ============================================================
// Persistence — config/char_popularity.txt  (name<TAB>count)
// ============================================================

fn void load_counts() {
    void* f = fopen_c("config/char_popularity.txt", "r");
    if (f == null) f = fopen_c("../config/char_popularity.txt", "r");
    if (f == null) return;
    char[256] line;
    while (fgets_c(&line[0], 256, f) != null) {
        String raw = cstr(&line[0]);
        // strip trailing newline
        usz end = raw.len;
        while (end > 0 && (raw[end - 1] == '\n' || raw[end - 1] == '\r')) end--;
        raw = end > 0 ? raw[0..end - 1] : "";
        if (raw.len == 0 || raw[0] == '#') continue;
        // split on the last tab
        usz tab = 0; bool found = false;
        for (usz i = 0; i < raw.len; i++) { if (raw[i] == '\t') { tab = i; found = true; } }
        if (!found || tab == 0 || tab + 1 >= raw.len) continue;
        String name = raw[0..tab - 1];
        long cnt = 0;
        for (usz i = tab + 1; i < raw.len; i++) { if (raw[i] >= '0' && raw[i] <= '9') cnt = cnt * 10 + (long)(raw[i] - '0'); }
        if (name.len > NAME_CAP || cnt <= 0) continue;
        // seed the table
        for (int i = 0; i < MAX_CHARS; i++) {
            if (!counts[i].used) {
                counts[i].used = true;
                int k = (int)name.len;
                for (int j = 0; j < k; j++) counts[i].name[j] = name[j];
                counts[i].len = k; counts[i].count = cnt;
                break;
            }
        }
    }
    fclose_c(f);
}

fn void save_counts() {
    void* f = fopen_c("config/char_popularity.txt", "w");
    if (f == null) f = fopen_c("../config/char_popularity.txt", "w");
    if (f == null) return;
    fputs_c((ZString)"# Whisker character-popularity counts (name<TAB>count). Auto-saved.\n", f);
    for (int i = 0; i < MAX_CHARS; i++) {
        if (!counts[i].used) continue;
        char[120] line; usz n = 0;
        n = put_str(line[..], n, nstr(&counts[i].name[0], counts[i].len));
        n = put_str(line[..], n, "\t");
        n = put_long(line[..], n, counts[i].count);
        n = put_str(line[..], n, "\n");
        line[n] = 0;
        fputs_c((ZString)&line[0], f);
    }
    fclose_c(f);
}

// ============================================================
// Plugin interface (exported)
// ============================================================

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return {
        .name        = "Character Popularity",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Most-used-character leaderboard: /charpop. Optional.",
    };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    for (int i = 0; i < MAX_PLAYERS; i++) seen[i].used = false;
    for (int i = 0; i < MAX_CHARS; i++) counts[i].used = false;

    load_counts();

    api.register_lifecycle_hook(&on_life, PLUGIN_NAME);
    api.register_command("charpop", &cmd_charpop, 0, "Top N most-used characters: /charpop [N]", PLUGIN_NAME);

    io::printn("[char_popularity] Loaded. /charpop ready.");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    save_counts();
    io::printn("[char_popularity] Saved + unloaded.");
}
