// Whisker AO2 Server — Command System
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// OOC commands are dispatched here. Commands start with '/'.
// The system is designed to be extended by plugins — the plugin
// manager is checked before built-in commands.

module whisker::commands;

import whisker::config;
import whisker::client;
import whisker::server;
import whisker::area;
import whisker::pairing;
import whisker::moderation;
import whisker::plugin;
import whisker::packets;
import whisker::protocol;
import whisker::security;
import std::io;

// ============================================================
// Permission bits — each permission is a named bit
// ============================================================

const ulong PERM_NONE       = 0;
const ulong PERM_MUTE       = 1 << 0;
const ulong PERM_KICK       = 1 << 1;
const ulong PERM_BAN        = 1 << 2;
const ulong PERM_MOVE_USERS = 1 << 3;
const ulong PERM_MODIFY_AREA = 1 << 4;
const ulong PERM_BAN_INFO   = 1 << 5;
const ulong PERM_ADMIN      = 1 << 6;
const ulong PERM_SHADOW     = 1 << 7;
const ulong PERM_DJ         = 1 << 8;

// ============================================================
// Command dispatch
// ============================================================

fn void dispatch(server::Server* srv, client::Client* c, String message) {
    if (message.len < 2) return;

    // Strip the leading '/'
    String cmd_line = message[1..];

    // Split into command name and arguments
    String cmd_name;
    String args_str = "";

    if (try space = cmd_line.index_of_char(' ')) {
        cmd_name = cmd_line[0..space - 1];
        args_str = cmd_line[space + 1..].trim();
    } else {
        cmd_name = cmd_line;
    }

    // Let plugins handle first
    if (plugin::on_command(&srv.plugins, c, cmd_name, args_str)) {
        return; // Plugin consumed the command
    }

    // Built-in commands
    switch {
        // ---- Player commands ----
        case cmd_name == "help":        cmd_help(srv, c, args_str);
        case cmd_name == "about":       cmd_about(c);
        case cmd_name == "area":        cmd_area(srv, c, args_str);
        case cmd_name == "areas":       cmd_areas(srv, c);
        case cmd_name == "pos":         cmd_pos(srv, c, args_str);
        case cmd_name == "ga":          cmd_ga(srv, c);
        case cmd_name == "players":     cmd_ga(srv, c);
        case cmd_name == "gas":         cmd_gas(srv, c);
        case cmd_name == "charselect":  cmd_charselect(srv, c);
        case cmd_name == "global":      cmd_global(srv, c, args_str);
        case cmd_name == "pm":          cmd_pm(srv, c, args_str);
        case cmd_name == "pair":        cmd_pair(srv, c, args_str);
        case cmd_name == "unpair":      cmd_unpair(srv, c);
        case cmd_name == "roll":        cmd_roll(c, args_str);

        // ---- Moderation commands ----
        case cmd_name == "login":       moderation::cmd_login(srv, c, args_str);
        case cmd_name == "logout":      moderation::cmd_logout(c);
        case cmd_name == "kick":        moderation::cmd_kick(srv, c, args_str);
        case cmd_name == "ban":         moderation::cmd_ban(srv, c, args_str);
        case cmd_name == "unban":       moderation::cmd_unban(srv, c, args_str);
        case cmd_name == "mute":        moderation::cmd_mute(srv, c, args_str);
        case cmd_name == "unmute":      moderation::cmd_unmute(srv, c, args_str);
        case cmd_name == "oocmute":     moderation::cmd_oocmute(srv, c, args_str);
        case cmd_name == "oocunmute":   moderation::cmd_oocunmute(srv, c, args_str);
        case cmd_name == "lock":        cmd_lock(srv, c);
        case cmd_name == "unlock":      cmd_unlock(srv, c);
        case cmd_name == "invite":      cmd_invite(srv, c, args_str);
        case cmd_name == "bg":          cmd_bg(srv, c, args_str);
        case cmd_name == "forcepair":   moderation::cmd_forcepair(srv, c, args_str);
        case cmd_name == "forceunpair": moderation::cmd_forceunpair(srv, c, args_str);

        default:
            c.send_server_message(string::tformat("Unknown command: /%s. Try /help.", cmd_name));
    }
}

// ============================================================
// Player commands
// ============================================================

fn void cmd_help(server::Server* srv, client::Client* c, String args) {
    if (args.len > 0) {
        // Help for specific command
        cmd_help_specific(srv, c, args);
        return;
    }

    c.send_server_message("=== Whisker Commands ===");
    c.send_server_message("/help [command]  - Show help");
    c.send_server_message("/about           - Server info and credits");
    c.send_server_message("/area <name>     - Move to area");
    c.send_server_message("/areas           - List all areas");
    c.send_server_message("/pos [position]  - Set IC position");
    c.send_server_message("/ga              - List players in this area");
    c.send_server_message("/gas             - List players in all areas");
    c.send_server_message("/global <msg>    - Server-wide OOC message");
    c.send_server_message("/pm <uid> <msg>  - Private message");
    c.send_server_message("/pair <uid>      - Request pair (mutual to confirm)");
    c.send_server_message("/unpair          - Cancel pair");
    c.send_server_message("/roll [NdM]      - Roll dice (default 1d6)");
    c.send_server_message("/charselect      - Return to character select");

    if (c.is_moderator()) {
        c.send_server_message("--- Moderator ---");
        c.send_server_message("/kick /ban /unban /mute /unmute /oocmute /oocunmute");
        c.send_server_message("/lock /unlock /invite /bg /forcepair /forceunpair");
    }

    // Plugin commands
    if (srv.plugins.command_count > 0) {
        String last_plugin = "";
        for (int i = 0; i < srv.plugins.command_count; i++) {
            plugin::PluginCommand* cmd = &srv.plugins.commands[i];
            if (cmd.required_perms != 0 && !c.has_permission(cmd.required_perms)) continue;

            if (cmd.plugin_name != last_plugin) {
                c.send_server_message(string::tformat("--- %s ---", cmd.plugin_name));
                last_plugin = cmd.plugin_name;
            }
            c.send_server_message(string::tformat("/%s  - %s", cmd.name, cmd.description));
        }
    }
}

fn void cmd_help_specific(server::Server* srv, client::Client* c, String cmd) {
    switch {
        case cmd == "pair":
            c.send_server_message("/pair <uid> — Request to pair with a player.");
            c.send_server_message("Both players must /pair each other for the pair to be established.");
            c.send_server_message("Pairs persist across character changes and area moves.");
        case cmd == "ban":
            c.send_server_message("/ban <uid> [-d duration] [reason]");
            c.send_server_message("Duration: 30s, 5m, 1h, 3d, 1w. Default: 3d.");
        case cmd == "roll":
            c.send_server_message("/roll [NdM] — Roll N dice with M sides. Default: 1d6.");
        default:
            // Check plugin commands
            for (int i = 0; i < srv.plugins.command_count; i++) {
                if (srv.plugins.commands[i].name == cmd) {
                    c.send_server_message(string::tformat("/%s — %s",
                        cmd, srv.plugins.commands[i].description));
                    c.send_server_message(string::tformat("(Plugin: %s)",
                        srv.plugins.commands[i].plugin_name));
                    return;
                }
            }
            c.send_server_message(string::tformat("No detailed help for '/%s'.", cmd));
    }
}

fn void cmd_about(client::Client* c) {
    c.send_server_message(string::tformat("=== %s v%s ===", config::SERVER_SOFTWARE, config::SERVER_VERSION));
    c.send_server_message("An AO2 server written in C3 by https://github.com/SyntaxNyah");
    c.send_server_message("Documentation, source code, issues and pull requests located here https://github.com/SyntaxNyah/Whisker");
    c.send_server_message("Protocol docs: OmniTroid (@omnitroid) & the AO dev team");
    c.send_server_message("https://github.com/AttorneyOnline");
    c.send_server_message("License: AGPL-3.0 | Extend with plugins, not forks!");
}

fn void cmd_area(server::Server* srv, client::Client* c, String args) {
    if (args.len == 0) {
        c.send_server_message(string::tformat("Current area: %s", srv.areas[c.area_id].name));
        return;
    }

    for (int i = 0; i < srv.area_count; i++) {
        if (srv.areas[i].name == args) {
            packets::change_area(srv, c, i);
            return;
        }
    }
    c.send_server_message("Area not found. Use /areas to list.");
}

fn void cmd_areas(server::Server* srv, client::Client* c) {
    c.send_server_message("=== Areas ===");
    for (int i = 0; i < srv.area_count; i++) {
        c.send_server_message(string::tformat("[%d] %s (%d players) [%s]",
            i, srv.areas[i].name, srv.areas[i].player_count,
            srv.areas[i].status.to_string()));
    }
}

fn void cmd_pos(server::Server* srv, client::Client* c, String args) {
    if (args.len == 0) {
        c.send_server_message(string::tformat("Position: %s", c.position));
        return;
    }

    // Validate position
    if (args == "def" || args == "pro" || args == "wit" ||
        args == "jud" || args == "hld" || args == "hlp") {
        c.position = args;
        // Send SP packet
        String[] sp_fields = { args };
        c.send_packet("SP", sp_fields);
        c.send_server_message(string::tformat("Position set to %s.", args));
    } else {
        c.send_server_message("Valid positions: def, pro, wit, jud, hld, hlp");
    }
}

fn void cmd_ga(server::Server* srv, client::Client* c) {
    c.send_server_message(string::tformat("=== %s (%d players) ===",
        srv.areas[c.area_id].name, srv.areas[c.area_id].player_count));

    for (int i = 0; i < server::MAX_SERVER_CLIENTS; i++) {
        client::Client* other = srv.clients[i];
        if (other != null && other.joined && other.area_id == c.area_id) {
            String mod_label = other.is_moderator() ? " [MOD]" : "";
            c.send_server_message(string::tformat("  [%d] %s (%s)%s",
                other.uid, other.display_name(), other.char_name, mod_label));
        }
    }
}

fn void cmd_gas(server::Server* srv, client::Client* c) {
    c.send_server_message("=== All Areas ===");
    int hidden_empty = 0;

    for (int i = 0; i < srv.area_count; i++) {
        if (srv.areas[i].player_count == 0) {
            hidden_empty++;
            continue;
        }

        c.send_server_message(string::tformat("--- %s (%d) ---",
            srv.areas[i].name, srv.areas[i].player_count));

        for (int j = 0; j < server::MAX_SERVER_CLIENTS; j++) {
            client::Client* other = srv.clients[j];
            if (other != null && other.joined && other.area_id == i) {
                c.send_server_message(string::tformat("  [%d] %s", other.uid, other.display_name()));
            }
        }
    }

    if (hidden_empty > 0) {
        c.send_server_message(string::tformat("(%d empty areas hidden)", hidden_empty));
    }
}

fn void cmd_charselect(server::Server* srv, client::Client* c) {
    if (c.char_id != config::NO_CHAR_SELECTED) {
        srv.areas[c.area_id].release_char(c.char_id);
        c.char_id = config::NO_CHAR_SELECTED;
        c.char_name = "";
    }
    c.send_simple("DONE");
}

fn void cmd_global(server::Server* srv, client::Client* c, String args) {
    if (args.len == 0) {
        c.send_server_message("Usage: /global <message>");
        return;
    }

    String msg = string::tformat("[GLOBAL] %s: %s", c.display_name(), args);
    for (int i = 0; i < server::MAX_SERVER_CLIENTS; i++) {
        client::Client* other = srv.clients[i];
        if (other != null && other.joined) {
            other.send_server_message(msg);
        }
    }
}

fn void cmd_pm(server::Server* srv, client::Client* c, String args) {
    // /pm <uid> <message>
    if (try space = args.index_of_char(' ')) {
        int uid = args[0..space - 1].to_int() ?? -1;
        String message = args[space + 1..].trim();

        if (uid < 0 || message.len == 0) {
            c.send_server_message("Usage: /pm <uid> <message>");
            return;
        }

        client::Client* target = server::find_client_by_uid(srv, uid);
        if (target == null) {
            c.send_server_message("Player not found.");
            return;
        }

        target.send_server_message(string::tformat("[PM from %s] %s", c.display_name(), message));
        c.send_server_message(string::tformat("[PM to %s] %s", target.display_name(), message));
    } else {
        c.send_server_message("Usage: /pm <uid> <message>");
    }
}

fn void cmd_pair(server::Server* srv, client::Client* c, String args) {
    int target_uid = args.to_int() ?? -1;
    if (target_uid < 0) {
        c.send_server_message("Usage: /pair <uid>");
        return;
    }

    client::Client* target = server::find_client_by_uid(srv, target_uid);
    if (target == null || !target.connected) {
        c.send_server_message("Player not found or disconnected.");
        return;
    }

    pairing::request_pair(c, target, &srv.clients, srv.client_count);
}

fn void cmd_unpair(server::Server* srv, client::Client* c) {
    pairing::cancel_pair(c, &srv.clients, srv.client_count);
}

fn void cmd_roll(client::Client* c, String args) {
    int num_dice = 1;
    int num_sides = 6;

    if (args.len > 0) {
        // Parse NdM format
        if (try d_pos = args.index_of_char('d')) {
            num_dice = args[0..d_pos - 1].to_int() ?? 1;
            num_sides = args[d_pos + 1..].to_int() ?? 6;
        }
    }

    // Clamp to reasonable values
    if (num_dice < 1) num_dice = 1;
    if (num_dice > 100) num_dice = 100;
    if (num_sides < 2) num_sides = 2;
    if (num_sides > 1000) num_sides = 1000;

    // Simple PRNG roll (not cryptographic, just for fun)
    long seed = security::current_time_sec();
    int total = 0;
    DString results = dstring::temp();

    for (int i = 0; i < num_dice; i++) {
        seed = (seed * 6364136223846793005 + 1442695040888963407); // LCG
        int roll = (int)((seed >> 33) % (long)num_sides) + 1;
        if (roll < 0) roll = -roll;
        total += roll;
        if (i > 0) results.append_string(", ");
        results.append_string(string::tformat("%d", roll));
    }

    c.send_server_message(string::tformat("Rolled %dd%d: [%s] = %d",
        num_dice, num_sides, results.str_view(), total));
}

fn void cmd_lock(server::Server* srv, client::Client* c) {
    area::Area* a = &srv.areas[c.area_id];
    if (!a.is_cm(c.uid) && !c.is_moderator()) {
        c.send_server_message("You must be a CM or moderator to lock the area.");
        return;
    }

    a.lock = area::LockState.LOCKED;

    // Auto-invite everyone currently in the area
    for (int i = 0; i < server::MAX_SERVER_CLIENTS; i++) {
        client::Client* other = srv.clients[i];
        if (other != null && other.joined && other.area_id == c.area_id) {
            a.invite(other.uid);
        }
    }

    server::broadcast_area(srv, c.area_id,
        protocol::build("CT", { config::SERVER_SOFTWARE, "Area locked.", "1" }));
    server::broadcast_arup(srv, config::ARUP_LOCK);
}

fn void cmd_unlock(server::Server* srv, client::Client* c) {
    area::Area* a = &srv.areas[c.area_id];
    if (!a.is_cm(c.uid) && !c.is_moderator()) {
        c.send_server_message("Not authorized.");
        return;
    }

    a.lock = area::LockState.FREE;
    a.invited_count = 0;

    server::broadcast_area(srv, c.area_id,
        protocol::build("CT", { config::SERVER_SOFTWARE, "Area unlocked.", "1" }));
    server::broadcast_arup(srv, config::ARUP_LOCK);
}

fn void cmd_invite(server::Server* srv, client::Client* c, String args) {
    int uid = args.to_int() ?? -1;
    if (uid < 0) {
        c.send_server_message("Usage: /invite <uid>");
        return;
    }

    srv.areas[c.area_id].invite(uid);
    c.send_server_message(string::tformat("Invited UID %d.", uid));
}

fn void cmd_bg(server::Server* srv, client::Client* c, String args) {
    if (args.len == 0) {
        c.send_server_message("Usage: /bg <background>");
        return;
    }

    srv.areas[c.area_id].background = args;
    String[] bn_fields = { args };
    server::broadcast_area(srv, c.area_id, protocol::build("BN", bn_fields));
}
