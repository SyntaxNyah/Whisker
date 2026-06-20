// Whisker Optional Plugin — IP Guard [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Connection-level access control: block individual IPs, CIDR ranges, whole
// ASNs, and whole countries — for IPv4 AND IPv6 — before a connection ever
// costs the server a thread. Drop the compiled .dll (Windows) / .so (Linux)
// into your server's plugins/ folder and restart. Optional — your server runs
// fine without it.
//
// This source file is provided as a learning exercise. To compile a C3 plugin
// yourself, follow the Plugin Dev Guide: plugins/PLUGIN DEV GUIDE README.md
//
// ============================================================
// What it does
// ============================================================
//
// IP Guard registers a v4 "connection filter": the server calls it for every
// inbound connection at accept time — the same spot the built-in IPID ban runs,
// BEFORE a handler thread (and its 256 KB pool) is spawned. The filter checks
// the raw client IP against the operator's blocklist and, on a match, the
// server closes the socket immediately. A blocked address therefore costs
// nothing beyond an O(log n) lookup — no thread, no handshake, no memory.
//
// The blocklist is built from a plain text file, config/ip_guard.txt:
//
//     ip       203.0.113.7            # one address
//     cidr     203.0.113.0/24         # a range
//     cidr     2001:db8::/32          # IPv6 ranges work too
//     asn      AS13335                # every range announced by an ASN
//     country  CN                     # every range geolocated to a country
//     allow    198.51.100.10          # exception: never block this (wins)
//
// ASNs and countries are resolved with a small public-domain IP database the
// plugin downloads ITSELF on first run (no account, no API key, nothing for the
// operator to install). See "Plug-and-play geo/ASN data" below.
//
// ============================================================
// Why this is useful (and why it's a PLUGIN, not core)
// ============================================================
//
// Attorney Online servers get a very specific kind of abuse: a single bad actor
// cycling through a cloud provider's address pool, or a flood of "users" out of
// a region that has no real player base and exists on your server only as VPN /
// proxy exit traffic. Per-IP bans lose to a /20 of fresh datacenter addresses,
// and the built-in ban list is keyed on a one-way IP *hash*, so it can't express
// "the whole range" or "that ASN" or "that country" at all.
//
// IP Guard fills that gap:
//   * Datacenter / cloud abuse — block the offending ASN (AS14061, AS16509, …)
//     or the provider's CIDRs and the entire pool is gone, not one address at a
//     time.
//   * VPN / proxy "countries" — some countries appear in AO traffic almost
//     exclusively as commercial VPN exit nodes with ~zero genuine players.
//     An operator who knows their community can choose to drop those countries
//     wholesale and cut a huge amount of ban-evasion and spam at the door.
//   * Ban evasion — a user hopping addresses within one ISP/region is stopped
//     by a range/ASN/country rule where a single-IP ban never would be.
//
// This is deliberately a heavy, opinionated, community-specific policy — exactly
// the kind of thing that must NOT be forced on every server. Country/ASN
// blocking is a blunt instrument: it WILL block real people who happen to share
// an ASN or country with abusers, and what's right for one server is wrong for
// another. So it lives in an optional plugin: servers that want it drop the file
// in; servers that don't, never think about it. The core stays small and
// neutral, and nobody has to fork the server to add — or avoid — this.
//
// ============================================================
// Plug-and-play geo/ASN data (no operator install)
// ============================================================
//
// To know which country / ASN an address belongs to, the plugin uses the
// iptoasn datasets redistributed by the public-domain (PDDL-1.0) project
// sapics/ip-location-db. On first run a background thread downloads the small
// CSVs it needs with `curl` (already required by the server_advertiser plugin;
// curl ships with modern Windows and every Linux) and caches them next to your
// config. They refresh automatically every `update_interval_days`. No API key,
// no registration, no manual download. If curl is unavailable or the fetch
// fails, the plugin logs it loudly and simply runs without geo/ASN rules —
// your `ip`/`cidr`/`allow` rules still work. Manual CIDR lists (e.g. a
// datacenter's published ranges) also work fully offline.
//
//   Data: https://github.com/sapics/ip-location-db (iptoasn-*, PDDL-1.0)
//   Upstream: https://iptoasn.com (PDDL-1.0). No attribution required; credited
//   here as a courtesy.
//
// ============================================================
// Performance (no degradation by design)
// ============================================================
//
//   * When no plugin registers a connection filter the core does ZERO extra
//     work. When this one is loaded, each connection is an O(log n) binary
//     search over sorted, de-duplicated ranges (a handful of comparisons even
//     for country-scale lists) plus a tiny linear scan of ad-hoc /ipban entries.
//   * The filter is allocation-free — it runs on the accept thread, where the
//     plugin's temp allocator isn't initialised, so it only touches stack and
//     pre-built tables (same discipline as the player_list plugin).
//   * The expensive parts — downloading and parsing the geo database, and
//     sending staff alerts — happen on a background thread, never on the accept
//     path. Blocked connections are RECORDED (O(1)) by the filter and reported
//     in coalesced summaries on a timer, so even a flood with alerts enabled
//     can't turn the reject path into per-connection broadcasts.
//
// ============================================================
// Commands (require the BAN permission)
// ============================================================
//
//   /ipban <ip|cidr> [note]   Add an ad-hoc rule live (also appended to the
//                             config file so it survives a restart).
//   /ipunban <ip|cidr>        Remove an ad-hoc /ipban rule.
//   /ipbanlist                Show rule counts, geo-DB status, recent blocks.
//   /ipbanlog                 Show the most recent blocked connection attempts.
//   /ipbanreload              Re-read config + refresh the geo/ASN database.
//
// ============================================================
// Notes / limitations
// ============================================================
//
//   * IPv6: fully matched. To actually RECEIVE IPv6 connections your server
//     must listen on an IPv6 address (set [server] addr = "::"). On Linux that
//     also accepts IPv4 clients (as v4-mapped, which the core normalises back to
//     dotted-quad); on Windows "::" is IPv6-only by default. IPs arriving via a
//     trusted reverse proxy (X-Forwarded-For / CF-Connecting-IP) are matched as
//     given, so geo-blocking works behind Cloudflare/nginx regardless.
//   * Two independent ban systems coexist: the core `/ban` keys on the hashed
//     IPID (good for "this user"); IP Guard keys on the real address / range /
//     ASN / country (good for "this network"). They don't interfere.

module ip_guard;

import std::io;

// ============================================================
// Whisker plugin interface (standalone definitions)
// Must match src/plugin.c3 PluginAPI exactly, field-for-field, in order.
// The three v4 fields at the very end (client_get_ip, register_conn_filter,
// broadcast_perm_raw) are what this plugin relies on.
// ============================================================

struct PluginInfo {
    String name;
    String version;
    String author;
    String description;
}

alias CommandHandler = fn void(void* client, String args);
alias PacketHook     = fn bool(void* client, void* packet);

alias RegisterCommandFn    = fn void(String, CommandHandler, ulong, String, String);
alias RegisterHookFn       = fn void(String, PacketHook, String);
alias FindClientFn         = fn void*(int);
alias BroadcastAreaMsgFn   = fn void(int, String);
alias BroadcastAreaRawFn   = fn void(int, String);
alias BroadcastArupFn      = fn void(int);
alias GetAreaCountFn       = fn int();
alias AreaIsCmFn           = fn bool(int, int);
alias AreaAddCmFn          = fn void(int, int);
alias AreaRemoveCmFn       = fn void(int, int);
alias AreaCmCountFn        = fn int(int);
alias AreaClearCmsFn       = fn void(int);
alias AreaUninviteFn       = fn void(int, int);
alias AreaSetStatusFn      = fn void(int, int);
alias AreaGetStatusFn      = fn int(int);
alias AreaGetNameFn        = fn String(int);
alias AreaSetSongFn        = fn void(int, String, int);
alias ForceMoveFn          = fn void(void*, int);
alias ClientSendMsgFn      = fn void(void*, String);
alias ClientSendRawFn      = fn void(void*, String);
alias ClientGetUidFn       = fn int(void*);
alias ClientGetAreaFn      = fn int(void*);
alias ClientIsModFn        = fn bool(void*);
alias ClientDisplayNameFn  = fn String(void*);
alias ClientGetCharIdFn    = fn int(void*);
alias ClientGetShownameFn  = fn String(void*);
alias ClientGetCharNameFn  = fn String(void*);
alias ClientIsJoinedFn     = fn bool(void*);
alias ClientSetPositionFn  = fn void(void*, String);

// Extended API (v2)
alias BroadcastAllMsgFn     = fn void(String);
alias BroadcastAllRawFn     = fn void(String);
alias GetPlayerCountFn      = fn int();
alias GetAreaPlayerCountFn  = fn int(int);
alias ClientGetIpidFn       = fn String(void*);
alias PacketGetFieldFn      = fn String(void*, int);
alias PacketGetFieldCountFn = fn int(void*);
alias ClientKickFn          = fn void(void*);
alias ClientMuteFn          = fn void(void*);
alias ClientUnmuteFn        = fn void(void*);
alias AreaGetBackgroundFn   = fn String(int);
alias AreaSetBackgroundFn   = fn void(int, String);
alias AreaGetLockFn         = fn int(int);
alias AreaSetLockFn         = fn void(int, int);
alias AreaInviteFn          = fn void(int, int);
alias ArgsSplitFn           = fn int(String, String*, int);
alias ToLowerFn             = fn int(String, char*, int);

// Lifecycle hooks (v3)
alias LifecycleHook           = fn void(void*, int);
alias RegisterLifecycleHookFn = fn void(LifecycleHook, String);
alias ClientGetOocNameFn      = fn String(void*);
alias ClientIsHiddenFn        = fn bool(void*);

// Connection filtering + raw IP + role-gated broadcast (v4)
alias ClientGetIpFn         = fn String(void*);
alias ConnectionFilter      = fn bool(String);
alias RegisterConnFilterFn  = fn void(ConnectionFilter, String);
alias BroadcastPermRawFn    = fn void(String, ulong);

struct PluginAPI {
    RegisterCommandFn   register_command;
    RegisterHookFn      register_hook;
    FindClientFn        find_client;
    BroadcastAreaMsgFn  broadcast_area_msg;
    BroadcastAreaRawFn  broadcast_area_raw;
    BroadcastArupFn     broadcast_arup;
    GetAreaCountFn      get_area_count;
    AreaIsCmFn          area_is_cm;
    AreaAddCmFn         area_add_cm;
    AreaRemoveCmFn      area_remove_cm;
    AreaCmCountFn       area_cm_count;
    AreaClearCmsFn      area_clear_cms;
    AreaUninviteFn      area_uninvite;
    AreaSetStatusFn     area_set_status;
    AreaGetStatusFn     area_get_status;
    AreaGetNameFn       area_get_name;
    AreaSetSongFn       area_set_song;
    ForceMoveFn         force_move;
    ClientSendMsgFn     client_send_msg;
    ClientSendRawFn     client_send_raw;
    ClientGetUidFn      client_get_uid;
    ClientGetAreaFn     client_get_area;
    ClientIsModFn       client_is_mod;
    ClientDisplayNameFn client_display_name;
    ClientGetCharIdFn   client_get_char_id;
    ClientGetShownameFn client_get_showname;
    ClientGetCharNameFn client_get_char_name;
    ClientIsJoinedFn    client_is_joined;
    ClientSetPositionFn client_set_position;

    // Extended API (v2)
    BroadcastAllMsgFn     broadcast_all_msg;
    BroadcastAllRawFn     broadcast_all_raw;
    GetPlayerCountFn      get_player_count;
    GetAreaPlayerCountFn  get_area_player_count;
    ClientGetIpidFn       client_get_ipid;
    PacketGetFieldFn      packet_get_field;
    PacketGetFieldCountFn packet_get_field_count;
    ClientKickFn          client_kick;
    ClientMuteFn          client_mute;
    ClientUnmuteFn        client_unmute;
    AreaGetBackgroundFn   area_get_background;
    AreaSetBackgroundFn   area_set_background;
    AreaGetLockFn         area_get_lock;
    AreaSetLockFn         area_set_lock;
    AreaInviteFn          area_invite;
    ArgsSplitFn           args_split;
    ToLowerFn             to_lower;

    // Lifecycle hooks + supporting getters (v3)
    RegisterLifecycleHookFn register_lifecycle_hook;
    ClientGetOocNameFn      client_get_ooc_name;
    ClientIsHiddenFn        client_is_hidden;

    // Connection filtering + raw IP + role-gated broadcast (v4)
    ClientGetIpFn         client_get_ip;
    RegisterConnFilterFn  register_conn_filter;
    BroadcastPermRawFn    broadcast_perm_raw;
}

// ============================================================
// C interop (file I/O, curl, threads, sleep, time, mkdir)
// ============================================================
//
// All file/network work uses libc directly so it is safe on any thread,
// including the raw background thread that has no C3 runtime context (the same
// approach the server_advertiser plugin uses).

extern fn CInt puts(ZString s);
extern fn CInt system(ZString cmd);
extern fn CInt fflush(void* stream);

// puts() + flush — the background thread runs with no C3 runtime and C stdio is
// block-buffered when stdout isn't a console, so without an explicit flush its
// progress/log lines can be lost if the process exits. Flushing keeps operators
// (and tests) seeing geo-download status promptly.
fn void bg_log(ZString s) {
    puts(s);
    fflush(null);
}
extern fn void* fopen_c(ZString path, ZString mode) @cname("fopen");
extern fn char* fgets_c(char* buf, CInt size, void* stream) @cname("fgets");
extern fn CInt fclose_c(void* stream) @cname("fclose");
extern fn CInt fputs_c(ZString s, void* stream) @cname("fputs");
extern fn long time_c(void* t) @cname("time");

extern fn uint  posix_sleep(uint seconds) @cname("sleep") @if(!env::WIN32);
extern fn void  win_sleep(uint milliseconds) @cname("Sleep") @if(env::WIN32);

extern fn CInt mkdir_win(ZString path) @cname("_mkdir") @if(env::WIN32);
extern fn CInt mkdir_posix(ZString path, uint mode) @cname("mkdir") @if(!env::WIN32);

alias RawThreadFn = fn void*(void*);
extern fn CInt   pthread_create(ulong* thread, void* attr, RawThreadFn start, void* arg) @if(!env::WIN32);
extern fn CInt   pthread_detach(ulong thread) @if(!env::WIN32);
extern fn void*  create_thread_win(void* attr, usz stack, RawThreadFn start, void* arg, uint flags, void* id) @cname("CreateThread") @if(env::WIN32);
extern fn CInt   close_handle_win(void* handle) @cname("CloseHandle") @if(env::WIN32);

macro void sleep_sec(uint seconds) {
    $if env::WIN32:
        win_sleep(seconds * 1000);
    $else
        posix_sleep(seconds);
    $endif
}

fn void make_dir(ZString path) {
    $if env::WIN32:
        (void)mkdir_win(path);
    $else
        (void)mkdir_posix(path, 0o755);
    $endif
}

// ============================================================
// Constants & limits
// ============================================================

const String PLUGIN_NAME = "IP Guard";

// Default permission gate for the commands and (by default) the alerts:
// commands::PERM_BAN == 1 << 2 == 4. Operators can re-point the alert gate at a
// different role's permission bits via `alert_permission` in the config.
const ulong PERM_BAN = 4;

// Sorted-table capacities. These are static (BSS) arrays: on every platform the
// pages stay unmapped until actually written, so sizing generously for
// country-scale data costs no resident memory until that data is loaded. On
// overflow we stop adding and warn (the table is still valid, just truncated).
const int MAX_GEO_V4   = 300000; // country/ASN ranges, IPv4, per source table
const int MAX_GEO_V6   = 150000; // country/ASN ranges, IPv6, per source table
const int MAX_MANUAL   = 16384;  // ip/cidr rules from the config file
const int MAX_ALLOW    = 8192;   // allow rules from the config file
const int MAX_LIVE     = 1024;   // ad-hoc /ipban rules added at runtime
const int MAX_COUNTRIES = 256;   // selected country codes
const int MAX_ASNS      = 512;   // selected ASNs
const int RING          = 64;    // recent-blocked ring buffer size

// Rule "kind" — recorded per range so alerts can say WHY a connection was cut.
const char KIND_MANUAL  = 0; // ip / cidr / live /ipban
const char KIND_COUNTRY = 1; // code = packed 2-letter code
const char KIND_ASN     = 2; // code = ASN number

// The ::ffff:0:0/96 prefix. IPv4 is stored in the unified 128-bit space as a
// v4-mapped address, so v4 and v6 never collide and one search path serves both.
const ulong V4_MAP = 0x0000_FFFF_0000_0000;

// Default geo database URLs (overridable in config). Public-domain (PDDL-1.0).
const String DEF_URL_C4 = "https://github.com/sapics/ip-location-db/releases/download/latest/iptoasn-country-ipv4.csv";
const String DEF_URL_C6 = "https://github.com/sapics/ip-location-db/releases/download/latest/iptoasn-country-ipv6.csv";
const String DEF_URL_A4 = "https://github.com/sapics/ip-location-db/releases/download/latest/iptoasn-asn-ipv4.csv";
const String DEF_URL_A6 = "https://github.com/sapics/ip-location-db/releases/download/latest/iptoasn-asn-ipv6.csv";

// ============================================================
// Address & range types (unified 128-bit)
// ============================================================

struct Addr {
    ulong hi;
    ulong lo;
}

struct Range {
    Addr start;
    Addr end;
    uint code; // country (packed 2 chars) or ASN number; 0 for manual
    char kind;
}

fn bool addr_le(Addr a, Addr b) {
    if (a.hi != b.hi) return a.hi < b.hi;
    return a.lo <= b.lo;
}

fn bool addr_eq(Addr a, Addr b) {
    return a.hi == b.hi && a.lo == b.lo;
}

// ============================================================
// Tables
// ============================================================
//
// Concurrency model (lockless, matching the core's own ban/broadcast code —
// e.g. the core mutates ban_list from a client thread while the accept thread
// reads it, with no lock; these tables follow the same accepted convention):
//   * allow / manual : built at startup before any connection is accepted, and
//     thereafter only rebuilt by /ipbanreload (re-parsing the config file on the
//     command thread). That rebuild is the one moment they change under the
//     accept thread: a brief, operator-initiated, lockless window on plain POD
//     ranges. Worst case during those few milliseconds is a single connection
//     evaluated against a partially-rebuilt table (it may be wrongly allowed,
//     never a crash) — the same trade-off the core ban_list already accepts.
//     /ipban does NOT touch these (it appends to `live`), so ordinary live bans
//     never disturb them.
//   * live           : runtime /ipban rules. Append-only (write the entry, then
//     bump the count last); linear-scanned. Never shrinks under a reader.
//   * geo_*          : rebuilt on the background thread. The rebuild sets the
//     count to 0 first, fills the table, then publishes the new count last — so
//     the accept thread either sees the old data, "no geo data yet" (fail-open),
//     or the complete new data, never a half-written table. allow/manual/live
//     are kept SEPARATE from geo specifically so refreshing the geo database
//     never blinks the operator's explicit bans off.

Range[MAX_ALLOW]  allow_tbl;  int allow_n;
Range[MAX_MANUAL] manual_tbl; int manual_n;
Range[MAX_LIVE]   live_tbl;   int live_n;

Range[MAX_GEO_V4] geo_country4; int geo_country4_n;
Range[MAX_GEO_V4] geo_asn4;     int geo_asn4_n;
Range[MAX_GEO_V6] geo_country6; int geo_country6_n;
Range[MAX_GEO_V6] geo_asn6;     int geo_asn6_n;

// Selected countries / ASNs (parsed from config).
char[2][MAX_COUNTRIES] sel_countries; int sel_country_n;
uint[MAX_ASNS]         sel_asns;       int sel_asn_n;

// ============================================================
// Options (from config)
// ============================================================

PluginAPI* api;

bool   opt_alert_blocked     = false;
ulong  opt_alert_permission  = PERM_BAN;
uint   opt_alert_interval    = 30;     // seconds between coalesced alerts
bool   opt_block_unknown     = false;  // reject IPs we cannot parse as v4/v6
bool   opt_auto_update       = true;
uint   opt_update_days       = 7;
bool   opt_running           = true;

// Set by /ipbanreload; the background thread picks it up and does the geo
// download + rebuild off the command thread (so a mod's /ipbanreload never
// blocks in curl).
bool   force_refresh         = false;

// Resolved file paths / commands, pre-built on the main thread (where the temp
// allocator works) so the background thread only has to fopen / system() them.
char[512]  path_config;
char[512]  path_cache_c4;
char[512]  path_cache_c6;
char[512]  path_cache_a4;
char[512]  path_cache_a6;
char[512]  path_marker;
char[1024] cmd_c4;
char[1024] cmd_c6;
char[1024] cmd_a4;
char[1024] cmd_a6;
char[512]  cfg_url_c4;
char[512]  cfg_url_c6;
char[512]  cfg_url_a4;
char[512]  cfg_url_a6;

// ============================================================
// Blocked-attempt ring buffer (for coalesced alerts + /ipbanlog)
// ============================================================

struct Hit {
    char[48] ip;
    char     kind;
    uint     code;
}

Hit[RING] ring;
ulong ring_total;     // total blocks ever (monotonic)
ulong ring_reported;  // value of ring_total at the last alert flush

// ============================================================
// Small string / number helpers (allocation-free, any thread)
// ============================================================

fn usz put_str(char[] buf, usz n, String s) {
    foreach (char ch : s) { if (n >= buf.len) break; buf[n] = ch; n++; }
    return n;
}

fn usz put_uint(char[] buf, usz n, ulong v) {
    if (v == 0) return put_str(buf, n, "0");
    char[20] tmp; int t = 0;
    while (v > 0) { tmp[t] = (char)('0' + (int)(v % 10)); t++; v /= 10; }
    while (t > 0) { t--; if (n >= buf.len) break; buf[n] = tmp[t]; n++; }
    return n;
}

// AO2 wire escaping for the CT alert payload.
fn usz put_escaped(char[] buf, usz n, String s) {
    foreach (char ch : s) {
        switch (ch) {
            case '#': n = put_str(buf, n, "<num>");
            case '&': n = put_str(buf, n, "<and>");
            case '%': n = put_str(buf, n, "<percent>");
            case '$': n = put_str(buf, n, "<dollar>");
            default:  if (n < buf.len) { buf[n] = ch; n++; }
        }
    }
    return n;
}

fn String cstr(char* buf) {
    int len = 0;
    while (buf[len] != 0) len++;
    if (len == 0) return "";
    return (String)buf[0..len - 1];
}

fn void copy_cstr(String src, char* dst, usz max) {
    usz i = 0;
    while (i < src.len && i < max) { dst[i] = src[i]; i++; }
    dst[i] = 0;
}

// ============================================================
// IP / CIDR parsing
// ============================================================

struct ParsedIp {
    bool ok;
    bool is_v4;
    Addr addr;
}

// Parse a dotted-quad into a host u32. Returns false on any malformed octet.
fn bool parse_v4(String s, uint* out) {
    uint result = 0;
    int parts = 0;
    int val = 0;
    bool have_digit = false;
    foreach (char ch : s) {
        if (ch >= '0' && ch <= '9') {
            val = val * 10 + (ch - '0');
            if (val > 255) return false;
            have_digit = true;
        } else if (ch == '.') {
            if (!have_digit) return false;
            result = (result << 8) | (uint)val;
            parts++;
            if (parts > 3) return false;
            val = 0;
            have_digit = false;
        } else {
            return false;
        }
    }
    if (!have_digit || parts != 3) return false;
    result = (result << 8) | (uint)val;
    *out = result;
    return true;
}

fn Addr v4_to_addr(uint v) {
    return { .hi = 0, .lo = V4_MAP | (ulong)v };
}

// Parse an IPv6 literal (handles "::" compression and uncompressed forms) into
// a 128-bit Addr. Embedded-IPv4 tails (::ffff:1.2.3.4) are not parsed here — the
// core already normalises v4-mapped peers to dotted-quad, and the geo CSVs use
// hex groups — so a literal that doesn't fit pure-hex form is rejected (fail
// open) rather than mis-parsed.
fn bool parse_v6(String s, Addr* out) {
    ushort[8] groups;
    for (int i = 0; i < 8; i++) groups[i] = 0;

    // Split on "::" (at most one).
    int dcolon = -1;
    for (usz i = 0; i + 1 < s.len; i++) {
        if (s[i] == ':' && s[i + 1] == ':') { dcolon = (int)i; break; }
    }

    if (dcolon < 0) {
        // No compression — must be exactly 8 groups.
        int g = 0;
        if (!parse_v6_groups(s, &groups, 0, &g)) return false;
        if (g != 8) return false;
    } else {
        String left  = s[0..(usz)dcolon == 0 ? 0 : (usz)dcolon - 1];
        if (dcolon == 0) left = "";
        usz rstart = (usz)dcolon + 2;
        String right = rstart <= s.len ? (rstart == s.len ? "" : s[rstart..]) : "";

        int gl = 0;
        int gr = 0;
        ushort[8] lg; ushort[8] rg;
        for (int i = 0; i < 8; i++) { lg[i] = 0; rg[i] = 0; }
        if (left.len  > 0 && !parse_v6_groups(left,  &lg, 0, &gl)) return false;
        if (right.len > 0 && !parse_v6_groups(right, &rg, 0, &gr)) return false;
        if (gl + gr > 7) return false; // "::" must stand for >= 1 zero group

        for (int i = 0; i < gl; i++) groups[i] = lg[i];
        for (int i = 0; i < gr; i++) groups[8 - gr + i] = rg[i];
    }

    ulong hi = 0;
    ulong lo = 0;
    for (int i = 0; i < 4; i++) hi = (hi << 16) | (ulong)groups[i];
    for (int i = 4; i < 8; i++) lo = (lo << 16) | (ulong)groups[i];
    *out = { .hi = hi, .lo = lo };
    return true;
}

// Parse colon-separated hex groups of a v6 literal segment into `dst` starting
// at index `start`; writes the produced count to *count.
fn bool parse_v6_groups(String s, ushort[8]* dst, int start, int* count) {
    int g = start;
    int val = 0;
    int digits = 0;
    foreach (char ch : s) {
        int d = hex_val(ch);
        if (d >= 0) {
            val = (val << 4) | d;
            digits++;
            if (digits > 4) return false;
        } else if (ch == ':') {
            if (digits == 0) return false;
            if (g >= 8) return false;
            (*dst)[g] = (ushort)val;
            g++;
            val = 0; digits = 0;
        } else {
            return false;
        }
    }
    if (digits == 0) return false;
    if (g >= 8) return false;
    (*dst)[g] = (ushort)val;
    g++;
    *count = g - start;
    return true;
}

fn int hex_val(char ch) {
    if (ch >= '0' && ch <= '9') return ch - '0';
    if (ch >= 'a' && ch <= 'f') return ch - 'a' + 10;
    if (ch >= 'A' && ch <= 'F') return ch - 'A' + 10;
    return -1;
}

fn ParsedIp parse_ip(String s) {
    ParsedIp p;
    p.ok = false;
    if (s.len == 0) return p;
    // A ':' means IPv6, otherwise IPv4.
    bool v6 = false;
    foreach (char ch : s) { if (ch == ':') { v6 = true; break; } }
    if (v6) {
        Addr a;
        if (parse_v6(s, &a)) { p.ok = true; p.is_v4 = false; p.addr = a; }
    } else {
        uint v;
        if (parse_v4(s, &v)) { p.ok = true; p.is_v4 = true; p.addr = v4_to_addr(v); }
    }
    return p;
}

struct ParsedRange {
    bool ok;
    bool is_v4;
    Addr start;
    Addr end;
}

// Parse "ip", "ip/prefix" (CIDR), or "start-end" into a range.
fn ParsedRange parse_range(String s) {
    ParsedRange r;
    r.ok = false;

    // CIDR?
    if (try slash = s.index_of_char('/')) {
        String ip_part  = s[0..slash - 1].trim();
        String pfx_part = s[slash + 1..].trim();
        ParsedIp ip = parse_ip(ip_part);
        if (!ip.ok) return r;
        int prefix = 0;
        foreach (char ch : pfx_part) {
            if (ch < '0' || ch > '9') return r;
            prefix = prefix * 10 + (ch - '0');
        }
        int maxbits = ip.is_v4 ? 32 : 128;
        if (prefix < 0 || prefix > maxbits) return r;
        // For v4, the host lives in the low 32 bits of the mapped address, so a
        // /p maps to a 128-bit prefix of (96 + p).
        int bits = ip.is_v4 ? 96 + prefix : prefix;
        Addr mask = mask_from_prefix(bits);
        r.start = { .hi = ip.addr.hi & mask.hi, .lo = ip.addr.lo & mask.lo };
        r.end   = { .hi = ip.addr.hi | ~mask.hi, .lo = ip.addr.lo | ~mask.lo };
        r.is_v4 = ip.is_v4;
        r.ok = true;
        return r;
    }

    // Plain single address → /32 or /128.
    ParsedIp ip = parse_ip(s);
    if (!ip.ok) return r;
    r.start = ip.addr;
    r.end = ip.addr;
    r.is_v4 = ip.is_v4;
    r.ok = true;
    return r;
}

// 128-bit network mask with the top `bits` bits set.
fn Addr mask_from_prefix(int bits) {
    Addr m;
    if (bits <= 0) { m.hi = 0; m.lo = 0; return m; }
    if (bits >= 128) { m.hi = 0xFFFFFFFFFFFFFFFF; m.lo = 0xFFFFFFFFFFFFFFFF; return m; }
    if (bits == 64) { m.hi = 0xFFFFFFFFFFFFFFFF; m.lo = 0; return m; }
    if (bits < 64) {
        m.hi = 0xFFFFFFFFFFFFFFFF << (64 - bits);
        m.lo = 0;
    } else {
        m.hi = 0xFFFFFFFFFFFFFFFF;
        m.lo = 0xFFFFFFFFFFFFFFFF << (128 - bits);
    }
    return m;
}

// ============================================================
// Table search & build
// ============================================================

// Binary search a sorted, non-overlapping range table. Returns the matching
// index, or -1. (geo tables come pre-sorted & disjoint from their CSV; manual /
// allow are sorted + merged at build time, so all are safe for binary search.)
fn int table_find(Range* tbl, int n, Addr a) {
    int lo = 0;
    int hi = n - 1;
    int found = -1;
    while (lo <= hi) {
        int mid = (lo + hi) / 2;
        if (addr_le(tbl[mid].start, a)) { found = mid; lo = mid + 1; }
        else { hi = mid - 1; }
    }
    if (found < 0) return -1;
    if (addr_le(a, tbl[found].end)) return found;
    return -1;
}

// Linear scan (for the small, append-only live table).
fn int live_find(Addr a) {
    for (int i = 0; i < live_n; i++) {
        if (addr_le(live_tbl[i].start, a) && addr_le(a, live_tbl[i].end)) return i;
    }
    return -1;
}

// Insertion-sort + overlap-merge a freshly-built table (manual / allow).
fn int sort_and_merge(Range* tbl, int n) {
    for (int i = 1; i < n; i++) {
        Range key = tbl[i];
        int j = i - 1;
        while (j >= 0 && !addr_le(tbl[j].start, key.start)) { tbl[j + 1] = tbl[j]; j--; }
        tbl[j + 1] = key;
    }
    if (n == 0) return 0;
    int w = 0;
    for (int i = 1; i < n; i++) {
        // Merge if the next range starts within (or just after) the current end.
        if (addr_le(tbl[i].start, tbl[w].end) || addr_le(tbl[i].start, addr_inc(tbl[w].end))) {
            if (!addr_le(tbl[i].end, tbl[w].end)) tbl[w].end = tbl[i].end;
        } else {
            w++;
            tbl[w] = tbl[i];
        }
    }
    return w + 1;
}

fn Addr addr_inc(Addr a) {
    Addr r = a;
    if (r.lo == 0xFFFFFFFFFFFFFFFF) { r.lo = 0; r.hi++; } else { r.lo++; }
    return r;
}

// Pack a 2-letter country code into a uint for storage / display.
fn uint pack_cc(char a, char b) {
    return ((uint)up(a) << 8) | (uint)up(b);
}

fn char up(char c) {
    if (c >= 'a' && c <= 'z') return c - 32;
    return c;
}

// ============================================================
// The connection filter — runs on the accept thread (allocation-free)
// ============================================================

fn bool conn_filter(String ip) {
    ParsedIp p = parse_ip(ip);
    if (!p.ok) {
        // Couldn't classify (e.g. "unknown", or a form we don't parse).
        return opt_block_unknown;
    }

    // Allowlist wins over everything.
    if (table_find(&allow_tbl[0], allow_n, p.addr) >= 0) return false;

    // Ad-hoc runtime bans.
    int li = live_find(p.addr);
    if (li >= 0) { record_hit(ip, live_tbl[li].kind, live_tbl[li].code); return true; }

    // Operator manual ip/cidr rules.
    int mi = table_find(&manual_tbl[0], manual_n, p.addr);
    if (mi >= 0) { record_hit(ip, manual_tbl[mi].kind, manual_tbl[mi].code); return true; }

    // Geo: country then ASN, family-specific. Counts are read once each
    // (publish-last discipline) so a concurrent refresh is safe.
    if (p.is_v4) {
        int n1 = geo_country4_n;
        int c = table_find(&geo_country4[0], n1, p.addr);
        if (c >= 0) { record_hit(ip, KIND_COUNTRY, geo_country4[c].code); return true; }
        int n2 = geo_asn4_n;
        int an = table_find(&geo_asn4[0], n2, p.addr);
        if (an >= 0) { record_hit(ip, KIND_ASN, geo_asn4[an].code); return true; }
    } else {
        int n1 = geo_country6_n;
        int c = table_find(&geo_country6[0], n1, p.addr);
        if (c >= 0) { record_hit(ip, KIND_COUNTRY, geo_country6[c].code); return true; }
        int n2 = geo_asn6_n;
        int an = table_find(&geo_asn6[0], n2, p.addr);
        if (an >= 0) { record_hit(ip, KIND_ASN, geo_asn6[an].code); return true; }
    }

    return false;
}

// O(1) record of a blocked attempt. Lockless: write the slot, then bump the
// total last. A torn read in /ipbanlog is at worst a cosmetic stale row.
fn void record_hit(String ip, char kind, uint code) {
    int slot = (int)(ring_total % (ulong)RING);
    copy_cstr(ip, &ring[slot].ip[0], 47);
    ring[slot].kind = kind;
    ring[slot].code = code;
    ring_total++;
}

// ============================================================
// Config file
// ============================================================

fn void add_to(Range* tbl, int* n, int cap, ParsedRange r, char kind, uint code) {
    if (*n >= cap) return;
    tbl[*n] = { .start = r.start, .end = r.end, .code = code, .kind = kind };
    (*n)++;
}

// Parse config/ip_guard.txt: fills options + manual/allow tables + the selected
// country/ASN sets. Runs on the main thread at init (temp allocator available),
// but uses libc file I/O so it's robust regardless.
fn void load_config() {
    allow_n = 0; manual_n = 0; sel_country_n = 0; sel_asn_n = 0;

    void* f = fopen_c((ZString)&path_config[0], "r");
    if (f == null) {
        io::printn("[ip_guard] No ip_guard.txt found — writing a template; no rules active yet.");
        write_template();
        return;
    }

    char[1024] line;
    while (fgets_c(&line[0], 1024, f) != null) {
        String raw = cstr(&line[0]).trim();
        if (raw.len == 0 || raw[0] == '#') continue;
        parse_config_line(raw);
    }
    fclose_c(f);

    manual_n = sort_and_merge(&manual_tbl[0], manual_n);
    allow_n  = sort_and_merge(&allow_tbl[0], allow_n);

    io::printfn("[ip_guard] Config: %d manual range(s), %d allow rule(s), %d country(ies), %d ASN(s).",
        manual_n, allow_n, sel_country_n, sel_asn_n);
}

fn void parse_config_line(String raw) {
    // Split into keyword + remainder.
    usz sp = 0;
    while (sp < raw.len && raw[sp] != ' ' && raw[sp] != '\t') sp++;
    String key = raw[0..(sp == 0 ? 0 : sp - 1)];
    if (sp == 0) key = raw;
    String rest = sp < raw.len ? raw[sp..].trim() : "";

    if (key == "ip" || key == "cidr" || key == "block") {
        ParsedRange r = parse_range(rest);
        if (r.ok) add_to(&manual_tbl[0], &manual_n, MAX_MANUAL, r, KIND_MANUAL, 0);
        return;
    }
    if (key == "allow") {
        ParsedRange r = parse_range(rest);
        if (r.ok) add_to(&allow_tbl[0], &allow_n, MAX_ALLOW, r, KIND_MANUAL, 0);
        return;
    }
    if (key == "country") {
        if (rest.len >= 2 && sel_country_n < MAX_COUNTRIES) {
            sel_countries[sel_country_n][0] = up(rest[0]);
            sel_countries[sel_country_n][1] = up(rest[1]);
            sel_country_n++;
        }
        return;
    }
    if (key == "asn") {
        // Accept "AS12345" or "12345".
        usz i = 0;
        if (rest.len >= 2 && up(rest[0]) == 'A' && up(rest[1]) == 'S') i = 2;
        uint v = 0; bool have = false;
        while (i < rest.len && rest[i] >= '0' && rest[i] <= '9') { v = v * 10 + (uint)(rest[i] - '0'); have = true; i++; }
        if (have && sel_asn_n < MAX_ASNS) { sel_asns[sel_asn_n] = v; sel_asn_n++; }
        return;
    }

    // Options.
    if (key == "alert_blocked")     { opt_alert_blocked = is_true(rest); return; }
    if (key == "alert_permission")  { opt_alert_permission = parse_ulong(rest); return; }
    if (key == "alert_interval_sec"){ uint v = (uint)parse_ulong(rest); if (v > 0) opt_alert_interval = v; return; }
    if (key == "block_unknown")     { opt_block_unknown = is_true(rest); return; }
    if (key == "auto_update")       { opt_auto_update = is_true(rest); return; }
    if (key == "update_interval_days") { uint v = (uint)parse_ulong(rest); if (v > 0) opt_update_days = v; return; }
    if (key == "country_db_url")    { copy_cstr(rest, &cfg_url_c4[0], 511); return; }
    if (key == "country_db_url_v6") { copy_cstr(rest, &cfg_url_c6[0], 511); return; }
    if (key == "asn_db_url")        { copy_cstr(rest, &cfg_url_a4[0], 511); return; }
    if (key == "asn_db_url_v6")     { copy_cstr(rest, &cfg_url_a6[0], 511); return; }

    // Otherwise: maybe a bare "1.2.3.4" or "1.2.3.0/24" convenience line.
    ParsedRange r = parse_range(raw);
    if (r.ok) add_to(&manual_tbl[0], &manual_n, MAX_MANUAL, r, KIND_MANUAL, 0);
}

fn bool is_true(String s) { return s == "true" || s == "1" || s == "yes" || s == "on"; }

fn ulong parse_ulong(String s) {
    ulong v = 0;
    foreach (char ch : s) { if (ch >= '0' && ch <= '9') v = v * 10 + (ulong)(ch - '0'); }
    return v;
}

fn void write_template() {
    void* f = fopen_c((ZString)&path_config[0], "w");
    if (f == null) return;
    fputs_c("# Whisker IP Guard — connection blocklist\n", f);
    fputs_c("# One rule per line. '#' starts a comment. Reload with /ipbanreload.\n", f);
    fputs_c("#\n", f);
    fputs_c("# ip       203.0.113.7         # block a single address (v4 or v6)\n", f);
    fputs_c("# cidr     203.0.113.0/24      # block a CIDR range\n", f);
    fputs_c("# cidr     2001:db8::/32       # IPv6 ranges work too\n", f);
    fputs_c("# asn      AS13335             # block every range announced by an ASN\n", f);
    fputs_c("# country  CN                  # block a country (ISO 3166-1 alpha-2)\n", f);
    fputs_c("# allow    198.51.100.10       # exception: never block this (wins over all)\n", f);
    fputs_c("#\n", f);
    fputs_c("# --- options ---\n", f);
    fputs_c("# alert_blocked       false    # OOC alert to staff when a block happens\n", f);
    fputs_c("# alert_permission    4        # which permission bit sees alerts (4 = ban)\n", f);
    fputs_c("# alert_interval_sec  30       # coalesce alerts over this many seconds\n", f);
    fputs_c("# block_unknown       false    # drop connections whose IP can't be read\n", f);
    fputs_c("# auto_update         true     # auto-download/refresh the geo+ASN database\n", f);
    fputs_c("# update_interval_days 7\n", f);
    fclose_c(f);
}

// Append a rule to the config file so a live /ipban survives a restart.
fn void persist_rule(String token) {
    void* f = fopen_c((ZString)&path_config[0], "a");
    if (f == null) return;
    char[600] buf; usz n = 0;
    n = put_str(buf[..], n, "cidr ");
    n = put_str(buf[..], n, token);
    n = put_str(buf[..], n, "\n");
    buf[n] = 0;
    fputs_c((ZString)&buf[0], f);
    fclose_c(f);
}

// ============================================================
// Geo database: download (curl) + parse (CSV)
// ============================================================

// Build the cache paths and curl commands once, on the main thread.
fn void build_paths_and_cmds(String dir) {
    build_path(&path_cache_c4, dir, "ip_guard_country4.csv");
    build_path(&path_cache_c6, dir, "ip_guard_country6.csv");
    build_path(&path_cache_a4, dir, "ip_guard_asn4.csv");
    build_path(&path_cache_a6, dir, "ip_guard_asn6.csv");
    build_path(&path_marker,   dir, "ip_guard_dbtime.txt");

    build_curl(&cmd_c4, cstr(&cfg_url_c4[0]), &path_cache_c4);
    build_curl(&cmd_c6, cstr(&cfg_url_c6[0]), &path_cache_c6);
    build_curl(&cmd_a4, cstr(&cfg_url_a4[0]), &path_cache_a4);
    build_curl(&cmd_a6, cstr(&cfg_url_a6[0]), &path_cache_a6);
}

fn void build_path(char[512]* dst, String dir, String name) {
    usz n = 0;
    n = put_str((*dst)[..], n, dir);
    n = put_str((*dst)[..], n, "/");
    n = put_str((*dst)[..], n, name);
    (*dst)[n] = 0;
}

fn void build_curl(char[1024]* dst, String url, char[512]* out_path) {
    usz n = 0;
    n = put_str((*dst)[..], n, "curl -sL --fail --max-time 180 -o \"");
    n = put_str((*dst)[..], n, cstr(&(*out_path)[0]));
    n = put_str((*dst)[..], n, "\" \"");
    n = put_str((*dst)[..], n, url);
    n = put_str((*dst)[..], n, "\"");
    // Redirect the child's own stdio to null so it never blocks on (or inherits)
    // the server's console/pipe — important when the server runs headless (e.g.
    // as a service), where an inherited pipe could otherwise stall the call.
    $if env::WIN32:
        n = put_str((*dst)[..], n, " >nul 2>&1");
    $else
        n = put_str((*dst)[..], n, " >/dev/null 2>&1");
    $endif
    (*dst)[n] = 0;
}

fn bool file_exists(char* path) {
    void* f = fopen_c((ZString)path, "r");
    if (f == null) return false;
    fclose_c(f);
    return true;
}

// Returns true if the cached DB is missing or older than the refresh interval.
fn bool db_stale() {
    if (!file_exists(&path_marker[0])) return true;
    void* f = fopen_c((ZString)&path_marker[0], "r");
    if (f == null) return true;
    char[64] buf;
    long saved = 0;
    if (fgets_c(&buf[0], 64, f) != null) saved = (long)parse_ulong(cstr(&buf[0]));
    fclose_c(f);
    long now = time_c(null);
    long age = now - saved;
    return age > (long)opt_update_days * 86400;
}

fn void mark_db_time() {
    void* f = fopen_c((ZString)&path_marker[0], "w");
    if (f == null) return;
    char[32] buf; usz n = put_uint(buf[..], 0, (ulong)time_c(null)); buf[n] = 0;
    fputs_c((ZString)&buf[0], f);
    fclose_c(f);
}

// Download the CSVs we actually need (only countries / ASNs that are selected).
// puts() (not io::printfn) because this runs on the raw background thread.
fn void download_db() {
    bool need_country = sel_country_n > 0;
    bool need_asn     = sel_asn_n > 0;
    if (!need_country && !need_asn) return;

    bool ok = true;
    if (need_country) {
        bg_log("[ip_guard] Downloading country IP database (v4/v6)...");
        if (system((ZString)&cmd_c4[0]) != 0) { ok = false; bg_log("[ip_guard] WARNING: country IPv4 DB download failed."); }
        if (system((ZString)&cmd_c6[0]) != 0) { bg_log("[ip_guard] WARNING: country IPv6 DB download failed (v6 country rules inactive)."); }
    }
    if (need_asn) {
        bg_log("[ip_guard] Downloading ASN IP database (v4/v6)...");
        if (system((ZString)&cmd_a4[0]) != 0) { ok = false; bg_log("[ip_guard] WARNING: ASN IPv4 DB download failed."); }
        if (system((ZString)&cmd_a6[0]) != 0) { bg_log("[ip_guard] WARNING: ASN IPv6 DB download failed (v6 ASN rules inactive)."); }
    }
    if (ok) {
        mark_db_time();
        bg_log("[ip_guard] Geo/ASN database ready.");
    } else {
        bg_log("[ip_guard] Geo/ASN database incomplete — check curl is installed and the server can reach github.com.");
    }
}

// Parse one cached CSV into a geo table. `is_country` selects the matcher and
// the column meaning. Publishes the count LAST (the table is filled with the
// count at 0 so the accept thread never binary-searches a half-built table).
fn void load_csv(char* path, Range* tbl, int* count_field, int cap, bool is_country, bool v4) {
    *count_field = 0; // fail-open while (re)building
    void* f = fopen_c((ZString)path, "r");
    if (f == null) return;

    int n = 0;
    char[256] line;
    while (fgets_c(&line[0], 256, f) != null && n < cap) {
        String row = cstr(&line[0]);
        // Columns: start_ip , end_ip , (country_code | asn) [, name]
        if (try c1 = row.index_of_char(',')) {
            String after1 = row[c1 + 1..];
            if (try c2rel = after1.index_of_char(',')) {
                String start_s = row[0..c1 - 1];
                String end_s   = after1[0..c2rel - 1];
                String third   = after1[c2rel + 1..].trim_right();

                ParsedIp a = parse_ip(start_s.trim());
                ParsedIp b = parse_ip(end_s.trim());
                if (!a.ok || !b.ok || a.is_v4 != v4 || b.is_v4 != v4) continue;

                uint code;
                char kind;
                if (is_country) {
                    if (!country_selected(third)) continue;
                    code = pack_cc(third.len > 0 ? third[0] : (char)'?', third.len > 1 ? third[1] : (char)'?');
                    kind = KIND_COUNTRY;
                } else {
                    uint asn = (uint)parse_ulong(third);
                    if (!asn_selected(asn)) continue;
                    code = asn;
                    kind = KIND_ASN;
                }
                tbl[n] = { .start = a.addr, .end = b.addr, .code = code, .kind = kind };
                n++;
            }
        }
    }
    fclose_c(f);
    *count_field = n; // publish
}

fn bool country_selected(String cc) {
    if (cc.len < 2) return false;
    char a = up(cc[0]); char b = up(cc[1]);
    for (int i = 0; i < sel_country_n; i++) {
        if (sel_countries[i][0] == a && sel_countries[i][1] == b) return true;
    }
    return false;
}

fn bool asn_selected(uint asn) {
    for (int i = 0; i < sel_asn_n; i++) { if (sel_asns[i] == asn) return true; }
    return false;
}

// Rebuild every geo table from the cached CSVs. Sources that are no longer
// selected are zeroed, so a /ipbanreload that REMOVES a country/ASN clears its
// ranges instead of leaving them live.
fn void rebuild_geo() {
    if (sel_country_n > 0) {
        load_csv(&path_cache_c4[0], &geo_country4[0], &geo_country4_n, MAX_GEO_V4, true, true);
        load_csv(&path_cache_c6[0], &geo_country6[0], &geo_country6_n, MAX_GEO_V6, true, false);
    } else {
        geo_country4_n = 0; geo_country6_n = 0;
    }
    if (sel_asn_n > 0) {
        load_csv(&path_cache_a4[0], &geo_asn4[0], &geo_asn4_n, MAX_GEO_V4, false, true);
        load_csv(&path_cache_a6[0], &geo_asn6[0], &geo_asn6_n, MAX_GEO_V6, false, false);
    } else {
        geo_asn4_n = 0; geo_asn6_n = 0;
    }
    char[160] msg; usz n = 0;
    n = put_str(msg[..], n, "[ip_guard] Geo tables: country v4=");
    n = put_uint(msg[..], n, (ulong)geo_country4_n);
    n = put_str(msg[..], n, " v6="); n = put_uint(msg[..], n, (ulong)geo_country6_n);
    n = put_str(msg[..], n, ", asn v4="); n = put_uint(msg[..], n, (ulong)geo_asn4_n);
    n = put_str(msg[..], n, " v6="); n = put_uint(msg[..], n, (ulong)geo_asn6_n);
    msg[n] = 0;
    bg_log((ZString)&msg[0]);
}

// ============================================================
// Staff alerts (coalesced, off the accept path)
// ============================================================

fn void flush_alerts() {
    if (!opt_alert_blocked) { ring_reported = ring_total; return; }
    ulong total = ring_total;
    if (total <= ring_reported) return;
    ulong delta = total - ring_reported;
    ring_reported = total;

    // Latest hit is the slot just before the current write head.
    int latest = (int)((total - 1) % (ulong)RING);

    char[256] msg; usz n = 0;
    n = put_str(msg[..], n, "[IP Guard] ");
    n = put_uint(msg[..], n, delta);
    n = put_str(msg[..], n, delta == 1 ? " connection blocked — " : " connections blocked — latest ");
    n = put_str(msg[..], n, cstr(&ring[latest].ip[0]));
    n = put_str(msg[..], n, " (");
    n = put_reason(msg[..], n, ring[latest].kind, ring[latest].code);
    n = put_str(msg[..], n, ")");
    String text = (String)msg[0..n - 1];

    broadcast_ct(text);
}

fn usz put_reason(char[] buf, usz n, char kind, uint code) {
    switch (kind) {
        case KIND_COUNTRY:
            n = put_str(buf, n, "country ");
            if (n < buf.len) { buf[n] = (char)((code >> 8) & 0xFF); n++; }
            if (n < buf.len) { buf[n] = (char)(code & 0xFF); n++; }
        case KIND_ASN:
            n = put_str(buf, n, "AS");
            n = put_uint(buf, n, (ulong)code);
        default:
            n = put_str(buf, n, "manual rule");
    }
    return n;
}

// Build a CT packet on the stack and send it to staff (role-gated). No temp
// allocator is touched, so this is safe on the background thread.
fn void broadcast_ct(String message) {
    char[512] buf; usz n = 0;
    n = put_str(buf[..], n, "CT#");
    n = put_escaped(buf[..], n, PLUGIN_NAME);
    n = put_str(buf[..], n, "#");
    n = put_escaped(buf[..], n, message);
    n = put_str(buf[..], n, "#1#%");
    api.broadcast_perm_raw((String)buf[0..n - 1], opt_alert_permission);
}

// ============================================================
// Background thread: download → build → periodic refresh + alert flush
// ============================================================

fn void* background_loop(void* arg) {
    sleep_sec(3);

    if ((sel_country_n > 0 || sel_asn_n > 0)) {
        if (db_stale()) {
            download_db();
        } else {
            bg_log("[ip_guard] Using cached geo/ASN database.");
        }
        rebuild_geo();
    }

    uint elapsed = 0;
    while (opt_running) {
        sleep_sec(opt_alert_interval);
        elapsed += opt_alert_interval;
        flush_alerts();

        // /ipbanreload requested a geo refresh — do the (blocking) download and
        // rebuild here, off the command thread that asked for it.
        if (force_refresh) {
            force_refresh = false;
            download_db();   // no-op if nothing is selected
            rebuild_geo();   // clears or rebuilds the geo tables as needed
        }

        // Periodic auto-refresh.
        if (opt_auto_update && (sel_country_n > 0 || sel_asn_n > 0) && elapsed >= 3600) {
            elapsed = 0;
            if (db_stale()) {
                download_db();
                rebuild_geo();
            }
        }
    }
    return null;
}

fn void start_background() {
    $if env::WIN32:
        void* h = create_thread_win(null, 0, &background_loop, null, 0, null);
        if (h != null) close_handle_win(h);
    $else
        ulong tid;
        if (pthread_create(&tid, null, &background_loop, null) == 0) pthread_detach(tid);
    $endif
}

// ============================================================
// Commands
// ============================================================
//
// Command handlers run on a client handler thread (inside the server's per-
// client pool), so the temp allocator IS available here — string::tformat is
// safe in these, unlike in the filter / background thread.

fn void send(void* client, String msg) {
    api.client_send_msg(client, msg);
}

fn void cmd_ipban(void* client, String args) {
    String token = first_token(args);
    if (token.len == 0) {
        send(client, "Usage: /ipban <ip|cidr> [note]");
        return;
    }
    ParsedRange r = parse_range(token);
    if (!r.ok) {
        send(client, string::tformat("IP Guard: '%s' is not a valid IP or CIDR.", token));
        return;
    }
    if (live_n >= MAX_LIVE) {
        send(client, "IP Guard: live ban list full — add it to ip_guard.txt and /ipbanreload instead.");
        return;
    }
    // Append, then publish the count last (safe against the accept thread).
    live_tbl[live_n] = { .start = r.start, .end = r.end, .code = 0, .kind = KIND_MANUAL };
    live_n++;
    persist_rule(token);
    send(client, string::tformat("IP Guard: now blocking %s (saved to ip_guard.txt).", token));
    io::printfn("[ip_guard] Live ban added: %s", token);
}

fn void cmd_ipunban(void* client, String args) {
    String token = first_token(args);
    ParsedRange r = parse_range(token);
    if (!r.ok) { send(client, "Usage: /ipunban <ip|cidr>"); return; }
    bool removed = false;
    for (int i = 0; i < live_n; i++) {
        if (addr_eq(live_tbl[i].start, r.start) && addr_eq(live_tbl[i].end, r.end)) {
            for (int j = i; j < live_n - 1; j++) live_tbl[j] = live_tbl[j + 1];
            live_n--;
            removed = true;
            break;
        }
    }
    if (removed) {
        send(client, string::tformat("IP Guard: removed live ban %s. (Rules in ip_guard.txt need a file edit + /ipbanreload.)", token));
    } else {
        send(client, "IP Guard: no matching live /ipban rule. File rules are removed by editing ip_guard.txt + /ipbanreload.");
    }
}

fn void cmd_ipbanlist(void* client, String args) {
    send(client, string::tformat("IP Guard rules — manual:%d allow:%d live:%d | geo country v4:%d v6:%d, asn v4:%d v6:%d",
        manual_n, allow_n, live_n, geo_country4_n, geo_country6_n, geo_asn4_n, geo_asn6_n));
    send(client, string::tformat("Selected: %d country(ies), %d ASN(s). Blocked so far: %d. alerts:%s",
        sel_country_n, sel_asn_n, (int)ring_total, opt_alert_blocked ? "on" : "off"));
}

fn void cmd_ipbanlog(void* client, String args) {
    if (ring_total == 0) { send(client, "IP Guard: no blocked connections recorded yet."); return; }
    ulong show = ring_total < (ulong)RING ? ring_total : (ulong)RING;
    send(client, string::tformat("IP Guard: last %d blocked attempt(s):", (int)show));
    for (ulong k = 0; k < show; k++) {
        ulong idx = ring_total - 1 - k;
        int slot = (int)(idx % (ulong)RING);
        char[96] rb; usz n = put_reason(rb[..], 0, ring[slot].kind, ring[slot].code); rb[n] = 0;
        send(client, string::tformat("  %s  (%s)", cstr(&ring[slot].ip[0]), cstr(&rb[0])));
    }
}

fn void cmd_ipbanreload(void* client, String args) {
    // Re-parse the config file (manual / allow / country / ASN selections +
    // options) here on the command thread. This re-reads ip/cidr/allow rules
    // immediately. The geo DOWNLOAD is handed to the background thread (below)
    // so this command never blocks the mod in curl.
    load_config();

    // Invalidate the cached DB timestamp and ask the background thread to
    // re-download + rebuild the geo tables on its next tick.
    void* f = fopen_c((ZString)&path_marker[0], "w");
    if (f != null) { fputs_c("0", f); fclose_c(f); }
    force_refresh = true;

    if (sel_country_n > 0 || sel_asn_n > 0) {
        send(client, "IP Guard: config reloaded. Refreshing the geo/ASN database in the background — /ipbanlist will show updated counts shortly.");
    } else {
        send(client, "IP Guard: config reloaded.");
    }
}

// First whitespace-delimited token of a raw arg string.
fn String first_token(String args) {
    String s = args.trim();
    usz i = 0;
    while (i < s.len && s[i] != ' ' && s[i] != '\t') i++;
    if (i == 0) return s.len == 0 ? "" : s;
    return s[0..i - 1];
}

// Command handlers run on the server's per-client thread, where this plugin's
// OWN temp allocator is not initialised — so the string::tformat / io::printfn
// calls in the handlers above would panic. These wrappers open a temp-allocator
// scope around each (the approach casing.c3 uses). The connection filter and
// background thread are allocation-free, so only the commands need wrapping.
const usz CMD_POOL = 1024 * 64;
fn void w_ipban(void* c, String a)       { @pool_init(mem, CMD_POOL) { cmd_ipban(c, a); }; }
fn void w_ipunban(void* c, String a)     { @pool_init(mem, CMD_POOL) { cmd_ipunban(c, a); }; }
fn void w_ipbanlist(void* c, String a)   { @pool_init(mem, CMD_POOL) { cmd_ipbanlist(c, a); }; }
fn void w_ipbanlog(void* c, String a)    { @pool_init(mem, CMD_POOL) { cmd_ipbanlog(c, a); }; }
fn void w_ipbanreload(void* c, String a) { @pool_init(mem, CMD_POOL) { cmd_ipbanreload(c, a); }; }

// ============================================================
// Plugin interface (exported)
// ============================================================

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return {
        .name        = "IP Guard",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Block IPs / CIDRs / ASNs / countries at connect time. Optional — see header.",
    };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    opt_running = true;

    // Defaults for the overridable DB URLs.
    copy_cstr(DEF_URL_C4, &cfg_url_c4[0], 511);
    copy_cstr(DEF_URL_C6, &cfg_url_c6[0], 511);
    copy_cstr(DEF_URL_A4, &cfg_url_a4[0], 511);
    copy_cstr(DEF_URL_A6, &cfg_url_a6[0], 511);

    // Resolve the config dir the same way server_advertiser does: prefer
    // ./config, fall back to ../config (when run from out/).
    String dir = "config";
    build_path(&path_config, dir, "ip_guard.txt");
    if (!file_exists(&path_config[0])) {
        String alt = "../config";
        char[512] probe; usz pn = 0;
        pn = put_str(probe[..], pn, alt); pn = put_str(probe[..], pn, "/ip_guard.txt"); probe[pn] = 0;
        if (file_exists(&probe[0])) dir = alt;
        build_path(&path_config, dir, "ip_guard.txt");
    }

    load_config();
    build_paths_and_cmds(dir);

    // Register the accept-time filter (this is the core hook the plugin needs).
    api.register_conn_filter(&conn_filter, PLUGIN_NAME);

    // Register management commands (BAN permission).
    api.register_command("ipban", &w_ipban, PERM_BAN, "Block an IP or CIDR range", PLUGIN_NAME);
    api.register_command("ipunban", &w_ipunban, PERM_BAN, "Remove a live /ipban rule", PLUGIN_NAME);
    api.register_command("ipbanlist", &w_ipbanlist, PERM_BAN, "Show IP Guard rule counts", PLUGIN_NAME);
    api.register_command("ipbanlog", &w_ipbanlog, PERM_BAN, "Show recent blocked connections", PLUGIN_NAME);
    api.register_command("ipbanreload", &w_ipbanreload, PERM_BAN, "Reload config + refresh geo database", PLUGIN_NAME);

    // Geo download/build + alert flushing happen off the hot path.
    start_background();

    io::printfn("[ip_guard] Loaded. Filtering connections (manual:%d allow:%d, %d country/%d ASN selected).",
        manual_n, allow_n, sel_country_n, sel_asn_n);
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    opt_running = false;
    io::printn("[ip_guard] Shutting down. Connection filtering stops on unload.");
}
