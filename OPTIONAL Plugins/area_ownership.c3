// Whisker Optional Plugin — Area Ownership [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Lets a player "own" an area: while an owner is present in their area they're
// automatically made a CM (Case Manager), so they control its lock, status, music,
// and background — their room, their rules — without a mod having to grant it each
// time. Ownership is keyed on IPID or HDID and persists across restarts. Drop the
// compiled .dll / .so into plugins/ and restart. Optional.
//
// This source file is provided as a learning exercise. To compile a C3 plugin
// yourself, follow the Plugin Dev Guide: plugins/PLUGIN DEV GUIDE README.md
//
// ============================================================
// What it does
// ============================================================
//
//   /claim          claim the current area if it's unowned   (players, if allowed)
//   /unclaim        give up an area you own                  (owner or mod)
//   /areaowner      show who owns the current area
//   /areaowner <uid>  assign that player as the owner        (mod)
//
// When an owner enters an area they own, they're auto-promoted to CM (the existing
// CM tooling then gives them lock/status/music/etc.). Owners are remembered by
// both IPID and HDID, so a reconnect still counts. Saved in config/area_owners.txt.
//
// > Identity note: the Plugin API exposes IPID and HDID (used here), but not
// > "accounts" — so ownership is by IPID/HDID, not by a login. (The optional
// > `case_manager` plugin should also be loaded so CMs have commands to use.)
//
// ============================================================
// Configuration — config/config.toml [area_ownership]
// ============================================================
//
//   allow_claim   true    # let players /claim unowned areas (false = mods assign only)
//   announce      true    # post an OOC line to the area when ownership changes
//
// ============================================================
// Why this is an OPTIONAL plugin — and (almost) zero cost
// ============================================================
//
// Persistent per-area ownership is a strong, opinionated model — great for a hub
// of personal rooms, wrong for a server where areas are shared/neutral — so it's
// opt-in. It has **no packet hooks**: it works off the lifecycle JOIN/UPDATE events
// and only does anything on a real area change (diffing each player's last area),
// where it does one ownership lookup. Nothing runs on the chat path.

module area_ownership;

import std::io;

// ============================================================
// Whisker plugin interface (standalone) — FULL v7 struct (uses client_get_hdid).
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
extern fn CInt  fputs_c(ZString s, void* stream) @cname("fputs");

const String PLUGIN_NAME = "Area Ownership";
const int MAX_AREAS   = 128;
const int MAX_PLAYERS = 1024;
const int ID_CAP      = 79;

const int EVENT_JOIN   = 0;
const int EVENT_LEAVE  = 1;
const int EVENT_UPDATE = 2;

PluginAPI* api;
bool opt_allow_claim = true;
bool opt_announce    = true;

// One owner per area, identified by IPID and/or HDID.
struct Owner { bool used; char[80] ipid; int ipidlen; char[80] hdid; int hdidlen; }
Owner[MAX_AREAS] owners;

// uid -> last known area (to act only on real area changes).
struct Pres { bool used; int uid; int area; }
Pres[MAX_PLAYERS] pres;

// ============================================================
// Helpers
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
fn String idstr(char* buf, int len) {
    if (len <= 0) return "";
    return (String)buf[0..len - 1];
}
fn String cstr(char* buf) {
    int len = 0;
    while (buf[len] != 0) len++;
    if (len == 0) return "";
    return (String)buf[0..len - 1];
}
fn bool is_true(String s) { return s == "true" || s == "1" || s == "yes" || s == "on"; }
fn void copy_id(String src, char* dst, int* outlen) {
    int n = (int)src.len; if (n > ID_CAP) n = ID_CAP;
    for (int i = 0; i < n; i++) dst[i] = src[i];
    *outlen = n;
}

fn bool has_owner(int area) {
    return area >= 0 && area < MAX_AREAS && owners[area].used;
}
fn bool is_owner(int area, String ipid, String hdid) {
    if (!has_owner(area)) return false;
    Owner* o = &owners[area];
    if (ipid.len > 0 && idstr(&o.ipid[0], o.ipidlen) == ipid) return true;
    if (hdid.len > 0 && idstr(&o.hdid[0], o.hdidlen) == hdid) return true;
    return false;
}
fn void set_owner(int area, String ipid, String hdid) {
    if (area < 0 || area >= MAX_AREAS) return;
    owners[area].used = true;
    copy_id(ipid, &owners[area].ipid[0], &owners[area].ipidlen);
    copy_id(hdid, &owners[area].hdid[0], &owners[area].hdidlen);
}
fn void clear_owner(int area) {
    if (area >= 0 && area < MAX_AREAS) owners[area].used = false;
}

// ============================================================
// Presence roster (for area-change detection)
// ============================================================

fn Pres* find_pres(int uid) {
    for (int i = 0; i < MAX_PLAYERS; i++) { if (pres[i].used && pres[i].uid == uid) return &pres[i]; }
    return null;
}
fn Pres* add_pres(int uid, int area) {
    Pres* e = find_pres(uid);
    if (e != null) { e.area = area; return e; }
    for (int i = 0; i < MAX_PLAYERS; i++) {
        if (!pres[i].used) { pres[i].used = true; pres[i].uid = uid; pres[i].area = area; return &pres[i]; }
    }
    return null;
}

// Promote an owner to CM of their area (idempotent — only if not already CM).
fn void maybe_cm(void* c, int area, int uid) {
    if (!has_owner(area)) return;
    if (is_owner(area, api.client_get_ipid(c), api.client_get_hdid(c))) {
        if (!api.area_is_cm(area, uid)) api.area_add_cm(area, uid);
    }
}

// ============================================================
// Lifecycle
// ============================================================

fn void on_life(void* c, int event) {
    int uid = api.client_get_uid(c);
    if (uid < 0) return;
    switch (event) {
        case EVENT_JOIN:
            int area = api.client_get_area(c);
            add_pres(uid, area);
            maybe_cm(c, area, uid);
        case EVENT_LEAVE:
            Pres* p = find_pres(uid);
            if (p != null) p.used = false;
        case EVENT_UPDATE:
            Pres* p2 = find_pres(uid);
            int na = api.client_get_area(c);
            if (p2 == null) { add_pres(uid, na); maybe_cm(c, na, uid); return; }
            if (na == p2.area) return;       // not an area change
            p2.area = na;
            maybe_cm(c, na, uid);
        default:
            break;
    }
}

// ============================================================
// Commands
// ============================================================

fn void announce(int area, String text) {
    if (!opt_announce) return;
    char[200] b; usz n = 0;
    n = put_str(b[..], n, "CT#");
    n = put_str(b[..], n, PLUGIN_NAME);
    n = put_str(b[..], n, "#");
    n = put_str(b[..], n, text);
    n = put_str(b[..], n, "#1#%");
    api.broadcast_area_raw(area, (String)b[0..n - 1]);
}

fn void cmd_claim(void* c, String args) {
    int area = api.client_get_area(c);
    if (area < 0 || area >= MAX_AREAS) return;
    if (!opt_allow_claim && !api.client_is_mod(c)) {
        api.client_send_msg(c, "Player claiming is disabled here — ask a moderator to assign ownership.");
        return;
    }
    int uid = api.client_get_uid(c);
    if (has_owner(area)) {
        if (is_owner(area, api.client_get_ipid(c), api.client_get_hdid(c))) {
            api.client_send_msg(c, "You already own this area.");
        } else {
            api.client_send_msg(c, "This area is already owned by someone else.");
        }
        return;
    }
    set_owner(area, api.client_get_ipid(c), api.client_get_hdid(c));
    save_owners();
    if (!api.area_is_cm(area, uid)) api.area_add_cm(area, uid);
    api.client_send_msg(c, "You now own this area — you're its CM whenever you're here.");
    announce(area, "This area has a new owner.");
}

fn void cmd_unclaim(void* c, String args) {
    int area = api.client_get_area(c);
    if (area < 0 || area >= MAX_AREAS) return;
    if (!has_owner(area)) { api.client_send_msg(c, "This area isn't owned."); return; }
    bool mine = is_owner(area, api.client_get_ipid(c), api.client_get_hdid(c));
    if (!mine && !api.client_is_mod(c)) { api.client_send_msg(c, "Only the owner or a moderator can release this area."); return; }
    clear_owner(area);
    save_owners();
    api.client_send_msg(c, "Area ownership released.");
    announce(area, "This area is no longer owned.");
}

fn void cmd_areaowner(void* c, String args) {
    int area = api.client_get_area(c);
    if (area < 0 || area >= MAX_AREAS) return;

    String a = args.trim();
    if (a.len > 0) {
        // assign: mod only
        if (!api.client_is_mod(c)) { api.client_send_msg(c, "Only a moderator can assign an owner."); return; }
        int uid = a.to_int() ?? -1;
        if (uid < 0) { api.client_send_msg(c, "Usage: /areaowner [uid]"); return; }
        void* t = api.find_client(uid);
        if (t == null) { api.client_send_msg(c, "No player with that UID is online."); return; }
        set_owner(area, api.client_get_ipid(t), api.client_get_hdid(t));
        save_owners();
        int tuid = api.client_get_uid(t);
        if (api.client_get_area(t) == area && !api.area_is_cm(area, tuid)) api.area_add_cm(area, tuid);
        char[160] m; usz n = 0;
        n = put_str(m[..], n, "Set ");
        n = put_str(m[..], n, api.client_display_name(t));
        n = put_str(m[..], n, " as the owner of this area.");
        api.client_send_msg(c, (String)m[0..n - 1]);
        announce(area, "This area has a new owner.");
        return;
    }

    // status
    if (!has_owner(area)) { api.client_send_msg(c, "This area is unowned. /claim it if you'd like."); return; }
    if (is_owner(area, api.client_get_ipid(c), api.client_get_hdid(c))) {
        api.client_send_msg(c, "You own this area.");
    } else if (api.client_is_mod(c)) {
        char[160] m; usz n = 0;
        n = put_str(m[..], n, "Owned by IPID ");
        n = put_str(m[..], n, idstr(&owners[area].ipid[0], owners[area].ipidlen));
        api.client_send_msg(c, (String)m[0..n - 1]);
    } else {
        api.client_send_msg(c, "This area is owned by another player.");
    }
}

// ============================================================
// Persistence — config/area_owners.txt   (area<TAB>ipid<TAB>hdid)
// ============================================================

fn void load_owners() {
    void* f = fopen_c("config/area_owners.txt", "r");
    if (f == null) f = fopen_c("../config/area_owners.txt", "r");
    if (f == null) return;
    char[256] line;
    while (fgets_c(&line[0], 256, f) != null) {
        String raw = cstr(&line[0]);
        usz end = raw.len;
        while (end > 0 && (raw[end - 1] == '\n' || raw[end - 1] == '\r')) end--;
        raw = end > 0 ? raw[0..end - 1] : "";
        if (raw.len == 0 || raw[0] == '#') continue;
        // split on tabs into up to 3 fields
        String[3] f3;
        int nf = 0; usz start = 0;
        for (usz i = 0; i <= raw.len; i++) {
            if (i == raw.len || raw[i] == '\t') {
                if (nf < 3) { f3[nf] = i > start ? raw[start..i - 1] : ""; nf++; }
                start = i + 1;
            }
        }
        if (nf < 2) continue;
        int area = f3[0].to_int() ?? -1;
        if (area < 0 || area >= MAX_AREAS) continue;
        String ipid = f3[1];
        String hdid = nf >= 3 ? f3[2] : "";
        set_owner(area, ipid, hdid);
    }
    fclose_c(f);
}

fn void save_owners() {
    void* f = fopen_c("config/area_owners.txt", "w");
    if (f == null) f = fopen_c("../config/area_owners.txt", "w");
    if (f == null) return;
    fputs_c((ZString)"# Whisker area owners (area<TAB>ipid<TAB>hdid). Auto-saved.\n", f);
    for (int a = 0; a < MAX_AREAS; a++) {
        if (!owners[a].used) continue;
        char[200] line; usz n = 0;
        n = put_int(line[..], n, a);
        n = put_str(line[..], n, "\t");
        n = put_str(line[..], n, idstr(&owners[a].ipid[0], owners[a].ipidlen));
        n = put_str(line[..], n, "\t");
        n = put_str(line[..], n, idstr(&owners[a].hdid[0], owners[a].hdidlen));
        n = put_str(line[..], n, "\n");
        line[n] = 0;
        fputs_c((ZString)&line[0], f);
    }
    fclose_c(f);
}

// ============================================================
// Config (config.toml [area_ownership])
// ============================================================

fn void read_config() {
    void* f = fopen_c("config/config.toml", "r");
    if (f == null) f = fopen_c("../config/config.toml", "r");
    if (f == null) return;
    char[512] line;
    bool in_section = false;
    while (fgets_c(&line[0], 512, f) != null) {
        String raw = cstr(&line[0]).trim();
        if (raw.len == 0 || raw[0] == '#') continue;
        if (raw[0] == '[') { in_section = (raw == "[area_ownership]"); continue; }
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
        if (key == "allow_claim")   { opt_allow_claim = is_true(val); }
        else if (key == "announce") { opt_announce = is_true(val); }
    }
    fclose_c(f);
}

// ============================================================
// Plugin interface (exported)
// ============================================================

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return {
        .name        = "Area Ownership",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Persistent per-area ownership (auto-CM for owners). Optional. Needs the v7 API.",
    };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    for (int i = 0; i < MAX_AREAS; i++) owners[i].used = false;
    for (int i = 0; i < MAX_PLAYERS; i++) pres[i].used = false;

    read_config();
    load_owners();

    api.register_lifecycle_hook(&on_life, PLUGIN_NAME);
    api.register_command("claim", &cmd_claim, 0, "Claim the current area if unowned", PLUGIN_NAME);
    api.register_command("unclaim", &cmd_unclaim, 0, "Release an area you own", PLUGIN_NAME);
    api.register_command("areaowner", &cmd_areaowner, 0, "Show/assign the current area's owner", PLUGIN_NAME);

    io::printfn("[area_ownership] Loaded. allow_claim=%s announce=%s",
        opt_allow_claim ? "on" : "off", opt_announce ? "on" : "off");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    save_owners();
    io::printn("[area_ownership] Saved + unloaded.");
}
