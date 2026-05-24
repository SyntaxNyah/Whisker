// Whisker AO2 Server — Server Console
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Interactive server console for runtime administration.
// Runs in a background thread, reads commands from stdin.
//
// Console Commands:
//   addmod <username> <password> [role]  — Create moderator account
//   removemod <username>                 — Remove moderator account
//   listmods                             — List all mod accounts
//   reload                               — Hot-reload all plugins
//   status                               — Server status
//   help                                 — Show available commands
//   quit / exit / stop                   — Shut down the server

module whisker::console;

import whisker::server;
import whisker::moderation;
import whisker::plugin;
import whisker::config;
import std::io;
import std::thread;

// C interop for stdin reading (cross-platform)
extern fn int getchar();

// ============================================================
// Console thread — reads stdin and processes commands
// ============================================================

fn int console_thread(void* arg) {
    @pool_init(mem, 1024 * 64) {
        server::Server* srv = (server::Server*)arg;

        io::printn("");
        io::printn("[console] Server console ready. Type 'help' for commands.");

        char[512] line_buf;

        while (srv.running) {
            // Read a line from stdin character by character
            int pos = 0;
            while (pos < 510) {
                int ch = getchar();
                if (ch < 0) { return 0; } // EOF — stdin closed
                if ((char)ch == '\n') break;
                if ((char)ch == '\r') continue;
                line_buf[pos] = (char)ch;
                pos++;
            }

            if (pos == 0) continue;
            String line = ((String)line_buf[0..pos - 1]).trim();
            if (line.len == 0) continue;

            process_command(srv, line);
        }
    };
    return 0;
}

// ============================================================
// Command dispatch
// ============================================================

fn void process_command(server::Server* srv, String line) {
    String cmd;
    String args = "";

    if (try space = line.index_of_char(' ')) {
        cmd = line[0..space - 1];
        args = line[space + 1..].trim();
    } else {
        cmd = line;
    }

    switch {
        case cmd == "help":
            cmd_help();
        case cmd == "addmod":
            cmd_addmod(args);
        case cmd == "removemod":
            cmd_removemod(args);
        case cmd == "listmods":
            cmd_listmods();
        case cmd == "reload":
            cmd_reload(srv);
        case cmd == "status":
            cmd_status(srv);
        case cmd == "quit" || cmd == "exit" || cmd == "stop":
            io::printn("[console] Shutting down server...");
            srv.running = false;
        default:
            io::printfn("[console] Unknown command: '%s'. Type 'help' for commands.", cmd);
    }
}

// ============================================================
// Console command handlers
// ============================================================

fn void cmd_help() {
    io::printn("=== Server Console Commands ===");
    io::printn("  addmod <user> <pass> [role]  Create moderator account (default: moderator)");
    io::printn("  removemod <username>         Remove moderator account");
    io::printn("  listmods                     List all mod accounts");
    io::printn("  reload                       Hot-reload all plugins");
    io::printn("  status                       Show server status");
    io::printn("  quit / exit / stop           Shut down server");
    io::printn("");
    io::printn("Available roles (from roles.toml):");
    moderation::list_roles();
}

fn void cmd_addmod(String args) {
    String[] parts = args.tsplit(" ");
    if (parts.len < 2) {
        io::printn("Usage: addmod <username> <password> [role]");
        io::printn("  Default role: moderator. See roles.toml for available roles.");
        return;
    }

    String username = parts[0];
    String password = parts[1];
    String role = parts.len >= 3 ? parts[2] : "moderator";

    if (moderation::add_account(username, password, role)) {
        io::printfn("[auth] Account '%s' created with role '%s'.", username, role);
    } else {
        io::printfn("[auth] Failed. Username may already exist or role '%s' is invalid.", role);
    }
}

fn void cmd_removemod(String args) {
    String username = args.trim();
    if (username.len == 0) {
        io::printn("Usage: removemod <username>");
        return;
    }

    if (moderation::remove_account(username)) {
        io::printfn("[auth] Account '%s' removed.", username);
    } else {
        io::printfn("[auth] Account '%s' not found.", username);
    }
}

fn void cmd_listmods() {
    moderation::list_accounts();
}

fn void cmd_reload(server::Server* srv) {
    io::printn("[console] Reloading plugins...");
    plugin::reload_all(&srv.plugins, &srv.plugin_api, srv.cfg.plugin_directory);
    io::printn("[console] Plugin reload complete.");
}

fn void cmd_status(server::Server* srv) {
    io::printfn("=== %s v%s ===", config::SERVER_SOFTWARE, config::SERVER_VERSION);
    io::printfn("  Server:   %s", srv.cfg.server_name);
    io::printfn("  Players:  %d / %d", srv.client_count, srv.cfg.max_players);
    io::printfn("  Areas:    %d", srv.area_count);
    io::printfn("  Plugins:  %d loaded, %d commands, %d hooks",
        srv.plugins.plugin_count, srv.plugins.command_count, srv.plugins.hook_count);
    io::printfn("  Accounts: %d", moderation::get_account_count());
}
