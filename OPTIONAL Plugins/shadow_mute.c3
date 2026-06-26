// Whisker Optional Plugin — Shadow Mute [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The perfect troll-handling tool. A moderator shadow-mutes a target: from then
// on the target's IC messages are echoed back to ONLY themselves — their own
// client shows their character talking normally, so they have no idea anything is
// wrong — while NOBODY ELSE in the room ever receives them. The troll thinks
// they're being calmly ignored and burns themselves out talking to an empty room.
// Drop the compiled .dll / .so into plugins/ and restart. Optional.
//
// This source file is provided as a learning exercise. To compile a C3 plugin
// yourself, follow the Plugin Dev Guide: plugins/PLUGIN DEV GUIDE README.md
//
// ============================================================
// What it does
// ============================================================
//
//   /shadowmute <uid>     shadow-mute a player        (mod — needs MUTE perm)
//   /unshadowmute <uid>   lift it                     (mod)
//   /shadowmutes          list who's shadow-muted     (mod)
//
// The target is never told. Their messages still appear on THEIR screen (so they
// don't realise and switch tactics); everyone else sees silence.
//
// ============================================================
// Configuration — config/config.toml [shadow_mute]
// ============================================================
//
//   sticky   true   re-apply the shadow mute automatically if the same IPID
//                    reconnects (so they can't escape by rejoining). The sticky
//                    list lives for the server run; a restart clears it.
//
// ============================================================
// Why this is an OPTIONAL plugin — and zero passive cost
// ============================================================
//
// Shadow-muting is a deliberately deceptive moderation style — some teams prefer
// an honest, visible mute and would never want this, so it's opt-in. Cost is
// effectively nil: one `MS` hook that does a tiny lookup and **returns instantly
// for everyone who isn't shadow-muted** (the normal case), so ordinary chat is
// untouched. Only a muted player's own messages take the echo path, and that's
// built allocation-free on the stack.
//
// ============================================================
// How the echo works (implementation note)
// ============================================================
//
// When a shadow-muted player sends `MS`, the hook consumes it (returns true, so
// no other plugin or the core ever broadcasts it) and rebuilds the *outgoing*
// relay form of that exact packet — the same field layout the core's handle_ms
// produces, with empty pairing fields — then sends it back to just the author
// with client_send_raw. So their client renders their line faithfully (character,
// emote, message, effects) while the area stays silent. See the Plugin Dev Guide
// note on emitting packets and on rebuilding `MS`.

module shadow_mute;

import std::io;

// ============================================================
// Whisker plugin interface (standalone) — v4 prefix (lifecycle + ipid + raw).
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
    AreaAddCmFn          area_add_cm;
    AreaRemoveCmFn       area_remove_cm;
    AreaCmCountFn        area_cm_count;
    AreaClearCmsFn       area_clear_cms;
    AreaUninviteFn       area_uninvite;
    AreaSetStatusFn      area_set_status;
    AreaGetStatusFn      area_get_status;
    AreaGetNameFn        area_get_name;
    AreaSetSongFn        area_set_song;
    ForceMoveFn          force_move;
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

const String PLUGIN_NAME = "Shadow Mute";
const ulong  PERM_MUTE   = 1;       // MUTE permission bit
const int    MAX_MUTED   = 256;

const int EVENT_JOIN  = 0;
const int EVENT_LEAVE = 1;

PluginAPI* api;
bool opt_sticky = true;

// ============================================================
// State: live sessions (by uid) + a sticky IPID set for reconnects.
// ============================================================

struct Active { bool used; int uid; char[80] ipid; int ipidlen; }
Active[MAX_MUTED] active;

struct Sticky { bool used; char[80] ipid; int ipidlen; }
Sticky[MAX_MUTED] sticky;

fn String astr(char* buf, int len) {
    if (len <= 0) return "";
    return (String)buf[0..len - 1];
}
fn void copy_ipid(String src, char* dst, int* outlen) {
    int n = (int)src.len; if (n > 79) n = 79;
    for (int i = 0; i < n; i++) dst[i] = src[i];
    *outlen = n;
}

fn bool is_active(int uid) {
    for (int i = 0; i < MAX_MUTED; i++) { if (active[i].used && active[i].uid == uid) return true; }
    return false;
}
fn bool add_active(int uid, String ipid) {
    if (is_active(uid)) return true;
    for (int i = 0; i < MAX_MUTED; i++) {
        if (!active[i].used) {
            active[i].used = true; active[i].uid = uid;
            copy_ipid(ipid, &active[i].ipid[0], &active[i].ipidlen);
            return true;
        }
    }
    return false;
}
// Remove a uid from the live set; returns its IPID (or "") so the caller can
// also clear the sticky entry.
fn String remove_active(int uid) {
    for (int i = 0; i < MAX_MUTED; i++) {
        if (active[i].used && active[i].uid == uid) {
            String ip = astr(&active[i].ipid[0], active[i].ipidlen);
            active[i].used = false;
            return ip;
        }
    }
    return "";
}

fn bool sticky_has(String ipid) {
    if (ipid.len == 0) return false;
    for (int i = 0; i < MAX_MUTED; i++) {
        if (sticky[i].used && astr(&sticky[i].ipid[0], sticky[i].ipidlen) == ipid) return true;
    }
    return false;
}
fn void sticky_add(String ipid) {
    if (ipid.len == 0 || sticky_has(ipid)) return;
    for (int i = 0; i < MAX_MUTED; i++) {
        if (!sticky[i].used) {
            sticky[i].used = true;
            copy_ipid(ipid, &sticky[i].ipid[0], &sticky[i].ipidlen);
            return;
        }
    }
}
fn void sticky_remove(String ipid) {
    if (ipid.len == 0) return;
    for (int i = 0; i < MAX_MUTED; i++) {
        if (sticky[i].used && astr(&sticky[i].ipid[0], sticky[i].ipidlen) == ipid) { sticky[i].used = false; }
    }
}

fn int active_count() {
    int n = 0;
    for (int i = 0; i < MAX_MUTED; i++) { if (active[i].used) n++; }
    return n;
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

// ============================================================
// Rebuild the outgoing (relay-form) MS and send it only to the author.
// Mirrors handle_ms with no pair partner: fields 0-15, then 6 pairing fields,
// then the client's trailing fields (18+).
// ============================================================

fn void echo_self(void* c, void* pkt) {
    int count = api.packet_get_field_count(pkt);
    char[4096] b; usz n = 0;
    n = put_str(b[..], n, "MS");

    int fwd = count < 16 ? count : 16;
    for (int i = 0; i < fwd; i++) {
        n = put_str(b[..], n, "#");
        n = put_escaped(b[..], n, api.packet_get_field(pkt, i));
    }

    n = put_str(b[..], n, "#-1");   // 16: other_charid (no partner)
    n = put_str(b[..], n, "#");     // 17: other_name   (empty)
    n = put_str(b[..], n, "#");     // 18: other_emote  (empty)
    n = put_str(b[..], n, "#");     // 19: self_offset
    if (count > 17) { n = put_escaped(b[..], n, api.packet_get_field(pkt, 17)); }
    else { n = put_str(b[..], n, "0&0"); }
    n = put_str(b[..], n, "#0&0");  // 20: other_offset
    n = put_str(b[..], n, "#0");    // 21: other_flip

    for (int i = 18; i < count; i++) {
        n = put_str(b[..], n, "#");
        n = put_escaped(b[..], n, api.packet_get_field(pkt, i));
    }

    n = put_str(b[..], n, "#%");
    api.client_send_raw(c, (String)b[0..n - 1]);
}

// ============================================================
// MS hook — the silent treatment
// ============================================================

fn bool on_ms(void* c, void* pkt) {
    int uid = api.client_get_uid(c);
    if (uid < 0) return false;
    if (!is_active(uid)) return false;     // normal path: instant return
    echo_self(c, pkt);                      // they see their own line…
    return true;                            // …nobody else does
}

// ============================================================
// Lifecycle — sticky re-apply on join, cleanup on leave
// ============================================================

fn void on_life(void* c, int event) {
    int uid = api.client_get_uid(c);
    if (uid < 0) return;
    if (event == EVENT_JOIN) {
        if (opt_sticky && sticky_has(api.client_get_ipid(c))) {
            add_active(uid, api.client_get_ipid(c));
        }
    } else if (event == EVENT_LEAVE) {
        remove_active(uid);   // free the slot; sticky set is kept for reconnects
    }
}

// ============================================================
// Commands
// ============================================================

fn void cmd_shadowmute(void* c, String args) {
    int uid = args.trim().to_int() ?? -1;
    if (uid < 0) { api.client_send_msg(c, "Usage: /shadowmute <uid>"); return; }

    void* t = api.find_client(uid);
    if (t == null) { api.client_send_msg(c, "No player with that UID is online."); return; }
    if (api.client_is_mod(t)) { api.client_send_msg(c, "You can't shadow-mute another moderator."); return; }

    if (is_active(uid)) { api.client_send_msg(c, "That player is already shadow-muted."); return; }

    String ipid = api.client_get_ipid(t);
    add_active(uid, ipid);
    if (opt_sticky) sticky_add(ipid);

    char[160] m; usz n = 0;
    n = put_str(m[..], n, "Shadow-muted ");
    n = put_str(m[..], n, api.client_display_name(t));
    n = put_str(m[..], n, " (UID ");
    n = put_int(m[..], n, uid);
    n = put_str(m[..], n, "). They don't know.");
    api.client_send_msg(c, (String)m[0..n - 1]);
}

fn void cmd_unshadowmute(void* c, String args) {
    int uid = args.trim().to_int() ?? -1;
    if (uid < 0) { api.client_send_msg(c, "Usage: /unshadowmute <uid>"); return; }

    if (!is_active(uid)) { api.client_send_msg(c, "That UID isn't shadow-muted right now."); return; }
    String ip = remove_active(uid);
    sticky_remove(ip);
    api.client_send_msg(c, "Shadow mute lifted.");
}

fn void cmd_shadowmutes(void* c, String args) {
    char[80] m; usz n = 0;
    n = put_str(m[..], n, "Shadow-muted right now: ");
    n = put_int(m[..], n, active_count());
    n = put_str(m[..], n, " player(s).");
    api.client_send_msg(c, (String)m[0..n - 1]);
}

// ============================================================
// Config
// ============================================================

fn bool is_true(String s) { return s == "true" || s == "1" || s == "yes" || s == "on"; }

fn void read_config() {
    void* f = fopen_c("config/config.toml", "r");
    if (f == null) f = fopen_c("../config/config.toml", "r");
    if (f == null) { io::printn("[shadow_mute] No config.toml found, using defaults."); return; }
    char[512] line;
    bool in_section = false;
    while (fgets_c(&line[0], 512, f) != null) {
        String raw = cstr(&line[0]).trim();
        if (raw.len == 0 || raw[0] == '#') continue;
        if (raw[0] == '[') { in_section = (raw == "[shadow_mute]"); continue; }
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
        if (key == "sticky") { opt_sticky = is_true(val); }
    }
    fclose_c(f);
    io::printn("[shadow_mute] Config loaded from config.toml.");
}

// ============================================================
// Plugin interface (exported)
// ============================================================

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return {
        .name        = "Shadow Mute",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Echo a troll's IC back to only themselves. Optional — see header.",
    };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    for (int i = 0; i < MAX_MUTED; i++) { active[i].used = false; sticky[i].used = false; }
    read_config();

    api.register_hook("MS", &on_ms, PLUGIN_NAME);
    api.register_lifecycle_hook(&on_life, PLUGIN_NAME);
    api.register_command("shadowmute", &cmd_shadowmute, PERM_MUTE, "Shadow-mute a player (mod)", PLUGIN_NAME);
    api.register_command("unshadowmute", &cmd_unshadowmute, PERM_MUTE, "Lift a shadow mute (mod)", PLUGIN_NAME);
    api.register_command("shadowmutes", &cmd_shadowmutes, PERM_MUTE, "How many are shadow-muted (mod)", PLUGIN_NAME);

    io::printfn("[shadow_mute] Loaded. /shadowmute ready (sticky=%s).", opt_sticky ? "on" : "off");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    io::printn("[shadow_mute] Unloaded.");
}
