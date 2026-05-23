// Whisker AO2 Server — WebSocket Support
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Implements WebSocket (RFC 6455) for webAO client compatibility.
// Handles the HTTP upgrade handshake and frame parsing.
// Supports both ws:// and wss:// (via reverse proxy like Cloudflare).
//
// The WebSocket handshake extracts X-Forwarded-For for Cloudflare
// reverse proxy support, so we always know the real client IP.

module whisker::websocket;

import whisker::config;
import whisker::security;
import std::io;
import std::net::tcp;
import std::crypto::sha1;
import std::encoding::base64;

// ============================================================
// WebSocket Opcodes
// ============================================================

const char WS_OPCODE_CONTINUATION = 0x0;
const char WS_OPCODE_TEXT         = 0x1;
const char WS_OPCODE_BINARY       = 0x2;
const char WS_OPCODE_CLOSE        = 0x8;
const char WS_OPCODE_PING         = 0x9;
const char WS_OPCODE_PONG         = 0xA;

const char WS_FIN_BIT             = 0x80;
const char WS_MASK_BIT            = 0x80;

// ============================================================
// WebSocket Handshake
// ============================================================

struct WsHandshakeResult {
    bool   success;
    String client_ip;        // Real IP (from X-Forwarded-For or socket)
    String origin;
    String ws_key;
}

// Perform the WebSocket upgrade handshake.
// Reads the HTTP request, validates it, and sends the 101 response.
fn WsHandshakeResult? perform_handshake(
    tcp::TcpSocket* socket,
    String socket_ip,
    bool reverse_proxy_mode,
    String trusted_header
) {
    WsHandshakeResult result;
    result.success = false;
    result.client_ip = socket_ip;

    // Read the HTTP request (up to 4KB should be plenty)
    char[4096] buf;
    usz? bytes = socket.read(&buf);
    if (catch bytes) return result;

    String request = ((String)buf)[0..bytes];

    // Must be a GET request with Upgrade: websocket
    if (!request.starts_with("GET ")) return result;

    // Parse headers
    String ws_key = "";
    String origin = "";
    String forwarded_for = "";

    foreach (line : request.tsplit("\r\n")) {
        String trimmed = line.trim();
        if (trimmed.len == 0) continue;

        if (trimmed.starts_with("Sec-WebSocket-Key:")) {
            ws_key = trimmed["Sec-WebSocket-Key:".len..].trim();
        }
        if (trimmed.starts_with("Origin:")) {
            origin = trimmed["Origin:".len..].trim();
        }
        // Cloudflare / reverse proxy headers
        if (reverse_proxy_mode) {
            if (trimmed.starts_with("X-Forwarded-For:")) {
                forwarded_for = trimmed["X-Forwarded-For:".len..].trim();
            }
            if (trimmed.starts_with("X-Real-IP:") && forwarded_for.len == 0) {
                forwarded_for = trimmed["X-Real-IP:".len..].trim();
            }
            if (trimmed.starts_with("CF-Connecting-IP:") && forwarded_for.len == 0) {
                forwarded_for = trimmed["CF-Connecting-IP:".len..].trim();
            }
        }
    }

    if (ws_key.len == 0) return result;

    // Extract real IP from proxy header if available
    if (forwarded_for.len > 0) {
        result.client_ip = security::extract_real_ip(forwarded_for);
    }

    // Compute accept key: SHA-1(key + GUID) → base64
    String accept_input = string::tformat("%s%s", ws_key, config::WS_MAGIC_GUID);

    // SHA-1 hash
    char[20] sha_hash;
    sha1::Sha1 hasher;
    hasher.init();
    hasher.update(accept_input);
    sha_hash = hasher.final();

    // Base64 encode
    String accept_key = base64::encode(mem::temp(), &sha_hash);

    // Build HTTP 101 response
    String response = string::tformat(
        "HTTP/1.1 101 Switching Protocols\r\n" ~
        "Upgrade: websocket\r\n" ~
        "Connection: Upgrade\r\n" ~
        "Sec-WebSocket-Accept: %s\r\n" ~
        "\r\n",
        accept_key
    );

    if (catch socket.write(response)) return result;

    result.success = true;
    result.origin = origin;
    result.ws_key = ws_key;
    return result;
}

// ============================================================
// WebSocket Frame Reading
// ============================================================

struct WsFrame {
    char   opcode;
    bool   is_masked;
    String payload;
    bool   is_fin;
}

// Read a single WebSocket frame from the socket.
fn WsFrame? read_frame(tcp::TcpSocket* socket) {
    WsFrame frame;

    // Read first 2 bytes (opcode + payload length indicator)
    char[2] header;
    usz? h = socket.read(&header);
    if (catch h) return frame;

    frame.is_fin = (header[0] & WS_FIN_BIT) != 0;
    frame.opcode = header[0] & 0x0F;
    frame.is_masked = (header[1] & WS_MASK_BIT) != 0;

    // Payload length
    usz payload_len = (usz)(header[1] & 0x7F);

    if (payload_len == 126) {
        char[2] len_buf;
        if (catch socket.read(&len_buf)) return frame;
        payload_len = ((usz)len_buf[0] << 8) | (usz)len_buf[1];
    } else if (payload_len == 127) {
        char[8] len_buf;
        if (catch socket.read(&len_buf)) return frame;
        payload_len = 0;
        for (int i = 0; i < 8; i++) {
            payload_len = (payload_len << 8) | (usz)len_buf[i];
        }
    }

    // Enforce max frame size
    if (payload_len > config::WS_MAX_FRAME_SIZE) return frame;

    // Read masking key (client → server frames are always masked)
    char[4] mask_key;
    if (frame.is_masked) {
        if (catch socket.read(&mask_key)) return frame;
    }

    // Read payload
    if (payload_len > 0) {
        char[] payload_buf = mem::temp_new_array(char, payload_len);
        usz total_read = 0;
        while (total_read < payload_len) {
            usz? n = socket.read(payload_buf[total_read..]);
            if (catch n) return frame;
            if (n == 0) return frame;
            total_read += n;
        }

        // Unmask
        if (frame.is_masked) {
            for (usz i = 0; i < payload_len; i++) {
                payload_buf[i] ^= mask_key[i % 4];
            }
        }

        frame.payload = (String)payload_buf;
    }

    return frame;
}

// ============================================================
// WebSocket Pong (respond to ping)
// ============================================================

fn void send_pong(tcp::TcpSocket* socket, String payload) {
    char[2] header;
    header[0] = WS_FIN_BIT | WS_OPCODE_PONG;
    header[1] = (char)payload.len;
    if (catch socket.write(&header)) return;
    if (payload.len > 0) {
        if (catch socket.write(payload)) return;
    }
}

// ============================================================
// WebSocket Close frame
// ============================================================

fn void send_close(tcp::TcpSocket* socket) {
    char[2] frame = { WS_FIN_BIT | WS_OPCODE_CLOSE, 0 };
    socket.write(&frame);
}

// ============================================================
// WebSocket Client Read Loop
// ============================================================

// Reads WebSocket frames and extracts AO2 packets.
// WebSocket frames already provide message boundaries, so
// we don't need the '%' delimiter parsing that TCP requires.
// Each text frame contains one or more complete AO2 packets.
fn String? read_ws_packet(tcp::TcpSocket* socket) {
    WsFrame? frame = read_frame(socket);
    if (catch frame) return SearchResult.MISSING?;

    switch (frame.opcode) {
        case WS_OPCODE_TEXT:
            return frame.payload;

        case WS_OPCODE_PING:
            send_pong(socket, frame.payload);
            return SearchResult.MISSING?;

        case WS_OPCODE_CLOSE:
            send_close(socket);
            return SearchResult.MISSING?;

        default:
            return SearchResult.MISSING?;
    }
}
