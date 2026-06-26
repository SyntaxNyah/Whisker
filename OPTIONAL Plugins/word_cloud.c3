// Whisker Optional Plugin — Word Cloud [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Light chat analytics: counts the words people actually use and shows the most
// common ones. A fun "what does our server talk about" readout. Drop the compiled
// .dll / .so into plugins/ and restart. Optional.
//
// This source file is provided as a learning exercise. To compile a C3 plugin
// yourself, follow the Plugin Dev Guide: plugins/PLUGIN DEV GUIDE README.md
//
// ============================================================
// What it does
// ============================================================
//
//   /wordcloud [N]    show the top N most-used words (default 12)
//
// Common filler words ("that", "this", "with", …) and very short words are
// ignored so the list is interesting. Counts are session-only (reset on restart).
//
// ============================================================
// Configuration — config/config.toml [word_cloud]
// ============================================================
//
//   enabled      true   master switch
//   min_length   4      ignore words shorter than this
//   track_ic     true   count IC (in-character) words
//   track_ooc    true   count OOC words (never counts commands)
//
// ============================================================
// Why this is an OPTIONAL plugin — and near-zero cost
// ============================================================
//
// It's a novelty, and counting what people type is a privacy choice some servers
// won't want — so it's opt-in (tell your players if you run it). It is the only
// plugin in this set that does any per-message work, and that work is deliberately
// tiny: a bounded tokenise (at most a few dozen words per line) plus a small-table
// increment — microseconds per message at AO's turn-based chat rates. It stores
// only word→count totals, never who said what.

module word_cloud;

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

const String PLUGIN_NAME = "Word Cloud";
const int MAX_WORDS     = 2048;
const int WORD_CAP      = 31;     // max stored word length
const int WORDS_PER_MSG = 40;     // bound work per message

PluginAPI* api;
bool opt_enabled   = true;
int  opt_min_len   = 4;
bool opt_track_ic  = true;
bool opt_track_ooc = true;

// word -> count
struct WordCount { bool used; char[32] word; int len; long count; }
WordCount[MAX_WORDS] words;

// ============================================================
// Common filler words to ignore (length >= 4; shorter ones are dropped by
// min_length anyway).
// ============================================================

const String[] STOPWORDS = {
    "that", "this", "with", "have", "your", "what", "when", "they", "them",
    "then", "than", "will", "would", "could", "should", "about", "there",
    "their", "here", "from", "into", "just", "like", "dont", "cant", "youre",
    "yeah", "okay", "well", "even", "also", "some", "much", "very", "want",
    "know", "going", "gonna", "really", "thing", "things", "people", "because",
};

fn bool is_stopword(String w) {
    for (int i = 0; i < (int)STOPWORDS.len; i++) { if (STOPWORDS[i] == w) return true; }
    return false;
}

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
fn String wstr(char* buf, int len) {
    if (len <= 0) return "";
    return (String)buf[0..len - 1];
}
fn String cstr(char* buf) {
    int len = 0;
    while (buf[len] != 0) len++;
    if (len == 0) return "";
    return (String)buf[0..len - 1];
}

fn bool is_wordchar(char ch) {
    if (ch >= 'a' && ch <= 'z') return true;
    if (ch >= 'A' && ch <= 'Z') return true;
    if (ch >= '0' && ch <= '9') return true;
    if (ch == '\'') return true; // keep apostrophes inside words
    return false;
}
fn char lower(char ch) {
    if (ch >= 'A' && ch <= 'Z') return (char)(ch + 32);
    return ch;
}

fn void bump(char* w, int len) {
    if (len <= 0) return;
    String word = (String)w[0..len - 1];
    for (int i = 0; i < MAX_WORDS; i++) {
        if (words[i].used && wstr(&words[i].word[0], words[i].len) == word) { words[i].count++; return; }
    }
    for (int i = 0; i < MAX_WORDS; i++) {
        if (!words[i].used) {
            words[i].used = true;
            for (int k = 0; k < len; k++) words[i].word[k] = w[k];
            words[i].len = len;
            words[i].count = 1;
            return;
        }
    }
    // table full → silently stop counting new words (existing ones still count)
}

fn void count_words(String msg) {
    char[32] cur; int cl = 0;
    int produced = 0;
    for (usz i = 0; i <= msg.len; i++) {
        char ch = i < msg.len ? msg[i] : ' ';
        if (i < msg.len && is_wordchar(ch)) {
            if (cl < WORD_CAP) { cur[cl] = lower(ch); cl++; }
        } else {
            if (cl >= opt_min_len) {
                String w = (String)cur[0..cl - 1];
                if (!is_stopword(w)) {
                    bump(&cur[0], cl);
                    produced++;
                    if (produced >= WORDS_PER_MSG) return;
                }
            }
            cl = 0;
        }
    }
}

// ============================================================
// Hooks (observe only — always return false)
// ============================================================

fn bool on_ms(void* c, void* pkt) {
    if (!opt_enabled || !opt_track_ic) return false;
    if (api.packet_get_field_count(pkt) < 5) return false;
    count_words(api.packet_get_field(pkt, 4)); // MS field 4 = message
    return false;
}
fn bool on_ct(void* c, void* pkt) {
    if (!opt_enabled || !opt_track_ooc) return false;
    if (api.packet_get_field_count(pkt) < 2) return false;
    String msg = api.packet_get_field(pkt, 1); // CT field 1 = message
    if (msg.len > 0 && msg[0] == '/') return false; // never count commands
    count_words(msg);
    return false;
}

// ============================================================
// /wordcloud
// ============================================================

fn void cmd_wordcloud(void* c, String args) {
    int topn = args.trim().len == 0 ? 12 : (args.trim().to_int() ?? 12);
    if (topn < 1) topn = 1;
    if (topn > 25) topn = 25;

    int distinct = 0;
    for (int i = 0; i < MAX_WORDS; i++) { if (words[i].used) distinct++; }
    if (distinct == 0) { api.client_send_msg(c, "No words counted yet."); return; }
    if (topn > distinct) topn = distinct;

    api.client_send_msg(c, "— Most-used words —");

    bool[MAX_WORDS] taken;
    for (int i = 0; i < MAX_WORDS; i++) taken[i] = false;

    for (int rank = 0; rank < topn; rank++) {
        long best = -1; int bi = -1;
        for (int i = 0; i < MAX_WORDS; i++) {
            if (!words[i].used || taken[i]) continue;
            if (words[i].count > best) { best = words[i].count; bi = i; }
        }
        if (bi < 0) break;
        taken[bi] = true;

        char[80] m; usz n = 0;
        n = put_long(m[..], n, (long)(rank + 1));
        n = put_str(m[..], n, ". ");
        n = put_str(m[..], n, wstr(&words[bi].word[0], words[bi].len));
        n = put_str(m[..], n, " — ");
        n = put_long(m[..], n, words[bi].count);
        api.client_send_msg(c, (String)m[0..n - 1]);
    }
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

fn void read_config() {
    void* f = fopen_c("config/config.toml", "r");
    if (f == null) f = fopen_c("../config/config.toml", "r");
    if (f == null) { io::printn("[word_cloud] No config.toml found, using defaults."); return; }
    char[512] line;
    bool in_section = false;
    while (fgets_c(&line[0], 512, f) != null) {
        String raw = cstr(&line[0]).trim();
        if (raw.len == 0 || raw[0] == '#') continue;
        if (raw[0] == '[') { in_section = (raw == "[word_cloud]"); continue; }
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
        if (key == "enabled")         { opt_enabled = is_true(val); }
        else if (key == "min_length") { int v = parse_uint(val); if (v > 0) opt_min_len = v; }
        else if (key == "track_ic")   { opt_track_ic = is_true(val); }
        else if (key == "track_ooc")  { opt_track_ooc = is_true(val); }
    }
    fclose_c(f);
}

// ============================================================
// Plugin interface (exported)
// ============================================================

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return {
        .name        = "Word Cloud",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Most-used-words analytics: /wordcloud. Optional.",
    };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    for (int i = 0; i < MAX_WORDS; i++) words[i].used = false;
    read_config();

    if (opt_track_ic)  api.register_hook("MS", &on_ms, PLUGIN_NAME);
    if (opt_track_ooc) api.register_hook("CT", &on_ct, PLUGIN_NAME);
    api.register_command("wordcloud", &cmd_wordcloud, 0, "Top N most-used words: /wordcloud [N]", PLUGIN_NAME);

    io::printfn("[word_cloud] Loaded. enabled=%s min_len=%d ic=%s ooc=%s",
        opt_enabled ? "on" : "off", opt_min_len,
        opt_track_ic ? "y" : "n", opt_track_ooc ? "y" : "n");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    io::printn("[word_cloud] Unloaded.");
}
