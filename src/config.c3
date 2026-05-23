// Whisker AO2 Server — Configuration
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Loads server settings from TOML-like config files.
// All tunables live here — no magic numbers in game logic.

module whisker::config;

import std::io;
import std::collections::map;

// ============================================================
// Named Constants — every tunable has a name, never a bare number
// ============================================================

// -- Network defaults --
const ushort  DEFAULT_TCP_PORT              = 27016;
const ushort  DEFAULT_WS_PORT               = 27017;
const ushort  DEFAULT_WSS_PORT              = 443;
const int     DEFAULT_MAX_PLAYERS           = 100;
const int     DEFAULT_LISTEN_BACKLOG        = 128;

// -- Timeouts (milliseconds) --
const int     HANDSHAKE_TIMEOUT_MS          = 60_000;
const int     KEEPALIVE_INTERVAL_MS         = 10_000;
const int     KEEPALIVE_TIMEOUT_MS          = 30_000;
const int     WS_PING_INTERVAL_MS           = 30_000;

// -- Rate limit defaults --
const int     DEFAULT_MSG_RATE_LIMIT        = 20;
const int     DEFAULT_MSG_RATE_WINDOW_SEC   = 10;
const int     DEFAULT_OOC_RATE_LIMIT        = 4;
const int     DEFAULT_OOC_RATE_WINDOW_SEC   = 1;
const int     DEFAULT_CONN_RATE_LIMIT       = 10;
const int     DEFAULT_CONN_RATE_WINDOW_SEC  = 10;
const int     DEFAULT_RAW_PKT_RATE_LIMIT    = 20;
const int     DEFAULT_RAW_PKT_RATE_WINDOW_SEC = 2;
const int     DEFAULT_FLOOD_BAN_THRESHOLD   = 6;

// -- Protocol limits --
const usz     MAX_PACKET_BYTES              = 8192;
const usz     MAX_PACKET_FIELDS             = 1024;
const usz     MAX_IC_MESSAGE_LEN            = 256;
const usz     MAX_OOC_MESSAGE_LEN           = 256;
const usz     MAX_OOC_NAME_LEN             = 30;
const usz     MAX_SHOWNAME_LEN              = 30;
const usz     MAX_EVIDENCE_NAME_LEN         = 255;
const usz     MAX_EVIDENCE_DESC_LEN         = 255;
const usz     MAX_EVIDENCE_IMG_LEN          = 255;
const int     MAX_EVIDENCE_PER_AREA         = 128;
const int     MAX_MULTICLIENT               = 16;

// -- Penalty bars --
const int     PENALTY_BAR_MIN               = 0;
const int     PENALTY_BAR_MAX               = 10;
const int     PENALTY_BAR_DEFENSE           = 1;
const int     PENALTY_BAR_PROSECUTION       = 2;

// -- Timer --
const int     MAX_TIMER_ID                  = 4;
const int     TIMER_CMD_START               = 0;
const int     TIMER_CMD_PAUSE               = 1;
const int     TIMER_CMD_SHOW                = 2;
const int     TIMER_CMD_HIDE                = 3;

// -- ARUP update types --
const int     ARUP_PLAYERS                  = 0;
const int     ARUP_STATUS                   = 1;
const int     ARUP_CM                       = 2;
const int     ARUP_LOCK                     = 3;

// -- Auth states --
const int     AUTH_SUCCESS                  = 1;
const int     AUTH_FAILURE                  = 0;
const int     AUTH_LOGOUT                   = -1;

// -- Character state --
const int     CHAR_TAKEN                    = -1;
const int     CHAR_FREE                     = 0;
const int     NO_CHAR_SELECTED              = -1;
const int     NO_UID                        = -1;
const int     NO_PAIR                       = -1;

// -- WebSocket --
const String  WS_MAGIC_GUID                 = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
const usz     WS_MAX_FRAME_SIZE             = 65536;

// -- Moderation defaults --
const String  DEFAULT_BAN_DURATION          = "3d";
const int     DEFAULT_BAN_DURATION_SEC      = 259200;
const int     MAX_BAN_REASON_LEN            = 255;

// -- Server identity --
const String  SERVER_SOFTWARE               = "Whisker";
const String  SERVER_VERSION                = "0.1.0";

// -- Decryptor (legacy FantaCrypt — we always send NOENCRYPT) --
const String  DECRYPTOR_PACKET              = "decryptor#NOENCRYPT#%";

// -- Packet terminators --
const char    FIELD_SEPARATOR               = '#';
const String  PACKET_TERMINATOR             = "#%";
const char    PACKET_END_CHAR               = '%';
const char    SUBFIELD_SEPARATOR            = '&';

// -- Escape sequences --
const String  ESCAPE_HASH                   = "<num>";
const String  ESCAPE_AMPERSAND              = "<and>";
const String  ESCAPE_PERCENT                = "<percent>";
const String  ESCAPE_DOLLAR                 = "<dollar>";


// ============================================================
// Server configuration struct
// ============================================================

struct ServerConfig {
    // -- Identity --
    String server_name;
    String server_description;
    String motd;

    // -- Network --
    String bind_address;
    ushort tcp_port;
    ushort ws_port;
    ushort wss_port;
    bool   enable_ws;
    bool   enable_wss;
    String tls_cert_path;
    String tls_key_path;

    // -- Capacity --
    int max_players;
    int multiclient_limit;

    // -- Assets --
    String asset_url;

    // -- Rate limits --
    int msg_rate_limit;
    int msg_rate_window_sec;
    int ooc_rate_limit;
    int ooc_rate_window_sec;
    int conn_rate_limit;
    int conn_rate_window_sec;
    int raw_pkt_rate_limit;
    int raw_pkt_rate_window_sec;

    // -- Flood protection --
    bool conn_flood_autoban;
    int  flood_ban_threshold;

    // -- Proxy --
    bool   reverse_proxy_mode;
    String trusted_proxy_header;

    // -- WebSocket --
    String ws_allowed_origin;

    // -- Moderation --
    String default_ban_duration;
    bool   automod_enabled;
    String automod_wordlist_path;
    String automod_action;

    // -- Logging --
    bool enable_area_logging;
    String log_directory;

    // -- Plugins --
    String plugin_directory;
}

// Create a config with sane defaults — no magic numbers
fn ServerConfig defaults() {
    return {
        .server_name          = "Whisker Server",
        .server_description   = "An Attorney Online 2 server powered by Whisker",
        .motd                 = "Welcome to the server!",
        .bind_address         = "0.0.0.0",
        .tcp_port             = DEFAULT_TCP_PORT,
        .ws_port              = DEFAULT_WS_PORT,
        .wss_port             = DEFAULT_WSS_PORT,
        .enable_ws            = true,
        .enable_wss           = false,
        .tls_cert_path        = "",
        .tls_key_path         = "",
        .max_players          = DEFAULT_MAX_PLAYERS,
        .multiclient_limit    = MAX_MULTICLIENT,
        .asset_url            = "",
        .msg_rate_limit       = DEFAULT_MSG_RATE_LIMIT,
        .msg_rate_window_sec  = DEFAULT_MSG_RATE_WINDOW_SEC,
        .ooc_rate_limit       = DEFAULT_OOC_RATE_LIMIT,
        .ooc_rate_window_sec  = DEFAULT_OOC_RATE_WINDOW_SEC,
        .conn_rate_limit      = DEFAULT_CONN_RATE_LIMIT,
        .conn_rate_window_sec = DEFAULT_CONN_RATE_WINDOW_SEC,
        .raw_pkt_rate_limit   = DEFAULT_RAW_PKT_RATE_LIMIT,
        .raw_pkt_rate_window_sec = DEFAULT_RAW_PKT_RATE_WINDOW_SEC,
        .conn_flood_autoban   = true,
        .flood_ban_threshold  = DEFAULT_FLOOD_BAN_THRESHOLD,
        .reverse_proxy_mode   = false,
        .trusted_proxy_header = "X-Forwarded-For",
        .ws_allowed_origin    = "*",
        .default_ban_duration = DEFAULT_BAN_DURATION,
        .automod_enabled      = false,
        .automod_wordlist_path = "config/banned_words.txt",
        .automod_action       = "kick",
        .enable_area_logging  = false,
        .log_directory        = "logs",
        .plugin_directory     = "plugins",
    };
}

// ============================================================
// Simple TOML-like config parser
// Handles: [section], key = "string", key = 123, key = true
// ============================================================

fn ServerConfig? load(String config_dir) {
    String path = string::tformat("%s/config.toml", config_dir);
    ServerConfig cfg = defaults();

    char[]? file_data = io::file::load(mem, path);
    if (catch file_data) {
        io::printfn("[config] No config.toml found at '%s', using defaults.", path);
        return cfg;
    }

    String content = (String)file_data[0..file_data.len];
    String current_section = "";

    // Parse line by line
    foreach (line : content.tsplit("\n")) {
        String trimmed = line.trim();

        // Skip empty lines and comments
        if (trimmed.len == 0 || trimmed[0] == '#') continue;

        // Section header
        if (trimmed[0] == '[') {
            if (try end = trimmed.index_of_char(']')) {
                current_section = trimmed[1..end];
            }
            continue;
        }

        // Key = value
        if (try eq = trimmed.index_of_char('=')) {
            String key   = trimmed[0..eq].trim();
            String value = trimmed[eq + 1..].trim();

            // Strip quotes from string values
            if (value.len >= 2 && value[0] == '"') {
                value = value[1..value.len - 1];
            }

            apply_setting(&cfg, current_section, key, value);
        }
    }

    return cfg;
}

fn void apply_setting(ServerConfig* cfg, String section, String key, String value) {
    // Server section
    if (section == "server" || section == "Server") {
        if (key == "name")                  { cfg.server_name = value; return; }
        if (key == "description")           { cfg.server_description = value; return; }
        if (key == "motd")                  { cfg.motd = value; return; }
        if (key == "addr")                  { cfg.bind_address = value; return; }
        if (key == "port")                  { cfg.tcp_port = parse_ushort(value); return; }
        if (key == "max_players")           { cfg.max_players = parse_int(value); return; }
        if (key == "multiclient_limit")     { cfg.multiclient_limit = parse_int(value); return; }
        if (key == "asset_url")             { cfg.asset_url = value; return; }
        if (key == "default_ban_duration")  { cfg.default_ban_duration = value; return; }
    }

    // WebSocket section
    if (section == "websocket" || section == "WebSocket") {
        if (key == "enable_ws")         { cfg.enable_ws = parse_bool(value); return; }
        if (key == "ws_port")           { cfg.ws_port = parse_ushort(value); return; }
        if (key == "enable_wss")        { cfg.enable_wss = parse_bool(value); return; }
        if (key == "wss_port")          { cfg.wss_port = parse_ushort(value); return; }
        if (key == "tls_cert_path")     { cfg.tls_cert_path = value; return; }
        if (key == "tls_key_path")      { cfg.tls_key_path = value; return; }
        if (key == "allowed_origin")    { cfg.ws_allowed_origin = value; return; }
    }

    // Rate limits
    if (section == "ratelimit" || section == "RateLimit") {
        if (key == "msg_rate_limit")          { cfg.msg_rate_limit = parse_int(value); return; }
        if (key == "msg_rate_window")         { cfg.msg_rate_window_sec = parse_int(value); return; }
        if (key == "ooc_rate_limit")          { cfg.ooc_rate_limit = parse_int(value); return; }
        if (key == "ooc_rate_window")         { cfg.ooc_rate_window_sec = parse_int(value); return; }
        if (key == "conn_rate_limit")         { cfg.conn_rate_limit = parse_int(value); return; }
        if (key == "conn_rate_window")        { cfg.conn_rate_window_sec = parse_int(value); return; }
        if (key == "raw_pkt_rate_limit")      { cfg.raw_pkt_rate_limit = parse_int(value); return; }
        if (key == "raw_pkt_rate_window")     { cfg.raw_pkt_rate_window_sec = parse_int(value); return; }
        if (key == "conn_flood_autoban")      { cfg.conn_flood_autoban = parse_bool(value); return; }
        if (key == "flood_ban_threshold")     { cfg.flood_ban_threshold = parse_int(value); return; }
    }

    // Proxy
    if (section == "proxy" || section == "Proxy") {
        if (key == "reverse_proxy_mode")   { cfg.reverse_proxy_mode = parse_bool(value); return; }
        if (key == "trusted_header")       { cfg.trusted_proxy_header = value; return; }
    }

    // Moderation
    if (section == "moderation" || section == "Moderation") {
        if (key == "automod_enabled")       { cfg.automod_enabled = parse_bool(value); return; }
        if (key == "automod_wordlist")      { cfg.automod_wordlist_path = value; return; }
        if (key == "automod_action")        { cfg.automod_action = value; return; }
    }

    // Logging
    if (section == "logging" || section == "Logging") {
        if (key == "enable_area_logging")  { cfg.enable_area_logging = parse_bool(value); return; }
        if (key == "log_directory")        { cfg.log_directory = value; return; }
    }

    // Plugins
    if (section == "plugins" || section == "Plugins") {
        if (key == "directory") { cfg.plugin_directory = value; return; }
    }
}

fn int parse_int(String s) {
    return s.to_int() ?? 0;
}

fn ushort parse_ushort(String s) {
    int val = parse_int(s);
    if (val < 0 || val > 65535) return 0;
    return (ushort)val;
}

fn bool parse_bool(String s) {
    return s == "true" || s == "1" || s == "yes";
}

// ============================================================
// Asset list loaders
// ============================================================

fn String[]? load_lines(String path) {
    char[]? data = io::file::load(mem, path);
    if (catch data) {
        io::printfn("[config] Could not load '%s'", path);
        return {};
    }

    String content = (String)data[0..data.len];
    String[] lines = content.split(mem, "\n");

    // Filter empty lines
    int count = 0;
    foreach (line : lines) {
        if (line.trim().len > 0) count++;
    }

    String[] result = mem::new_array(String, count);
    int idx = 0;
    foreach (line : lines) {
        String trimmed = line.trim();
        if (trimmed.len > 0) {
            result[idx] = trimmed;
            idx++;
        }
    }

    return result;
}

fn String[]? load_characters(String config_dir) {
    return load_lines(string::tformat("%s/characters.txt", config_dir));
}

fn String[]? load_music(String config_dir) {
    return load_lines(string::tformat("%s/music.txt", config_dir));
}

fn String[]? load_backgrounds(String config_dir) {
    return load_lines(string::tformat("%s/backgrounds.txt", config_dir));
}
