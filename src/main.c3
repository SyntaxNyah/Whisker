// Whisker AO2 Server — Entry Point
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Whisker is a clean, minimal Attorney Online 2 server written in C3.
// Built for speed, extensibility, and simplicity.
//
// Protocol documentation by OmniTroid (@omnitroid) and the
// Attorney Online dev team: https://github.com/AttorneyOnline
//
// Architectural inspiration from:
//   Athena    — https://github.com/MangosArentLiterature/Athena
//   Nyathena  — https://github.com/SyntaxNyah/Nyathena (fork of Athena)
//   Ferris-AO — https://github.com/AO2-Client/Ferris-AO
//   tsuserver / KFO-Server — https://github.com/AttorneyOnline/KFO-Server
//   webAO     — https://github.com/AttorneyOnline/webAO
//   AO2 Client — https://github.com/AttorneyOnline/AO2-Client
//
// License: AGPL-3.0

module whisker;

import whisker::config;
import whisker::server;
import std::io;

fn void main(String[] args) {
    io::printn("");
    io::printn("  ╦ ╦┬ ┬┬┌─┐┬┌─┌─┐┬─┐");
    io::printn("  ║║║├─┤│└─┐├┴┐├┤ ├┬┘");
    io::printn("  ╚╩╝┴ ┴┴└─┘┴ ┴└─┘┴└─");
    io::printn("  Attorney Online 2 Server");
    io::printn("");

    // Parse command-line arguments
    String config_dir = "config";
    bool config_specified = false;

    usz i = 0;
    while (i < args.len) {
        if (args[i] == "-c" && i + 1 < args.len) {
            config_dir = args[i + 1];
            config_specified = true;
            i += 2;
            continue;
        }
        if (args[i] == "--help" || args[i] == "-h") {
            print_usage();
            return;
        }
        if (args[i] == "--version" || args[i] == "-v") {
            io::printfn("%s v%s", config::SERVER_SOFTWARE, config::SERVER_VERSION);
            return;
        }
        i++;
    }

    // Auto-resolve config directory relative to executable
    if (!config_specified) {
        config_dir = resolve_config_dir(args);
    }
    io::printfn("  Config: %s", config_dir);

    // Initialize and run the server
    server::Server*? srv = server::init(config_dir);
    if (catch err = srv) {
        io::printfn("[FATAL] Failed to initialize server: %s", err);
        return;
    }

    // Run the main accept loop (blocks until shutdown)
    if (catch err = srv.run()) {
        io::printfn("[FATAL] Server error: %s", err);
    }
}

// Find config/ directory relative to executable location.
// Checks: <exe_dir>/config/, <exe_dir>/../config/, then ./config/
fn String resolve_config_dir(String[] args) {
    if (args.len > 0 && args[0].len > 0) {
        String exe = args[0];

        // Find last path separator to get executable's directory
        int last_sep = -1;
        for (int i = 0; i < (int)exe.len; i++) {
            if (exe[i] == '/' || exe[i] == '\\') {
                last_sep = i;
            }
        }

        if (last_sep >= 0) {
            String exe_dir = exe[0..(usz)last_sep];

            // Try config/ next to the executable
            String candidate = string::tformat("%s/config", exe_dir);
            if (config_dir_valid(candidate)) return candidate;

            // Try ../config/ (binary might be in a build subdirectory)
            String candidate2 = string::tformat("%s/../config", exe_dir);
            if (config_dir_valid(candidate2)) return candidate2;
        }
    }

    // Fall back to ./config relative to working directory
    return "config";
}

fn bool config_dir_valid(String dir) {
    String path = string::tformat("%s/config.toml", dir);
    char[]? data = io::file::load(tmem, path);
    if (catch data) return false;
    return true;
}

fn void print_usage() {
    io::printn("Usage: whisker [options]");
    io::printn("");
    io::printn("Options:");
    io::printn("  -c <path>    Config directory (default: config)");
    io::printn("  -h, --help   Show this help");
    io::printn("  -v, --version  Show version");
    io::printn("");
    io::printn("Configuration:");
    io::printn("  Place config files in the config directory:");
    io::printn("    config.toml     Server settings");
    io::printn("    areas.toml      Area definitions");
    io::printn("    characters.txt  Character list (one per line)");
    io::printn("    music.txt       Music list (one per line)");
    io::printn("    roles.toml      Moderator role permissions");
    io::printn("");
    io::printn("Plugins:");
    io::printn("  Drop .so/.dll files into plugins/ directory.");
    io::printn("  See plugins/README.md for development guide.");
}
