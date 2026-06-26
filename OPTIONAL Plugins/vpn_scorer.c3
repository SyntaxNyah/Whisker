// Whisker Optional Plugin — VPN / Proxy Scorer [Standalone]
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Flags connections that come from known VPN / proxy / datacenter IP ranges and
// quietly tells your staff — WITHOUT blocking anyone. It is the same shape as
// `tor_blocker` (a v4 connection filter that runs at accept time against
// downloaded IP-range lists), but it never closes the socket: it just records a
// hit and posts a coalesced staff alert. Use it to KNOW who's behind a VPN, then
// decide case-by-case, instead of bluntly turning everyone away. Drop the
// compiled .dll / .so into plugins/ and restart. Optional.
//
// This source file is provided as a learning exercise. To compile a C3 plugin
// yourself, follow the Plugin Dev Guide: plugins/PLUGIN DEV GUIDE README.md
//
// ============================================================
// What it does, and why "no performance degradation"
// ============================================================
//
// On first run it downloads one or more public VPN/datacenter IP-range lists with
// curl on a background thread (default: the public-domain X4BNet VPN list — no key,
// nothing to install), caches them next to your config, and refreshes them on a
// timer. For every inbound connection the filter does an O(log n) binary search
// over the sorted ranges — a handful of comparisons even across hundreds of
// thousands of ranges — and ALWAYS allows the connection (returns false). It never
// downloads, allocates, or broadcasts on the accept path; the download and the
// (coalesced, timer-driven) staff alerts run on the background thread. So you can
// point it at a "shit ton of databases" and the connect path stays flat.
//
// ============================================================
// Why this is an OPTIONAL plugin
// ============================================================
//
// Knowing a player is on a VPN is *information*, not a verdict — many legitimate
// people use VPNs for privacy. This plugin deliberately does NOT act on that; it
// just surfaces it to staff, who can pair it with the real tools (`/ban`,
// `ip_guard`, `tor_blocker`, `lockdown`) when there's actual abuse. Servers that
// don't care never load it. Treat the score as a hint, expect false positives
// (residential IPs sometimes land in datacenter ranges), and use the `allow` list
// for known-good addresses.

module vpn_scorer;

import std::io;

// ============================================================
// Whisker plugin interface (standalone) — v4 prefix (copied from tor_blocker).
// ============================================================

struct PluginInfo { String name; String version; String author; String description; }

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
alias LifecycleHook           = fn void(void*, int);
alias RegisterLifecycleHookFn = fn void(LifecycleHook, String);
alias ClientGetOocNameFn      = fn String(void*);
alias ClientIsHiddenFn        = fn bool(void*);
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
    RegisterLifecycleHookFn register_lifecycle_hook;
    ClientGetOocNameFn      client_get_ooc_name;
    ClientIsHiddenFn        client_is_hidden;
    ClientGetIpFn         client_get_ip;
    RegisterConnFilterFn  register_conn_filter;
    BroadcastPermRawFn    broadcast_perm_raw;
}

// ============================================================
// C interop (file I/O, curl, threads, sleep, time) — libc directly so it is safe
// on any thread, including the raw background thread with no C3 runtime.
// ============================================================

extern fn CInt puts(ZString s);
extern fn CInt system(ZString cmd);
extern fn CInt fflush(void* stream);

fn void bg_log(ZString s) { puts(s); fflush(null); }

extern fn void* fopen_c(ZString path, ZString mode) @cname("fopen");
extern fn char* fgets_c(char* buf, CInt size, void* stream) @cname("fgets");
extern fn CInt  fclose_c(void* stream) @cname("fclose");
extern fn CInt  fputs_c(ZString s, void* stream) @cname("fputs");
extern fn long  time_c(void* t) @cname("time");

extern fn uint posix_sleep(uint seconds) @cname("sleep") @if(!env::WIN32);
extern fn void win_sleep(uint milliseconds) @cname("Sleep") @if(env::WIN32);

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

// ============================================================
// Constants & limits
// ============================================================

const String PLUGIN_NAME = "VPN Scorer";
const ulong  PERM_BAN    = 4;

const int MAX_VPN    = 300000; // downloaded range entries
const int MAX_MANUAL = 4096;   // manual `flag` rules from config
const int MAX_ALLOW  = 4096;   // `allow` exceptions from config
const int MAX_LISTS  = 8;      // distinct feed URLs
const int RING       = 64;     // recent-flagged ring buffer

const ulong V4_MAP = 0x0000_FFFF_0000_0000;

// Public-domain VPN range list (CIDR per line), no key. Operators can add more
// feeds (datacenter, proxy, abuse) with extra `feed <url>` lines.
const String DEFAULT_FEED = "https://raw.githubusercontent.com/X4BNet/lists_vpn/main/output/vpn/ipv4.txt";

// ============================================================
// Address & range types (unified 128-bit; IPv4 stored v4-mapped)
// ============================================================

struct Addr { ulong hi; ulong lo; }
struct Range { Addr start; Addr end; }

fn bool addr_le(Addr a, Addr b) {
    if (a.hi != b.hi) return a.hi < b.hi;
    return a.lo <= b.lo;
}
fn bool addr_eq(Addr a, Addr b) { return a.hi == b.hi && a.lo == b.lo; }
fn Addr addr_inc(Addr a) {
    Addr r = a;
    if (r.lo == 0xFFFFFFFFFFFFFFFF) { r.lo = 0; r.hi++; } else { r.lo++; }
    return r;
}

// ============================================================
// Tables (lockless; publish-last discipline)
// ============================================================

Range[MAX_ALLOW]  allow_tbl;  int allow_n;
Range[MAX_MANUAL] manual_tbl; int manual_n;
Range[MAX_VPN]    vpn_tbl;    int vpn_n;

char[512][MAX_LISTS]  list_url;
char[512][MAX_LISTS]  list_cache;
char[1024][MAX_LISTS] list_cmd;
int list_n;

char[512] path_config;
char[512] path_marker;

// ============================================================
// Options
// ============================================================

PluginAPI* api;

bool  opt_alerts          = true;      // post staff alerts (this is the point)
ulong opt_alert_permission = PERM_BAN;
uint  opt_alert_interval   = 30;
bool  opt_score_unknown    = false;    // also flag IPs that can't be parsed
bool  opt_auto_update      = true;
uint  opt_update_hours     = 24;       // VPN ranges churn slowly
bool  opt_running          = true;
bool  force_refresh        = false;

String cfg_dir;

// ============================================================
// Flagged-attempt ring (coalesced alerts + /vpnlog)
// ============================================================

struct Hit { char[48] ip; }
Hit[RING] ring;
ulong ring_total;
ulong ring_reported;

// ============================================================
// Small string helpers
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
fn bool is_true(String s) { return s == "true" || s == "1" || s == "yes" || s == "on"; }
fn ulong parse_ulong(String s) {
    ulong v = 0;
    foreach (char ch : s) { if (ch >= '0' && ch <= '9') v = v * 10 + (ulong)(ch - '0'); }
    return v;
}
fn String first_token(String args) {
    String s = args.trim();
    usz i = 0;
    while (i < s.len && s[i] != ' ' && s[i] != '\t') i++;
    if (i == 0) return s.len == 0 ? "" : s;
    return s[0..i - 1];
}

// ============================================================
// IP / CIDR parsing (unified 128-bit). Lifted from ip_guard / tor_blocker.
// ============================================================

struct ParsedIp { bool ok; bool is_v4; Addr addr; }

fn bool parse_v4(String s, uint* out) {
    uint result = 0; int parts = 0; int val = 0; bool have_digit = false;
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
            val = 0; have_digit = false;
        } else { return false; }
    }
    if (!have_digit || parts != 3) return false;
    result = (result << 8) | (uint)val;
    *out = result;
    return true;
}

fn Addr v4_to_addr(uint v) { return { .hi = 0, .lo = V4_MAP | (ulong)v }; }

fn int hex_val(char ch) {
    if (ch >= '0' && ch <= '9') return ch - '0';
    if (ch >= 'a' && ch <= 'f') return ch - 'a' + 10;
    if (ch >= 'A' && ch <= 'F') return ch - 'A' + 10;
    return -1;
}

fn bool parse_v6_groups(String s, ushort[8]* dst, int start, int* count) {
    int g = start; int val = 0; int digits = 0;
    foreach (char ch : s) {
        int d = hex_val(ch);
        if (d >= 0) {
            val = (val << 4) | d; digits++;
            if (digits > 4) return false;
        } else if (ch == ':') {
            if (digits == 0) return false;
            if (g >= 8) return false;
            (*dst)[g] = (ushort)val; g++; val = 0; digits = 0;
        } else { return false; }
    }
    if (digits == 0) return false;
    if (g >= 8) return false;
    (*dst)[g] = (ushort)val; g++;
    *count = g - start;
    return true;
}

fn bool parse_v6(String s, Addr* out) {
    ushort[8] groups;
    for (int i = 0; i < 8; i++) groups[i] = 0;

    int dcolon = -1;
    for (usz i = 0; i + 1 < s.len; i++) {
        if (s[i] == ':' && s[i + 1] == ':') { dcolon = (int)i; break; }
    }

    if (dcolon < 0) {
        int g = 0;
        if (!parse_v6_groups(s, &groups, 0, &g)) return false;
        if (g != 8) return false;
    } else {
        String left = s[0..(usz)dcolon == 0 ? 0 : (usz)dcolon - 1];
        if (dcolon == 0) left = "";
        usz rstart = (usz)dcolon + 2;
        String right = rstart <= s.len ? (rstart == s.len ? "" : s[rstart..]) : "";

        int gl = 0; int gr = 0;
        ushort[8] lg; ushort[8] rg;
        for (int i = 0; i < 8; i++) { lg[i] = 0; rg[i] = 0; }
        if (left.len  > 0 && !parse_v6_groups(left,  &lg, 0, &gl)) return false;
        if (right.len > 0 && !parse_v6_groups(right, &rg, 0, &gr)) return false;
        if (gl + gr > 7) return false;

        for (int i = 0; i < gl; i++) groups[i] = lg[i];
        for (int i = 0; i < gr; i++) groups[8 - gr + i] = rg[i];
    }

    ulong hi = 0; ulong lo = 0;
    for (int i = 0; i < 4; i++) hi = (hi << 16) | (ulong)groups[i];
    for (int i = 4; i < 8; i++) lo = (lo << 16) | (ulong)groups[i];
    *out = { .hi = hi, .lo = lo };
    return true;
}

fn ParsedIp parse_ip(String s) {
    ParsedIp p; p.ok = false;
    if (s.len == 0) return p;
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

fn Addr mask_from_prefix(int bits) {
    Addr m;
    if (bits <= 0) { m.hi = 0; m.lo = 0; return m; }
    if (bits >= 128) { m.hi = 0xFFFFFFFFFFFFFFFF; m.lo = 0xFFFFFFFFFFFFFFFF; return m; }
    if (bits == 64) { m.hi = 0xFFFFFFFFFFFFFFFF; m.lo = 0; return m; }
    if (bits < 64) { m.hi = 0xFFFFFFFFFFFFFFFF << (64 - bits); m.lo = 0; }
    else { m.hi = 0xFFFFFFFFFFFFFFFF; m.lo = 0xFFFFFFFFFFFFFFFF << (128 - bits); }
    return m;
}

struct ParsedRange { bool ok; Addr start; Addr end; }

fn ParsedRange parse_range(String s) {
    ParsedRange r; r.ok = false;

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
        int bits = ip.is_v4 ? 96 + prefix : prefix;
        Addr mask = mask_from_prefix(bits);
        r.start = { .hi = ip.addr.hi & mask.hi, .lo = ip.addr.lo & mask.lo };
        r.end   = { .hi = ip.addr.hi | ~mask.hi, .lo = ip.addr.lo | ~mask.lo };
        r.ok = true;
        return r;
    }

    ParsedIp ip = parse_ip(s);
    if (!ip.ok) return r;
    r.start = ip.addr; r.end = ip.addr; r.ok = true;
    return r;
}

fn ParsedRange parse_any_token(String row) {
    String s = row.trim();
    while (s.len > 0) {
        usz i = 0;
        while (i < s.len && s[i] != ' ' && s[i] != '\t') i++;
        String tok = s[0..i - 1];
        ParsedRange r = parse_range(tok);
        if (r.ok) return r;
        while (i < s.len && (s[i] == ' ' || s[i] == '\t')) i++;
        s = i < s.len ? s[i..] : "";
    }
    ParsedRange none; none.ok = false; return none;
}

// ============================================================
// Table search & build
// ============================================================

fn int table_find(Range* tbl, int n, Addr a) {
    int lo = 0; int hi = n - 1; int found = -1;
    while (lo <= hi) {
        int mid = (lo + hi) / 2;
        if (addr_le(tbl[mid].start, a)) { found = mid; lo = mid + 1; }
        else { hi = mid - 1; }
    }
    if (found < 0) return -1;
    if (addr_le(a, tbl[found].end)) return found;
    return -1;
}

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
        if (addr_le(tbl[i].start, tbl[w].end) || addr_le(tbl[i].start, addr_inc(tbl[w].end))) {
            if (!addr_le(tbl[i].end, tbl[w].end)) tbl[w].end = tbl[i].end;
        } else {
            w++; tbl[w] = tbl[i];
        }
    }
    return w + 1;
}

fn void add_to(Range* tbl, int* n, int cap, ParsedRange r) {
    if (*n >= cap) return;
    tbl[*n] = { .start = r.start, .end = r.end };
    (*n)++;
}

// ============================================================
// The connection filter — accept thread, allocation-free, NEVER blocks.
// Records a hit (for the staff alert) when the IP is in a flagged range, then
// always returns false so the connection proceeds.
// ============================================================

fn void record_hit(String ip) {
    int slot = (int)(ring_total % (ulong)RING);
    copy_cstr(ip, &ring[slot].ip[0], 47);
    ring_total++;
}

fn bool conn_filter(String ip) {
    ParsedIp p = parse_ip(ip);
    if (!p.ok) {
        if (opt_score_unknown) record_hit(ip);
        return false;
    }
    if (table_find(&allow_tbl[0], allow_n, p.addr) >= 0) return false;     // excepted — don't flag
    if (table_find(&manual_tbl[0], manual_n, p.addr) >= 0) { record_hit(ip); return false; }
    int n = vpn_n;                                                          // publish-last read
    if (table_find(&vpn_tbl[0], n, p.addr) >= 0) { record_hit(ip); }
    return false;                                                          // never block
}

// ============================================================
// Config file (config/vpn_scorer.txt)
// ============================================================

fn void load_config() {
    allow_n = 0; manual_n = 0; list_n = 0;

    void* f = fopen_c((ZString)&path_config[0], "r");
    if (f == null) {
        io::printn("[vpn_scorer] No vpn_scorer.txt found — writing a template; using the default VPN feed.");
        write_template();
    } else {
        char[1024] line;
        while (fgets_c(&line[0], 1024, f) != null) {
            String raw = cstr(&line[0]).trim();
            if (raw.len == 0 || raw[0] == '#') continue;
            parse_config_line(raw);
        }
        fclose_c(f);
    }

    if (list_n == 0) { copy_cstr(DEFAULT_FEED, &list_url[0][0], 511); list_n = 1; }

    manual_n = sort_and_merge(&manual_tbl[0], manual_n);
    allow_n  = sort_and_merge(&allow_tbl[0], allow_n);

    io::printfn("[vpn_scorer] Config: %d feed URL(s), %d manual flag(s), %d allow(s).",
        list_n, manual_n, allow_n);
}

fn void parse_config_line(String raw) {
    usz sp = 0;
    while (sp < raw.len && raw[sp] != ' ' && raw[sp] != '\t') sp++;
    String key = sp == 0 ? raw : raw[0..sp - 1];
    String rest = sp < raw.len ? raw[sp..].trim() : "";

    if (key == "feed" || key == "list") {
        if (rest.len > 0 && list_n < MAX_LISTS) { copy_cstr(rest, &list_url[list_n][0], 511); list_n++; }
        return;
    }
    if (key == "flag" || key == "ip" || key == "cidr") {
        ParsedRange r = parse_range(rest);
        if (r.ok) add_to(&manual_tbl[0], &manual_n, MAX_MANUAL, r);
        return;
    }
    if (key == "allow") {
        ParsedRange r = parse_range(rest);
        if (r.ok) add_to(&allow_tbl[0], &allow_n, MAX_ALLOW, r);
        return;
    }
    if (key == "alerts")              { opt_alerts = is_true(rest); return; }
    if (key == "alert_permission")    { opt_alert_permission = parse_ulong(rest); return; }
    if (key == "alert_interval_sec")  { uint v = (uint)parse_ulong(rest); if (v > 0) opt_alert_interval = v; return; }
    if (key == "score_unknown")       { opt_score_unknown = is_true(rest); return; }
    if (key == "auto_update")         { opt_auto_update = is_true(rest); return; }
    if (key == "update_interval_hours") { uint v = (uint)parse_ulong(rest); if (v > 0) opt_update_hours = v; return; }

    ParsedRange r = parse_range(raw);
    if (r.ok) add_to(&manual_tbl[0], &manual_n, MAX_MANUAL, r);
}

fn void write_template() {
    void* f = fopen_c((ZString)&path_config[0], "w");
    if (f == null) return;
    fputs_c("# Whisker VPN Scorer — flag (never block) connections from VPN/proxy ranges\n", f);
    fputs_c("# One rule per line. '#' starts a comment. Reload with /vpnreload.\n", f);
    fputs_c("#\n", f);
    fputs_c("# By default the public X4BNet VPN list is used. Add `feed` lines for more\n", f);
    fputs_c("# range lists (datacenter / proxy / abuse). Each feed is plain text, one IP\n", f);
    fputs_c("# or CIDR per line.\n", f);
    fputs_c("#\n", f);
    fputs_c("# feed   https://raw.githubusercontent.com/X4BNet/lists_vpn/main/output/vpn/ipv4.txt\n", f);
    fputs_c("# feed   https://raw.githubusercontent.com/X4BNet/lists_vpn/main/output/datacenter/ipv4.txt\n", f);
    fputs_c("# allow  203.0.113.10        # never flag this address (wins)\n", f);
    fputs_c("# flag   198.51.100.0/24     # always flag this range (manual)\n", f);
    fputs_c("#\n", f);
    fputs_c("# --- options ---\n", f);
    fputs_c("# alerts               true    # post a staff OOC alert on a flagged join\n", f);
    fputs_c("# alert_permission     4       # which permission bit sees alerts (4 = ban)\n", f);
    fputs_c("# alert_interval_sec   30      # coalesce alerts over this many seconds\n", f);
    fputs_c("# score_unknown        false   # also flag IPs that can't be parsed\n", f);
    fputs_c("# auto_update          true    # periodically re-download the feed(s)\n", f);
    fputs_c("# update_interval_hours 24     # how often to refresh\n", f);
    fclose_c(f);
}

fn void persist_allow(String token) {
    void* f = fopen_c((ZString)&path_config[0], "a");
    if (f == null) return;
    char[600] buf; usz n = 0;
    n = put_str(buf[..], n, "allow ");
    n = put_str(buf[..], n, token);
    n = put_str(buf[..], n, "\n");
    buf[n] = 0;
    fputs_c((ZString)&buf[0], f);
    fclose_c(f);
}

// ============================================================
// Download (curl) + parse
// ============================================================

fn void build_path(char[512]* dst, String dir, String name) {
    usz n = 0;
    n = put_str((*dst)[..], n, dir);
    n = put_str((*dst)[..], n, "/");
    n = put_str((*dst)[..], n, name);
    (*dst)[n] = 0;
}

fn void build_curl(char[1024]* dst, String url, char* out_path) {
    usz n = 0;
    n = put_str((*dst)[..], n, "curl -sL --fail --max-time 120 -o \"");
    n = put_str((*dst)[..], n, cstr(out_path));
    n = put_str((*dst)[..], n, "\" \"");
    n = put_str((*dst)[..], n, url);
    n = put_str((*dst)[..], n, "\"");
    $if env::WIN32:
        n = put_str((*dst)[..], n, " >nul 2>&1");
    $else
        n = put_str((*dst)[..], n, " >/dev/null 2>&1");
    $endif
    (*dst)[n] = 0;
}

fn void build_paths_and_cmds(String dir) {
    build_path(&path_marker, dir, "vpn_scorer_dbtime.txt");
    for (int i = 0; i < list_n; i++) {
        char[40] name; usz nn = 0;
        nn = put_str(name[..], nn, "vpn_scorer_feed_");
        nn = put_uint(name[..], nn, (ulong)i);
        nn = put_str(name[..], nn, ".txt");
        name[nn] = 0;
        build_path(&list_cache[i], dir, cstr(&name[0]));
        build_curl(&list_cmd[i], cstr(&list_url[i][0]), &list_cache[i][0]);
    }
}

fn bool file_exists(char* path) {
    void* f = fopen_c((ZString)path, "r");
    if (f == null) return false;
    fclose_c(f);
    return true;
}

fn bool db_stale() {
    if (!file_exists(&path_marker[0])) return true;
    void* f = fopen_c((ZString)&path_marker[0], "r");
    if (f == null) return true;
    char[64] buf; long saved = 0;
    if (fgets_c(&buf[0], 64, f) != null) saved = (long)parse_ulong(cstr(&buf[0]));
    fclose_c(f);
    long age = time_c(null) - saved;
    return age > (long)opt_update_hours * 3600;
}

fn void mark_db_time() {
    void* f = fopen_c((ZString)&path_marker[0], "w");
    if (f == null) return;
    char[32] buf; usz n = put_uint(buf[..], 0, (ulong)time_c(null)); buf[n] = 0;
    fputs_c((ZString)&buf[0], f);
    fclose_c(f);
}

fn void download_lists() {
    if (list_n == 0) return;
    bool ok = true;
    bg_log("[vpn_scorer] Downloading VPN range feed(s)...");
    for (int i = 0; i < list_n; i++) {
        if (system((ZString)&list_cmd[i][0]) != 0) {
            ok = false;
            bg_log("[vpn_scorer] WARNING: a feed download failed (using last cached copy if present).");
        }
    }
    if (ok) { mark_db_time(); bg_log("[vpn_scorer] Feed(s) downloaded."); }
    else    { bg_log("[vpn_scorer] Feed refresh incomplete — check curl is installed and the URLs are reachable."); }
}

fn void rebuild_vpn() {
    vpn_n = 0;
    int k = 0;
    for (int i = 0; i < list_n; i++) {
        void* f = fopen_c((ZString)&list_cache[i][0], "r");
        if (f == null) continue;
        char[256] line;
        while (fgets_c(&line[0], 256, f) != null && k < MAX_VPN) {
            String row = cstr(&line[0]).trim();
            if (row.len == 0 || row[0] == '#') continue;
            ParsedRange r = parse_any_token(row);
            if (r.ok) { vpn_tbl[k] = { .start = r.start, .end = r.end }; k++; }
        }
        fclose_c(f);
    }
    int merged = sort_and_merge(&vpn_tbl[0], k);
    vpn_n = merged; // publish

    char[96] msg; usz n = 0;
    n = put_str(msg[..], n, "[vpn_scorer] VPN ranges active: ");
    n = put_uint(msg[..], n, (ulong)vpn_n);
    n = put_str(msg[..], n, ".");
    msg[n] = 0;
    bg_log((ZString)&msg[0]);
}

// ============================================================
// Staff alerts (coalesced, off the accept path)
// ============================================================

fn void broadcast_ct(String message) {
    char[512] buf; usz n = 0;
    n = put_str(buf[..], n, "CT#");
    n = put_escaped(buf[..], n, PLUGIN_NAME);
    n = put_str(buf[..], n, "#");
    n = put_escaped(buf[..], n, message);
    n = put_str(buf[..], n, "#1#%");
    api.broadcast_perm_raw((String)buf[0..n - 1], opt_alert_permission);
}

fn void flush_alerts() {
    if (!opt_alerts) { ring_reported = ring_total; return; }
    ulong total = ring_total;
    if (total <= ring_reported) return;
    ulong delta = total - ring_reported;
    ring_reported = total;

    int latest = (int)((total - 1) % (ulong)RING);

    char[256] msg; usz n = 0;
    n = put_str(msg[..], n, "[VPN Scorer] ");
    n = put_uint(msg[..], n, delta);
    n = put_str(msg[..], n, delta == 1 ? " connection flagged (VPN/proxy) — " : " connections flagged (VPN/proxy) — latest ");
    n = put_str(msg[..], n, cstr(&ring[latest].ip[0]));
    n = put_str(msg[..], n, " — allowed, not blocked.");
    broadcast_ct((String)msg[0..n - 1]);
}

// ============================================================
// Background thread
// ============================================================

fn void* background_loop(void* arg) {
    sleep_sec(3);

    if (list_n > 0) {
        if (db_stale()) { download_lists(); }
        else { bg_log("[vpn_scorer] Using cached feed(s)."); }
        rebuild_vpn();
    }

    uint elapsed = 0;
    while (opt_running) {
        sleep_sec(opt_alert_interval);
        elapsed += opt_alert_interval;
        flush_alerts();

        if (force_refresh) {
            force_refresh = false;
            download_lists();
            rebuild_vpn();
        }
        if (opt_auto_update && list_n > 0 && elapsed >= 3600) {
            elapsed = 0;
            if (db_stale()) { download_lists(); rebuild_vpn(); }
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
// Commands (BAN permission)
// ============================================================

fn void send(void* client, String msg) { api.client_send_msg(client, msg); }

fn void cmd_vpnstatus(void* client, String args) {
    long age = -1;
    if (file_exists(&path_marker[0])) {
        void* f = fopen_c((ZString)&path_marker[0], "r");
        if (f != null) {
            char[64] buf; long saved = 0;
            if (fgets_c(&buf[0], 64, f) != null) saved = (long)parse_ulong(cstr(&buf[0]));
            fclose_c(f);
            age = time_c(null) - saved;
        }
    }
    send(client, string::tformat("VPN Scorer — feeds:%d vpn ranges:%d manual:%d allow:%d",
        list_n, vpn_n, manual_n, allow_n));
    if (age < 0) {
        send(client, string::tformat("Not downloaded yet. Flagged so far: %d. alerts:%s",
            (int)ring_total, opt_alerts ? "on" : "off"));
    } else {
        send(client, string::tformat("Last refresh: %d min ago (every %d h). Flagged so far: %d. alerts:%s",
            (int)(age / 60), opt_update_hours, (int)ring_total, opt_alerts ? "on" : "off"));
    }
}

fn void cmd_vpnreload(void* client, String args) {
    load_config();
    build_paths_and_cmds(cfg_dir);
    void* f = fopen_c((ZString)&path_marker[0], "w");
    if (f != null) { fputs_c("0", f); fclose_c(f); }
    force_refresh = true;
    send(client, "VPN Scorer: config reloaded. Re-downloading feed(s) in the background — /vpnstatus shows progress.");
}

fn void cmd_vpnlog(void* client, String args) {
    if (ring_total == 0) { send(client, "VPN Scorer: nothing flagged yet."); return; }
    ulong show = ring_total < (ulong)RING ? ring_total : (ulong)RING;
    send(client, string::tformat("VPN Scorer: last %d flagged connection(s):", (int)show));
    for (ulong k = 0; k < show; k++) {
        ulong idx = ring_total - 1 - k;
        int slot = (int)(idx % (ulong)RING);
        send(client, string::tformat("  %s", cstr(&ring[slot].ip[0])));
    }
}

fn void cmd_vpnallow(void* client, String args) {
    String token = first_token(args);
    if (token.len == 0) { send(client, "Usage: /vpnallow <ip|cidr>  (stop flagging this address/range)"); return; }
    ParsedRange r = parse_range(token);
    if (!r.ok) { send(client, string::tformat("VPN Scorer: '%s' is not a valid IP or CIDR.", token)); return; }
    if (allow_n >= MAX_ALLOW) { send(client, "VPN Scorer: allow list full — edit vpn_scorer.txt + /vpnreload."); return; }
    allow_tbl[allow_n] = { .start = r.start, .end = r.end };
    allow_n++;
    allow_n = sort_and_merge(&allow_tbl[0], allow_n);
    persist_allow(token);
    send(client, string::tformat("VPN Scorer: %s will no longer be flagged (saved to vpn_scorer.txt).", token));
}

const usz CMD_POOL = 1024 * 64;
fn void w_vpnstatus(void* c, String a) { @pool_init(mem, CMD_POOL) { cmd_vpnstatus(c, a); }; }
fn void w_vpnreload(void* c, String a) { @pool_init(mem, CMD_POOL) { cmd_vpnreload(c, a); }; }
fn void w_vpnlog(void* c, String a)    { @pool_init(mem, CMD_POOL) { cmd_vpnlog(c, a); }; }
fn void w_vpnallow(void* c, String a)  { @pool_init(mem, CMD_POOL) { cmd_vpnallow(c, a); }; }

// ============================================================
// Plugin interface (exported)
// ============================================================

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return {
        .name        = "VPN Scorer",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Flag (never block) VPN/proxy connections to staff. Optional — see header.",
    };
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    opt_running = true;

    String dir = "config";
    build_path(&path_config, dir, "vpn_scorer.txt");
    if (!file_exists(&path_config[0])) {
        char[512] probe; usz pn = 0;
        pn = put_str(probe[..], pn, "../config/vpn_scorer.txt"); probe[pn] = 0;
        char[512] probe_dir; usz dn = 0;
        dn = put_str(probe_dir[..], dn, "../config/config.toml"); probe_dir[dn] = 0;
        if (file_exists(&probe[0]) || file_exists(&probe_dir[0])) dir = "../config";
        build_path(&path_config, dir, "vpn_scorer.txt");
    }
    cfg_dir = dir;

    load_config();
    build_paths_and_cmds(dir);

    api.register_conn_filter(&conn_filter, PLUGIN_NAME);

    api.register_command("vpnstatus", &w_vpnstatus, PERM_BAN, "Show VPN Scorer status/counts", PLUGIN_NAME);
    api.register_command("vpnreload", &w_vpnreload, PERM_BAN, "Reload config + re-download feeds", PLUGIN_NAME);
    api.register_command("vpnlog", &w_vpnlog, PERM_BAN, "Show recent flagged connections", PLUGIN_NAME);
    api.register_command("vpnallow", &w_vpnallow, PERM_BAN, "Stop flagging an IP/CIDR", PLUGIN_NAME);

    start_background();

    io::printfn("[vpn_scorer] Loaded. Scoring connections (%d feed URL(s), manual:%d allow:%d). Downloading in background.",
        list_n, manual_n, allow_n);
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    opt_running = false;
    io::printn("[vpn_scorer] Shutting down. Scoring stops on unload.");
}
