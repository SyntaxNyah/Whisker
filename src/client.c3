// Whisker AO2 Server — Client State
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Each connected player is represented by a Client struct.
// Contains all per-connection state: identity, character,
// area, pairing, moderation, and rate limiting.

module whisker::client;

import whisker::config;
import whisker::protocol;
import whisker::security;
import std::io;
import std::net::tcp;
import std::time;

// ============================================================
// Client struct
// ============================================================

struct Client {
    // -- Connection --
    int              uid;
    tcp::TcpSocket   socket;
    bool             is_websocket;
    bool             connected;
    bool             joined;
    protocol::PacketBuffer packet_buf;

    // -- Identity --
    String           hdid;
    String           ipid;
    String           ip_address;

    // -- Character --
    int              char_id;
    String           char_name;
    String           showname;
    String           ooc_name;

    // -- Area --
    int              area_id;
    String           position;

    // -- Pairing (persistent, UID-based) --
    int              pair_wanted_uid;
    int              force_pair_uid;
    String           pair_char_name;
    String           pair_emote;
    String           pair_flip;
    String           pair_offset;

    // -- Moderation --
    bool             is_authenticated;
    ulong            permissions;
    bool             is_muted;
    bool             is_ooc_muted;

    // -- Rate limiting --
    security::RateLimiter  msg_limiter;
    security::RateLimiter  ooc_limiter;
    security::RateLimiter  raw_pkt_limiter;

    // -- Timing --
    long             connect_time;
    long             last_activity;
}

// ============================================================
// Client lifecycle
// ============================================================

fn Client new_client(tcp::TcpSocket socket, String ip, bool is_websocket) {
    long now = (long)time::clock::now().to_seconds();

    return {
        .uid             = config::NO_UID,
        .socket          = socket,
        .is_websocket    = is_websocket,
        .connected       = true,
        .joined          = false,
        .packet_buf      = protocol::new_buffer(),

        .hdid            = "",
        .ipid            = "",
        .ip_address      = ip,

        .char_id         = config::NO_CHAR_SELECTED,
        .char_name       = "",
        .showname        = "",
        .ooc_name        = "",

        .area_id         = 0,
        .position        = "wit",

        .pair_wanted_uid = config::NO_PAIR,
        .force_pair_uid  = config::NO_PAIR,
        .pair_char_name  = "",
        .pair_emote      = "",
        .pair_flip       = "0",
        .pair_offset     = "0",

        .is_authenticated = false,
        .permissions      = 0,
        .is_muted         = false,
        .is_ooc_muted     = false,

        .msg_limiter     = security::new_limiter(
            config::DEFAULT_MSG_RATE_LIMIT,
            config::DEFAULT_MSG_RATE_WINDOW_SEC
        ),
        .ooc_limiter     = security::new_limiter(
            config::DEFAULT_OOC_RATE_LIMIT,
            config::DEFAULT_OOC_RATE_WINDOW_SEC
        ),
        .raw_pkt_limiter = security::new_limiter(
            config::DEFAULT_RAW_PKT_RATE_LIMIT,
            config::DEFAULT_RAW_PKT_RATE_WINDOW_SEC
        ),

        .connect_time    = now,
        .last_activity   = now,
    };
}

fn void Client.disconnect(&self) {
    self.connected = false;
    self.socket.close();
    self.packet_buf.destroy();
}

// ============================================================
// Sending packets
// ============================================================

// Send a pre-built wire-format packet string to this client.
fn void Client.send_raw(&self, String data) {
    if (!self.connected) return;

    if (self.is_websocket) {
        // WebSocket: wrap in a text frame
        websocket_send_text(&self.socket, data);
    } else {
        // TCP: send raw bytes
        if (catch self.socket.write(data)) {
            self.connected = false;
        }
    }
}

// Send a packet built from header + fields.
fn void Client.send_packet(&self, String header, String[] fields) {
    self.send_raw(protocol::build(header, fields));
}

// Send a simple packet with no fields.
fn void Client.send_simple(&self, String header) {
    self.send_raw(protocol::build_simple(header));
}

// Send an OOC message (CT packet) from the server.
fn void Client.send_server_message(&self, String message) {
    String[] fields = { config::SERVER_SOFTWARE, message, "1" };
    self.send_packet("CT", fields);
}

// Send a keepalive response.
fn void Client.send_keepalive(&self) {
    self.send_simple("CHECK");
}

// ============================================================
// Display name helpers
// ============================================================

// Returns the name to display for this client:
// showname > ooc_name > char_name > "Player"
fn String Client.display_name(&self) {
    if (self.showname.len > 0) return self.showname;
    if (self.ooc_name.len > 0) return self.ooc_name;
    if (self.char_name.len > 0) return self.char_name;
    return "Player";
}

// ============================================================
// Permission helpers
// ============================================================

fn bool Client.has_permission(&self, ulong required) {
    return (self.permissions & required) == required;
}

fn bool Client.is_moderator(&self) {
    return self.is_authenticated && self.permissions > 0;
}

// ============================================================
// WebSocket text frame sender (minimal implementation)
// Full WebSocket handling is in websocket.c3
// ============================================================

fn void websocket_send_text(tcp::TcpSocket* socket, String data) {
    // WebSocket text frame: opcode 0x81, then length, then payload
    // Server-to-client frames are NOT masked (per RFC 6455)

    char[10] header_buf;
    usz header_len;

    header_buf[0] = 0x81; // FIN + text opcode

    if (data.len < 126) {
        header_buf[1] = (char)data.len;
        header_len = 2;
    } else if (data.len < 65536) {
        header_buf[1] = 126;
        header_buf[2] = (char)(data.len >> 8);
        header_buf[3] = (char)(data.len & 0xFF);
        header_len = 4;
    } else {
        header_buf[1] = 127;
        // 8-byte length (big-endian)
        for (int i = 0; i < 8; i++) {
            header_buf[2 + i] = (char)((data.len >> ((7 - i) * 8)) & 0xFF);
        }
        header_len = 10;
    }

    if (catch socket.write(header_buf[0..header_len])) return;
    if (catch socket.write(data)) return;
}
