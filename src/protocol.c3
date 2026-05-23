// Whisker AO2 Server — Protocol Layer
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// FantaCode serialization/deserialization for the AO2 wire protocol.
// Handles packet framing, field escaping, and buffer management.
//
// Protocol docs by OmniTroid (@omnitroid) and the AO dev team:
// https://github.com/AttorneyOnline

module whisker::protocol;

import whisker::config;
import std::io;

// ============================================================
// Packet structure
// ============================================================

struct Packet {
    String   header;
    String[] fields;
    usz      field_count;
}

// ============================================================
// FantaCode Escaping
// ============================================================

// Escape special characters in a value before putting it on the wire.
fn String escape_value(String raw) {
    if (raw.len == 0) return raw;

    DString result = dstring::temp();
    foreach (ch : raw) {
        switch (ch) {
            case '#':  result.append_string(config::ESCAPE_HASH);
            case '&':  result.append_string(config::ESCAPE_AMPERSAND);
            case '%':  result.append_string(config::ESCAPE_PERCENT);
            case '$':  result.append_string(config::ESCAPE_DOLLAR);
            default: result.append_char(ch);
        }
    }
    return result.str_view();
}

// Unescape special sequences in a value received from the wire.
fn String unescape_value(String escaped) {
    if (escaped.len == 0) return escaped;

    DString result = dstring::temp();
    usz i = 0;
    while (i < escaped.len) {
        if (escaped[i] == '<' && i + 4 < escaped.len) {
            String remaining = escaped[i..];

            if (remaining.starts_with(config::ESCAPE_HASH)) {
                result.append_char('#');
                i += config::ESCAPE_HASH.len;
                continue;
            }
            if (remaining.starts_with(config::ESCAPE_AMPERSAND)) {
                result.append_char('&');
                i += config::ESCAPE_AMPERSAND.len;
                continue;
            }
            if (remaining.starts_with(config::ESCAPE_PERCENT)) {
                result.append_char('%');
                i += config::ESCAPE_PERCENT.len;
                continue;
            }
            if (remaining.starts_with(config::ESCAPE_DOLLAR)) {
                result.append_char('$');
                i += config::ESCAPE_DOLLAR.len;
                continue;
            }
        }
        result.append_char(escaped[i]);
        i++;
    }
    return result.str_view();
}

// ============================================================
// Packet Parsing
// ============================================================

// Parse a raw packet string (without the trailing %) into a Packet.
// Input: "HI#some_hdid" (the "#%" terminator already stripped)
fn Packet? parse(String raw) {
    if (raw.len == 0) return Packet{};
    if (raw.len > config::MAX_PACKET_BYTES) return Packet{};

    // Split on '#'
    String[] parts = raw.tsplit("#");
    if (parts.len == 0) return Packet{};
    if (parts.len > config::MAX_PACKET_FIELDS) return Packet{};

    // First part is always the header
    String header = parts[0];

    // Remaining parts are fields (unescape each)
    usz field_count = parts.len - 1;

    // Strip trailing empty field if packet ended with #
    if (field_count > 0 && parts[parts.len - 1].len == 0) {
        field_count--;
    }

    String[] fields;
    if (field_count > 0) {
        fields = mem::temp_new_array(String, field_count);
        for (usz i = 0; i < field_count; i++) {
            fields[i] = unescape_value(parts[i + 1]);
        }
    }

    return {
        .header      = header,
        .fields      = fields,
        .field_count = field_count,
    };
}

// ============================================================
// Packet Serialization
// ============================================================

// Build a wire-format packet: "HEADER#field1#field2#...#%"
fn String build(String header, String[] fields) {
    DString pkt = dstring::temp();
    pkt.append_string(header);

    foreach (field : fields) {
        pkt.append_char(config::FIELD_SEPARATOR);
        pkt.append_string(escape_value(field));
    }

    pkt.append_string(config::PACKET_TERMINATOR);
    return pkt.str_view();
}

// Convenience: build a packet with no fields
fn String build_simple(String header) {
    DString pkt = dstring::temp();
    pkt.append_string(header);
    pkt.append_string(config::PACKET_TERMINATOR);
    return pkt.str_view();
}

// Build a packet with raw (pre-escaped) field string.
// Used when forwarding packets without re-escaping.
fn String build_raw(String header, String raw_fields) {
    DString pkt = dstring::temp();
    pkt.append_string(header);
    pkt.append_char(config::FIELD_SEPARATOR);
    pkt.append_string(raw_fields);
    pkt.append_string(config::PACKET_TERMINATOR);
    return pkt.str_view();
}

// ============================================================
// TCP Packet Buffer
// ============================================================

// Buffers incoming TCP bytes and extracts complete packets
// delimited by '%'. AO2 TCP packets end with "#%", but since
// '%' in values is escaped as "<percent>", a bare '%' always
// marks the end of a packet.

struct PacketBuffer {
    DString buf;
}

fn PacketBuffer new_buffer() {
    return {
        .buf = dstring::new(mem::heap(), ""),
    };
}

fn void PacketBuffer.destroy(&self) {
    self.buf.free();
}

// Append raw bytes received from the socket.
fn void PacketBuffer.feed(&self, String data) {
    self.buf.append_string(data);
}

// Extract the next complete packet from the buffer, if any.
// Returns the raw packet string (without the trailing '%').
fn String? PacketBuffer.next_packet(&self) {
    String view = self.buf.str_view();

    // Find the '%' terminator
    foreach (i, ch : view) {
        if (ch == config::PACKET_END_CHAR) {
            // Extract everything before '%'
            String raw = view[0..i];

            // Strip trailing '#' if present (the "#%" terminator)
            if (raw.len > 0 && raw[raw.len - 1] == config::FIELD_SEPARATOR) {
                raw = raw[0..raw.len - 1];
            }

            // Remove processed bytes from buffer
            self.buf.delete_range(0, i + 1);

            return raw;
        }
    }

    // No complete packet yet
    return SearchResult.MISSING?;
}

// ============================================================
// Feature list
// ============================================================

// All features this server supports, sent in the FL packet.
const String[] SUPPORTED_FEATURES = {
    "yellowtext",
    "flipping",
    "customobjections",
    "fastloading",
    "noencryption",
    "deskmod",
    "evidence",
    "cccc_ic_support",
    "arup",
    "casing_alerts",
    "modcall_reason",
    "looping_sfx",
    "additive",
    "effects",
    "y_offset",
    "expanded_desk_mods",
    "auth_packet",
};

// Build the FL (feature list) packet
fn String build_feature_list() {
    return build("FL", SUPPORTED_FEATURES);
}
