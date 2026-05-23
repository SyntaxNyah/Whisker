// Whisker AO2 Server — Moderation Commands
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// All moderator-only commands. Requires authentication via /login
// and appropriate permission bits. Plugins can add more mod
// commands without touching this file.

module whisker::moderation;

import whisker::config;
import whisker::client;
import whisker::server;
import whisker::commands;
import whisker::security;
import whisker::pairing;
import whisker::protocol;
import std::io;

// ============================================================
// Authentication
// ============================================================

// Simple password-based auth.
// In production, use bcrypt/argon2 and a proper account DB.
// This is the minimal viable implementation — extend via plugins.

const String DEFAULT_MOD_PASSWORD = "changeme";

fn void cmd_login(server::Server* srv, client::Client* c, String args) {
    // /login <username> <password>
    if (try space = args.index_of_char(' ')) {
        String username = args[0..space];
        String password = args[space + 1..].trim();

        // TODO: Check against account database
        // For now, simple password check (CHANGE THIS!)
        if (password == DEFAULT_MOD_PASSWORD) {
            c.is_authenticated = true;
            c.permissions = commands::PERM_MUTE | commands::PERM_KICK |
                            commands::PERM_BAN | commands::PERM_MOVE_USERS |
                            commands::PERM_MODIFY_AREA | commands::PERM_BAN_INFO |
                            commands::PERM_ADMIN;

            String[] auth_fields = { string::tformat("%d", config::AUTH_SUCCESS) };
            c.send_packet("AUTH", auth_fields);
            c.send_server_message(string::tformat("Logged in as %s.", username));
            io::printfn("[mod] %s logged in as '%s' (UID %d)", c.ipid, username, c.uid);
        } else {
            String[] auth_fields = { string::tformat("%d", config::AUTH_FAILURE) };
            c.send_packet("AUTH", auth_fields);
            c.send_server_message("Login failed. Wrong password.");
        }
    } else {
        c.send_server_message("Usage: /login <username> <password>");
    }
}

fn void cmd_logout(client::Client* c) {
    c.is_authenticated = false;
    c.permissions = 0;
    String[] auth_fields = { string::tformat("%d", config::AUTH_LOGOUT) };
    c.send_packet("AUTH", auth_fields);
    c.send_server_message("Logged out.");
}

// ============================================================
// Kick
// ============================================================

fn void cmd_kick(server::Server* srv, client::Client* c, String args) {
    if (!c.has_permission(commands::PERM_KICK)) {
        c.send_server_message("No permission.");
        return;
    }

    int uid = args.to_int() ?? -1;
    if (uid < 0) {
        c.send_server_message("Usage: /kick <uid>");
        return;
    }

    client::Client* target = server::find_client_by_uid(srv, uid);
    if (target == null) {
        c.send_server_message("Player not found.");
        return;
    }

    // Send kick notice
    String[] kk_fields = { "You have been kicked." };
    target.send_packet("KK", kk_fields);
    target.connected = false;

    c.send_server_message(string::tformat("Kicked UID %d (%s).", uid, target.display_name()));
    io::printfn("[mod] %s kicked UID %d (%s)", c.display_name(), uid, target.ipid);

    // Also remove from area invite list (prevents locked-room kick bypass)
    srv.areas[target.area_id].uninvite(uid);
}

// ============================================================
// Ban
// ============================================================

fn void cmd_ban(server::Server* srv, client::Client* c, String args) {
    if (!c.has_permission(commands::PERM_BAN)) {
        c.send_server_message("No permission.");
        return;
    }

    // Parse: /ban <uid> [-d duration] [reason]
    int uid = -1;
    long duration_sec = config::DEFAULT_BAN_DURATION_SEC;
    String reason = "No reason given.";

    String[] parts = args.tsplit(" ");
    if (parts.len == 0) {
        c.send_server_message("Usage: /ban <uid> [-d duration] [reason]");
        return;
    }

    uid = parts[0].to_int() ?? -1;
    if (uid < 0) {
        c.send_server_message("Invalid UID.");
        return;
    }

    // Parse optional flags
    usz i = 1;
    DString reason_buf = dstring::temp();
    while (i < parts.len) {
        if (parts[i] == "-d" && i + 1 < parts.len) {
            duration_sec = security::parse_duration(parts[i + 1]);
            i += 2;
        } else {
            if (reason_buf.len() > 0) reason_buf.append_char(' ');
            reason_buf.append_string(parts[i]);
            i++;
        }
    }
    if (reason_buf.len() > 0) reason = reason_buf.str_view();

    client::Client* target = server::find_client_by_uid(srv, uid);
    if (target == null) {
        c.send_server_message("Player not found.");
        return;
    }

    // Add ban
    srv.ban_list.add(target.ipid, target.hdid, reason, duration_sec);

    // Notify and disconnect
    String[] kb_fields = { string::tformat("Banned: %s", reason) };
    target.send_packet("KB", kb_fields);
    target.connected = false;

    c.send_server_message(string::tformat("Banned UID %d for %s. Reason: %s",
        uid, format_duration(duration_sec), reason));
    io::printfn("[mod] %s banned UID %d (%s): %s", c.display_name(), uid, target.ipid, reason);
}

fn void cmd_unban(server::Server* srv, client::Client* c, String args) {
    if (!c.has_permission(commands::PERM_BAN)) {
        c.send_server_message("No permission.");
        return;
    }

    int index = args.to_int() ?? -1;
    if (index < 0) {
        c.send_server_message("Usage: /unban <ban-index>");
        return;
    }

    if (srv.ban_list.remove_by_index(index)) {
        c.send_server_message(string::tformat("Ban #%d removed.", index));
    } else {
        c.send_server_message("Invalid ban index.");
    }
}

// ============================================================
// Mute / Unmute
// ============================================================

fn void cmd_mute(server::Server* srv, client::Client* c, String args) {
    if (!c.has_permission(commands::PERM_MUTE)) {
        c.send_server_message("No permission.");
        return;
    }

    int uid = args.to_int() ?? -1;
    client::Client* target = server::find_client_by_uid(srv, uid);
    if (target == null) {
        c.send_server_message("Player not found.");
        return;
    }

    target.is_muted = true;
    target.send_server_message("You have been muted.");
    c.send_server_message(string::tformat("Muted UID %d.", uid));
}

fn void cmd_unmute(server::Server* srv, client::Client* c, String args) {
    if (!c.has_permission(commands::PERM_MUTE)) {
        c.send_server_message("No permission.");
        return;
    }

    int uid = args.to_int() ?? -1;
    client::Client* target = server::find_client_by_uid(srv, uid);
    if (target == null) {
        c.send_server_message("Player not found.");
        return;
    }

    target.is_muted = false;
    target.send_server_message("You have been unmuted.");
    c.send_server_message(string::tformat("Unmuted UID %d.", uid));
}

fn void cmd_oocmute(server::Server* srv, client::Client* c, String args) {
    if (!c.has_permission(commands::PERM_MUTE)) {
        c.send_server_message("No permission.");
        return;
    }

    int uid = args.to_int() ?? -1;
    client::Client* target = server::find_client_by_uid(srv, uid);
    if (target == null) { c.send_server_message("Player not found."); return; }

    target.is_ooc_muted = true;
    target.send_server_message("You have been muted from OOC chat.");
    c.send_server_message(string::tformat("OOC-muted UID %d.", uid));
}

fn void cmd_oocunmute(server::Server* srv, client::Client* c, String args) {
    if (!c.has_permission(commands::PERM_MUTE)) {
        c.send_server_message("No permission.");
        return;
    }

    int uid = args.to_int() ?? -1;
    client::Client* target = server::find_client_by_uid(srv, uid);
    if (target == null) { c.send_server_message("Player not found."); return; }

    target.is_ooc_muted = false;
    target.send_server_message("OOC chat restored.");
    c.send_server_message(string::tformat("OOC-unmuted UID %d.", uid));
}

// ============================================================
// Force pair (moderator)
// ============================================================

fn void cmd_forcepair(server::Server* srv, client::Client* c, String args) {
    if (!c.has_permission(commands::PERM_MUTE)) {
        c.send_server_message("No permission.");
        return;
    }

    // /forcepair <uid1> <uid2>
    String[] parts = args.tsplit(" ");
    if (parts.len < 2) {
        c.send_server_message("Usage: /forcepair <uid1> <uid2>");
        return;
    }

    int uid1 = parts[0].to_int() ?? -1;
    int uid2 = parts[1].to_int() ?? -1;

    client::Client* a = server::find_client_by_uid(srv, uid1);
    client::Client* b = server::find_client_by_uid(srv, uid2);

    if (a == null || b == null) {
        c.send_server_message("One or both players not found.");
        return;
    }

    pairing::force_pair(a, b);
    c.send_server_message(string::tformat("Force-paired UID %d and UID %d.", uid1, uid2));
}

fn void cmd_forceunpair(server::Server* srv, client::Client* c, String args) {
    if (!c.has_permission(commands::PERM_MUTE)) {
        c.send_server_message("No permission.");
        return;
    }

    int uid = args.to_int() ?? -1;
    client::Client* target = server::find_client_by_uid(srv, uid);
    if (target == null) {
        c.send_server_message("Player not found.");
        return;
    }

    pairing::force_unpair(target, &srv.clients, srv.client_count);
    c.send_server_message(string::tformat("Force-unpaired UID %d.", uid));
}

// ============================================================
// Utility
// ============================================================

fn String format_duration(long seconds) {
    if (seconds <= 0) return "permanent";
    if (seconds < 60) return string::tformat("%ds", seconds);
    if (seconds < 3600) return string::tformat("%dm", seconds / 60);
    if (seconds < 86400) return string::tformat("%dh", seconds / 3600);
    return string::tformat("%dd", seconds / 86400);
}
