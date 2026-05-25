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
// SETUP (after installing the .dll/.so):
//   1. Optionally add to your config/config.toml:
//
//        [advertiser]
//        masterserver = "https://servers.aceattorneyonline.com/servers"
//
//   2. Restart the server.
//
// The plugin reads [server] and [websocket] from config.toml automatically.
// It sends a heartbeat to the master server every 60 seconds so players
// can find your server in the public browser.

module server_advertiser;

import std::io;
import std::thread;

// ============================================================
// Whisker plugin interface (standalone definitions)
// ============================================================

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
// Configuration defaults
// ============================================================

const String DEFAULT_MS_URL     = "https://servers.aceattorneyonline.com/servers";
const ushort DEFAULT_TCP_PORT   = 27016;
const ushort DEFAULT_WS_PORT    = 27017;
const ushort DEFAULT_WSS_PORT   = 443;
const uint   HEARTBEAT_INTERVAL = 60;

// ============================================================
// Plugin state
// ============================================================

struct AdvertiserState {
    bool     running;
    ushort   tcp_port;
    ushort   ws_port;
    ushort   wss_port;
    bool     ws_enabled;
    bool     wss_enabled;
}

AdvertiserState state;

// Pre-built curl command — assembled on the main thread during init.
char[4096] curl_cmd_buf;

// Static buffers for strings read from config (must outlive init).
char[256] cfg_name;
char[512] cfg_description;
char[512] cfg_masterserver;

// C functions used in the heartbeat thread to avoid C3 runtime TLS issues.
extern fn CInt puts(ZString s);
extern fn CInt system(ZString cmd);
extern fn uint sleep_c(uint seconds) @cname("sleep");

// C file I/O for config parsing.
extern fn void* fopen_c(ZString path, ZString mode) @cname("fopen");
extern fn char* fgets_c(char* buf, CInt size, void* stream) @cname("fgets");
extern fn CInt fclose_c(void* stream) @cname("fclose");

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
    // Set defaults
    state.tcp_port    = DEFAULT_TCP_PORT;
    state.ws_port     = DEFAULT_WS_PORT;
    state.wss_port    = DEFAULT_WSS_PORT;
    state.ws_enabled  = true;
    state.wss_enabled = false;
    state.running     = true;

    // Default strings
    copy_str("Whisker Server", &cfg_name, 255);
    copy_str("", &cfg_description, 511);
    copy_str(DEFAULT_MS_URL, &cfg_masterserver, 511);

    // Read actual values from config.toml
    read_config();

    io::printfn("[advertiser] Advertising to: %s", (ZString)&cfg_masterserver);
    io::printfn("[advertiser] Server: %s (TCP:%d WS:%d WSS:%d)",
        (ZString)&cfg_name, state.tcp_port, state.ws_port, state.wss_port);

    // Build the curl command on the main thread (temp allocators work here).
    // The AO master server expects JSON: {"port", "ws_port", "name", "description", "players"}
    String ws_part = "";
    if (state.ws_enabled) {
        ws_part = string::tformat(`,"ws_port":%d`, state.ws_port);
    }
    if (state.wss_enabled) {
        ws_part = string::tformat(`,"ws_port":%d`, state.wss_port);
    }

    ZString cmd = string::tformat_zstr(
        `curl -sf --max-time 10 -X POST -H "Content-Type: application/json" -d '{"port":%d,"name":"%s","description":"%s","players":0%s}' "%s"`,
        state.tcp_port, (ZString)&cfg_name, (ZString)&cfg_description, ws_part, (ZString)&cfg_masterserver
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
// Heartbeat loop (C functions only — no C3 temp allocator)
// ============================================================

fn int heartbeat_loop(void* arg) {
    sleep_c(5);

    while (state.running) {
        CInt result = system((ZString)&curl_cmd_buf[0]);
        if (result == 0) {
            puts("[advertiser] Heartbeat sent successfully.");
        } else {
            puts("[advertiser] WARNING: Failed to send heartbeat.");
        }
        sleep_c(HEARTBEAT_INTERVAL);
    }
    return 0;
}

// ============================================================
// Config file reader
// ============================================================
//
// Reads config/config.toml to get server name, ports, and the
// [advertiser] masterserver URL. Uses C file I/O so it works
// reliably in a standalone plugin.

fn void read_config() {
    // Try config/ relative to working directory first,
    // then ../config/ (for running from out/)
    void* f = fopen_c("config/config.toml", "r");
    if (f == null) {
        f = fopen_c("../config/config.toml", "r");
    }
    if (f == null) {
        io::printn("[advertiser] Could not open config.toml, using defaults.");
        return;
    }

    char[512] line_buf;
    // Track which [section] we're in: 0=none, 1=server, 2=websocket, 3=advertiser
    int section = 0;

    while (fgets_c(&line_buf[0], 512, f) != null) {
        // Find line length and trim trailing whitespace
        usz len = 0;
        while (len < 511 && line_buf[len] != 0 && line_buf[len] != '\n' && line_buf[len] != '\r') len++;
        if (len == 0) continue;

        // Skip leading whitespace
        usz start = 0;
        while (start < len && (line_buf[start] == ' ' || line_buf[start] == '\t')) start++;
        if (start >= len) continue;

        // Skip comments
        if (line_buf[start] == '#') continue;

        // Check for section headers
        if (line_buf[start] == '[') {
            if (match_section(&line_buf, start, len, "server"))          { section = 1; }
            else if (match_section(&line_buf, start, len, "websocket"))  { section = 2; }
            else if (match_section(&line_buf, start, len, "advertiser")) { section = 3; }
            else { section = 0; }
            continue;
        }

        // Parse key = value
        if (section == 0) continue;

        // Find '='
        usz eq = start;
        while (eq < len && line_buf[eq] != '=') eq++;
        if (eq >= len) continue;

        // Extract key (trimmed)
        usz key_end = eq;
        while (key_end > start && (line_buf[key_end - 1] == ' ' || line_buf[key_end - 1] == '\t')) key_end--;
        String key = (String)line_buf[start..key_end - 1];

        // Extract value (trimmed, unquoted)
        usz val_start = eq + 1;
        while (val_start < len && (line_buf[val_start] == ' ' || line_buf[val_start] == '\t')) val_start++;
        usz val_end = len;
        while (val_end > val_start && (line_buf[val_end - 1] == ' ' || line_buf[val_end - 1] == '\t')) val_end--;

        // Strip quotes
        if (val_end > val_start && line_buf[val_start] == '"' && line_buf[val_end - 1] == '"') {
            val_start++;
            val_end--;
        }

        String value = "";
        if (val_end > val_start) {
            value = (String)line_buf[val_start..val_end - 1];
        }

        // Apply to state
        if (section == 1) { // [server]
            if (key == "name")        { copy_str(value, &cfg_name, 255); }
            if (key == "description") { copy_str(value, &cfg_description, 511); }
            if (key == "port")        { state.tcp_port = parse_ushort(value); }
        }

        if (section == 2) { // [websocket]
            if (key == "enable_ws")   { state.ws_enabled = (value == "true"); }
            if (key == "ws_port")     { state.ws_port = parse_ushort(value); }
            if (key == "enable_wss")  { state.wss_enabled = (value == "true"); }
            if (key == "wss_port")    { state.wss_port = parse_ushort(value); }
        }

        if (section == 3) { // [advertiser]
            if (key == "masterserver") { copy_str(value, &cfg_masterserver, 511); }
        }
    }

    fclose_c(f);
    io::printn("[advertiser] Config loaded from config.toml.");
}

// ============================================================
// Helpers
// ============================================================

fn bool match_section(char* buf, usz start, usz len, String name) {
    // Check if buf[start..len] matches [name]
    if (buf[start] != '[') return false;
    usz i = start + 1;
    // Skip whitespace after [
    while (i < len && (buf[i] == ' ' || buf[i] == '\t')) i++;
    usz name_start = i;
    // Find ]
    while (i < len && buf[i] != ']') i++;
    if (i >= len) return false;
    usz name_end = i;
    // Trim trailing whitespace before ]
    while (name_end > name_start && (buf[name_end - 1] == ' ' || buf[name_end - 1] == '\t')) name_end--;

    if (name_end - name_start != name.len) return false;
    for (usz j = 0; j < name.len; j++) {
        char a = buf[name_start + j];
        char b = name[j];
        // Case-insensitive
        if (a >= 'A' && a <= 'Z') a += 32;
        if (b >= 'A' && b <= 'Z') b += 32;
        if (a != b) return false;
    }
    return true;
}

fn void copy_str(String src, char* dst, usz max_len) {
    usz i = 0;
    while (i < src.len && i < max_len) {
        dst[i] = src[i];
        i++;
    }
    dst[i] = 0;
}

fn ushort parse_ushort(String s) {
    int result = 0;
    foreach (char c : s) {
        if (c >= '0' && c <= '9') {
            result = result * 10 + (c - '0');
        }
    }
    return (ushort)result;
}
