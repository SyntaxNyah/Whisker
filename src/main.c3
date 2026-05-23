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

    usz i = 0;
    while (i < args.len) {
        if (args[i] == "-c" && i + 1 < args.len) {
            config_dir = args[i + 1];
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

    // Initialize and run the server
    server::Server? srv = server::init(config_dir);
    if (catch err = srv) {
        io::printfn("[FATAL] Failed to initialize server: %s", err);
        return;
    }

    // Run the main accept loop (blocks until shutdown)
    if (catch err = srv.run()) {
        io::printfn("[FATAL] Server error: %s", err);
    }
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
