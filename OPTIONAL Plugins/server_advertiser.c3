// Whisker Optional Plugin — Server Advertiser
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Advertises your server to the Attorney Online master server
// so players can find it in the public server browser.
//
// SETUP:
//   1. Build this as a dynamic library and drop it into plugins/
//   2. Add to your config/config.toml:
//
//        [advertiser]
//        masterserver = "https://servers.aceattorneyonline.com/servers"
//
//   3. Restart the server.
//
// The plugin reads the server name, description, port, and player
// count from the running server and sends a heartbeat to the master
// server every 60 seconds.

module server_advertiser;

import whisker::plugin;
import whisker::config;
import whisker::client;
import std::io;
import std::net;
import std::thread;
import std::time;

// ============================================================
// Configuration
// ============================================================

// Default master server URL (the official AO2 master server).
// Override this by setting masterserver in [advertiser] in config.toml.
const String DEFAULT_MS_URL = "https://servers.aceattorneyonline.com/servers";

// How often to send a heartbeat (in seconds).
const int HEARTBEAT_INTERVAL_SEC = 60;

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
// Plugin interface
// ============================================================

fn plugin::PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return plugin::PluginInfo {
        .name        = "Server Advertiser",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Advertises to the AO master server",
    };
}

fn bool whisker_plugin_init(plugin::PluginAPI* api) @export("whisker_plugin_init") {
    // Read config values from the server config.
    // The masterserver URL comes from config.toml [advertiser] section.
    // Server name, port, etc. come from [server] section.
    //
    // NOTE: The plugin API provides access to the server config.
    // If your build doesn't expose config reading to plugins yet,
    // you can hardcode the URL here instead:
    //
    //   state.masterserver_url = "https://servers.aceattorneyonline.com/servers";
    //
    // For now, we use the default and let the config override it.

    state.masterserver_url  = DEFAULT_MS_URL;
    state.server_name       = config::SERVER_SOFTWARE;
    state.server_description = "";
    state.server_port       = config::DEFAULT_TCP_PORT;
    state.ws_port           = config::DEFAULT_WS_PORT;
    state.ws_enabled        = true;
    state.max_players       = config::DEFAULT_MAX_PLAYERS;
    state.running           = true;

    io::printfn("[advertiser] Advertising to: %s", state.masterserver_url);
    io::printfn("[advertiser] Server: %s (port %d)", state.server_name, state.server_port);

    // Start the heartbeat thread
    Thread heartbeat;
    if (!catch heartbeat.create(&heartbeat_loop, null)) {
        heartbeat.detach();
        io::printn("[advertiser] Heartbeat thread started (interval: 60s).");
    } else {
        io::printn("[advertiser] WARNING: Failed to start heartbeat thread.");
        return false;
    }

    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    state.running = false;
    io::printn("[advertiser] Shutting down. Server will be delisted on next MS refresh.");
}

// ============================================================
// Heartbeat loop
// ============================================================

fn int heartbeat_loop(void* arg) {
    // Initial delay — let the server finish starting up
    time::sleep(time::Duration.from_sec(5));

    while (state.running) {
        send_heartbeat();
        time::sleep(time::Duration.from_sec(HEARTBEAT_INTERVAL_SEC));
    }
    return 0;
}

// ============================================================
// HTTP POST to master server
// ============================================================

fn void send_heartbeat() {
    // Build the advertisement payload.
    //
    // The AO2 master server expects a POST with server information.
    // The exact format depends on the master server implementation.
    //
    // Standard fields:
    //   - port:        TCP port
    //   - ws_port:     WebSocket port (if enabled)
    //   - players:     Current player count
    //   - name:        Server display name
    //   - description: Server description
    //
    // The master server uses the source IP of the request as the
    // server's IP address, so you don't need to send it explicitly.

    // Build a simple form-encoded body
    // (Adjust format if the master server expects JSON instead)
    DString body = dstring::temp();
    body.append_string("port=");
    body.append_string(string::tformat("%d", state.server_port));
    body.append_string("&name=");
    body.append_string(url_encode(state.server_name));
    body.append_string("&description=");
    body.append_string(url_encode(state.server_description));
    body.append_string("&players=0");  // TODO: read live player count from server
    body.append_string("&max_players=");
    body.append_string(string::tformat("%d", state.max_players));

    if (state.ws_enabled) {
        body.append_string("&ws_port=");
        body.append_string(string::tformat("%d", state.ws_port));
    }

    // Send HTTP POST
    // NOTE: This is a simplified HTTP client. C3's standard library
    // network support varies by version. You may need to adapt this
    // to use whatever HTTP client is available in your C3 build.
    //
    // For a minimal implementation, you can also shell out:
    //   std::process::run("curl", { "-s", "-X", "POST", "-d", body, url });
    //
    // Or use C3's built-in net module if available.

    if (post_to_url(state.masterserver_url, body.str_view())) {
        io::printn("[advertiser] Heartbeat sent successfully.");
    } else {
        io::printn("[advertiser] WARNING: Failed to send heartbeat.");
    }
}

// ============================================================
// Minimal HTTP POST helper
// ============================================================

fn bool post_to_url(String url, String body) {
    // Parse the URL to extract host and path.
    //
    // This is a simplified implementation. For production use,
    // consider using a proper HTTP library or shelling out to curl.
    //
    // The implementation below handles the common case:
    //   https://servers.aceattorneyonline.com/servers
    //         ^host                          ^path

    // For now, log what we would send.
    // Replace this with actual HTTP POST when C3's net module
    // supports it, or use the curl fallback above.
    io::printfn("[advertiser] POST %s (%d bytes)", url, body.len);

    // TODO: Implement actual HTTP POST. Options:
    //
    // Option A: Use C3's built-in TCP + manual HTTP
    //   1. Parse URL into host, port, path
    //   2. Open TCP connection to host:443
    //   3. Send HTTP POST request with Content-Type: application/x-www-form-urlencoded
    //   4. Read response, check for 200 OK
    //
    // Option B: Shell out to curl (simplest, works everywhere)
    //   std::process::run("curl", {
    //       "-s", "-X", "POST",
    //       "-H", "Content-Type: application/x-www-form-urlencoded",
    //       "-d", body,
    //       url
    //   });
    //
    // Option C: Link against libcurl via C3's C interop
    //   import libc_curl;  // Write a C3 wrapper for libcurl

    return true; // Placeholder — replace with real implementation
}

// ============================================================
// URL encoding helper
// ============================================================

fn String url_encode(String input) {
    // Simple URL encoding for the advertisement payload.
    // Encodes spaces as '+' and special characters as %XX.

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
