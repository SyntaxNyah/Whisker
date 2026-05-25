// Whisker Optional Plugin — Server Advertiser
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Advertises your server to the Attorney Online master server
// so players can find it in the public server browser.
//
// A compiled .dll is included alongside this file. If you just want
// to use the plugin, drag the .dll into your plugins/ folder.
//
// This source file is provided as a learning exercise — if you want
// to try compiling a C3 plugin yourself, follow the Plugin Dev Guide:
//   plugins/PLUGIN DEV GUIDE README.md
//
// SETUP (after installing the .dll):
//   1. Add to your config/config.toml:
//
//        [advertiser]
//        masterserver = "https://servers.aceattorneyonline.com/servers"
//
//   2. Restart the server.
//
// The plugin sends a heartbeat to the master server every 60 seconds
// so players can find your server in the public browser.

module server_advertiser;

import std::io;
import std::thread;
import std::time;

// ============================================================
// Whisker plugin interface (standalone definitions)
// ============================================================
// When building a plugin standalone (outside the server source tree),
// you define the plugin structs locally. The server loads your .dll
// at runtime and calls the exported functions by name.

struct PluginInfo {
    String name;
    String version;
    String author;
    String description;
}

struct PluginAPI {
    void* manager;
}

// ============================================================
// Configuration
// ============================================================

const String DEFAULT_MS_URL    = "https://servers.aceattorneyonline.com/servers";
const String SERVER_NAME       = "Whisker";
const ushort DEFAULT_TCP_PORT  = 27016;
const ushort DEFAULT_WS_PORT   = 27017;
const int    DEFAULT_MAX_PLAYERS = 100;
const long   HEARTBEAT_INTERVAL_SEC = 60;

// ============================================================
// Plugin state
// ============================================================

struct AdvertiserState {
    String   masterserver_url;
    String   server_name;
    String   server_description;
    ushort   server_port;
    ushort   ws_port;
    bool     ws_enabled;
    int      max_players;
    bool     running;
}

AdvertiserState state;

// ============================================================
// Plugin interface (exported)
// ============================================================

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return {
        .name        = "Server Advertiser",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Advertises to the AO master server",
    };
}

fn bool whisker_plugin_init(PluginAPI* api) @export("whisker_plugin_init") {
    state.masterserver_url   = DEFAULT_MS_URL;
    state.server_name        = SERVER_NAME;
    state.server_description = "";
    state.server_port        = DEFAULT_TCP_PORT;
    state.ws_port            = DEFAULT_WS_PORT;
    state.ws_enabled         = true;
    state.max_players        = DEFAULT_MAX_PLAYERS;
    state.running            = true;

    io::printfn("[advertiser] Advertising to: %s", state.masterserver_url);
    io::printfn("[advertiser] Server: %s (port %d)", state.server_name, state.server_port);

    Thread heartbeat;
    if (catch heartbeat.create(&heartbeat_loop, null)) {
        io::printn("[advertiser] WARNING: Failed to start heartbeat thread.");
        return false;
    }
    heartbeat.detach();
    io::printn("[advertiser] Heartbeat thread started (interval: 60s).");

    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    state.running = false;
    io::printn("[advertiser] Shutting down. Server will be delisted on next MS refresh.");
}

// ============================================================
// Heartbeat loop
// ============================================================

fn int heartbeat_loop(void* arg) @pool() {
    thread::sleep(time::sec(5));

    while (state.running) {
        send_heartbeat();
        thread::sleep(time::sec(HEARTBEAT_INTERVAL_SEC));
    }
    return 0;
}

// ============================================================
// HTTP POST to master server
// ============================================================

fn void send_heartbeat() {
    // The AO2 master server expects a POST with server information.
    // Standard fields: port, ws_port, players, name, description.
    // The master server uses the source IP as the server's IP.

    DString body = dstring::temp();
    body.append_string("port=");
    body.append_string(string::tformat("%d", state.server_port));
    body.append_string("&name=");
    body.append_string(url_encode(state.server_name));
    body.append_string("&description=");
    body.append_string(url_encode(state.server_description));
    body.append_string("&players=0");
    body.append_string("&max_players=");
    body.append_string(string::tformat("%d", state.max_players));

    if (state.ws_enabled) {
        body.append_string("&ws_port=");
        body.append_string(string::tformat("%d", state.ws_port));
    }

    if (post_to_url(state.masterserver_url, body.str_view())) {
        io::printn("[advertiser] Heartbeat sent successfully.");
    } else {
        io::printn("[advertiser] WARNING: Failed to send heartbeat.");
    }
}

// ============================================================
// HTTP POST via curl
// ============================================================

// C's system() — lets us shell out to curl for HTTPS support.
// curl ships with Windows 10+, Linux, and macOS.
extern fn CInt system(ZString cmd);

fn bool post_to_url(String url, String body) {
    // -s: silent, -f: fail on HTTP errors, --max-time: 10s timeout
    ZString cmd = string::tformat_zstr(
        `curl -sf --max-time 10 -X POST -H "Content-Type: application/x-www-form-urlencoded" -d "%s" "%s"`,
        body, url
    );
    return system(cmd) == 0;
}

// ============================================================
// URL encoding helper
// ============================================================

fn String url_encode(String input) {
    DString result = dstring::temp();

    foreach (char c : input) {
        switch {
            case c == ' ':
                result.append_char('+');
            case (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
                 (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.':
                result.append_char(c);
            default:
                result.append_string(string::tformat("%%%02X", (int)c));
        }
    }

    return result.str_view();
}
