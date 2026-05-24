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

// C interop for file writing (accounts persistence)
extern fn void* fopen(char* path, char* mode);
extern fn int fputs(char* str, void* stream);
extern fn int fclose(void* stream);

// ============================================================
// Authentication
// ============================================================

// Account-based auth managed from the server console.
// Use 'addmod' in the server terminal to create accounts.
// Falls back to legacy password if no accounts are configured.
// For production auth (bcrypt, database, OAuth), extend via plugins.

const String DEFAULT_MOD_PASSWORD = "changeme";

// ============================================================
// Roles and Accounts
// ============================================================

const int MAX_ROLES    = 32;
const int MAX_ACCOUNTS = 256;

struct Role {
    String name;
    ulong  permissions;
}

struct Account {
    String username;
    String password;
    String role_name;
    ulong  permissions;  // Resolved from role at load time
}

// Module-level storage
Role[MAX_ROLES]       _roles;
int                   _role_count;
Account[MAX_ACCOUNTS] _accounts;
int                   _account_count;
String                _config_dir;

// ============================================================
// Auth initialization — called once at server startup
// ============================================================

fn void init_auth(String config_dir) {
    _config_dir = config_dir;
    _role_count = 0;
    _account_count = 0;

    load_roles(config_dir);
    load_accounts(config_dir);

    if (_account_count == 0) {
        io::printn("[auth] No accounts configured. Using legacy password auth.");
        io::printn("[auth] Use 'addmod <user> <pass> [role]' in the server console to create accounts.");
    }
}

fn void load_roles(String config_dir) {
    String path = string::tformat("%s/roles.toml", config_dir);
    char[]? data = io::file::load(mem, path);
    if (catch data) {
        io::printn("[auth] No roles.toml found, using default roles.");
        _roles[0] = { .name = "moderator", .permissions = 39 };
        _roles[1] = { .name = "admin", .permissions = 127 };
        _roles[2] = { .name = "dj", .permissions = 256 };
        _role_count = 3;
        return;
    }

    String content = (String)data[0..data.len - 1];
    int current = -1;

    foreach (line : content.tsplit("\n")) {
        String trimmed = line.trim();
        if (trimmed.len == 0 || trimmed[0] == '#') continue;

        if (trimmed == "[[role]]") {
            if (_role_count >= MAX_ROLES) break;
            current = _role_count;
            _roles[current] = { .name = "", .permissions = 0 };
            _role_count++;
            continue;
        }

        if (current >= 0) {
            if (try eq = trimmed.index_of_char('=')) {
                String key   = trimmed[0..eq - 1].trim();
                String value = trimmed[eq + 1..].trim();
                if (value.len >= 2 && value[0] == '"') {
                    value = value[1..value.len - 2];
                }
                if (key == "name")        _roles[current].name = value;
                if (key == "permissions") _roles[current].permissions = (ulong)(value.to_int() ?? 0);
            }
        }
    }

    io::printfn("[auth] Loaded %d roles from roles.toml.", _role_count);
}

fn void load_accounts(String config_dir) {
    String path = string::tformat("%s/accounts.txt", config_dir);
    char[]? data = io::file::load(mem, path);
    if (catch data) return; // No accounts file — that's fine

    String content = (String)data[0..data.len - 1];

    foreach (line : content.tsplit("\n")) {
        String trimmed = line.trim();
        if (trimmed.len == 0 || trimmed[0] == '#') continue;
        if (_account_count >= MAX_ACCOUNTS) break;

        // Format: username:password:role
        String[] parts = trimmed.tsplit(":");
        if (parts.len < 3) continue;

        String role_name = parts[2];
        ulong perms = resolve_role_permissions(role_name);

        _accounts[_account_count] = {
            .username    = parts[0],
            .password    = parts[1],
            .role_name   = role_name,
            .permissions = perms,
        };
        _account_count++;
    }

    if (_account_count > 0) {
        io::printfn("[auth] Loaded %d accounts.", _account_count);
    }
}

fn ulong resolve_role_permissions(String role_name) {
    for (int i = 0; i < _role_count; i++) {
        if (_roles[i].name == role_name) return _roles[i].permissions;
    }
    return 0;
}

fn bool save_accounts() {
    String path = string::tformat("%s/accounts.txt", _config_dir);
    void* f = fopen(path.ptr, "w".ptr);
    if (f == null) {
        io::printn("[auth] ERROR: Failed to write accounts file.");
        return false;
    }

    fputs("# Whisker moderator accounts\n".ptr, f);
    fputs("# Managed via server console. Do not edit while server is running.\n".ptr, f);
    fputs("# Format: username:password:role\n".ptr, f);

    for (int i = 0; i < _account_count; i++) {
        String line = string::tformat("%s:%s:%s\n",
            _accounts[i].username, _accounts[i].password, _accounts[i].role_name);
        fputs(line.ptr, f);
    }

    fclose(f);
    return true;
}

// ============================================================
// Account management — called from server console
// ============================================================

fn bool add_account(String username, String password, String role_name) {
    // Validate role exists
    bool role_found = false;
    for (int i = 0; i < _role_count; i++) {
        if (_roles[i].name == role_name) { role_found = true; break; }
    }
    if (!role_found) return false;

    // Check for duplicate username
    for (int i = 0; i < _account_count; i++) {
        if (_accounts[i].username == username) return false;
    }

    if (_account_count >= MAX_ACCOUNTS) return false;

    _accounts[_account_count] = {
        .username    = username,
        .password    = password,
        .role_name   = role_name,
        .permissions = resolve_role_permissions(role_name),
    };
    _account_count++;

    return save_accounts();
}

fn bool remove_account(String username) {
    for (int i = 0; i < _account_count; i++) {
        if (_accounts[i].username == username) {
            // Shift remaining accounts down
            for (int j = i; j < _account_count - 1; j++) {
                _accounts[j] = _accounts[j + 1];
            }
            _account_count--;
            return save_accounts();
        }
    }
    return false;
}

fn void list_accounts() {
    if (_account_count == 0) {
        io::printn("[auth] No accounts configured. Use 'addmod' to create one.");
        return;
    }

    io::printfn("[auth] %d account(s):", _account_count);
    for (int i = 0; i < _account_count; i++) {
        io::printfn("  %s  [%s]  (perms: %d)",
            _accounts[i].username, _accounts[i].role_name, (int)_accounts[i].permissions);
    }
}

fn void list_roles() {
    for (int i = 0; i < _role_count; i++) {
        io::printfn("  %s  (perms: %d)", _roles[i].name, (int)_roles[i].permissions);
    }
}

fn int get_account_count() {
    return _account_count;
}

fn void cmd_login(server::Server* srv, client::Client* c, String args) {
    // /login <username> <password>
    if (try space = args.index_of_char(' ')) {
        String username = args[0..space - 1];
        String password = args[space + 1..].trim();

        if (_account_count > 0) {
            // Account-based auth — check username + password against accounts
            for (int i = 0; i < _account_count; i++) {
                if (_accounts[i].username == username && _accounts[i].password == password) {
                    c.is_authenticated = true;
                    c.permissions = _accounts[i].permissions;

                    String[] auth_fields = { string::tformat("%d", config::AUTH_SUCCESS) };
                    c.send_packet("AUTH", auth_fields);
                    c.send_server_message(string::tformat("Logged in as %s (%s).", username, _accounts[i].role_name));
                    io::printfn("[mod] %s logged in as '%s' [%s] (UID %d)", c.ipid, username, _accounts[i].role_name, c.uid);
                    return;
                }
            }

            // No matching account
            String[] auth_fields = { string::tformat("%d", config::AUTH_FAILURE) };
            c.send_packet("AUTH", auth_fields);
            c.send_server_message("Login failed. Invalid username or password.");
        } else {
            // Fallback: legacy single-password auth (no accounts configured)
            if (password == DEFAULT_MOD_PASSWORD) {
                c.is_authenticated = true;
                c.permissions = commands::PERM_MUTE | commands::PERM_KICK |
                                commands::PERM_BAN | commands::PERM_MOVE_USERS |
                                commands::PERM_MODIFY_AREA | commands::PERM_BAN_INFO |
                                commands::PERM_ADMIN;

                String[] auth_fields = { string::tformat("%d", config::AUTH_SUCCESS) };
                c.send_packet("AUTH", auth_fields);
                c.send_server_message(string::tformat("Logged in as %s.", username));
                io::printfn("[mod] %s logged in as '%s' (UID %d) [legacy auth]", c.ipid, username, c.uid);
            } else {
                String[] auth_fields = { string::tformat("%d", config::AUTH_FAILURE) };
                c.send_packet("AUTH", auth_fields);
                c.send_server_message("Login failed. Wrong password.");
            }
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
