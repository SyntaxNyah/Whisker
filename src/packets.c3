// Whisker AO2 Server — Packet Handlers
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Every AO2 packet the server handles has a function here.
// Implements the full joining handshake and in-game packets.
//
// Protocol docs by OmniTroid (@omnitroid) and the AO dev team:
// https://github.com/AttorneyOnline

module whisker::packets;

import whisker::config;
import whisker::client;
import whisker::server;
import whisker::protocol;
import whisker::area;
import whisker::pairing;
import whisker::commands;
import whisker::security;
import whisker::plugin_services;
import std::io;

// ============================================================
// Packet dispatch — route by header
// ============================================================

fn void dispatch(server::Server* srv, client::Client* c, protocol::Packet* pkt) {
    String header = pkt.header;

    // Pre-join packets (handshake)
    if (header == "HI")      { handle_hi(srv, c, pkt); return; }
    if (header == "ID")      { handle_id_server(srv, c, pkt); return; }
    if (header == "askchaa") { handle_askchaa(srv, c, pkt); return; }
    if (header == "RC")      { handle_rc(srv, c, pkt); return; }
    if (header == "RM")      { handle_rm(srv, c, pkt); return; }
    if (header == "RD")      { handle_rd(srv, c, pkt); return; }

    // Post-join packets — require the client to have completed handshake
    if (!c.joined) return;

    if (header == "CC")      { handle_cc(srv, c, pkt); return; }
    if (header == "MS")      { handle_ms(srv, c, pkt); return; }
    if (header == "CT")      { handle_ct(srv, c, pkt); return; }
    if (header == "MC")      { handle_mc(srv, c, pkt); return; }
    if (header == "CH")      { handle_ch(srv, c, pkt); return; }
    if (header == "HP")      { handle_hp(srv, c, pkt); return; }
    if (header == "PE")      { handle_pe(srv, c, pkt); return; }
    if (header == "EE")      { handle_ee(srv, c, pkt); return; }
    if (header == "DE")      { handle_de(srv, c, pkt); return; }
    if (header == "RT")      { handle_rt(srv, c, pkt); return; }
    if (header == "ZZ")      { handle_zz(srv, c, pkt); return; }
    if (header == "SETCASE") { return; } // acknowledged but no action needed
    if (header == "CASEA")   { handle_casea(srv, c, pkt); return; }
}

// ============================================================
// Handshake: HI → ID → askchaa → RC/RM → RD
// ============================================================

// HI: Client sends hardware ID
fn void handle_hi(server::Server* srv, client::Client* c, protocol::Packet* pkt) {
    if (pkt.field_count < 1) return;

    c.hdid = security::hash_hdid(pkt.fields[0]);

    // Check bans
    if (srv.ban_list.is_banned_ipid(c.ipid)) {
        String[] fields = { "You are banned from this server." };
        c.send_packet("BD", fields);
        c.connected = false;
        return;
    }
    if (srv.ban_list.is_banned_hdid(c.hdid)) {
        String[] fields = { "You are banned from this server." };
        c.send_packet("BD", fields);
        c.connected = false;
        return;
    }

    // Respond with server ID
    String[] id_fields = {
        string::tformat("%d", srv.client_count),
        config::SERVER_SOFTWARE,
        config::SERVER_VERSION,
    };
    c.send_packet("ID", id_fields);

    // Send player number
    String[] pn_fields = {
        string::tformat("%d", srv.client_count),
        string::tformat("%d", srv.cfg.max_players),
        srv.cfg.server_description,
    };
    c.send_packet("PN", pn_fields);
}

// ID (from client): Client identifies its software
fn void handle_id_server(server::Server* srv, client::Client* c, protocol::Packet* pkt) {
    // Client told us its software name and version — we can log it

    // Send feature list
    c.send_raw(protocol::build_feature_list());

    // Send asset URL if configured
    if (srv.cfg.asset_url.len > 0) {
        String[] ass_fields = { srv.cfg.asset_url };
        c.send_packet("ASS", ass_fields);
    }
}

// askchaa: Client requests server info
fn void handle_askchaa(server::Server* srv, client::Client* c, protocol::Packet* pkt) {
    // Check if server is full
    if (srv.client_count >= srv.cfg.max_players) {
        String[] fields = { "Server is full." };
        c.send_packet("BD", fields);
        c.connected = false;
        return;
    }

    // Respond with SI (server info)
    String[] si_fields = {
        string::tformat("%d", srv.char_count),
        "0", // evidence count (always 0 at handshake)
        string::tformat("%d", srv.music_count + srv.area_count),
    };
    c.send_packet("SI", si_fields);
}

// RC: Client requests character list
fn void handle_rc(server::Server* srv, client::Client* c, protocol::Packet* pkt) {
    // Build SC packet: SC#char1_name&&&#char2_name&&&#%
    DString sc_pkt = dstring::temp();
    sc_pkt.append_string("SC");

    for (int i = 0; i < srv.char_count; i++) {
        sc_pkt.append_char('#');
        sc_pkt.append_string(protocol::escape_value(srv.characters[i]));
        sc_pkt.append_string("&&"); // desc & evidence (empty)
    }
    sc_pkt.append_string(config::PACKET_TERMINATOR);

    c.send_raw(sc_pkt.str_view());
}

// RM: Client requests music/area list
fn void handle_rm(server::Server* srv, client::Client* c, protocol::Packet* pkt) {
    // Build SM packet: area names first (no extension = area), then music
    DString sm_pkt = dstring::temp();
    sm_pkt.append_string("SM");

    // Areas first (names without file extensions are treated as areas)
    for (int i = 0; i < srv.area_count; i++) {
        sm_pkt.append_char('#');
        sm_pkt.append_string(protocol::escape_value(srv.areas[i].name));
    }

    // Then music
    for (int i = 0; i < srv.music_count; i++) {
        sm_pkt.append_char('#');
        sm_pkt.append_string(protocol::escape_value(srv.music[i]));
    }

    sm_pkt.append_string(config::PACKET_TERMINATOR);
    c.send_raw(sm_pkt.str_view());
}

// RD: Client is ready — finalize join
fn void handle_rd(server::Server* srv, client::Client* c, protocol::Packet* pkt) {
    // Allocate UID
    c.uid = srv.allocate_uid();
    c.joined = true;
    c.area_id = 0; // Start in first area

    srv.areas[0].player_count++;

    io::printfn("[server] Client joined: UID %d (%s)", c.uid, c.ipid);

    // Send DONE (join complete)
    c.send_simple("DONE");

    // Send current area state
    send_area_state(srv, c);

    // Send MOTD
    if (srv.cfg.motd.len > 0) {
        c.send_server_message(srv.cfg.motd);
    }

    // Broadcast updated ARUP
    server::broadcast_all_arup(srv);

    // The client is now in the courtroom — let lifecycle plugins (e.g. the
    // player list) announce it. Fired after DONE so the client's courtroom
    // exists and will accept any packets the hook sends back to it.
    server::notify_client_join(srv, c);
}

// ============================================================
// In-game packets
// ============================================================

// CC: Character select
fn void handle_cc(server::Server* srv, client::Client* c, protocol::Packet* pkt) {
    // CC#0#char_id#char_pw#%
    if (pkt.field_count < 2) return;

    int char_id = pkt.fields[1].to_int() ?? -1;
    if (char_id < 0 || char_id >= srv.char_count) {
        c.send_server_message("Invalid character ID.");
        return;
    }

    // Release old character
    if (c.char_id != config::NO_CHAR_SELECTED) {
        srv.areas[c.area_id].release_char(c.char_id);
    }

    // Check if taken in current area
    if (srv.areas[c.area_id].is_char_taken(char_id)) {
        c.send_server_message("That character is taken.");
        return;
    }

    // Assign character
    srv.areas[c.area_id].take_char(char_id);
    c.char_id = char_id;
    c.char_name = srv.characters[char_id];

    // Send PV (player view)
    String[] pv_fields = {
        string::tformat("%d", c.uid),
        "CID",
        string::tformat("%d", char_id),
    };
    c.send_packet("PV", pv_fields);

    // Broadcast updated char availability
    send_chars_check(srv, c.area_id);

    // Character changed — refresh lifecycle listeners (player list, etc.).
    server::notify_client_update(srv, c);
}

// MS: In-character message — the most complex packet
fn void handle_ms(server::Server* srv, client::Client* c, protocol::Packet* pkt) {
    if (c.is_muted) return;
    if (c.char_id == config::NO_CHAR_SELECTED) return;

    // Rate limit
    if (!c.msg_limiter.check()) {
        c.send_server_message("You are sending messages too fast.");
        return;
    }

    // Validate minimum fields (the MS packet has many optional fields)
    if (pkt.field_count < 15) return;

    // Message length check
    String message = pkt.fields[4];
    if (message.len > config::MAX_IC_MESSAGE_LEN) {
        message = message[0..config::MAX_IC_MESSAGE_LEN - 1];
    }

    // v8: let plugins rewrite ONLY the IC message text (field 4) before the
    // relay is built below, so every pairing field is preserved (lossless
    // censor / translate, unlike consume + rebuild). run_ic_filters returns -1
    // when no filter is registered or all decline, in which case we fall back to
    // the original field verbatim — so behaviour is byte-for-byte unchanged for
    // servers without an IC-filter plugin.
    char[1024] ic_buf;
    int    ic_n        = plugin_services::run_ic_filters((void*)c, message, &ic_buf[0], 1024);
    bool   ic_filtered = ic_n >= 0;
    String ic_message  = ic_n > 0 ? (String)ic_buf[0..ic_n - 1] : "";

    // === Pairing logic ===
    // Resolve pair partner (persistent UID-based pairing)
    client::Client* pair_partner = pairing::resolve_pair(c, &srv.clients, srv.client_count);

    // Build the outgoing MS packet.
    //
    // The client sends fields in this order:
    //   0:desk_mod  1:preanim  2:character  3:emote  4:message  5:side
    //   6:sfx  7:emote_mod  8:char_id  9:sfx_delay  10:shout_mod
    //   11:evidence  12:flip  13:realization  14:text_color  15:showname
    //   16:other_charid  17:self_offset  18+:nonint_pre, sfx_loop, ...
    //
    // The server relays with 4 inserted fields for pairing:
    //   0-15: same as client
    //   16: other_charid  (server replaces with partner's char_id or -1)
    //   17: other_name    (server inserts partner's char folder name)
    //   18: other_emote   (server inserts partner's last emote)
    //   19: self_offset   (forwarded from client field 17)
    //   20: other_offset  (server inserts partner's last offset)
    //   21: other_flip    (server inserts partner's last flip)
    //   22+: remaining client fields (18+) shifted by 4
    DString out = dstring::temp();
    out.append_string("MS");

    // Forward fields 0-15 as-is (up to showname), except field 4 (the IC
    // message) when a v8 IC filter rewrote it — everything else, including all
    // the pairing fields below, is untouched.
    usz forward_limit = pkt.field_count < 16 ? pkt.field_count : 16;
    for (usz i = 0; i < forward_limit; i++) {
        out.append_char('#');
        if (i == 4 && ic_filtered) {
            out.append_string(protocol::escape_value(ic_message));
        } else {
            out.append_string(protocol::escape_value(pkt.fields[i]));
        }
    }

    // Field 16: other_charid — inject pair partner's char_id
    out.append_char('#');
    if (pair_partner != null) {
        out.append_string(string::tformat("%d", pair_partner.char_id));
    } else {
        out.append_string("-1");
    }

    // Field 17 (inserted): other_name — partner's character folder name
    out.append_char('#');
    if (pair_partner != null) {
        out.append_string(protocol::escape_value(pair_partner.char_name));
    }

    // Field 18 (inserted): other_emote — partner's last emote
    out.append_char('#');
    if (pair_partner != null) {
        out.append_string(protocol::escape_value(pair_partner.pair_emote));
    }

    // Field 19: self_offset — forwarded from client field 17
    out.append_char('#');
    if (pkt.field_count > 17) {
        out.append_string(protocol::escape_value(pkt.fields[17]));
    } else {
        out.append_string("0&0");
    }

    // Field 20 (inserted): other_offset — partner's last offset
    out.append_char('#');
    if (pair_partner != null) {
        out.append_string(protocol::escape_value(pair_partner.pair_offset));
    } else {
        out.append_string("0&0");
    }

    // Field 21 (inserted): other_flip — partner's last flip state
    out.append_char('#');
    if (pair_partner != null) {
        out.append_string(protocol::escape_value(pair_partner.pair_flip));
    } else {
        out.append_string("0");
    }

    // Forward remaining client fields (18+) — these become 22+ in the relay
    for (usz i = 18; i < pkt.field_count; i++) {
        out.append_char('#');
        out.append_string(protocol::escape_value(pkt.fields[i]));
    }

    out.append_string(config::PACKET_TERMINATOR);

    // Broadcast to area
    server::broadcast_area(srv, c.area_id, out.str_view());

    // Update sender's pair state for future partner lookups
    if (pkt.field_count > 3) {
        c.pair_emote = pkt.fields[3];
    }
    if (pkt.field_count > 12) {
        c.pair_flip = pkt.fields[12];
    }
    if (pkt.field_count > 17) {
        c.pair_offset = pkt.fields[17];
    }
}

// CT: OOC (out-of-character) message
fn void handle_ct(server::Server* srv, client::Client* c, protocol::Packet* pkt) {
    if (pkt.field_count < 2) return;
    if (c.is_ooc_muted) return;

    // Rate limit
    if (!c.ooc_limiter.check()) {
        c.send_server_message("OOC rate limit. Slow down.");
        return;
    }

    String name    = pkt.fields[0];
    String message = pkt.fields[1];

    // Validate name
    if (name.len == 0 || name.len > config::MAX_OOC_NAME_LEN) return;
    if (message.len == 0 || message.len > config::MAX_OOC_MESSAGE_LEN) return;

    // Set OOC name
    c.ooc_name = name;

    // OOC name may have changed — refresh lifecycle listeners. Cheap when
    // unchanged: a player-list plugin diffs and only re-broadcasts on a real
    // change, so this firing on every OOC line stays effectively free.
    server::notify_client_update(srv, c);

    // Check if it's a command
    if (message.len > 0 && message[0] == '/') {
        commands::dispatch(srv, c, message);
        return;
    }

    // Broadcast to area
    String[] ct_fields = { name, message };
    String ct_pkt = protocol::build("CT", ct_fields);
    server::broadcast_area(srv, c.area_id, ct_pkt);
}

// MC: Music change or area change
fn void handle_mc(server::Server* srv, client::Client* c, protocol::Packet* pkt) {
    if (pkt.field_count < 2) return;

    String name = pkt.fields[0];

    // Rate limit
    if (!c.msg_limiter.check()) return;

    // Check if it's an area change (no file extension = area name)
    if (!name.contains(".")) {
        // Area change
        for (int i = 0; i < srv.area_count; i++) {
            if (srv.areas[i].name == name) {
                change_area(srv, c, i);
                return;
            }
        }
        c.send_server_message("Area not found.");
        return;
    }

    // Music change — broadcast to area
    String showname = pkt.field_count >= 3 ? pkt.fields[2] : "";
    String[] mc_fields = {
        name,
        string::tformat("%d", c.char_id),
        showname,
        "1", // looping
        "0", // channel 0
        "0", // no effects
    };
    String mc_pkt = protocol::build("MC", mc_fields);
    server::broadcast_area(srv, c.area_id, mc_pkt);

    srv.areas[c.area_id].current_song = name;
    srv.areas[c.area_id].song_player_uid = c.uid;
}

// CH: Keepalive
fn void handle_ch(server::Server* srv, client::Client* c, protocol::Packet* pkt) {
    c.send_keepalive();
}

// HP: Penalty bar update
fn void handle_hp(server::Server* srv, client::Client* c, protocol::Packet* pkt) {
    if (pkt.field_count < 2) return;

    int bar   = pkt.fields[0].to_int() ?? 0;
    int value = pkt.fields[1].to_int() ?? 0;

    if (bar != config::PENALTY_BAR_DEFENSE && bar != config::PENALTY_BAR_PROSECUTION) return;
    if (value < config::PENALTY_BAR_MIN || value > config::PENALTY_BAR_MAX) return;

    if (bar == config::PENALTY_BAR_DEFENSE) {
        srv.areas[c.area_id].defense_hp = value;
    } else {
        srv.areas[c.area_id].prosecution_hp = value;
    }

    // Broadcast to area
    String[] hp_fields = { pkt.fields[0], pkt.fields[1] };
    server::broadcast_area(srv, c.area_id, protocol::build("HP", hp_fields));
}

// PE: Add evidence
fn void handle_pe(server::Server* srv, client::Client* c, protocol::Packet* pkt) {
    if (pkt.field_count < 3) return;

    String name = pkt.fields[0];
    String desc = pkt.fields[1];
    String img  = pkt.fields[2];

    if (name.len > config::MAX_EVIDENCE_NAME_LEN) return;
    if (desc.len > config::MAX_EVIDENCE_DESC_LEN) return;
    if (img.len > config::MAX_EVIDENCE_IMG_LEN) return;

    srv.areas[c.area_id].add_evidence(name, desc, img);

    // Broadcast updated evidence list
    server::broadcast_area(srv, c.area_id, srv.areas[c.area_id].build_evidence_packet());
}

// EE: Edit evidence
fn void handle_ee(server::Server* srv, client::Client* c, protocol::Packet* pkt) {
    if (pkt.field_count < 4) return;

    int id      = pkt.fields[0].to_int() ?? -1;
    String name = pkt.fields[1];
    String desc = pkt.fields[2];
    String img  = pkt.fields[3];

    srv.areas[c.area_id].edit_evidence(id, name, desc, img);
    server::broadcast_area(srv, c.area_id, srv.areas[c.area_id].build_evidence_packet());
}

// DE: Delete evidence
fn void handle_de(server::Server* srv, client::Client* c, protocol::Packet* pkt) {
    if (pkt.field_count < 1) return;
    int id = pkt.fields[0].to_int() ?? -1;
    srv.areas[c.area_id].delete_evidence(id);
    server::broadcast_area(srv, c.area_id, srv.areas[c.area_id].build_evidence_packet());
}

// RT: Judge animation
fn void handle_rt(server::Server* srv, client::Client* c, protocol::Packet* pkt) {
    if (pkt.field_count < 1) return;
    server::broadcast_area(srv, c.area_id, protocol::build("RT", pkt.fields[0..pkt.field_count - 1]));
}

// ZZ: Modcall
fn void handle_zz(server::Server* srv, client::Client* c, protocol::Packet* pkt) {
    String reason = pkt.field_count >= 1 ? pkt.fields[0] : "No reason given";

    io::printfn("[MODCALL] UID %d (%s) in area '%s': %s",
        c.uid, c.display_name(), srv.areas[c.area_id].name, reason);

    // Send to all moderators
    String alert = string::tformat("MODCALL from %s (UID %d) in %s: %s",
        c.display_name(), c.uid, srv.areas[c.area_id].name, reason);

    for (int i = 0; i < server::MAX_SERVER_CLIENTS; i++) {
        client::Client* mod = srv.clients[i];
        if (mod != null && mod.joined && mod.is_moderator()) {
            mod.send_server_message(alert);
            // Also send ZZ packet for audio/visual notification
            String[] zz_fields = { alert };
            mod.send_packet("ZZ", zz_fields);
        }
    }

    c.send_server_message("Your modcall has been sent to all online moderators.");
}

// CASEA: Case announcement
fn void handle_casea(server::Server* srv, client::Client* c, protocol::Packet* pkt) {
    if (pkt.field_count < 6) return;
    // Broadcast to all connected clients
    server::broadcast(srv, protocol::build("CASEA", pkt.fields[0..pkt.field_count - 1]));
}

// ============================================================
// Area change
// ============================================================

fn void change_area(server::Server* srv, client::Client* c, int new_area_id) {
    if (new_area_id < 0 || new_area_id >= srv.area_count) return;
    if (new_area_id == c.area_id) return;

    area::Area* new_area = &srv.areas[new_area_id];

    // Check lock
    if (new_area.lock == area::LockState.LOCKED && !new_area.is_invited(c.uid) && !c.is_moderator()) {
        c.send_server_message("That area is locked.");
        return;
    }

    // Leave old area
    area::Area* old_area = &srv.areas[c.area_id];
    if (c.char_id != config::NO_CHAR_SELECTED) {
        old_area.release_char(c.char_id);
    }
    old_area.player_count--;
    old_area.remove_cm(c.uid);

    if (old_area.player_count <= 0) {
        old_area.reset();
    }

    // Enter new area
    c.area_id = new_area_id;
    new_area.player_count++;

    // Take character in new area if free
    if (c.char_id != config::NO_CHAR_SELECTED) {
        if (!new_area.is_char_taken(c.char_id)) {
            new_area.take_char(c.char_id);
        } else {
            // Character taken — reset to spectator
            c.char_id = config::NO_CHAR_SELECTED;
            c.char_name = "";
        }
    }

    // Send area state to the client
    send_area_state(srv, c);

    // Broadcast updated ARUP
    server::broadcast_all_arup(srv);

    c.send_server_message(string::tformat("Moved to %s.", new_area.name));

    // Area (and possibly character, if it was taken) changed — refresh
    // lifecycle listeners such as the player list.
    server::notify_client_update(srv, c);
}

// ============================================================
// Send area state to a client
// ============================================================

fn void send_area_state(server::Server* srv, client::Client* c) {
    area::Area* a = &srv.areas[c.area_id];

    // Background
    String[] bn_fields = { a.background };
    c.send_packet("BN", bn_fields);

    // Penalty bars
    String[] hp_def = {
        string::tformat("%d", config::PENALTY_BAR_DEFENSE),
        string::tformat("%d", a.defense_hp),
    };
    c.send_packet("HP", hp_def);
    String[] hp_pro = {
        string::tformat("%d", config::PENALTY_BAR_PROSECUTION),
        string::tformat("%d", a.prosecution_hp),
    };
    c.send_packet("HP", hp_pro);

    // Evidence list
    c.send_raw(a.build_evidence_packet());

    // Character availability
    send_chars_check_to(srv, c);
}

// ============================================================
// CharsCheck — tell clients which characters are taken
// ============================================================

fn void send_chars_check(server::Server* srv, int area_id) {
    String pkt = build_chars_check(srv, area_id);
    server::broadcast_area(srv, area_id, pkt);
}

fn void send_chars_check_to(server::Server* srv, client::Client* c) {
    c.send_raw(build_chars_check(srv, c.area_id));
}

fn String build_chars_check(server::Server* srv, int area_id) {
    DString pkt = dstring::temp();
    pkt.append_string("CharsCheck");

    for (int i = 0; i < srv.char_count; i++) {
        pkt.append_char('#');
        if (srv.areas[area_id].is_char_taken(i)) {
            pkt.append_string("-1"); // taken
        } else {
            pkt.append_string("0");  // free
        }
    }
    pkt.append_string(config::PACKET_TERMINATOR);
    return pkt.str_view();
}
