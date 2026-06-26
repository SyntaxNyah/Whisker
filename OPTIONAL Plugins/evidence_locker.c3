// Whisker Optional Plugin — Evidence Locker (v8) [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// CM/mod evidence management from OOC, demoing the whole v8 evidence API:
//   /eadd  <name>|<desc>|<image>         add_evidence
//   /eedit <id> <name>|<desc>|<image>    edit_evidence
//   /edel  <id>                          remove_evidence
//   /elist                               evidence_count + get_evidence
//
// LIFETIME: like the core's own PE handler, area_add_evidence / area_edit_evidence
// store the strings BY REFERENCE. User input lives in the packet buffer (freed
// after the command), so this plugin copies each field into a static RING of
// buffers and passes those stable slices. The ring holds the last RING entries;
// add more than that between restarts and the oldest backing memory is reused
// (documented trade-off for a demo — a production plugin would size to taste).

module evidence_locker;

import std::io;

// === Whisker v8 PluginAPI (standalone copy — see plugin.c3 for the canonical) ==
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
alias AreaSetNameFn           = fn void(int, String);
alias ClientSetHiddenFn       = fn void(void*, bool);
alias ClientGetPairFn         = fn int(void*);
alias ClientBanFn             = fn void(void*, String, int);
alias AreaAddEvidenceFn       = fn void(int, String, String, String);
alias AreaEditEvidenceFn      = fn void(int, int, String, String, String);
alias AreaRemoveEvidenceFn    = fn void(int, int);
alias AreaEvidenceCountFn     = fn int(int);
alias AreaGetEvidenceFn       = fn int(int, int, int, char*, int);
alias AreaPostIcFn            = fn void(int, String, String, String, String);
alias IcMsgFilter             = fn int(void*, String, char*, int);
alias RegisterIcFilterFn      = fn void(IcMsgFilter);
alias KvSetFn                 = fn void(String, String);
alias KvGetFn                 = fn int(String, char*, int);
alias KvDeleteFn              = fn void(String);
alias EventListener           = fn void(String, String);
alias EmitEventFn             = fn void(String, String);
alias RegisterEventListenerFn = fn void(EventListener);
struct PluginAPI {
    RegisterCommandFn   register_command;     RegisterHookFn      register_hook;
    FindClientFn        find_client;          BroadcastAreaMsgFn  broadcast_area_msg;
    BroadcastAreaRawFn  broadcast_area_raw;   BroadcastArupFn     broadcast_arup;
    GetAreaCountFn      get_area_count;        AreaIsCmFn          area_is_cm;
    AreaAddCmFn         area_add_cm;           AreaRemoveCmFn      area_remove_cm;
    AreaCmCountFn       area_cm_count;         AreaClearCmsFn      area_clear_cms;
    AreaUninviteFn      area_uninvite;         AreaSetStatusFn     area_set_status;
    AreaGetStatusFn     area_get_status;       AreaGetNameFn       area_get_name;
    AreaSetSongFn       area_set_song;         ForceMoveFn         force_move;
    ClientSendMsgFn     client_send_msg;       ClientSendRawFn     client_send_raw;
    ClientGetUidFn      client_get_uid;        ClientGetAreaFn     client_get_area;
    ClientIsModFn       client_is_mod;         ClientDisplayNameFn client_display_name;
    ClientGetCharIdFn   client_get_char_id;    ClientGetShownameFn client_get_showname;
    ClientGetCharNameFn client_get_char_name;  ClientIsJoinedFn    client_is_joined;
    ClientSetPositionFn client_set_position;   BroadcastAllMsgFn   broadcast_all_msg;
    BroadcastAllRawFn   broadcast_all_raw;     GetPlayerCountFn    get_player_count;
    GetAreaPlayerCountFn get_area_player_count; ClientGetIpidFn    client_get_ipid;
    PacketGetFieldFn    packet_get_field;      PacketGetFieldCountFn packet_get_field_count;
    ClientKickFn        client_kick;           ClientMuteFn        client_mute;
    ClientUnmuteFn      client_unmute;         AreaGetBackgroundFn area_get_background;
    AreaSetBackgroundFn area_set_background;   AreaGetLockFn       area_get_lock;
    AreaSetLockFn       area_set_lock;         AreaInviteFn        area_invite;
    ArgsSplitFn         args_split;            ToLowerFn           to_lower;
    RegisterLifecycleHookFn register_lifecycle_hook; ClientGetOocNameFn client_get_ooc_name;
    ClientIsHiddenFn    client_is_hidden;      ClientGetIpFn       client_get_ip;
    RegisterConnFilterFn register_conn_filter; BroadcastPermRawFn  broadcast_perm_raw;
    ClientSetStatusTagFn client_set_status_tag; ClientGetStatusTagFn client_get_status_tag;
    ClientKickMsgFn     client_kick_msg;       GetPluginCountFn    get_plugin_count;
    GetPluginNameFn     get_plugin_name;       GetPluginVersionFn  get_plugin_version;
    RegisterOutboundFilterFn register_outbound_filter; ClientGetHdidFn client_get_hdid;
    AreaSetHpFn         area_set_hp;
    // -- v8 --
    AreaSetNameFn       area_set_name;         ClientSetHiddenFn   client_set_hidden;
    ClientGetPairFn     client_get_pair;       ClientBanFn         client_ban;
    AreaAddEvidenceFn   area_add_evidence;     AreaEditEvidenceFn  area_edit_evidence;
    AreaRemoveEvidenceFn area_remove_evidence; AreaEvidenceCountFn area_evidence_count;
    AreaGetEvidenceFn   area_get_evidence;     AreaPostIcFn        area_post_ic;
    RegisterIcFilterFn  register_ic_filter;    KvSetFn             kv_set;
    KvGetFn             kv_get;                KvDeleteFn          kv_delete;
    EmitEventFn         emit_event;            RegisterEventListenerFn register_event_listener;
}
// ================================================================================

const String PLUGIN_NAME = "Evidence Locker";
const int    RING = 64;

PluginAPI* api;
char[128][RING] nbuf;
char[256][RING] dbuf;
char[256][RING] ibuf;
int ring_pos;

fn bool can_edit(void* c) {
    if (api.client_is_mod(c)) return true;
    return api.area_is_cm(api.client_get_area(c), api.client_get_uid(c));
}

// Copy n/d/i into a stable ring slot; return the stable slices via out-params.
fn void stash(String n, String d, String im, String* on, String* od, String* oi) {
    int slot = ring_pos;
    ring_pos = (ring_pos + 1) % RING;
    int nl = (int)n.len;  if (nl > 127) nl = 127;
    int dl = (int)d.len;  if (dl > 255) dl = 255;
    int il = (int)im.len; if (il > 255) il = 255;
    for (int i = 0; i < nl; i++) nbuf[slot][i] = n[i];
    for (int i = 0; i < dl; i++) dbuf[slot][i] = d[i];
    for (int i = 0; i < il; i++) ibuf[slot][i] = im[i];
    *on = nl > 0 ? (String)nbuf[slot][0..(usz)nl - 1] : "";
    *od = dl > 0 ? (String)dbuf[slot][0..(usz)dl - 1] : "";
    *oi = il > 0 ? (String)ibuf[slot][0..(usz)il - 1] : "";
}

// Split "a|b|c" (the trailing field captures any extra '|').
fn void pipe3(String s, String* a, String* b, String* cc) {
    *a = s; *b = ""; *cc = "";
    usz p1 = s.len;
    for (usz i = 0; i < s.len; i++) { if (s[i] == '|') { p1 = i; break; } }
    if (p1 == s.len) return;
    *a = p1 > 0 ? s[0..p1 - 1] : "";
    String tail = (p1 + 1 < s.len) ? s[p1 + 1..] : "";
    usz p2 = tail.len;
    for (usz i = 0; i < tail.len; i++) { if (tail[i] == '|') { p2 = i; break; } }
    if (p2 == tail.len) { *b = tail; return; }
    *b = p2 > 0 ? tail[0..p2 - 1] : "";
    *cc = (p2 + 1 < tail.len) ? tail[p2 + 1..] : "";
}

fn String cstr(char* buf, int n) { return n <= 0 ? "" : (String)buf[0..(usz)n - 1]; }

fn void eadd_body(void* c, String args) {
    if (!can_edit(c)) { api.client_send_msg(c, "Only CMs or mods can edit evidence here."); return; }
    String raw = args.trim();
    if (raw.len == 0) { api.client_send_msg(c, "Usage: /eadd <name>|<description>|<image.png>"); return; }
    String n, d, im;
    pipe3(raw, &n, &d, &im);
    String sn, sd, si;
    stash(n.trim(), d.trim(), im.trim(), &sn, &sd, &si);
    int area = api.client_get_area(c);
    api.area_add_evidence(area, sn, sd, si);
    api.client_send_msg(c, string::tformat("Evidence added: '%s' (now %d total).", sn, api.area_evidence_count(area)));
}
fn void cmd_eadd(void* c, String args) { @pool_init(mem, 64 * 1024) { eadd_body(c, args); }; }

fn void eedit_body(void* c, String args) {
    if (!can_edit(c)) { api.client_send_msg(c, "Only CMs or mods can edit evidence here."); return; }
    String a = args.trim();
    usz sp = a.len;
    for (usz i = 0; i < a.len; i++) { if (a[i] == ' ') { sp = i; break; } }
    if (sp == a.len) { api.client_send_msg(c, "Usage: /eedit <id> <name>|<description>|<image.png>"); return; }
    int id = (a[0..sp - 1].to_int()) ?? -1;
    String rest = (sp + 1 < a.len) ? a[sp + 1..] : "";
    if (id < 0 || rest.len == 0) { api.client_send_msg(c, "Usage: /eedit <id> <name>|<description>|<image.png>"); return; }
    String n, d, im;
    pipe3(rest, &n, &d, &im);
    String sn, sd, si;
    stash(n.trim(), d.trim(), im.trim(), &sn, &sd, &si);
    int area = api.client_get_area(c);
    api.area_edit_evidence(area, id, sn, sd, si);
    api.client_send_msg(c, string::tformat("Evidence #%d updated to '%s'.", id, sn));
}
fn void cmd_eedit(void* c, String args) { @pool_init(mem, 64 * 1024) { eedit_body(c, args); }; }

fn void edel_body(void* c, String args) {
    if (!can_edit(c)) { api.client_send_msg(c, "Only CMs or mods can edit evidence here."); return; }
    int id = (args.trim().to_int()) ?? -1;
    if (id < 0) { api.client_send_msg(c, "Usage: /edel <id>"); return; }
    int area = api.client_get_area(c);
    api.area_remove_evidence(area, id);
    api.client_send_msg(c, string::tformat("Evidence #%d removed (%d remain).", id, api.area_evidence_count(area)));
}
fn void cmd_edel(void* c, String args) { @pool_init(mem, 64 * 1024) { edel_body(c, args); }; }

fn void elist_body(void* c) {
    int area = api.client_get_area(c);
    int cnt = api.area_evidence_count(area);
    if (cnt == 0) { api.client_send_msg(c, "No evidence in this area."); return; }
    DString out = dstring::temp();
    out.append_string(string::tformat("Evidence in this area (%d):", cnt));
    for (int i = 0; i < cnt; i++) {
        char[256] nb;
        int nl = api.area_get_evidence(area, i, 0, &nb[0], 256);
        out.append_string(string::tformat("\n  %d. %s", i, cstr(&nb[0], nl)));
    }
    api.client_send_msg(c, out.str_view());
}
fn void cmd_elist(void* c, String args) { @pool_init(mem, 64 * 1024) { elist_body(c); }; }

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return { .name = "Evidence Locker", .version = "1.0.0", .author = "Whisker Community",
             .description = "/eadd /eedit /edel /elist — CM evidence tools. Demo of the v8 evidence API." };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    ring_pos = 0;
    api.register_command("eadd",  &cmd_eadd,  0, "Add evidence: /eadd <name>|<desc>|<image> (CM/mod)", PLUGIN_NAME);
    api.register_command("eedit", &cmd_eedit, 0, "Edit evidence: /eedit <id> <name>|<desc>|<image> (CM/mod)", PLUGIN_NAME);
    api.register_command("edel",  &cmd_edel,  0, "Remove evidence: /edel <id> (CM/mod)", PLUGIN_NAME);
    api.register_command("elist", &cmd_elist, 0, "List this area's evidence", PLUGIN_NAME);
    io::printn("[evidence_locker] Loaded. /eadd /eedit /edel /elist ready.");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    io::printn("[evidence_locker] Unloaded.");
}
