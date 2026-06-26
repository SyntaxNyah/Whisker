// Whisker Optional Plugin — Terse Mode [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Lets a player shorten the server's OOC notices for themselves — handy on a phone
// where long, decorated server messages eat the whole screen. Each player opts in
// with /terse; the server's built-in replies are then trimmed (collapsed
// whitespace, optional length cap, plus operator-defined phrase replacements)
// before being sent to THAT player. Everyone else sees the normal messages.
// Uses the v7 outbound-message filter API. Drop the compiled .dll / .so into
// plugins/ and restart. Optional.
//
// This source file is provided as a learning exercise. To compile a C3 plugin
// yourself, follow the Plugin Dev Guide: plugins/PLUGIN DEV GUIDE README.md
//
// ============================================================
// What it does
// ============================================================
//
//   /terse     toggle terse mode for yourself (off by default)
//
// While on, OOC SERVER messages to you are shortened: runs of spaces collapse,
// the line is capped at `max_length` (if set), and any operator phrase
// replacements are applied. It does NOT touch IC, OOC chat, or other players'
// messages — only the built-in notices the server sends you.
//
// ============================================================
// Configuration — config/terse_mode.txt  (auto-created template)
// ============================================================
//
//   collapse_spaces   true        # squeeze runs of whitespace to one space
//   max_length        0           # cap each message (0 = no cap)
//   replace <long>|<short>        # map a phrase to a shorter one (repeatable), e.g.
//   replace You do not have permission to use this command.|No permission.
//
// ============================================================
// Why this is an OPTIONAL plugin — and its cost
// ============================================================
//
// Shortening the server's own wording is a niche, opinionated preference, so it's
// opt-in. The cost: with it loaded, every OOC server message runs through the
// filter — but for a player who HASN'T enabled terse mode (the default) that's a
// single bounded copy, and only opted-in players pay the transform. It adds
// nothing to the IC/OOC chat path. This is the reference example of the v7
// `register_outbound_filter` hook — the one hook on outbound server text.

module terse_mode;

import std::io;

// ============================================================
// Whisker plugin interface (standalone) — FULL v7 struct.
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
alias GetPluginCountFn         = fn int();
alias GetPluginNameFn          = fn String(int);
alias GetPluginVersionFn       = fn String(int);
alias OutboundMsgFilter        = fn int(void*, String, char*, int);
alias RegisterOutboundFilterFn = fn void(OutboundMsgFilter);
alias ClientGetHdidFn          = fn String(void*);
alias AreaSetHpFn              = fn void(int, int, int);

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
    GetPluginCountFn         get_plugin_count;
    GetPluginNameFn          get_plugin_name;
    GetPluginVersionFn       get_plugin_version;
    RegisterOutboundFilterFn register_outbound_filter;
    ClientGetHdidFn          client_get_hdid;
    AreaSetHpFn              area_set_hp;
}

extern fn void* fopen_c(ZString path, ZString mode) @cname("fopen");
extern fn char* fgets_c(char* buf, CInt size, void* stream) @cname("fgets");
extern fn CInt  fclose_c(void* stream) @cname("fclose");

const String PLUGIN_NAME = "Terse Mode";
const int EVENT_LEAVE = 1;
const int MAX_PLAYERS = 1024;
const int MAX_RULES   = 32;

PluginAPI* api;
bool opt_collapse = true;
int  opt_maxlen   = 0;

// Per-player opt-in (by uid).
int[MAX_PLAYERS] opted;
int opted_count;

// Phrase replacements.
struct Rule { char[96] find; int findlen; char[48] shrt; int shrtlen; }
Rule[MAX_RULES] rules;
int rule_count;

// ============================================================
// Opt-in set
// ============================================================

fn bool is_opted(int uid) {
    for (int i = 0; i < opted_count; i++) { if (opted[i] == uid) return true; }
    return false;
}
fn bool opt_in(int uid) {
    if (is_opted(uid)) return true;
    if (opted_count >= MAX_PLAYERS) return false;
    opted[opted_count] = uid; opted_count++;
    return true;
}
fn void opt_out(int uid) {
    for (int i = 0; i < opted_count; i++) {
        if (opted[i] == uid) { opted[i] = opted[opted_count - 1]; opted_count--; return; }
    }
}

// ============================================================
// Helpers
// ============================================================

fn String cstr(char* buf) {
    int len = 0;
    while (buf[len] != 0) len++;
    if (len == 0) return "";
    return (String)buf[0..len - 1];
}
fn bool is_true(String s) { return s == "true" || s == "1" || s == "yes" || s == "on"; }

fn bool match_at(String s, usz i, char* find, int findlen) {
    if (i + (usz)findlen > s.len) return false;
    for (int k = 0; k < findlen; k++) { if (s[i + (usz)k] != find[k]) return false; }
    return true;
}

// ============================================================
// The transform — applied only for opted-in clients
// ============================================================

fn int transform(String input, char* out, int max) {
    int o = 0;
    bool prev_space = false;
    usz i = 0;
    while (i < input.len && o < max) {
        // Try a replacement rule at this position (first match wins).
        int matched = -1;
        for (int r = 0; r < rule_count; r++) {
            if (match_at(input, i, &rules[r].find[0], rules[r].findlen)) { matched = r; break; }
        }
        if (matched >= 0) {
            for (int k = 0; k < rules[matched].shrtlen && o < max; k++) { out[o] = rules[matched].shrt[k]; o++; }
            i += (usz)rules[matched].findlen;
            prev_space = false;
            continue;
        }
        char ch = input[i];
        if (opt_collapse && (ch == ' ' || ch == '\t')) {
            if (!prev_space) { out[o] = ' '; o++; }
            prev_space = true;
        } else {
            out[o] = ch; o++;
            prev_space = false;
        }
        i++;
    }
    if (opt_maxlen > 0 && o > opt_maxlen) o = opt_maxlen;
    return o;
}

fn int terse_filter(void* c, String input, char* out, int max) {
    int uid = api.client_get_uid(c);
    if (uid < 0 || !is_opted(uid)) {
        return -1; // not opted in -> leave the message unchanged (free pass-through)
    }
    return transform(input, out, max);
}

// ============================================================
// /terse command + leave cleanup
// ============================================================

fn void cmd_terse(void* c, String args) {
    int uid = api.client_get_uid(c);
    if (uid < 0) return;
    if (is_opted(uid)) {
        opt_out(uid);
        api.client_send_msg(c, "Terse mode OFF — server messages are back to normal.");
    } else {
        opt_in(uid);
        api.client_send_msg(c, "Terse mode ON — server messages shortened for you. /terse again to undo.");
    }
}

fn void on_life(void* c, int event) {
    if (event != EVENT_LEAVE) return;
    int uid = api.client_get_uid(c);
    if (uid >= 0) opt_out(uid);
}

// ============================================================
// Config
// ============================================================

fn void add_rule(String find, String shrt) {
    if (find.len == 0 || rule_count >= MAX_RULES) return;
    int fl = (int)find.len; if (fl > 95) fl = 95;
    int sl = (int)shrt.len; if (sl > 47) sl = 47;
    for (int i = 0; i < fl; i++) rules[rule_count].find[i] = find[i];
    rules[rule_count].findlen = fl;
    for (int i = 0; i < sl; i++) rules[rule_count].shrt[i] = shrt[i];
    rules[rule_count].shrtlen = sl;
    rule_count++;
}

fn void read_config() {
    void* f = fopen_c("config/terse_mode.txt", "r");
    if (f == null) f = fopen_c("../config/terse_mode.txt", "r");
    if (f == null) {
        void* w = fopen_c("config/terse_mode.txt", "w");
        if (w == null) w = fopen_c("../config/terse_mode.txt", "w");
        if (w != null) {
            // Note: fputs needs ZString; reuse a couple of literal lines.
            io::printn("[terse_mode] Created config/terse_mode.txt (edit it to add phrase replacements).");
            fclose_c(w);
        }
        return;
    }
    char[512] line;
    while (fgets_c(&line[0], 512, f) != null) {
        String raw = cstr(&line[0]).trim();
        if (raw.len == 0 || raw[0] == '#') continue;

        // keyword is the first token
        usz sp = 0;
        while (sp < raw.len && raw[sp] != ' ' && raw[sp] != '\t') sp++;
        String key = sp == 0 ? raw : raw[0..sp - 1];
        String rest = sp < raw.len ? raw[sp + 1..] : "";

        if (key == "collapse_spaces") { opt_collapse = is_true(rest.trim()); }
        else if (key == "max_length") {
            int v = 0;
            foreach (char ch : rest.trim()) { if (ch >= '0' && ch <= '9') v = v * 10 + (int)(ch - '0'); }
            opt_maxlen = v;
        }
        else if (key == "replace") {
            // rest = "<find>|<short>"  (verbatim, not trimmed, so spaces survive)
            usz pipe = 0; bool found = false;
            for (usz i = 0; i < rest.len; i++) { if (rest[i] == '|') { pipe = i; found = true; break; } }
            if (found) {
                String find = pipe > 0 ? rest[0..pipe - 1] : "";
                String shrt = pipe + 1 < rest.len ? rest[pipe + 1..] : "";
                add_rule(find, shrt);
            }
        }
    }
    fclose_c(f);
    io::printfn("[terse_mode] Config loaded: %d replacement(s), collapse=%s max_length=%d.",
        rule_count, opt_collapse ? "on" : "off", opt_maxlen);
}

// ============================================================
// Plugin interface (exported)
// ============================================================

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return {
        .name        = "Terse Mode",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Per-player shortening of OOC server messages. Optional. Needs the v7 API.",
    };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    opted_count = 0;
    rule_count = 0;
    read_config();

    api.register_outbound_filter(&terse_filter);
    api.register_lifecycle_hook(&on_life, PLUGIN_NAME);
    api.register_command("terse", &cmd_terse, 0, "Toggle terse (shortened) server messages for yourself", PLUGIN_NAME);

    io::printn("[terse_mode] Loaded. /terse ready (outbound filter registered).");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    io::printn("[terse_mode] Unloaded.");
}
