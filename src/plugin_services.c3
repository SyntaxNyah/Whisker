// Whisker AO2 Server — Plugin Runtime Services (v8)
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Leaf module holding the three NON-struct mechanisms the v8 PluginAPI block
// adds, kept here (not in the plugin manager) so there is no circular import:
// this module imports nothing from client/server/plugin and refers to a client
// only as an opaque void*, exactly like the v7 outbound-filter registry that
// lives in client.c3.
//
//   1. Key/value store   — a tiny persistent string database every plugin can
//                          share (economy, profiles, streaks) instead of each
//                          re-implementing file I/O. Fixed-size buffers, no heap
//                          allocation, and reads copy into a caller-owned buffer,
//                          so nothing the plugin holds is tied to a temp
//                          allocator across the dlopen boundary (same safety
//                          model as args_split / to_lower).
//
//   2. Event bus         — synchronous publish/subscribe so plugins can compose.
//                          emit_event runs every listener on the caller's thread
//                          (no new thread), so it is the same risk class as the
//                          outbound filter: cleared on /reload so a stale pointer
//                          into an unloaded plugin is never called.
//
//   3. IC message filter — the chat-path counterpart of the v7 OOC outbound
//                          filter. handle_ms runs the IC message (MS field 4)
//                          through these before broadcast, rewriting ONLY that
//                          field so every pairing field is preserved (lossless
//                          censor / translate, unlike consume+rebuild). Cleared
//                          on /reload.
//
// clear_registrations() (called from plugin::unload_all) clears the event and
// IC-filter registries. The KV store deliberately PERSISTS across /reload — it
// is a database, not a hook.

module whisker::plugin_services;

import std::io;
import std::thread;

// C file I/O for KV persistence (mirrors moderation.c3's account persistence).
extern fn void* fopen(char* path, char* mode);
extern fn int   fputs(char* str, void* stream);
extern fn int   fclose(void* stream);

// ============================================================
// 1. Key/value store
// ============================================================
//
// Fixed-capacity, fixed-width entries: no heap allocation anywhere, so a read
// or write is safe from any thread's stack. Keys may not contain '=' or a
// newline; values may not contain a newline (sanitised on write). Persisted to
// <config>/plugin_kv.txt as `key=value` lines on every successful set.

const int KV_MAX_ENTRIES = 256;
const int KV_KEY_MAX     = 64;
const int KV_VAL_MAX     = 512;

struct KvEntry {
    char[KV_KEY_MAX] key;
    int              key_len;
    char[KV_VAL_MAX] val;
    int              val_len;
    bool             used;
}

KvEntry[KV_MAX_ENTRIES] _kv;
char[512]               _kv_path;      // null-terminated path to plugin_kv.txt
int                     _kv_path_len;  // bytes before the null
bool                    _kv_ready;     // init() has run
Mutex                   _kv_lock;      // the store is shared across per-client threads

// Build "<dir>/plugin_kv.txt\0" into _kv_path without the temp allocator (init
// runs on the main thread, but keeping it alloc-free is simplest and harmless).
fn void init(String config_dir) {
    int n = 0;
    foreach (char ch : config_dir) {
        if (n < 480) { _kv_path[n] = ch; n++; }
    }
    String suffix = "/plugin_kv.txt";
    foreach (char ch : suffix) {
        if (n < 500) { _kv_path[n] = ch; n++; }
    }
    _kv_path[n] = 0;
    _kv_path_len = n;

    if (catch _kv_lock.init()) {
        io::printn("[plugin_services] WARNING: KV mutex init failed.");
    }
    for (int i = 0; i < KV_MAX_ENTRIES; i++) _kv[i].used = false;
    _kv_ready = true;
    load_kv();   // init-time, single-threaded — no lock needed
}

// Find the slot index for `key`, or -1.
fn int kv_find(String key) {
    for (int i = 0; i < KV_MAX_ENTRIES; i++) {
        if (!_kv[i].used) continue;
        if (_kv[i].key_len != (int)key.len) continue;
        bool eq = true;
        for (int j = 0; j < _kv[i].key_len; j++) {
            if (_kv[i].key[j] != key[j]) { eq = false; break; }
        }
        if (eq) return i;
    }
    return -1;
}

// Store (or overwrite) a value. Rejects keys with '=' or newline; truncates a
// value at the first newline and to KV_VAL_MAX bytes. Persists on success.
fn void kv_set(String key, String value) {
    if (!_kv_ready) return;
    if (key.len == 0 || key.len > KV_KEY_MAX) return;
    foreach (char ch : key) {
        if (ch == '=' || ch == '\n' || ch == '\r') return; // invalid key
    }
    // Per-client worker threads call this concurrently (e.g. coin_economy on
    // every OOC message), so the array mutation AND the file write (save_kv)
    // must be serialised — two simultaneous fopen("w") on plugin_kv.txt would
    // corrupt it. save_kv runs UNDER this lock and never re-locks.
    _kv_lock.@in_lock() {
        int slot = kv_find(key);
        bool ok = true;
        if (slot < 0) {
            for (int i = 0; i < KV_MAX_ENTRIES; i++) {
                if (!_kv[i].used) { slot = i; break; }
            }
            if (slot < 0) {
                ok = false; // table full
            } else {
                int kn = (int)key.len;
                for (int j = 0; j < kn; j++) _kv[slot].key[j] = key[j];
                _kv[slot].key_len = kn;
                _kv[slot].used = true;
            }
        }
        if (ok) {
            int vn = 0;
            foreach (char ch : value) {
                if (ch == '\n' || ch == '\r') break; // values are single-line
                if (vn >= KV_VAL_MAX) break;
                _kv[slot].val[vn] = ch;
                vn++;
            }
            _kv[slot].val_len = vn;
            save_kv();
        }
    };
}

// Read a value into the caller's buffer. Returns bytes written, or -1 if the key
// is absent. The bytes live in the caller's memory, so there is no lifetime tied
// to this module — the same contract as args_split / to_lower.
fn int kv_get(String key, char* out, int max) {
    if (!_kv_ready || out == null || max <= 0) return -1;
    int result = -1;
    _kv_lock.@in_lock() {
        int slot = kv_find(key);
        if (slot >= 0) {
            int n = _kv[slot].val_len;
            if (n > max) n = max;
            for (int i = 0; i < n; i++) out[i] = _kv[slot].val[i];
            result = n;
        }
    };
    return result;
}

// Remove a key. No-op if absent. Persists.
fn void kv_delete(String key) {
    if (!_kv_ready) return;
    _kv_lock.@in_lock() {
        int slot = kv_find(key);
        if (slot >= 0) {
            _kv[slot].used = false;
            _kv[slot].key_len = 0;
            _kv[slot].val_len = 0;
            save_kv();
        }
    };
}

// Persist the whole table. O(n) per call — fine for AO-volume writes; document
// that kv_set is not for high-frequency hammering.
// Caller MUST hold _kv_lock (kv_set / kv_delete call this under the lock).
fn void save_kv() {
    if (!_kv_ready) return;
    void* f = fopen(&_kv_path[0], "w".ptr);
    if (f == null) return;
    fputs("# Whisker plugin key/value store — managed by the Plugin API.\n".ptr, f);
    fputs("# Format: key=value (one per line).\n".ptr, f);

    char[KV_KEY_MAX + KV_VAL_MAX + 4] line;
    for (int i = 0; i < KV_MAX_ENTRIES; i++) {
        if (!_kv[i].used) continue;
        int p = 0;
        for (int j = 0; j < _kv[i].key_len; j++) { line[p] = _kv[i].key[j]; p++; }
        line[p] = '='; p++;
        for (int j = 0; j < _kv[i].val_len; j++) { line[p] = _kv[i].val[j]; p++; }
        line[p] = '\n'; p++;
        line[p] = 0;
        fputs(&line[0], f);
    }
    fclose(f);
}

// Load the table at startup. Missing file is fine (empty store).
fn void load_kv() {
    String path = (String)_kv_path[0..(usz)_kv_path_len - 1];
    char[]? data = io::file::load(mem, path);
    if (catch data) return;
    if (data.len == 0) return;

    String content = (String)data[0..data.len - 1];
    foreach (line : content.tsplit("\n")) {
        String trimmed = line.trim();
        if (trimmed.len == 0 || trimmed[0] == '#') continue;
        if (try eq = trimmed.index_of_char('=')) {
            String key = trimmed[0..eq - 1];
            String val = trimmed[eq + 1..];
            kv_set_quiet(key, val);
        }
    }
}

// Like kv_set but without re-persisting (used while loading the file).
fn void kv_set_quiet(String key, String value) {
    if (key.len == 0 || key.len > KV_KEY_MAX) return;
    int slot = kv_find(key);
    if (slot < 0) {
        for (int i = 0; i < KV_MAX_ENTRIES; i++) {
            if (!_kv[i].used) { slot = i; break; }
        }
        if (slot < 0) return;
        int kn = (int)key.len;
        for (int j = 0; j < kn; j++) _kv[slot].key[j] = key[j];
        _kv[slot].key_len = kn;
        _kv[slot].used = true;
    }
    int vn = 0;
    foreach (char ch : value) {
        if (vn >= KV_VAL_MAX) break;
        _kv[slot].val[vn] = ch;
        vn++;
    }
    _kv[slot].val_len = vn;
}

// ============================================================
// 2. Event bus (synchronous publish/subscribe)
// ============================================================
//
// register_event_listener subscribes a callback; emit_event fans an event out
// to every listener on the calling thread. No queue, no thread: a listener runs
// inside the emit call, so payload lifetime is the call itself (same as a packet
// hook's pointer). Cleared on /reload.

alias EventListenerFn = fn void(String name, String payload);
const int MAX_EVENT_LISTENERS = 32;
EventListenerFn[MAX_EVENT_LISTENERS] _listeners;
int _listener_count = 0;

fn void register_event_listener(EventListenerFn f) {
    if (f != null && _listener_count < MAX_EVENT_LISTENERS) {
        _listeners[_listener_count] = f;
        _listener_count++;
    }
}

fn void emit_event(String name, String payload) {
    for (int i = 0; i < _listener_count; i++) {
        _listeners[i](name, payload);
    }
}

// ============================================================
// 3. IC message filter (chat-path field-4 rewrite)
// ============================================================
//
// Signature: fn int(void* client, String message, char* out, int max) — write
// the transformed IC message into `out` (up to `max` bytes) and return its byte
// length, or < 0 to leave it unchanged. Must be allocation-free (it runs in the
// MS broadcast path). run_ic_filters chains them with two scratch buffers so a
// filter never reads and writes the same memory, then copies the final result
// into the caller's `out`.

alias IcFilterFn = fn int(void*, String, char*, int);
const int MAX_IC_FILTERS = 8;
const int IC_FILTER_BUF  = 1024;   // IC messages are clamped to 256; room to grow
IcFilterFn[MAX_IC_FILTERS] _ic_filters;
int _ic_filter_count = 0;

fn void register_ic_filter(IcFilterFn f) {
    if (f != null && _ic_filter_count < MAX_IC_FILTERS) {
        _ic_filters[_ic_filter_count] = f;
        _ic_filter_count++;
    }
}

// Run every IC filter over `msg`. Returns the transformed length written to
// `out` (>= 0), or -1 meaning "no change — use the original verbatim" (the
// common case when no filter is registered or all decline, so handle_ms stays
// byte-for-byte identical to pre-v8 behaviour).
fn int run_ic_filters(void* client, String msg, char* out, int max) {
    if (_ic_filter_count == 0) return -1;

    char[IC_FILTER_BUF] buf_a;
    char[IC_FILTER_BUF] buf_b;
    String cur     = msg;
    char*  cur_ptr = null; // buffer `cur` points into (null = original msg)
    bool   changed = false;

    for (int i = 0; i < _ic_filter_count; i++) {
        char* dst = (cur_ptr == &buf_a[0]) ? &buf_b[0] : &buf_a[0];
        int n = _ic_filters[i](client, cur, dst, IC_FILTER_BUF);
        if (n >= 0) {
            if (n > IC_FILTER_BUF) n = IC_FILTER_BUF;
            cur     = n == 0 ? "" : (String)dst[0..n - 1];
            cur_ptr = dst;
            changed = true;
        }
    }

    if (!changed) return -1;
    int len = (int)cur.len;
    if (len > max) len = max;
    for (int i = 0; i < len; i++) out[i] = cur[i];
    return len;
}

// ============================================================
// 4. Timer scheduler (v8) — boot-scoped thread, /reload-safe
// ============================================================
//
// register_timer subscribes a callback fired every `interval_ms`. A SINGLE timer
// thread is started once at server boot (start_timers) and lives for the whole
// process — it is NOT restarted on /reload. The danger a core timer thread poses
// is calling a plugin fn-pointer after the plugin's .dll/.so has been unloaded;
// this design closes it with a mutex:
//
//   * the timer thread holds _timer_lock the entire time it fires due callbacks;
//   * clear_timers() (run from unload_all, before any dlclose) takes the SAME
//     lock, so it blocks until the in-flight tick finishes, then empties the
//     registry. After that no callback can run, and only then does unload_all
//     close the libraries. So a callback is never mid-flight across an unload.
//
// CONSTRAINTS (documented for plugin authors):
//   * The callback runs on the timer thread, which has neither the plugin's nor
//     the server's temp allocator — so it MUST be allocation-free OR wrap its
//     body in @pool_init (the same rule as any hook, but easy to forget because
//     nothing "calls" the timer). The heartbeat example shows the @pool_init form.
//   * A callback must NOT trigger /reload or call register_timer/clear (it runs
//     under _timer_lock, which is non-recursive — that would deadlock).

alias TimerFn = fn void();
const int MAX_TIMERS    = 16;
const int TIMER_TICK_MS = 100;   // scheduler granularity + minimum interval

struct TimerEntry {
    TimerFn callback;
    long    interval_ms;
    long    elapsed_ms;
    bool    used;
}

TimerEntry[MAX_TIMERS] _timers;
Mutex                  _timer_lock;
bool                   _timer_started = false;

fn int timer_thread(void* arg) {
    while (true) {
        thread::sleep_ms(TIMER_TICK_MS);
        _timer_lock.@in_lock() {
            for (int i = 0; i < MAX_TIMERS; i++) {
                if (!_timers[i].used) continue;
                _timers[i].elapsed_ms += TIMER_TICK_MS;
                if (_timers[i].elapsed_ms >= _timers[i].interval_ms) {
                    _timers[i].elapsed_ms = 0;
                    // Set up the SERVER runtime's temp allocator before calling the
                    // plugin — only when a callback actually fires, not every tick.
                    // The server .exe and a plugin .dll statically link SEPARATE C3
                    // runtimes (separate thread-local temps); worker threads get the
                    // server temp from the client loop, but this thread is
                    // core-spawned, so without this any server-side API the callback
                    // calls (broadcast/build → dstring::temp) panics. The plugin is
                    // still responsible for ITS own temp via @pool_init in the callback.
                    @pool_init(mem, 256 * 1024) {
                        _timers[i].callback();   // fired UNDER the lock — clear_timers() waits
                    };
                }
            }
        };
    }
}

// Start the single timer thread. Called once at boot, before plugins load, so
// _timer_lock is initialised before any register_timer call. Safe to call again
// (no-op once started).
fn void start_timers() {
    if (_timer_started) return;
    if (catch _timer_lock.init()) {
        io::printn("[plugin_services] WARNING: timer mutex init failed; register_timer disabled.");
        return;
    }
    Thread t;
    if (catch t.create(&timer_thread, null)) {
        io::printn("[plugin_services] WARNING: timer thread failed to start; register_timer disabled.");
        return;
    }
    (void)t.detach();
    _timer_started = true;
    io::printn("[plugin_services] Timer scheduler started.");
}

fn void register_timer(int interval_ms, TimerFn f) {
    if (!_timer_started || f == null) return;
    if (interval_ms < TIMER_TICK_MS) interval_ms = TIMER_TICK_MS;
    _timer_lock.@in_lock() {
        for (int i = 0; i < MAX_TIMERS; i++) {
            if (!_timers[i].used) {
                _timers[i] = { .callback = f, .interval_ms = (long)interval_ms, .elapsed_ms = 0, .used = true };
                break;
            }
        }
    };
}

// Clear all timers under the lock — blocks until any in-flight tick finishes, so
// after this returns no timer callback can run. Called from clear_registrations.
fn void clear_timers() {
    if (!_timer_started) return;
    _timer_lock.@in_lock() {
        for (int i = 0; i < MAX_TIMERS; i++) _timers[i].used = false;
    };
}

// ============================================================
// Reload hygiene
// ============================================================
//
// Called from plugin::unload_all BEFORE the libraries are closed, so no event
// listener, IC filter, or timer pointing into an unloaded plugin is ever called
// after a /reload. The KV store is intentionally left intact — it is persistent
// state. (Event/IC registries are cleared unlocked, matching the v7 outbound
// filter; the timer is cleared UNDER its lock because a core thread fires it
// continuously and is far more likely to be mid-call during a reload.)

fn void clear_registrations() {
    _listener_count   = 0;
    _ic_filter_count  = 0;
    clear_timers();
}
