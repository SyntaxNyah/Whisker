// Whisker AO2 Server — Area Management
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Areas are the rooms players inhabit. Each area tracks its own
// character occupancy, evidence, penalty bars, lock state, and CMs.

module whisker::area;

import whisker::config;
import std::io;

// ============================================================
// Area status enum — no magic strings in game logic
// ============================================================

enum AreaStatus : int {
    IDLE,
    LOOKING_FOR_PLAYERS,
    CASING,
    RECESS,
    RP,
    GAMING,
}

fn String AreaStatus.to_string(AreaStatus self) {
    switch (self) {
        case IDLE:                return "IDLE";
        case LOOKING_FOR_PLAYERS: return "LOOKING-FOR-PLAYERS";
        case CASING:              return "CASING";
        case RECESS:              return "RECESS";
        case RP:                  return "RP";
        case GAMING:              return "GAMING";
    }
    return "IDLE";
}

fn AreaStatus from_string(String s) {
    if (s == "IDLE")                 return IDLE;
    if (s == "LOOKING-FOR-PLAYERS")  return LOOKING_FOR_PLAYERS;
    if (s == "CASING")               return CASING;
    if (s == "RECESS")               return RECESS;
    if (s == "RP")                   return RP;
    if (s == "GAMING")               return GAMING;
    return IDLE;
}

// ============================================================
// Area lock state
// ============================================================

enum LockState : int {
    FREE,
    SPECTATABLE,
    LOCKED,
}

fn String LockState.to_string(LockState self) {
    switch (self) {
        case FREE:        return "FREE";
        case SPECTATABLE: return "SPECTATABLE";
        case LOCKED:      return "LOCKED";
    }
    return "FREE";
}

// ============================================================
// Evidence mode
// ============================================================

enum EvidenceMode : int {
    ANY,
    CMS_ONLY,
    MODS_ONLY,
}

// ============================================================
// Evidence item
// ============================================================

struct Evidence {
    String name;
    String description;
    String image;
}

// ============================================================
// Area struct
// ============================================================

struct Area {
    // -- Identity --
    String       name;
    int          index;

    // -- State --
    AreaStatus   status;
    LockState    lock;
    String       background;
    int          player_count;

    // -- Characters --
    bool[]       char_taken;  // indexed by char_id: true = taken

    // -- Penalty bars --
    int          defense_hp;
    int          prosecution_hp;

    // -- Evidence --
    Evidence[]   evidence;
    int          evidence_count;
    EvidenceMode evidence_mode;

    // -- CMs (case managers) --
    int[]        cm_uids;
    int          cm_count;

    // -- Lock --
    int[]        invited_uids;
    int          invited_count;

    // -- Music --
    String       current_song;
    int          song_player_uid;
}

// ============================================================
// Area lifecycle
// ============================================================

fn Area new_area(String name, int index, int char_list_len) {
    bool[] taken = mem::new_array(bool, char_list_len);
    for (usz i = 0; i < taken.len; i++) taken[i] = false;

    return {
        .name           = name,
        .index          = index,
        .status         = AreaStatus.IDLE,
        .lock           = LockState.FREE,
        .background     = "default",
        .player_count   = 0,
        .char_taken     = taken,
        .defense_hp     = 10,
        .prosecution_hp = 10,
        .evidence       = mem::new_array(Evidence, config::MAX_EVIDENCE_PER_AREA),
        .evidence_count = 0,
        .evidence_mode  = EvidenceMode.ANY,
        .cm_uids        = mem::new_array(int, config::DEFAULT_MAX_PLAYERS),
        .cm_count       = 0,
        .invited_uids   = mem::new_array(int, config::DEFAULT_MAX_PLAYERS),
        .invited_count  = 0,
        .current_song   = "",
        .song_player_uid = config::NO_UID,
    };
}

// ============================================================
// Character occupancy
// ============================================================

fn bool Area.is_char_taken(&self, int char_id) {
    if (char_id < 0 || char_id >= (int)self.char_taken.len) return true;
    return self.char_taken[char_id];
}

fn void Area.take_char(&self, int char_id) {
    if (char_id >= 0 && char_id < (int)self.char_taken.len) {
        self.char_taken[char_id] = true;
    }
}

fn void Area.release_char(&self, int char_id) {
    if (char_id >= 0 && char_id < (int)self.char_taken.len) {
        self.char_taken[char_id] = false;
    }
}

// ============================================================
// Evidence management
// ============================================================

fn void Area.add_evidence(&self, String name, String desc, String image) {
    if (self.evidence_count >= config::MAX_EVIDENCE_PER_AREA) return;

    self.evidence[self.evidence_count] = {
        .name = name,
        .description = desc,
        .image = image,
    };
    self.evidence_count++;
}

fn void Area.edit_evidence(&self, int id, String name, String desc, String image) {
    if (id < 0 || id >= self.evidence_count) return;
    self.evidence[id].name = name;
    self.evidence[id].description = desc;
    self.evidence[id].image = image;
}

fn void Area.delete_evidence(&self, int id) {
    if (id < 0 || id >= self.evidence_count) return;
    // Shift remaining evidence down
    for (int i = id; i < self.evidence_count - 1; i++) {
        self.evidence[i] = self.evidence[i + 1];
    }
    self.evidence_count--;
}

// Build the LE (evidence list) packet for this area.
fn String Area.build_evidence_packet(&self) {
    DString pkt = dstring::temp();
    pkt.append_string("LE");

    for (int i = 0; i < self.evidence_count; i++) {
        Evidence* e = &self.evidence[i];
        pkt.append_char('#');
        pkt.append_string(protocol::escape_value(e.name));
        pkt.append_char('&');
        pkt.append_string(protocol::escape_value(e.description));
        pkt.append_char('&');
        pkt.append_string(protocol::escape_value(e.image));
    }
    pkt.append_string(config::PACKET_TERMINATOR);
    return pkt.str_view();
}

// ============================================================
// CM (Case Manager) management
// ============================================================

fn bool Area.is_cm(&self, int uid) {
    for (int i = 0; i < self.cm_count; i++) {
        if (self.cm_uids[i] == uid) return true;
    }
    return false;
}

fn void Area.add_cm(&self, int uid) {
    if (self.is_cm(uid)) return;
    if (self.cm_count >= (int)self.cm_uids.len) return;
    self.cm_uids[self.cm_count] = uid;
    self.cm_count++;
}

fn void Area.remove_cm(&self, int uid) {
    for (int i = 0; i < self.cm_count; i++) {
        if (self.cm_uids[i] == uid) {
            // Shift down
            for (int j = i; j < self.cm_count - 1; j++) {
                self.cm_uids[j] = self.cm_uids[j + 1];
            }
            self.cm_count--;
            return;
        }
    }
}

// ============================================================
// Invite list (for locked areas)
// ============================================================

fn bool Area.is_invited(&self, int uid) {
    for (int i = 0; i < self.invited_count; i++) {
        if (self.invited_uids[i] == uid) return true;
    }
    return false;
}

fn void Area.invite(&self, int uid) {
    if (self.is_invited(uid)) return;
    if (self.invited_count >= (int)self.invited_uids.len) return;
    self.invited_uids[self.invited_count] = uid;
    self.invited_count++;
}

fn void Area.uninvite(&self, int uid) {
    for (int i = 0; i < self.invited_count; i++) {
        if (self.invited_uids[i] == uid) {
            for (int j = i; j < self.invited_count - 1; j++) {
                self.invited_uids[j] = self.invited_uids[j + 1];
            }
            self.invited_count--;
            return;
        }
    }
}

// ============================================================
// Area reset (when all players leave)
// ============================================================

fn void Area.reset(&self) {
    self.status = AreaStatus.IDLE;
    self.lock = LockState.FREE;
    self.cm_count = 0;
    self.invited_count = 0;
    self.defense_hp = config::PENALTY_BAR_MAX;
    self.prosecution_hp = config::PENALTY_BAR_MAX;
}

// ============================================================
// Area list loading (from areas.toml)
// ============================================================

fn Area[]? load_areas(String config_dir, int char_list_len) {
    String path = string::tformat("%s/areas.toml", config_dir);

    char[]? data = io::file::load(mem::heap(), path);
    if (catch data) {
        // Default: single area called "Lobby"
        Area[] default_areas = mem::new_array(Area, 1);
        default_areas[0] = new_area("Lobby", 0, char_list_len);
        return default_areas;
    }

    String content = (String)data;

    // Count areas (each [[area]] block)
    int area_count = 0;
    foreach (line : content.tsplit("\n")) {
        if (line.trim() == "[[area]]") area_count++;
    }
    if (area_count == 0) area_count = 1;

    Area[] areas = mem::new_array(Area, area_count);
    int idx = -1;

    foreach (line : content.tsplit("\n")) {
        String trimmed = line.trim();
        if (trimmed.len == 0 || trimmed[0] == '#') continue;

        if (trimmed == "[[area]]") {
            idx++;
            areas[idx] = new_area("Unnamed", idx, char_list_len);
            continue;
        }

        if (idx < 0) continue;

        if (trimmed.index_of_char('=')) |eq| {
            String key   = trimmed[0..eq].trim();
            String value = trimmed[eq + 1..].trim();
            if (value.len >= 2 && value[0] == '"') {
                value = value[1..value.len - 1];
            }

            if (key == "name")       areas[idx].name = value;
            if (key == "background") areas[idx].background = value;
        }
    }

    return areas;
}
