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

extern fn long c_send(int sock, char* buf, usz len, int flags) @cname("send");
const int MSG_NOSIGNAL = 0x4000; // Prevent SIGPIPE on broken sockets

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
    long now = (long)time::now().to_seconds();

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
    (void)self.socket.close();
    self.packet_buf.destroy();
}

// ============================================================
// Sending packets
// ============================================================

// Send a pre-built wire-format packet string to this client.
// Uses c_send() with MSG_NOSIGNAL to prevent SIGPIPE on broken sockets.
// WebSocket frames are built in a single buffer to prevent frame
// interleaving when multiple threads broadcast concurrently.
fn void Client.send_raw(&self, String data) {
    if (!self.connected) return;

    int fd = *(int*)&self.socket;
    $if env::WIN32:
        int flags = 0;
    $else
        int flags = MSG_NOSIGNAL;
    $endif

    if (self.is_websocket) {
        // Build WebSocket text frame header
        char[10] ws_hdr;
        usz hdr_len;
        ws_hdr[0] = 0x81; // FIN + text opcode

        if (data.len < 126) {
            ws_hdr[1] = (char)data.len;
            hdr_len = 2;
        } else if (data.len < 65536) {
            ws_hdr[1] = 126;
            ws_hdr[2] = (char)(data.len >> 8);
            ws_hdr[3] = (char)(data.len & 0xFF);
            hdr_len = 4;
        } else {
            ws_hdr[1] = 127;
            for (int i = 0; i < 8; i++) {
                ws_hdr[2 + i] = (char)((data.len >> ((7 - i) * 8)) & 0xFF);
            }
            hdr_len = 10;
        }

        // Send header + payload as a single atomic write to prevent
        // frame interleaving when multiple threads broadcast.
        usz total = hdr_len + data.len;
        if (total <= 16384) {
            // Typical AO2 packet: single send from stack buffer
            char[16384] buf;
            for (usz i = 0; i < hdr_len; i++) buf[i] = ws_hdr[i];
            for (usz i = 0; i < data.len; i++) buf[hdr_len + i] = data[i];
            if (c_send(fd, &buf[0], total, flags) < 0) {
                self.connected = false;
            }
        } else {
            // Large frame (char/music lists during handshake): two sends
            // are safe here since no concurrent broadcasts happen yet
            if (c_send(fd, &ws_hdr[0], hdr_len, flags) < 0) {
                self.connected = false;
                return;
            }
            if (c_send(fd, data.ptr, data.len, flags) < 0) {
                self.connected = false;
            }
        }
    } else {
        // TCP: send with MSG_NOSIGNAL to prevent SIGPIPE
        if (c_send(fd, data.ptr, data.len, flags) < 0) {
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

