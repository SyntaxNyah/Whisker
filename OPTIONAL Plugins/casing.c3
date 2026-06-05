// Whisker Optional Plugin — Casing [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A standalone plugin (.dll / .so) that adds Attorney Online 2 casing
// commands to Whisker. Inspired by Akashi and Nyathena's casing systems.
//
// Drop the compiled .dll or .so into your server's plugins/ folder
// and restart. No configuration needed.
//
// This source file is provided as a learning exercise — if you want
// to try compiling a C3 plugin yourself, follow the Plugin Dev Guide:
//   plugins/PLUGIN DEV GUIDE README.md
//
// Features:
//   - Full testimony recording and cross-examination playback
//   - Case documents
//   - Notecards (hidden until revealed by CM)
//   - Global case advertisements (/need)
//   - WT/CE blocking per player
//   - Judge action log
//
// Commands (16 total):
//
//   Testimony:
//     /testify           — Start recording testimony (CM/mod)
//     /examine           — Begin cross-examination playback
//     /pause             — Stop recording or playback (CM/mod)
//     /testimony         — View recorded testimony statements
//     /add               — Insert statement after current (CM/mod, during CE)
//     /update            — Replace current statement (CM/mod, during CE)
//     /delete            — Delete current statement (CM/mod, during CE)
//
//   Case Utility:
//     /doc [text]        — Get or set the area's case document
//     /cleardoc          — Clear the document (CM/mod)
//     /need <message>    — Broadcast server-wide case advertisement
//
//   Notecards:
//     /notecard <text>   — Write a hidden notecard
//     /notecardreveal    — Reveal all notecards (CM/mod)
//     /notecardclear     — Clear your notecard
//
//   WT/CE Control:
//     /blockwtce <uid>   — Block a player from using WT/CE (CM/mod)
//     /unblockwtce <uid> — Unblock a player (CM/mod)
//     /judgelog           — View recent judge actions (CM/mod)
//
// Hooks:
//   - MS (IC message): testimony recording and cross-examination playback
//   - RT (WT/CE animation): WT/CE blocking enforcement + judge log
//   - HP (penalty bars): judge log

module casing;

import std::io;

// ============================================================
// Whisker plugin interface (standalone definitions)
// ============================================================
//
// Must match the server's definitions exactly. Copied from
// case_manager.c3 — the canonical standalone plugin reference.

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

struct PluginAPI {
    // Registration
    RegisterCommandFn   register_command;
    RegisterHookFn      register_hook;

    // Server
    FindClientFn        find_client;
    BroadcastAreaMsgFn  broadcast_area_msg;
    BroadcastAreaRawFn  broadcast_area_raw;
    BroadcastArupFn     broadcast_arup;
    GetAreaCountFn      get_area_count;

    // Area
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

    // Client
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
    ArgsSplitFn           args_split;  // appended — see server's plugin.c3
    ToLowerFn             to_lower;    // appended after args_split — same ABI rule
}

// ============================================================
// Constants
// ============================================================

const int MAX_AREAS       = 128;
const int MAX_STATEMENTS  = 30;
const int MAX_STMT_LEN    = 2048;  // raw MS packet for replay
const int MAX_DISPLAY_LEN = 256;   // message text for /testimony
const int MAX_NOTECARDS   = 32;
const int MAX_NC_LEN      = 256;
const int MAX_DOC_LEN     = 512;
const int MAX_BLOCKED     = 32;
const int MAX_LOG         = 10;
const int MAX_LOG_LEN     = 256;

// Testimony state machine
const int TS_IDLE      = 0;
const int TS_RECORDING = 1;
const int TS_PLAYBACK  = 2;
const int TS_UPDATE    = 3;
const int TS_ADD       = 4;

// ============================================================
// Data types
// ============================================================

struct Statement {
    char[MAX_STMT_LEN]    packet;   // raw outgoing MS packet for replay
    char[MAX_DISPLAY_LEN] display;  // unescaped message text for /testimony
    int pkt_len;
}

struct Notecard {
    int  uid;
    char[MAX_NC_LEN] text;
    bool used;
}

struct LogEntry {
    char[MAX_LOG_LEN] text;
}

struct AreaCasing {
    // Testimony
    int tstate;
    Statement[MAX_STATEMENTS] stmts;
    int stmt_count;
    int stmt_index;

    // Document
    char[MAX_DOC_LEN] doc;
    bool has_doc;

    // Notecards
    Notecard[MAX_NOTECARDS] cards;
    int card_count;

    // WT/CE blocks
    int[MAX_BLOCKED] blocked;
    int blocked_count;

    // Judge log (ring buffer)
    LogEntry[MAX_LOG] jlog;
    int jlog_count;
    int jlog_start;
}

// ============================================================
// Plugin state
// ============================================================

AreaCasing[MAX_AREAS] areas;
PluginAPI* api;

// ============================================================
// Plugin interface (exported)
// ============================================================

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return {
        .name        = "Casing",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Casing commands: testimony, notecards, WT/CE control",
    };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;

    // -- Testimony --
    api.register_command("testify", &cmd_testify, 0,
        "Start recording testimony (CM/mod)", "Casing");
    api.register_command("examine", &cmd_examine, 0,
        "Begin cross-examination", "Casing");
    api.register_command("pause", &cmd_pause, 0,
        "Stop recording/playback (CM/mod)", "Casing");
    api.register_command("testimony", &cmd_testimony, 0,
        "View recorded testimony", "Casing");
    api.register_command("add", &cmd_add, 0,
        "Insert statement after current (CM/mod)", "Casing");
    api.register_command("update", &cmd_update, 0,
        "Replace current statement (CM/mod)", "Casing");
    api.register_command("delete", &cmd_delete, 0,
        "Delete current statement (CM/mod)", "Casing");

    // -- Case utility --
    api.register_command("doc", &cmd_doc, 0,
        "Get/set case document", "Casing");
    api.register_command("cleardoc", &cmd_cleardoc, 0,
        "Clear case document (CM/mod)", "Casing");
    api.register_command("need", &cmd_need, 0,
        "Broadcast case advertisement (CM/mod)", "Casing");

    // -- Notecards --
    api.register_command("notecard", &cmd_notecard, 0,
        "Write a hidden notecard", "Casing");
    api.register_command("notecardreveal", &cmd_notecardreveal, 0,
        "Reveal all notecards (CM/mod)", "Casing");
    api.register_command("notecardclear", &cmd_notecardclear, 0,
        "Clear your notecard", "Casing");

    // -- WT/CE control --
    api.register_command("blockwtce", &cmd_blockwtce, 0,
        "Block player from WT/CE controls (CM/mod)", "Casing");
    api.register_command("unblockwtce", &cmd_unblockwtce, 0,
        "Unblock player WT/CE controls (CM/mod)", "Casing");
    api.register_command("judgelog", &cmd_judgelog, 0,
        "View recent judge actions (CM/mod)", "Casing");

    // -- Hooks --
    api.register_hook("MS", &on_ic_message, "Casing");
    api.register_hook("RT", &on_rt_packet,  "Casing");
    api.register_hook("HP", &on_hp_packet,  "Casing");

    io::printn("[casing] Casing plugin loaded (16 commands, 3 hooks).");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    io::printn("[casing] Casing plugin unloaded.");
}

// ============================================================
// Helpers
// ============================================================

fn bool is_cm_or_mod(void* c) {
    return api.area_is_cm(api.client_get_area(c), api.client_get_uid(c))
        || api.client_is_mod(c);
}

fn AreaCasing* get_ac(int area_id) {
    if (area_id < 0 || area_id >= MAX_AREAS) return null;
    return &areas[area_id];
}

fn void copy_to_buf(char* dst, String src, int max_len) {
    if (max_len <= 0) return;
    int n = (int)src.len < max_len - 1 ? (int)src.len : max_len - 1;
    for (int i = 0; i < n; i++) {
        dst[i] = src[i];
    }
    dst[n] = 0;
}

fn String buf_to_str(char* buf) {
    int len = 0;
    while (buf[len] != 0) len++;
    if (len == 0) return "";
    return (String)buf[0..len - 1];
}

fn bool is_wtce_blocked(AreaCasing* ac, int uid) {
    for (int i = 0; i < ac.blocked_count; i++) {
        if (ac.blocked[i] == uid) return true;
    }
    return false;
}

fn void add_judge_log(AreaCasing* ac, String entry) {
    int idx;
    if (ac.jlog_count < MAX_LOG) {
        idx = ac.jlog_count;
        ac.jlog_count++;
    } else {
        idx = ac.jlog_start;
        ac.jlog_start = (ac.jlog_start + 1) % MAX_LOG;
    }
    copy_to_buf(&ac.jlog[idx].text[0], entry, MAX_LOG_LEN);
}

// ============================================================
// Testimony helpers
// ============================================================

// Escape special AO2 characters for wire format
fn void escape_append(DString buf, String s) {
    foreach (char ch : s) {
        switch (ch) {
            case '#':  buf.append_string("<num>");
            case '&':  buf.append_string("<and>");
            case '%':  buf.append_string("<percent>");
            case '$':  buf.append_string("<dollar>");
            default:   buf.append_char(ch);
        }
    }
}

// Build an outgoing MS packet from incoming fields, with empty pairing data.
// The server normally inserts 4 pairing fields (other_name, other_emote,
// other_offset, other_flip) after field 17 (self_offset). For testimony
// replay there is no pair, so we insert 4 empty fields.
fn void build_statement(Statement* stmt, void* pkt) {
    int fc = api.packet_get_field_count(pkt);

    // Store display text (field 4 = IC message)
    if (fc > 4) {
        copy_to_buf(&stmt.display[0], api.packet_get_field(pkt, 4), MAX_DISPLAY_LEN);
    } else {
        stmt.display[0] = 0;
    }

    // Build outgoing MS packet
    DString buf = dstring::temp();
    buf.append_string("MS");

    // Fields 0-17 from incoming
    int n = fc < 18 ? fc : 18;
    for (int i = 0; i < n; i++) {
        buf.append_char('#');
        escape_append(buf, api.packet_get_field(pkt, i));
    }
    // Pad if fewer than 18 fields
    for (int i = n; i < 18; i++) {
        buf.append_string("#");
    }

    // 4 empty pairing fields (other_name, other_emote, other_offset, other_flip)
    buf.append_string("####");

    // Remaining fields (incoming 18+)
    for (int i = 18; i < fc; i++) {
        buf.append_char('#');
        escape_append(buf, api.packet_get_field(pkt, i));
    }

    buf.append_string("#%");

    String raw = buf.str_view();
    copy_to_buf(&stmt.packet[0], raw, MAX_STMT_LEN);
    stmt.pkt_len = (int)raw.len < MAX_STMT_LEN - 1 ? (int)raw.len : MAX_STMT_LEN - 1;
}

fn void store_statement(AreaCasing* ac, void* pkt) {
    if (ac.stmt_count >= MAX_STATEMENTS) return;
    build_statement(&ac.stmts[ac.stmt_count], pkt);
    ac.stmt_count++;
}

fn void replace_statement(AreaCasing* ac, int idx, void* pkt) {
    if (idx < 0 || idx >= ac.stmt_count) return;
    build_statement(&ac.stmts[idx], pkt);
}

fn void insert_statement(AreaCasing* ac, int at_idx, void* pkt) {
    if (ac.stmt_count >= MAX_STATEMENTS) return;
    if (at_idx > ac.stmt_count) at_idx = ac.stmt_count;

    // Shift statements from at_idx onward to make room
    for (int i = ac.stmt_count; i > at_idx; i--) {
        // Copy packet data
        for (int j = 0; j < MAX_STMT_LEN; j++) {
            ac.stmts[i].packet[j] = ac.stmts[i - 1].packet[j];
        }
        // Copy display text
        for (int j = 0; j < MAX_DISPLAY_LEN; j++) {
            ac.stmts[i].display[j] = ac.stmts[i - 1].display[j];
        }
        ac.stmts[i].pkt_len = ac.stmts[i - 1].pkt_len;
    }

    build_statement(&ac.stmts[at_idx], pkt);
    ac.stmt_count++;
}

fn void replay_statement(int area_id, AreaCasing* ac) {
    if (ac.stmt_index < 0 || ac.stmt_index >= ac.stmt_count) return;
    String raw = buf_to_str(&ac.stmts[ac.stmt_index].packet[0]);
    if (raw.len > 0) {
        api.broadcast_area_raw(area_id, raw);
    }
}

// ============================================================
// Hooks
// ============================================================

// MS hook — handles testimony recording and cross-examination playback.
// During RECORDING: stores each IC message as a testimony statement.
// During PLAYBACK:  consumes the IC message and replays the next statement.
// During UPDATE:    replaces the current statement with the new IC message.
// During ADD:       inserts a new statement after the current position.
fn bool on_ic_message(void* c, void* pkt) {
    int area_id = api.client_get_area(c);
    AreaCasing* ac = get_ac(area_id);
    if (ac == null || ac.tstate == TS_IDLE) return false;

    // Safety: auto-pause if no CMs remain and sender is not a mod
    if (api.area_cm_count(area_id) == 0 && !api.client_is_mod(c)) {
        ac.tstate = TS_IDLE;
        api.broadcast_area_msg(area_id, "[Testimony] Auto-paused — no CMs in area.");
        return false;
    }

    switch (ac.tstate) {
        case TS_RECORDING:
            if (ac.stmt_count >= MAX_STATEMENTS) {
                api.client_send_msg(c, "Maximum statements reached. Use /pause to stop.");
                return false;
            }
            store_statement(ac, pkt);
            api.broadcast_area_msg(area_id,
                string::tformat("[Testimony] Statement %d recorded.", ac.stmt_count));
            return false;  // let the IC message through normally

        case TS_PLAYBACK:
            ac.stmt_index++;
            if (ac.stmt_index >= ac.stmt_count) {
                ac.stmt_index = 0;
                // Re-send Cross-Examination splash on wrap
                api.broadcast_area_raw(area_id, "RT#testimony2#%");
            }
            replay_statement(area_id, ac);
            return true;  // consume the original IC message

        case TS_UPDATE:
            replace_statement(ac, ac.stmt_index, pkt);
            ac.tstate = TS_PLAYBACK;
            replay_statement(area_id, ac);
            api.broadcast_area_msg(area_id,
                string::tformat("[Testimony] Statement %d updated.", ac.stmt_index + 1));
            return true;

        case TS_ADD:
            if (ac.stmt_count >= MAX_STATEMENTS) {
                api.client_send_msg(c, "Maximum statements reached.");
                ac.tstate = TS_PLAYBACK;
                return false;
            }
            insert_statement(ac, ac.stmt_index + 1, pkt);
            ac.stmt_index++;
            ac.tstate = TS_PLAYBACK;
            replay_statement(area_id, ac);
            api.broadcast_area_msg(area_id,
                string::tformat("[Testimony] Statement %d inserted.", ac.stmt_index + 1));
            return true;

        default:
            return false;
    }
}

// RT hook — enforces WT/CE blocks and logs judge actions.
fn bool on_rt_packet(void* c, void* pkt) {
    int area_id = api.client_get_area(c);
    AreaCasing* ac = get_ac(area_id);
    if (ac == null) return false;

    int uid = api.client_get_uid(c);

    // Enforce WT/CE block
    if (is_wtce_blocked(ac, uid)) {
        api.client_send_msg(c, "You are blocked from using WT/CE controls.");
        return true;  // consume
    }

    // Log the action
    String rt_type = api.packet_get_field(pkt, 0);
    add_judge_log(ac, string::tformat("[WT/CE] %s played %s",
        api.client_display_name(c), rt_type));

    return false;
}

// HP hook — logs penalty bar changes for /judgelog.
fn bool on_hp_packet(void* c, void* pkt) {
    int area_id = api.client_get_area(c);
    AreaCasing* ac = get_ac(area_id);
    if (ac == null) return false;

    String bar_str = api.packet_get_field(pkt, 0);
    String val_str = api.packet_get_field(pkt, 1);
    String bar_name = "defense";
    if (bar_str == "2") bar_name = "prosecution";

    add_judge_log(ac, string::tformat("[HP] %s set %s HP to %s",
        api.client_display_name(c), bar_name, val_str));

    return false;  // let the server handle it normally
}

// ============================================================
// Testimony commands
// ============================================================

// /testify — Start recording testimony (CM/mod).
// Clears any previous testimony. Sends the Witness Testimony
// splash (RT#testimony1) to the area. All subsequent IC messages
// in the area are recorded as statements until /pause.
fn void cmd_testify(void* c, String args) {
    if (!is_cm_or_mod(c)) {
        api.client_send_msg(c, "You must be a CM or moderator.");
        return;
    }

    int area_id = api.client_get_area(c);
    AreaCasing* ac = get_ac(area_id);
    if (ac == null) return;

    if (ac.tstate != TS_IDLE) {
        api.client_send_msg(c, "Testimony already in progress. Use /pause first.");
        return;
    }

    // Clear old testimony
    ac.stmt_count = 0;
    ac.stmt_index = 0;
    ac.tstate = TS_RECORDING;

    // Send Witness Testimony splash
    api.broadcast_area_raw(area_id, "RT#testimony1#%");
    api.broadcast_area_msg(area_id,
        string::tformat("=== Testimony recording started by %s ===",
            api.client_display_name(c)));
    api.broadcast_area_msg(area_id,
        "All IC messages are now being recorded as statements.");
}

// /examine — Begin cross-examination playback.
// Sends the Cross-Examination splash (RT#testimony2) and replays
// the first recorded statement. During playback, each IC message
// from any player advances to the next statement.
fn void cmd_examine(void* c, String args) {
    int area_id = api.client_get_area(c);
    AreaCasing* ac = get_ac(area_id);
    if (ac == null) return;

    if (ac.stmt_count == 0) {
        api.client_send_msg(c, "No testimony recorded. Use /testify first.");
        return;
    }

    if (ac.tstate == TS_RECORDING) {
        api.client_send_msg(c, "Still recording. Use /pause first.");
        return;
    }

    ac.tstate = TS_PLAYBACK;
    ac.stmt_index = 0;

    // Send Cross-Examination splash
    api.broadcast_area_raw(area_id, "RT#testimony2#%");
    api.broadcast_area_msg(area_id, "=== Cross-Examination ===");

    // Play first statement
    replay_statement(area_id, ac);
}

// /pause — Stop testimony recording or playback (CM/mod).
fn void cmd_pause(void* c, String args) {
    if (!is_cm_or_mod(c)) {
        api.client_send_msg(c, "You must be a CM or moderator.");
        return;
    }

    int area_id = api.client_get_area(c);
    AreaCasing* ac = get_ac(area_id);
    if (ac == null) return;

    if (ac.tstate == TS_IDLE) {
        api.client_send_msg(c, "No testimony in progress.");
        return;
    }

    int prev = ac.tstate;
    ac.tstate = TS_IDLE;

    if (prev == TS_RECORDING) {
        api.broadcast_area_msg(area_id,
            string::tformat("=== Recording stopped. %d statement(s) recorded. ===",
                ac.stmt_count));
    } else {
        api.broadcast_area_msg(area_id, "=== Cross-Examination paused ===");
    }
}

// /testimony — View all recorded testimony statements.
// Shows the statement number and message text. The current
// statement during playback is marked with <<<.
fn void cmd_testimony(void* c, String args) {
    int area_id = api.client_get_area(c);
    AreaCasing* ac = get_ac(area_id);
    if (ac == null) return;

    if (ac.stmt_count == 0) {
        api.client_send_msg(c, "No testimony recorded.");
        return;
    }

    api.client_send_msg(c,
        string::tformat("=== Testimony (%d statement%s) ===",
            ac.stmt_count, ac.stmt_count == 1 ? "" : "s"));

    for (int i = 0; i < ac.stmt_count; i++) {
        String text = buf_to_str(&ac.stmts[i].display[0]);
        if (ac.tstate == TS_PLAYBACK && i == ac.stmt_index) {
            api.client_send_msg(c, string::tformat("%d. %s  <<<", i + 1, text));
        } else {
            api.client_send_msg(c, string::tformat("%d. %s", i + 1, text));
        }
    }
}

// /add — Set recorder to ADD mode (CM/mod, during CE).
// The next IC message will be inserted after the current statement.
fn void cmd_add(void* c, String args) {
    if (!is_cm_or_mod(c)) {
        api.client_send_msg(c, "You must be a CM or moderator.");
        return;
    }

    int area_id = api.client_get_area(c);
    AreaCasing* ac = get_ac(area_id);
    if (ac == null) return;

    if (ac.tstate != TS_PLAYBACK) {
        api.client_send_msg(c, "Must be in cross-examination. Use /examine first.");
        return;
    }

    if (ac.stmt_count >= MAX_STATEMENTS) {
        api.client_send_msg(c,
            string::tformat("Maximum statements (%d) reached.", MAX_STATEMENTS));
        return;
    }

    ac.tstate = TS_ADD;
    api.broadcast_area_msg(area_id,
        string::tformat("Next IC message will be inserted after statement %d.",
            ac.stmt_index + 1));
}

// /update — Set recorder to UPDATE mode (CM/mod, during CE).
// The next IC message will replace the current statement.
fn void cmd_update(void* c, String args) {
    if (!is_cm_or_mod(c)) {
        api.client_send_msg(c, "You must be a CM or moderator.");
        return;
    }

    int area_id = api.client_get_area(c);
    AreaCasing* ac = get_ac(area_id);
    if (ac == null) return;

    if (ac.tstate != TS_PLAYBACK) {
        api.client_send_msg(c, "Must be in cross-examination. Use /examine first.");
        return;
    }

    ac.tstate = TS_UPDATE;
    api.broadcast_area_msg(area_id,
        string::tformat("Next IC message will replace statement %d.",
            ac.stmt_index + 1));
}

// /delete — Delete the current statement (CM/mod, during CE).
// Requires at least 2 statements (cannot delete the last one).
fn void cmd_delete(void* c, String args) {
    if (!is_cm_or_mod(c)) {
        api.client_send_msg(c, "You must be a CM or moderator.");
        return;
    }

    int area_id = api.client_get_area(c);
    AreaCasing* ac = get_ac(area_id);
    if (ac == null) return;

    if (ac.tstate != TS_PLAYBACK) {
        api.client_send_msg(c, "Must be in cross-examination.");
        return;
    }

    if (ac.stmt_count <= 1) {
        api.client_send_msg(c, "Cannot delete the last remaining statement.");
        return;
    }

    int del_idx = ac.stmt_index;

    // Shift statements after del_idx down
    for (int i = del_idx; i < ac.stmt_count - 1; i++) {
        for (int j = 0; j < MAX_STMT_LEN; j++) {
            ac.stmts[i].packet[j] = ac.stmts[i + 1].packet[j];
        }
        for (int j = 0; j < MAX_DISPLAY_LEN; j++) {
            ac.stmts[i].display[j] = ac.stmts[i + 1].display[j];
        }
        ac.stmts[i].pkt_len = ac.stmts[i + 1].pkt_len;
    }
    ac.stmt_count--;

    // Adjust index
    if (ac.stmt_index >= ac.stmt_count) {
        ac.stmt_index = ac.stmt_count - 1;
    }

    api.broadcast_area_msg(area_id,
        string::tformat("[Testimony] Statement %d deleted. %d remaining.",
            del_idx + 1, ac.stmt_count));

    replay_statement(area_id, ac);
}

// ============================================================
// Case utility commands
// ============================================================

// /doc [text] — Get or set the area's case document.
// No arguments: shows the current document.
// With text: sets the document (CM/mod only).
fn void cmd_doc(void* c, String args) {
    int area_id = api.client_get_area(c);
    AreaCasing* ac = get_ac(area_id);
    if (ac == null) return;

    if (args.len == 0) {
        if (!ac.has_doc) {
            api.client_send_msg(c, "No document set. Use /doc <text> to set one.");
        } else {
            api.client_send_msg(c,
                string::tformat("Document: %s", buf_to_str(&ac.doc[0])));
        }
        return;
    }

    if (!is_cm_or_mod(c)) {
        api.client_send_msg(c, "You must be a CM or moderator to set the document.");
        return;
    }

    copy_to_buf(&ac.doc[0], args, MAX_DOC_LEN);
    ac.has_doc = true;
    api.broadcast_area_msg(area_id,
        string::tformat("Document set by %s.", api.client_display_name(c)));
    api.broadcast_area_msg(area_id,
        string::tformat("Document: %s", args));
}

// /cleardoc — Clear the area's case document (CM/mod).
fn void cmd_cleardoc(void* c, String args) {
    if (!is_cm_or_mod(c)) {
        api.client_send_msg(c, "You must be a CM or moderator.");
        return;
    }

    int area_id = api.client_get_area(c);
    AreaCasing* ac = get_ac(area_id);
    if (ac == null) return;

    ac.doc[0] = 0;
    ac.has_doc = false;
    api.broadcast_area_msg(area_id,
        string::tformat("Document cleared by %s.", api.client_display_name(c)));
}

// /need <message> — Broadcast a case advertisement server-wide (CM/mod).
// Sends a styled announcement to all connected players.
fn void cmd_need(void* c, String args) {
    if (!is_cm_or_mod(c)) {
        api.client_send_msg(c, "You must be a CM or moderator.");
        return;
    }

    if (args.len == 0) {
        api.client_send_msg(c, "Usage: /need <message>");
        return;
    }

    int area_id = api.client_get_area(c);
    String area_name = api.area_get_name(area_id);
    String name = api.client_display_name(c);

    api.broadcast_all_msg("=== Case Advertisement ===");
    api.broadcast_all_msg(
        string::tformat("%s in [%s] needs: %s", name, area_name, args));
    api.broadcast_all_msg("==========================");
}

// ============================================================
// Notecard commands
// ============================================================

// /notecard <text> — Write a hidden notecard.
// One notecard per player per area. Overwritten if you write again.
// Notecards are invisible until a CM reveals them with /notecardreveal.
fn void cmd_notecard(void* c, String args) {
    if (args.len == 0) {
        api.client_send_msg(c, "Usage: /notecard <message>");
        return;
    }

    int area_id = api.client_get_area(c);
    int uid = api.client_get_uid(c);
    AreaCasing* ac = get_ac(area_id);
    if (ac == null) return;

    // Check for existing notecard from this player
    for (int i = 0; i < ac.card_count; i++) {
        if (ac.cards[i].uid == uid) {
            copy_to_buf(&ac.cards[i].text[0], args, MAX_NC_LEN);
            ac.cards[i].used = true;
            api.client_send_msg(c, "Notecard updated.");
            return;
        }
    }

    // Create new
    if (ac.card_count >= MAX_NOTECARDS) {
        api.client_send_msg(c, "Too many notecards in this area.");
        return;
    }

    ac.cards[ac.card_count].uid = uid;
    copy_to_buf(&ac.cards[ac.card_count].text[0], args, MAX_NC_LEN);
    ac.cards[ac.card_count].used = true;
    ac.card_count++;
    api.client_send_msg(c, "Notecard written.");
}

// /notecardreveal — Reveal all notecards in the area (CM/mod).
// Shows every active notecard to the entire area, then clears them all.
fn void cmd_notecardreveal(void* c, String args) {
    if (!is_cm_or_mod(c)) {
        api.client_send_msg(c, "You must be a CM or moderator.");
        return;
    }

    int area_id = api.client_get_area(c);
    AreaCasing* ac = get_ac(area_id);
    if (ac == null) return;

    int revealed = 0;
    api.broadcast_area_msg(area_id, "=== Notecards Revealed ===");

    for (int i = 0; i < ac.card_count; i++) {
        if (ac.cards[i].used) {
            void* author = api.find_client(ac.cards[i].uid);
            String name;
            if (author != null) {
                name = api.client_display_name(author);
            } else {
                name = string::tformat("UID %d", ac.cards[i].uid);
            }
            api.broadcast_area_msg(area_id,
                string::tformat("%s: %s", name, buf_to_str(&ac.cards[i].text[0])));
            revealed++;
        }
    }

    if (revealed == 0) {
        api.broadcast_area_msg(area_id, "No notecards to reveal.");
    }
    api.broadcast_area_msg(area_id, "==========================");

    // Clear all notecards after reveal
    for (int i = 0; i < ac.card_count; i++) {
        ac.cards[i].used = false;
    }
    ac.card_count = 0;
}

// /notecardclear — Clear your own notecard.
fn void cmd_notecardclear(void* c, String args) {
    int area_id = api.client_get_area(c);
    int uid = api.client_get_uid(c);
    AreaCasing* ac = get_ac(area_id);
    if (ac == null) return;

    for (int i = 0; i < ac.card_count; i++) {
        if (ac.cards[i].uid == uid && ac.cards[i].used) {
            ac.cards[i].used = false;
            api.client_send_msg(c, "Notecard cleared.");
            return;
        }
    }
    api.client_send_msg(c, "You don't have a notecard in this area.");
}

// ============================================================
// WT/CE control commands
// ============================================================

// /blockwtce <uid> — Block a player from using WT/CE controls (CM/mod).
// The block is per-area. The player cannot send RT packets in this area
// until unblocked. Does not persist across server restarts.
fn void cmd_blockwtce(void* c, String args) {
    if (!is_cm_or_mod(c)) {
        api.client_send_msg(c, "You must be a CM or moderator.");
        return;
    }

    int target_uid = args.to_int() ?? -1;
    if (target_uid < 0) {
        api.client_send_msg(c, "Usage: /blockwtce <uid>");
        return;
    }

    int area_id = api.client_get_area(c);
    AreaCasing* ac = get_ac(area_id);
    if (ac == null) return;

    if (is_wtce_blocked(ac, target_uid)) {
        api.client_send_msg(c, "Player is already blocked from WT/CE.");
        return;
    }

    if (ac.blocked_count >= MAX_BLOCKED) {
        api.client_send_msg(c, "Block list is full.");
        return;
    }

    ac.blocked[ac.blocked_count] = target_uid;
    ac.blocked_count++;

    void* target = api.find_client(target_uid);
    if (target != null) {
        api.client_send_msg(target, "You have been blocked from using WT/CE controls in this area.");
    }
    api.client_send_msg(c, string::tformat("Blocked UID %d from WT/CE.", target_uid));
}

// /unblockwtce <uid> — Unblock a player from WT/CE controls (CM/mod).
fn void cmd_unblockwtce(void* c, String args) {
    if (!is_cm_or_mod(c)) {
        api.client_send_msg(c, "You must be a CM or moderator.");
        return;
    }

    int target_uid = args.to_int() ?? -1;
    if (target_uid < 0) {
        api.client_send_msg(c, "Usage: /unblockwtce <uid>");
        return;
    }

    int area_id = api.client_get_area(c);
    AreaCasing* ac = get_ac(area_id);
    if (ac == null) return;

    for (int i = 0; i < ac.blocked_count; i++) {
        if (ac.blocked[i] == target_uid) {
            for (int j = i; j < ac.blocked_count - 1; j++) {
                ac.blocked[j] = ac.blocked[j + 1];
            }
            ac.blocked_count--;

            void* target = api.find_client(target_uid);
            if (target != null) {
                api.client_send_msg(target, "You have been unblocked from WT/CE controls.");
            }
            api.client_send_msg(c, string::tformat("Unblocked UID %d from WT/CE.", target_uid));
            return;
        }
    }

    api.client_send_msg(c, "Player is not blocked from WT/CE.");
}

// /judgelog — View recent WT/CE and penalty bar actions (CM/mod).
// Shows the last 10 judge actions in the area (ring buffer).
fn void cmd_judgelog(void* c, String args) {
    if (!is_cm_or_mod(c)) {
        api.client_send_msg(c, "You must be a CM or moderator.");
        return;
    }

    int area_id = api.client_get_area(c);
    AreaCasing* ac = get_ac(area_id);
    if (ac == null) return;

    if (ac.jlog_count == 0) {
        api.client_send_msg(c, "No judge actions recorded.");
        return;
    }

    api.client_send_msg(c, "=== Judge Log ===");
    for (int i = 0; i < ac.jlog_count; i++) {
        int idx = (ac.jlog_start + i) % MAX_LOG;
        api.client_send_msg(c, buf_to_str(&ac.jlog[idx].text[0]));
    }
    api.client_send_msg(c, "=================");
}
