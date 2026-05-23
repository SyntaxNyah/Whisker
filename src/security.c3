// Whisker AO2 Server — Security & Rate Limiting
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Defense-in-depth against abuse: configurable rate limiters,
// connection flood detection, IP hashing, and ban checking.
// Built from the ground up for DDoS resilience.

module whisker::security;

import whisker::config;
import std::time;
import std::io;
import std::crypto;

// ============================================================
// Rate Limiter — sliding window counter
// ============================================================
//
// Tracks timestamps of recent actions in a circular buffer.
// If the count within the window exceeds the limit, the action
// is rejected. Simple, predictable, no token math.

const int RATE_WINDOW_SLOTS = 64;

struct RateLimiter {
    long[RATE_WINDOW_SLOTS] timestamps;
    int   head;
    int   count;
    int   max_actions;
    int   window_seconds;
}

fn RateLimiter new_limiter(int max_actions, int window_seconds) {
    RateLimiter rl;
    rl.head = 0;
    rl.count = 0;
    rl.max_actions = max_actions;
    rl.window_seconds = window_seconds;
    return rl;
}

// Returns true if the action is allowed, false if rate limited.
fn bool RateLimiter.check(&self) {
    if (self.max_actions <= 0) return true; // disabled

    long now = current_time_sec();
    long cutoff = now - (long)self.window_seconds;

    // Expire old entries
    while (self.count > 0) {
        int oldest = (self.head - self.count + RATE_WINDOW_SLOTS) % RATE_WINDOW_SLOTS;
        if (self.timestamps[oldest] < cutoff) {
            self.count--;
        } else {
            break;
        }
    }

    // Check limit
    if (self.count >= self.max_actions) {
        return false;
    }

    // Record this action
    self.timestamps[self.head] = now;
    self.head = (self.head + 1) % RATE_WINDOW_SLOTS;
    self.count++;
    return true;
}

fn void RateLimiter.configure(&self, int max_actions, int window_seconds) {
    self.max_actions = max_actions;
    self.window_seconds = window_seconds;
}

// ============================================================
// Connection Rate Tracker — per-IP flood detection
// ============================================================

const int MAX_TRACKED_IPS = 4096;

struct IpTracker {
    String[MAX_TRACKED_IPS]      ips;
    RateLimiter[MAX_TRACKED_IPS] limiters;
    int[MAX_TRACKED_IPS]         rejection_counts;
    int                          count;
    int                          conn_limit;
    int                          conn_window;
    int                          flood_threshold;
}

fn IpTracker new_ip_tracker(int conn_limit, int conn_window, int flood_threshold) {
    IpTracker tracker;
    tracker.count = 0;
    tracker.conn_limit = conn_limit;
    tracker.conn_window = conn_window;
    tracker.flood_threshold = flood_threshold;
    return tracker;
}

// Check if a new connection from this IP should be allowed.
// Returns: true = allow, false = reject (rate limited or banned)
fn bool IpTracker.check_connection(&self, String ip) {
    int slot = self.find_or_create(ip);
    if (slot < 0) return false; // tracker full, reject

    if (self.limiters[slot].check()) {
        return true;
    }

    // Rate limited — increment rejection count
    self.rejection_counts[slot]++;
    return false;
}

// Check if an IP has exceeded the flood ban threshold.
fn bool IpTracker.should_autoban(&self, String ip) {
    int slot = self.find_ip(ip);
    if (slot < 0) return false;
    return self.rejection_counts[slot] >= self.flood_threshold;
}

fn int IpTracker.find_ip(&self, String ip) {
    for (int i = 0; i < self.count; i++) {
        if (self.ips[i] == ip) return i;
    }
    return -1;
}

fn int IpTracker.find_or_create(&self, String ip) {
    int existing = self.find_ip(ip);
    if (existing >= 0) return existing;

    if (self.count >= MAX_TRACKED_IPS) {
        // Evict oldest entry
        for (int i = 0; i < self.count - 1; i++) {
            self.ips[i] = self.ips[i + 1];
            self.limiters[i] = self.limiters[i + 1];
            self.rejection_counts[i] = self.rejection_counts[i + 1];
        }
        self.count--;
    }

    int slot = self.count;
    self.ips[slot] = ip;
    self.limiters[slot] = new_limiter(self.conn_limit, self.conn_window);
    self.rejection_counts[slot] = 0;
    self.count++;
    return slot;
}

// ============================================================
// Multiclient limiter — max connections per IP
// ============================================================

fn int count_clients_by_ip(String ip, String[] client_ips, int client_count) {
    int count = 0;
    for (int i = 0; i < client_count; i++) {
        if (client_ips[i] == ip) count++;
    }
    return count;
}

// ============================================================
// IPID generation — hash the IP so we never store raw addresses
// ============================================================

// Generate an IPID from a raw IP address.
// Uses a simple hash to create a short, stable identifier.
// The raw IP is never stored or logged.
fn String generate_ipid(String raw_ip) {
    // Simple FNV-1a hash to create a stable short ID
    ulong hash = 14695981039346656037; // FNV offset basis
    foreach (ch : raw_ip) {
        hash ^= (ulong)ch;
        hash *= 1099511628211; // FNV prime
    }

    // Format as hex string (first 10 chars)
    return string::tformat("%010llx", hash);
}

// ============================================================
// HDID hashing — hardware IDs are also never stored raw
// ============================================================

fn String hash_hdid(String raw_hdid) {
    ulong hash = 14695981039346656037;
    foreach (ch : raw_hdid) {
        hash ^= (ulong)ch;
        hash *= 1099511628211;
    }
    return string::tformat("%010llx", hash);
}

// ============================================================
// Ban storage — simple file-based ban list
// ============================================================

struct BanEntry {
    String ipid;
    String hdid;
    String reason;
    long   expires;  // unix timestamp, 0 = permanent
    long   created;
}

const int MAX_BANS = 8192;

struct BanList {
    BanEntry[MAX_BANS] entries;
    int                 count;
}

fn BanList new_ban_list() {
    BanList bl;
    bl.count = 0;
    return bl;
}

fn bool BanList.is_banned_ipid(&self, String ipid) {
    long now = current_time_sec();
    for (int i = 0; i < self.count; i++) {
        if (self.entries[i].ipid == ipid) {
            if (self.entries[i].expires == 0 || self.entries[i].expires > now) {
                return true;
            }
        }
    }
    return false;
}

fn bool BanList.is_banned_hdid(&self, String hdid) {
    long now = current_time_sec();
    for (int i = 0; i < self.count; i++) {
        if (self.entries[i].hdid == hdid) {
            if (self.entries[i].expires == 0 || self.entries[i].expires > now) {
                return true;
            }
        }
    }
    return false;
}

fn void BanList.add(&self, String ipid, String hdid, String reason, long duration_sec) {
    if (self.count >= MAX_BANS) return;

    long now = current_time_sec();
    self.entries[self.count] = BanEntry {
        .ipid    = ipid,
        .hdid    = hdid,
        .reason  = reason,
        .expires = duration_sec > 0 ? now + duration_sec : 0,
        .created = now,
    };
    self.count++;
}

fn bool BanList.remove_by_index(&self, int index) {
    if (index < 0 || index >= self.count) return false;
    for (int i = index; i < self.count - 1; i++) {
        self.entries[i] = self.entries[i + 1];
    }
    self.count--;
    return true;
}

// ============================================================
// IP extraction for reverse proxy support
// ============================================================

// Extract the real client IP from proxy headers.
// Supports X-Forwarded-For (first IP in chain) and X-Real-IP.
fn String extract_real_ip(String header_value) {
    if (header_value.len == 0) return "";

    // X-Forwarded-For: client, proxy1, proxy2
    // Take the first (leftmost) IP — that's the original client
    if (header_value.index_of_char(',')) |comma| {
        return header_value[0..comma].trim();
    }
    return header_value.trim();
}

// ============================================================
// Utility
// ============================================================

fn long current_time_sec() {
    return (long)time::clock::now().to_seconds();
}

// Parse a duration string like "3d", "1h", "30m", "60s" into seconds.
fn long parse_duration(String s) {
    if (s.len == 0) return 0;

    long value = 0;
    usz i = 0;
    while (i < s.len && s[i] >= '0' && s[i] <= '9') {
        value = value * 10 + (long)(s[i] - '0');
        i++;
    }

    if (i >= s.len) return value; // bare seconds

    char unit = s[i];
    switch (unit) {
        's': return value;
        'm': return value * 60;
        'h': return value * 3600;
        'd': return value * 86400;
        'w': return value * 604800;
    }
    return value;
}
