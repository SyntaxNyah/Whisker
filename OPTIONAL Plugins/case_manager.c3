// Whisker Optional Plugin — Case Manager (CM) [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A standalone plugin (.dll / .so) that gives players a Case Manager
// (CM) role for area control. Inspired by Akashi's CM system.
//
// Drop the compiled .dll or .so into your server's plugins/ folder
// and restart. No configuration needed.
//
// This source file is provided as a learning exercise — if you want
// to try compiling a C3 plugin yourself, follow the Plugin Dev Guide:
//   plugins/PLUGIN DEV GUIDE README.md
//
// CMs can:
//   - Lock/unlock the area (built-in /lock and /unlock already support CM)
//   - Kick players from the area
//   - Play music
//   - Set area status
//   - Force player positions
//   - Manage the area invite list
//
// How it works:
//   - Any player can /cm to become CM if no CMs exist in the area
//   - Existing CMs can promote others with /cm <uid>
//   - CM status is automatically removed on area change or disconnect
//   - Moderators bypass all CM permission checks
//
// Commands:
//   /cm [uid]              — Become CM, or promote another player
//   /uncm [uid|all]        — Remove CM from self, another player, or all
//   /area_kick <uid>       — Kick a player from the area to the lobby
//   /play <song>           — Play a song in the area
//   /status [status]       — Set area status (idle, casing, rp, etc.)
//   /forcepos <uid> <pos>  — Force a player's position
//   /uninvite <uid>        — Remove player from the area invite list

module case_manager;

import std::io;

// ============================================================
// Whisker plugin interface (standalone definitions)
// ============================================================
//
// When building a standalone plugin (outside the server source tree),
// you define the plugin structs locally. The layout must match the
// server's definitions exactly. The server loads your .dll at runtime
// and calls the exported functions by name.

struct PluginInfo {
    String name;
    String version;
    String author;
    String description;
}

// Handler types (must match server-side definitions)
alias CommandHandler = fn void(void* client, String args);
alias PacketHook     = fn bool(void* client, void* packet);

// API function pointer types (must match server PluginAPI layout)
alias RegisterCommandFn   = fn void(String, CommandHandler, ulong, String, String);
alias RegisterHookFn      = fn void(String, PacketHook, String);
alias FindClientFn        = fn void*(int);
alias BroadcastAreaMsgFn  = fn void(int, String);
alias BroadcastAreaRawFn  = fn void(int, String);
alias BroadcastArupFn     = fn void(int);
alias GetAreaCountFn      = fn int();
alias AreaIsCmFn          = fn bool(int, int);
alias AreaAddCmFn         = fn void(int, int);
alias AreaRemoveCmFn      = fn void(int, int);
alias AreaCmCountFn       = fn int(int);
alias AreaClearCmsFn      = fn void(int);
alias AreaUninviteFn      = fn void(int, int);
alias AreaSetStatusFn     = fn void(int, int);
alias AreaGetStatusFn     = fn int(int);
alias AreaGetNameFn       = fn String(int);
alias AreaSetSongFn       = fn void(int, String, int);
alias ForceMoveFn         = fn void(void*, int);
alias ClientSendMsgFn     = fn void(void*, String);
alias ClientSendRawFn     = fn void(void*, String);
alias ClientGetUidFn      = fn int(void*);
alias ClientGetAreaFn     = fn int(void*);
alias ClientIsModFn       = fn bool(void*);
alias ClientDisplayNameFn = fn String(void*);
alias ClientGetCharIdFn   = fn int(void*);
alias ClientGetShownameFn = fn String(void*);
alias ClientGetCharNameFn = fn String(void*);
alias ClientIsJoinedFn    = fn bool(void*);
alias ClientSetPositionFn = fn void(void*, String);

// Extended API (v2) function pointer types
alias BroadcastAllMsgFn    = fn void(String);
alias BroadcastAllRawFn    = fn void(String);
alias GetPlayerCountFn     = fn int();
alias GetAreaPlayerCountFn = fn int(int);
alias ClientGetIpidFn      = fn String(void*);
alias PacketGetFieldFn     = fn String(void*, int);
alias PacketGetFieldCountFn = fn int(void*);
alias ClientKickFn         = fn void(void*);
alias ClientMuteFn         = fn void(void*);
alias ClientUnmuteFn       = fn void(void*);
alias AreaGetBackgroundFn  = fn String(int);
alias AreaSetBackgroundFn  = fn void(int, String);
alias AreaGetLockFn        = fn int(int);
alias AreaSetLockFn        = fn void(int, int);
alias AreaInviteFn         = fn void(int, int);
alias ArgsSplitFn          = fn int(String, String*, int);

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
}

// ============================================================
// Constants
// ============================================================

const int ARUP_STATUS = 1;
const int ARUP_CM     = 2;

const int STATUS_IDLE   = 0;
const int STATUS_LFP    = 1;
const int STATUS_CASING = 2;
const int STATUS_RECESS = 3;
const int STATUS_RP     = 4;
const int STATUS_GAMING = 5;

// ============================================================
// Plugin state
// ============================================================

PluginAPI* api;

// ============================================================
// Plugin interface (exported)
// ============================================================

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return {
        .name        = "Case Manager",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "CM role for area control",
    };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;

    api.register_command("cm", &cmd_cm, 0,
        "Become CM or promote [uid]", "Case Manager");
    api.register_command("uncm", &cmd_uncm, 0,
        "Remove CM from self or [uid|all]", "Case Manager");
    api.register_command("area_kick", &cmd_area_kick, 0,
        "Kick player from area to lobby", "Case Manager");
    api.register_command("play", &cmd_play, 0,
        "Play a song in the area", "Case Manager");
    api.register_command("status", &cmd_status, 0,
        "Set area status (idle, casing, rp, etc.)", "Case Manager");
    api.register_command("forcepos", &cmd_forcepos, 0,
        "Force a player's position", "Case Manager");
    api.register_command("uninvite", &cmd_uninvite, 0,
        "Remove player from area invite list", "Case Manager");

    io::printn("[case_manager] Case Manager plugin loaded (7 commands).");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    io::printn("[case_manager] Case Manager plugin unloaded.");
}

// ============================================================
// Helpers
// ============================================================

fn bool is_cm_or_mod(void* c) {
    return api.area_is_cm(api.client_get_area(c), api.client_get_uid(c))
        || api.client_is_mod(c);
}

fn int parse_status(String input) {
    if (input == "idle" || input == "IDLE") return STATUS_IDLE;
    if (input == "lfp" || input == "looking-for-players" || input == "LOOKING-FOR-PLAYERS") return STATUS_LFP;
    if (input == "casing" || input == "CASING") return STATUS_CASING;
    if (input == "recess" || input == "RECESS") return STATUS_RECESS;
    if (input == "rp" || input == "RP") return STATUS_RP;
    if (input == "gaming" || input == "GAMING") return STATUS_GAMING;
    return STATUS_IDLE;
}

fn String status_to_string(int status) {
    switch (status) {
        case STATUS_IDLE:    return "IDLE";
        case STATUS_LFP:     return "LOOKING-FOR-PLAYERS";
        case STATUS_CASING:  return "CASING";
        case STATUS_RECESS:  return "RECESS";
        case STATUS_RP:      return "RP";
        case STATUS_GAMING:  return "GAMING";
        default:             return "IDLE";
    }
}

// ============================================================
// /cm [uid] — Become CM or promote another player
// ============================================================
//
// No arguments: claim CM if no other CMs exist in the area.
// With UID:     promote another player (requires existing CM or mod).
//
// Moderators can always become CM, even if CMs already exist.

fn void cmd_cm(void* c, String args) {
    int area_id = api.client_get_area(c);
    int uid = api.client_get_uid(c);

    if (args.len == 0) {
        if (api.area_is_cm(area_id, uid)) {
            api.client_send_msg(c, "You are already a CM in this area.");
            return;
        }
        if (api.area_cm_count(area_id) > 0 && !api.client_is_mod(c)) {
            api.client_send_msg(c, "This area already has a CM. Ask them to promote you with /cm <your uid>.");
            return;
        }

        api.area_add_cm(area_id, uid);
        api.broadcast_area_msg(area_id,
            string::tformat("%s is now CM in this area.", api.client_display_name(c)));
        api.broadcast_arup(ARUP_CM);
        return;
    }

    // Promote another player
    if (!is_cm_or_mod(c)) {
        api.client_send_msg(c, "You must be a CM or moderator to promote others.");
        return;
    }

    int target_uid = args.to_int() ?? -1;
    if (target_uid < 0) {
        api.client_send_msg(c, "Usage: /cm [uid]");
        return;
    }

    void* target = api.find_client(target_uid);
    if (target == null || !api.client_is_joined(target)) {
        api.client_send_msg(c, "Player not found.");
        return;
    }
    if (api.client_get_area(target) != area_id) {
        api.client_send_msg(c, "Player is not in this area.");
        return;
    }
    if (api.area_is_cm(area_id, target_uid)) {
        api.client_send_msg(c, "That player is already a CM.");
        return;
    }

    api.area_add_cm(area_id, target_uid);
    api.broadcast_area_msg(area_id,
        string::tformat("%s is now CM in this area.", api.client_display_name(target)));
    api.broadcast_arup(ARUP_CM);
}

// ============================================================
// /uncm [uid|all] — Remove CM status
// ============================================================
//
// No arguments: remove yourself as CM.
// With UID:     remove another player's CM (requires CM or mod).
// "all":        remove all CMs from the area (requires CM or mod).

fn void cmd_uncm(void* c, String args) {
    int area_id = api.client_get_area(c);
    int uid = api.client_get_uid(c);

    if (args.len == 0) {
        if (!api.area_is_cm(area_id, uid)) {
            api.client_send_msg(c, "You are not a CM in this area.");
            return;
        }

        api.area_remove_cm(area_id, uid);
        api.broadcast_area_msg(area_id,
            string::tformat("%s is no longer CM.", api.client_display_name(c)));
        api.broadcast_arup(ARUP_CM);
        return;
    }

    if (!is_cm_or_mod(c)) {
        api.client_send_msg(c, "You must be a CM or moderator.");
        return;
    }

    if (args == "all") {
        api.area_clear_cms(area_id);
        api.broadcast_area_msg(area_id, "All CMs have been removed from this area.");
        api.broadcast_arup(ARUP_CM);
        return;
    }

    int target_uid = args.to_int() ?? -1;
    if (target_uid < 0) {
        api.client_send_msg(c, "Usage: /uncm [uid|all]");
        return;
    }

    if (!api.area_is_cm(area_id, target_uid)) {
        api.client_send_msg(c, "That player is not a CM.");
        return;
    }

    api.area_remove_cm(area_id, target_uid);

    void* target = api.find_client(target_uid);
    String name;
    if (target != null) {
        name = api.client_display_name(target);
    } else {
        name = string::tformat("UID %d", target_uid);
    }

    api.broadcast_area_msg(area_id, string::tformat("%s is no longer CM.", name));
    api.broadcast_arup(ARUP_CM);
}

// ============================================================
// /area_kick <uid> — Kick player from area to the lobby
// ============================================================
//
// Requires CM or moderator. Cannot kick:
//   - Yourself
//   - Another CM
//   - A moderator (unless you are also a mod)
//   - Players not in the same area
//   - From the lobby (area 0)
//
// The target is removed from the area's invite list so they
// cannot walk back into a locked area immediately.

fn void cmd_area_kick(void* c, String args) {
    int area_id = api.client_get_area(c);
    int uid = api.client_get_uid(c);

    if (!is_cm_or_mod(c)) {
        api.client_send_msg(c, "You must be a CM or moderator.");
        return;
    }

    if (area_id == 0) {
        api.client_send_msg(c, "Cannot kick from the lobby.");
        return;
    }

    int target_uid = args.to_int() ?? -1;
    if (target_uid < 0) {
        api.client_send_msg(c, "Usage: /area_kick <uid>");
        return;
    }

    if (target_uid == uid) {
        api.client_send_msg(c, "You cannot kick yourself.");
        return;
    }

    void* target = api.find_client(target_uid);
    if (target == null || !api.client_is_joined(target)) {
        api.client_send_msg(c, "Player not found.");
        return;
    }
    if (api.client_get_area(target) != area_id) {
        api.client_send_msg(c, "Player is not in this area.");
        return;
    }
    if (api.area_is_cm(area_id, target_uid)) {
        api.client_send_msg(c, "Cannot kick another CM.");
        return;
    }
    if (api.client_is_mod(target) && !api.client_is_mod(c)) {
        api.client_send_msg(c, "Cannot kick a moderator.");
        return;
    }

    // Remove from invite list to prevent re-entry to locked areas
    api.area_uninvite(area_id, target_uid);

    // Move to lobby
    api.force_move(target, 0);

    api.client_send_msg(target,
        string::tformat("You were kicked from the area by %s.", api.client_display_name(c)));
    api.client_send_msg(c,
        string::tformat("Kicked %s (UID %d) to the lobby.",
            api.client_display_name(target), api.client_get_uid(target)));
}

// ============================================================
// /play <song> — Play a song in the area
// ============================================================
//
// Requires CM or moderator. Broadcasts an MC packet to all
// players in the area, changing the currently playing music.

fn void cmd_play(void* c, String args) {
    if (!is_cm_or_mod(c)) {
        api.client_send_msg(c, "You must be a CM or moderator.");
        return;
    }

    if (args.len == 0) {
        api.client_send_msg(c, "Usage: /play <song>");
        return;
    }

    int area_id = api.client_get_area(c);
    int char_id = api.client_get_char_id(c);
    String showname = api.client_get_showname(c);
    if (showname.len == 0) showname = api.client_get_char_name(c);

    // Build MC packet: MC#song#char_id#showname#1#0#0#%
    DString pkt = dstring::temp();
    pkt.append_string("MC#");
    pkt.append_string(args);
    pkt.append_char('#');
    pkt.append_string(string::tformat("%d", char_id));
    pkt.append_char('#');
    pkt.append_string(showname);
    pkt.append_string("#1#0#0#%");

    api.broadcast_area_raw(area_id, pkt.str_view());
    api.area_set_song(area_id, args, api.client_get_uid(c));
}

// ============================================================
// /status [status] — Set or show area status
// ============================================================
//
// With no arguments: shows the current status and valid options.
// With a status name: sets the area status and broadcasts ARUP.
//
// Valid statuses: idle, lfp, casing, recess, rp, gaming

fn void cmd_status(void* c, String args) {
    int area_id = api.client_get_area(c);

    if (args.len == 0) {
        int status = api.area_get_status(area_id);
        api.client_send_msg(c, string::tformat("Current status: %s", status_to_string(status)));
        api.client_send_msg(c, "Valid: idle, lfp, casing, recess, rp, gaming");
        return;
    }

    if (!is_cm_or_mod(c)) {
        api.client_send_msg(c, "You must be a CM or moderator.");
        return;
    }

    int new_status = parse_status(args);
    api.area_set_status(area_id, new_status);
    api.broadcast_arup(ARUP_STATUS);

    api.broadcast_area_msg(area_id,
        string::tformat("Area status set to %s by %s.",
            status_to_string(new_status), api.client_display_name(c)));
}

// ============================================================
// /forcepos <uid> <position> — Force a player's position
// ============================================================
//
// Requires CM or moderator. Moves a player to a specific
// courtroom position (def, pro, wit, jud, hld, hlp).

fn void cmd_forcepos(void* c, String args) {
    if (!is_cm_or_mod(c)) {
        api.client_send_msg(c, "You must be a CM or moderator.");
        return;
    }

    if (try space = args.index_of_char(' ')) {
        int uid = args[0..space - 1].to_int() ?? -1;
        String pos = args[space + 1..].trim();

        if (uid < 0 || pos.len == 0) {
            api.client_send_msg(c, "Usage: /forcepos <uid> <position>");
            return;
        }

        if (pos != "def" && pos != "pro" && pos != "wit" &&
            pos != "jud" && pos != "hld" && pos != "hlp") {
            api.client_send_msg(c, "Valid positions: def, pro, wit, jud, hld, hlp");
            return;
        }

        void* target = api.find_client(uid);
        if (target == null || !api.client_is_joined(target)) {
            api.client_send_msg(c, "Player not found.");
            return;
        }
        if (api.client_get_area(target) != api.client_get_area(c)) {
            api.client_send_msg(c, "Player is not in this area.");
            return;
        }

        api.client_set_position(target, pos);

        // Send SP packet to update the target's client
        DString sp_pkt = dstring::temp();
        sp_pkt.append_string("SP#");
        sp_pkt.append_string(pos);
        sp_pkt.append_string("#%");
        api.client_send_raw(target, sp_pkt.str_view());

        api.client_send_msg(target,
            string::tformat("Your position was set to %s by %s.", pos, api.client_display_name(c)));
        api.client_send_msg(c,
            string::tformat("Forced %s to position %s.", api.client_display_name(target), pos));
    } else {
        api.client_send_msg(c, "Usage: /forcepos <uid> <position>");
    }
}

// ============================================================
// /uninvite <uid> — Remove player from area invite list
// ============================================================
//
// Requires CM or moderator. Removes a UID from the area's
// invite list. Useful for revoking access to a locked area.

fn void cmd_uninvite(void* c, String args) {
    if (!is_cm_or_mod(c)) {
        api.client_send_msg(c, "You must be a CM or moderator.");
        return;
    }

    int uid = args.to_int() ?? -1;
    if (uid < 0) {
        api.client_send_msg(c, "Usage: /uninvite <uid>");
        return;
    }

    api.area_uninvite(api.client_get_area(c), uid);
    api.client_send_msg(c, string::tformat("Removed UID %d from invite list.", uid));
}
