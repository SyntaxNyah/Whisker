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
const uint   HEARTBEAT_INTERVAL_SEC = 60;

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

// Pre-built curl command — assembled on the main thread during init
// so the heartbeat thread never needs C3's temp allocator.
char[4096] curl_cmd_buf;

// C functions used in the heartbeat thread to avoid C3 runtime TLS issues
extern fn CInt puts(ZString s);
extern fn uint sleep_c(uint seconds) @cname("sleep");

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

    // Pre-build the curl command on the main thread (where C3's temp
    // allocator works). The heartbeat thread will just call system()
    // with this pre-built string — no C3 runtime needed in the thread.
    // The AO master server expects a JSON POST body.
    String ws_part = "";
    if (state.ws_enabled) {
        ws_part = string::tformat(`,"ws_port":%d`, state.ws_port);
    }

    ZString cmd = string::tformat_zstr(
        `curl -sf --max-time 10 -X POST -H "Content-Type: application/json" -d '{"port":%d,"name":"%s","description":"%s","players":0%s}' "%s"`,
        state.server_port, state.server_name, state.server_description, ws_part, state.masterserver_url
    );

    // Copy into static buffer so it survives past this function
    usz i = 0;
    while (i < 4095 && cmd[i] != 0) {
        curl_cmd_buf[i] = cmd[i];
        i++;
    }
    curl_cmd_buf[i] = 0;

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
//
// This thread uses ONLY C functions (system, sleep, puts) to avoid
// C3 temp allocator TLS issues in dynamically loaded plugins.
// The curl command is pre-built during init on the main thread.

extern fn CInt system(ZString cmd);

fn int heartbeat_loop(void* arg) {
    sleep_c(5);

    while (state.running) {
        CInt result = system((ZString)&curl_cmd_buf[0]);
        if (result == 0) {
            puts("[advertiser] Heartbeat sent successfully.");
        } else {
            puts("[advertiser] WARNING: Failed to send heartbeat.");
        }
        sleep_c(HEARTBEAT_INTERVAL_SEC);
    }
    return 0;
}

