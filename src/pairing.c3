// Whisker AO2 Server — Persistent Pairing System
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// UID-based mutual pairing that survives character and area changes.
// Inspired by Nyathena's pairing system.
//
// How it works:
//   1. Player A does /pair <B's UID>  → A.pair_wanted_uid = B
//   2. Player B does /pair <A's UID>  → B.pair_wanted_uid = A
//   3. Both wanted UIDs match → mutual pair established:
//      A.force_pair_uid = B, B.force_pair_uid = A
//   4. Pair persists across character changes and area moves.
//   5. Dissolves on disconnect or /unpair.

module whisker::pairing;

import whisker::config;
import whisker::client;
import std::io;

// ============================================================
// Pairing operations
// ============================================================

// Request a pair with another player.
// If mutual (both requested each other), establishes the pair.
// Returns true if the pair was finalized (mutual).
fn bool request_pair(
    client::Client* requester,
    client::Client* target,
    client::Client*[] all_clients,
    int client_count
) {
    if (requester.uid == target.uid) return false;

    requester.pair_wanted_uid = target.uid;

    // Check if target already requested us → mutual pair
    if (target.pair_wanted_uid == requester.uid) {
        // Establish mutual pair
        requester.force_pair_uid = target.uid;
        target.force_pair_uid = requester.uid;

        requester.send_server_message(
            string::tformat("Paired with %s (UID %d).", target.display_name(), target.uid)
        );
        target.send_server_message(
            string::tformat("Paired with %s (UID %d).", requester.display_name(), requester.uid)
        );

        return true;
    }

    // One-sided request — notify both
    requester.send_server_message(
        string::tformat("Pair request sent to %s (UID %d). They must /pair %d back.",
            target.display_name(), target.uid, requester.uid)
    );
    target.send_server_message(
        string::tformat("%s (UID %d) wants to pair with you. Type /pair %d to accept.",
            requester.display_name(), requester.uid, requester.uid)
    );

    return false;
}

// Cancel a pair. Full bidirectional reset:
// Clears pair state on every client that references the canceller.
fn void cancel_pair(
    client::Client* canceller,
    client::Client*[] all_clients,
    int client_count
) {
    int uid = canceller.uid;

    // Clear own state
    canceller.pair_wanted_uid = config::NO_PAIR;
    canceller.force_pair_uid  = config::NO_PAIR;

    // Clear any client that references us
    for (int i = 0; i < client_count; i++) {
        client::Client* other = all_clients[i];
        if (other == null || !other.connected) continue;

        bool changed = false;
        if (other.pair_wanted_uid == uid) {
            other.pair_wanted_uid = config::NO_PAIR;
            changed = true;
        }
        if (other.force_pair_uid == uid) {
            other.force_pair_uid = config::NO_PAIR;
            changed = true;
        }

        if (changed) {
            other.send_server_message(
                string::tformat("%s has unpaired.", canceller.display_name())
            );
        }
    }

    canceller.send_server_message("Pair cancelled.");
}

// Force two players into a pair (moderator command).
fn void force_pair(client::Client* a, client::Client* b) {
    a.force_pair_uid = b.uid;
    b.force_pair_uid = a.uid;
    a.pair_wanted_uid = b.uid;
    b.pair_wanted_uid = a.uid;

    a.send_server_message(string::tformat("Force-paired with %s.", b.display_name()));
    b.send_server_message(string::tformat("Force-paired with %s.", a.display_name()));
}

// Break a forced pair (moderator command).
fn void force_unpair(
    client::Client* target,
    client::Client*[] all_clients,
    int client_count
) {
    cancel_pair(target, all_clients, client_count);
}

// ============================================================
// IC message pairing logic
// ============================================================

// Called during MS packet processing to resolve pairing.
// Fills in the pair partner's character info if a valid pair exists.
//
// Returns: the paired partner client, or null if no active pair.
fn client::Client* resolve_pair(
    client::Client* sender,
    client::Client*[] all_clients,
    int client_count
) {
    // Check force pair first (persistent, UID-based)
    if (sender.force_pair_uid != config::NO_PAIR) {
        client::Client* partner = find_by_uid(all_clients, client_count, sender.force_pair_uid);
        if (partner != null && partner.connected && partner.area_id == sender.area_id) {
            return partner;
        }
    }

    // Check requested pair (non-persistent, requires same area)
    if (sender.pair_wanted_uid != config::NO_PAIR) {
        client::Client* partner = find_by_uid(all_clients, client_count, sender.pair_wanted_uid);
        if (partner != null
            && partner.connected
            && partner.area_id == sender.area_id
            && partner.pair_wanted_uid == sender.uid) {
            return partner;
        }
    }

    return null;
}

// ============================================================
// Client cleanup on disconnect
// ============================================================

// Call this when a client disconnects to clean up pair references.
fn void on_disconnect(
    client::Client* disconnecting,
    client::Client*[] all_clients,
    int client_count
) {
    cancel_pair(disconnecting, all_clients, client_count);
}

// ============================================================
// Utility
// ============================================================

fn client::Client* find_by_uid(client::Client*[] clients, int count, int uid) {
    for (int i = 0; i < count; i++) {
        if (clients[i] != null && clients[i].uid == uid) return clients[i];
    }
    return null;
}
