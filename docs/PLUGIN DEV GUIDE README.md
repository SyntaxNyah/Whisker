# Whisker Plugin Development Guide

This guide explains how to create plugins for the Whisker AO2 server.

## Why Plugins?

The AO community has suffered from server fragmentation — dozens of forks
that diverge and become unmaintainable. Whisker's plugin system is designed
to solve this: extend the server without modifying core code.

Want to add custom moderation commands? A casino system? A Discord bot bridge?
Write a plugin. Ship it separately. Everyone benefits.

## Quick Start

### 1. Create a new C3 project for your plugin

```bash
c3c init my_plugin --template dynamic-lib
```

### 2. Implement the plugin interface

Your plugin must export three functions with C-compatible signatures.

**Important:** Handler functions use `void*` for client and packet parameters — this
is required for ABI compatibility with the server's function pointer types. Use the
`PluginAPI` function pointers to interact with clients (e.g., `api.client_send_msg`).

```c3
module my_plugin;

import whisker::plugin;
import std::io;

// Called by Whisker to get plugin metadata
fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return plugin::PluginInfo {
        .name        = "My Plugin",
        .version     = "1.0.0",
        .author      = "Your Name",
        .description = "Does cool stuff",
    };
}

plugin::PluginAPI* api;

// Called once at server startup
fn bool whisker_plugin_init(plugin::PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;

    // Register commands
    api.register_command(
        "hello",                    // command name (without /)
        &cmd_hello,                 // handler function
        0,                          // required permissions (0 = anyone)
        "Says hello",               // description
        "My Plugin"                 // plugin name
    );

    // Register packet hooks
    api.register_hook(
        "MS",                       // packet header to hook
        &on_ic_message,             // hook function
        "My Plugin"                 // plugin name
    );

    return true; // return false to abort loading
}

// Called on server shutdown
fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {
    // Cleanup resources
}

// ---- Your command handlers ----
// Parameters are void* — use the PluginAPI to interact with clients

fn void cmd_hello(void* c, String args) {
    api.client_send_msg(c, "Hello from My Plugin!");
}

// ---- Your packet hooks ----
// Return true to consume the packet (stop further processing)
// Return false to let other hooks and the default handler run

fn bool on_ic_message(void* c, void* pkt) {
    // Example: log all IC messages
    io::printfn("[my_plugin] IC message from UID %d", api.client_get_uid(c));
    // Return false so the message still gets processed normally
    return false;
}
```

### 3. Set up `project.json`

Create a `project.json` in your plugin's directory:

```json
{
    "version": "1.0.0",
    "authors": ["Your Name"],
    "langrev": "1",
    "warnings": ["no-unused"],
    "targets": {
        "my_plugin": {
            "type": "dynamic-lib",
            "sources-override": ["../my_plugin.c3"],
            "linked-libraries": ["c"]
        }
    }
}
```

Key settings:
- **`type: "dynamic-lib"`** — builds a `.so` (Linux) or `.dll` (Windows) instead of an executable
- **`sources-override`** — points to your `.c3` source file(s). Use this to control exactly which files are compiled
- **`linked-libraries: ["c"]`** — explicitly links against libc. **Required on Linux** to avoid `undefined symbol: atexit` errors when the server loads the plugin

### 4. Build

**Option A: Using `project.json`** (recommended for repeatable builds):
```bash
cd my_plugin/          # directory containing project.json
c3c build              # builds for current platform
```

This produces `out/my_plugin.so` (Linux) or `out/my_plugin.dll` (Windows).

**Option B: Command-line** (no project.json needed):
```bash
# Linux — the -l c flag links against libc (required)
c3c dynamic-lib my_plugin.c3 -l c -o my_plugin

# Windows
c3c dynamic-lib my_plugin.c3 -o my_plugin
```

This produces `my_plugin.so` or `my_plugin.dll` in the current directory.

> **Important:** On Linux, you **must** either use `"linked-libraries": ["c"]` in
> your `project.json` or pass `-l c` on the command line. Without this, the plugin
> will fail to load with `undefined symbol: atexit`.

**Cross-compilation:**
```bash
c3c build --target windows-x64                    # Windows .dll from Linux
```

> **Note:** Cross-compiling Linux `.so` files from Windows is **not recommended**.
> The resulting binaries will have unresolved libc symbols (`atexit`, etc.) that
> cause them to fail at load time. Build `.so` files natively on your Linux server
> instead. Windows `.dll` files can be cross-compiled from Linux without issues.

### 5. Deploy

Copy the `.so` or `.dll` file to the server's `plugins/` directory.
Restart Whisker. Your plugin loads automatically.

> **Tip:** You don't need to restart the whole server every time. Use the
> `/reload` console command to hot-reload all plugins — it unloads everything,
> re-scans `plugins/`, and re-loads. Great for the build-deploy-test loop.

> **Note:** The server automatically resolves the `plugins/` path relative to the
> project root (same as `config/`), so it works whether you run from the project
> root or from `out/`. Configurable via `[plugins] directory` in `config.toml`.

## Plugin API Reference

### Registering Commands

```c3
api.register_command(name, handler, required_perms, description, plugin_name);
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | `String` | Command name without `/` |
| `handler` | `fn void(void*, String)` | Handler function |
| `required_perms` | `ulong` | Permission bitfield (0 = no perms needed) |
| `description` | `String` | Help text |
| `plugin_name` | `String` | Your plugin's name |

Permission bits (combine with `|`):
- `PERM_NONE = 0`
- `PERM_MUTE = 1`
- `PERM_KICK = 2`
- `PERM_BAN = 4`
- `PERM_MOVE_USERS = 8`
- `PERM_MODIFY_AREA = 16`
- `PERM_ADMIN = 64`

### Parsing command arguments

Your command handler receives the raw argument string — everything the player
typed after the command name. The handler signature `fn void(void*, String)` is
frozen for ABI stability (so old compiled plugins keep working), which means the
server can't hand you a pre-split list directly. Instead it exposes the same
quote-aware splitter the built-in commands use, through `api.args_split`:

```c3
fn void cmd_ban(void* c, String args) {
    // Splits  12 "ban evading" "3 days"  into  ["12", "ban evading", "3 days"]
    String[8] argv;
    int n = api.args_split(args, &argv[0], 8);   // returns the token count

    if (n < 1) {
        api.client_send_msg(c, "Usage: /ban <uid> [reason] [duration]");
        return;
    }

    int uid         = argv[0].to_int() ?? -1;
    String reason   = n >= 2 ? argv[1] : "No reason given.";
    String duration = n >= 3 ? argv[2] : "3d";
    // ...
}
```

`args_split(args, out, max)` writes up to `max` tokens into your buffer and
returns how many it found. Tokens are sub-slices of `args` (no allocation), so
they're valid for as long as `args` itself is — which is **only for the duration
of this handler call**. Double or single quotes group whitespace into a single
token, so multi-word arguments survive intact. You're free to parse the raw
string by hand instead — `args_split` is a convenience, not a requirement.

> **Two ways this bites people (see [Common Crashes](#common-crashes-and-how-to-avoid-them) for the full list):**
>
> - **`max` must equal your buffer length.** `args_split` writes up to `max`
>   tokens; a `max` larger than your `argv` array overflows the stack. A
>   `String[8] argv` pairs with `api.args_split(args, &argv[0], 8)`.
> - **The tokens are borrowed.** They — and the raw `args` — point into a
>   temporary packet buffer that the server reuses the moment your handler
>   returns. Never stash a token in a global and read it on a later call; copy
>   what you need first.

### Lower-casing text (`to_lower`)

Comparing player input usually means ignoring case — `Rock`, `rock`, and `ROCK`
should all match. Rather than hand-rolling the `'A'..'Z'` shift every time, the
API gives you an ASCII lower-caser that works like `args_split`: it writes into
a buffer **you** own and returns the byte count, so there's no allocated string
whose lifetime you have to track.

```c3
fn void cmd_choose(void* c, String args) {
    String[1] argv;
    if (api.args_split(args, &argv[0], 1) < 1) return;

    // Lower-case the whole word once, then compare case-insensitively.
    char[16] buf;
    int n = api.to_lower(argv[0], &buf[0], 16);
    String choice = (String)buf[0..n - 1];

    if (choice == "rock" || choice == "r") {
        api.client_send_msg(c, "You picked rock!");
    }
}
```

`to_lower(s, out, max)` copies `s` into `out` with every `A`–`Z` shifted to
`a`–`z` and returns how many bytes it wrote (never more than `max`). Bytes that
aren't ASCII letters — digits, punctuation, UTF-8 multibyte sequences — are
copied through untouched, so it won't mangle non-English shownames; it just
doesn't case-fold them. The same two cautions as `args_split` apply: **`max`
must not exceed your buffer length**, and the returned `String` view is only
valid while `buf` is in scope — copy it into your own storage if you need it on
a later call.

### Registering Packet Hooks

```c3
api.register_hook(header, hook_fn, plugin_name);
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `header` | `String` | AO2 packet header ("MS", "CT", "MC", etc.) |
| `hook_fn` | `fn bool(void*, void*)` | Hook function |
| `plugin_name` | `String` | Your plugin's name |

Hook functions return `bool`:
- `true` = consume the packet (stop processing)
- `false` = pass through to next hook / default handler

### Registering Lifecycle Hooks (v3)

Packet hooks are great, but they only fire when a client **sends** a packet.
That leaves two blind spots:

1. **Disconnects produce no packet.** A socket just closes — so a packet hook
   can *never* observe a client leaving. Anything tracking "who is here" would
   accumulate ghosts forever.
2. **The keepalive is slow.** The desktop client only sends `CH` every ~45
   seconds, so anything you drive off incoming packets can lag badly in a
   quiet room.

**Lifecycle hooks** close both gaps. The server calls them *directly* at the
moments a client joins, leaves, or changes visible state. This is exactly what
a live player list needs (see the `player_list` plugin in `OPTIONAL Plugins/`),
but they're useful for anything stateful: join/leave announcers, Discord
bridges, presence logging, auto-roles, and so on.

```c3
api.register_lifecycle_hook(hook_fn, plugin_name);
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `hook_fn` | `fn void(void*, int)` | `fn void(void* client, int event)` |
| `plugin_name` | `String` | Your plugin's name |

One handler receives **every** event — `switch` on the `event` code to tell
them apart. Unlike packet hooks, lifecycle hooks **never consume**: every
plugin that registered one sees every event. The event codes (defined in the
server's `config.c3` as `PLUGIN_EVENT_*`) are:

| Event | Value | Fires when… | Client state when it fires |
|-------|-------|-------------|----------------------------|
| `JOIN`   | `0` | A client finished the handshake and is in the courtroom. | UID assigned; character not yet picked (area is the entry area). |
| `LEAVE`  | `1` | A joined client is disconnecting. | Still fully readable (UID/character/area), not yet removed. |
| `UPDATE` | `2` | A joined client's character, area, or OOC name changed. | Already updated — read the new value with the `client_*` getters. |

Standalone plugins declare the codes locally to match:

```c3
const int EVENT_JOIN   = 0;
const int EVENT_LEAVE  = 1;
const int EVENT_UPDATE = 2;
```

Key points:

- **`UPDATE` is a "something changed, re-read me" nudge, not a diff.** It fires
  on every character pick, area move, and OOC line. Read the current state with
  `client_get_char_name` / `client_get_area` / `client_get_ooc_name` and compare
  against your own stored copy so you only act on *real* changes (the OOC-name
  case fires on every OOC message). See `handle_update` in `player_list.c3`.
- **`JOIN` fires before a character is chosen.** If you need the character, read
  it on the following `UPDATE`, not on `JOIN`.
- **`LEAVE` fires while the client is still intact** — your handler can safely
  read its UID/character/area and broadcast about it.
- **Honour hidden clients.** `api.client_is_hidden(c)` is `true` for shadow mods
  (the SHADOW role, "hidden from player lists"). Skip them in anything public.
- **No temp allocator here.** Lifecycle hooks run on the client's own server
  thread, where the plugin's *own* copy of the C3 temp allocator is **not**
  initialised — so `dstring::temp()` and `string::tformat()` **panic**
  (*"Use @pool_init()..."*). Build any wire data or message into a fixed
  `char[]` buffer instead; see the allocator-free `put_str` / `put_int` /
  `put_escaped` helpers in `player_list.c3`. The same caveat applies to command
  and packet handlers — see [Threading in Plugins](#threading-in-plugins).

> **In-tree vs standalone:** if you `import whisker::plugin` (in-tree style),
> `register_lifecycle_hook` and the `client_get_ooc_name` / `client_is_hidden`
> getters are already on `PluginAPI` — nothing to do. If you use the standalone
> pattern (your own `PluginAPI` copy), append the three v3 fields to the **end**
> of your struct exactly as shown in `player_list.c3`. See
> [Version Compatibility](#version-compatibility).

A minimal example (full worked version is [Example 10](#example-10-joinleave-announcer-lifecycle-hooks-v3)):

```c3
fn void on_lifecycle(void* c, int event) {
    // Static strings need no allocator. To include dynamic data (a name, a
    // count), format into a fixed char[] buffer — do NOT use string::tformat
    // in a plugin handler (see player_list.c3 and the Threading section).
    if (event == EVENT_JOIN) {
        api.broadcast_all_msg("A player connected.");
    } else if (event == EVENT_LEAVE) {
        api.broadcast_all_msg("A player disconnected.");
    }
}

// in whisker_plugin_init:
api.register_lifecycle_hook(&on_lifecycle, "My Plugin");
```

### Registering Connection Filters (v4)

Commands, packet hooks, and lifecycle hooks all fire **after** a client has
already connected and been given a handler thread. For access control you often
want to decide *before* that — to turn an unwanted connection away at the door,
without it ever costing a thread. That's what a **connection filter** does.

The server calls every registered filter for each inbound connection at **accept
time** — the exact point the built-in IPID ban check runs, before a handler
thread (and its 256 KB pool) is spawned. The filter receives the raw client IP
and returns `true` to **reject** (the socket is closed immediately) or `false`
to allow.

```c3
api.register_conn_filter(filter_fn, plugin_name);
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `filter_fn` | `fn bool(String)` | `fn bool(String ip)` — return `true` to reject the connection |
| `plugin_name` | `String` | Your plugin's name |

```c3
fn bool my_filter(String ip) {
    // ip is the raw address: IPv4 dotted-quad ("1.2.3.4") or IPv6 hex
    // ("2001:db8::1"), or "unknown" if it couldn't be read.
    return ip == "203.0.113.7"; // block exactly this one address
}

// in whisker_plugin_init:
api.register_conn_filter(&my_filter, "My Plugin");
```

This is the hook the optional `ip_guard` plugin (IP / CIDR / ASN / country
blocklist) is built on — see `OPTIONAL Plugins/ip_guard.c3` for a full worked
example with CIDR matching and geolocation.

Two companion functions were added alongside it (v4):

- **`client_get_ip(c)`** → the client's **raw** IP (`String`). Every earlier API
  only exposed the *hashed* IPID (`client_get_ipid`), which is one-way; a plugin
  that needs to reason about ranges, ASNs, or geolocation needs the real address.
- **`broadcast_perm_raw(data, perms)`** → send a pre-built wire packet only to
  connected clients whose permissions include **all** bits of `perms` (e.g. the
  BAN bit). A role-gated broadcast, for staff-only notices.

Key points:

- **Filters must be cheap and allocation-free.** They run on the accept loop, so
  a slow filter slows *every* connection. Do O(log n) table lookups, never
  network calls or broadcasts, in the filter itself. The accept thread also has
  **no temp allocator**, so `string::tformat` / `dstring::temp()` **panic** here
  (same rule as lifecycle hooks) — build into fixed `char[]` buffers, and don't
  retain the borrowed `ip` slice past the call.
- **Push expensive work elsewhere.** `ip_guard` records blocked attempts in the
  filter (O(1)) and does its database downloads and coalesced staff alerts on a
  background thread, never on the accept path.
- **`broadcast_perm_raw` scans the whole client list**, so call it off the hot
  path too (e.g. from a timer), not from inside the filter.

> **In-tree vs standalone:** in-tree plugins already have all three on
> `PluginAPI`. Standalone plugins append the three v4 fields (`client_get_ip`,
> `register_conn_filter`, `broadcast_perm_raw`) to the **end** of their struct
> copy, exactly as shown in `ip_guard.c3`. See
> [Version Compatibility](#version-compatibility).

### Client API (via PluginAPI function pointers)

Client pointers are `void*` in plugin handlers. Use the PluginAPI to interact:

```c3
// Messaging
api.client_send_msg(c, "text");          // Send OOC server message
api.client_send_raw(c, "RAW#data#%");    // Send raw wire data

// Client info
api.client_get_uid(c)                    // Player's UID (int)
api.client_get_area(c)                   // Current area index (int)
api.client_display_name(c)               // Best display name (String)
api.client_get_char_id(c)                // Character ID (int)
api.client_get_char_name(c)              // Character name (String)
api.client_get_showname(c)               // Showname (String)
api.client_is_mod(c)                     // Is authenticated mod? (bool)
api.client_is_joined(c)                  // Has finished joining? (bool)
api.client_set_position(c, "def")        // Set courtroom position
api.client_get_ipid(c)                   // Hashed IP identifier (String)
api.client_get_ooc_name(c)               // Current OOC name, "" if unset (String)  [v3]
api.client_is_hidden(c)                  // Hidden from player lists? (SHADOW role) (bool)  [v3]
api.client_get_ip(c)                     // Raw IP — v4 dotted-quad or v6 hex (String)  [v4]

// Server/Area operations
api.find_client(uid)                     // Find client by UID (void*)
api.broadcast_area_msg(area_id, "text")  // OOC message to entire area
api.broadcast_area_raw(area_id, "data")  // Raw packet to entire area
api.broadcast_all_msg("text")            // OOC message to ALL players
api.broadcast_all_raw("data")            // Raw packet to ALL players
api.broadcast_arup(arup_type)            // Broadcast area update
api.get_area_count()                     // Number of areas (int)
api.get_player_count()                   // Total joined players (int)
api.get_area_player_count(area_id)       // Players in an area (int)
api.force_move(c, new_area_id)           // Move client to area

// CM (Case Manager) operations
api.area_is_cm(area_id, uid)             // Is UID a CM? (bool)
api.area_add_cm(area_id, uid)            // Add UID as CM
api.area_remove_cm(area_id, uid)         // Remove UID from CM
api.area_cm_count(area_id)               // Number of CMs (int)
api.area_clear_cms(area_id)              // Remove all CMs
api.area_uninvite(area_id, uid)          // Remove from invite list
api.area_invite(area_id, uid)            // Add to invite list
api.area_set_status(area_id, status)     // Set area status
api.area_get_status(area_id)             // Get area status (int)
api.area_get_name(area_id)               // Get area name (String)
api.area_set_song(area_id, song, uid)    // Set playing song
api.area_get_background(area_id)         // Get background name (String)
api.area_set_background(area_id, "bg")   // Set background (broadcasts BN)
api.area_get_lock(area_id)               // Get lock state (int: 0=FREE, 1=SPECTATABLE, 2=LOCKED)
api.area_set_lock(area_id, lock_state)   // Set lock state (broadcasts ARUP)

// Packet field access (for hooks)
api.packet_get_field_count(pkt)          // Number of fields in packet (int)
api.packet_get_field(pkt, 0)             // Get field by index (String)

// Moderation
api.client_kick(c)                       // Disconnect a player
api.client_mute(c)                       // Mute IC chat
api.client_unmute(c)                     // Unmute IC chat
api.broadcast_perm_raw("data", perms)    // Raw packet to clients with ALL bits of perms (role-gated)  [v4]

// Connection access control (see "Registering Connection Filters")
api.register_conn_filter(fn, name)       // Reject/allow each inbound connection at accept time  [v4]

// Command arguments
api.args_split(args, &buf[0], max)       // Quote-aware split into buf (String[]); returns token count

// String helpers
api.to_lower(s, &buf[0], max)            // ASCII-lowercase s into buf (char[]); returns bytes written
```

## Example Plugins

Each example below uses the standalone pattern — types defined locally,
`void*` handler parameters, PluginAPI function pointers. This is the
same pattern used by the production plugins in `OPTIONAL Plugins/`.

**Important:** The `PluginAPI` struct layout must exactly match the server's
definition in `plugin.c3`. For production plugins, copy the full struct from
`case_manager.c3` — it has every field correctly defined. Examples 1 and 2
include the full struct so they are self-contained and copy-paste-ready.
Examples 3–9 omit it for brevity — copy it from Example 1.

Examples 1–5 cover core concepts (commands, hooks, permissions, logging).
Examples 6–9 showcase the v2 extended API (moderation, area management,
packet inspection, player counting).

---

### Example 1: Rules Command (simplest possible plugin)

One command, no hooks, no permissions. Player types `/rules`, sees the
server rules. This is the "hello world" of Whisker plugins.

```c3
// file: rules.c3
module rules;

import std::io;

// -- Standalone plugin types (must match server's plugin.c3) --
struct PluginInfo { String name; String version; String author; String description; }
alias CommandHandler = fn void(void* client, String args);
alias PacketHook     = fn bool(void* client, void* packet);

struct PluginAPI {
    fn void(String, CommandHandler, ulong, String, String) register_command;
    fn void(String, PacketHook, String)                    register_hook;
    fn void*(int)      find_client;
    fn void(int, String) broadcast_area_msg;
    fn void(int, String) broadcast_area_raw;
    fn void(int)       broadcast_arup;
    fn int()           get_area_count;
    fn bool(int, int)  area_is_cm;
    fn void(int, int)  area_add_cm;
    fn void(int, int)  area_remove_cm;
    fn int(int)        area_cm_count;
    fn void(int)       area_clear_cms;
    fn void(int, int)  area_uninvite;
    fn void(int, int)  area_set_status;
    fn int(int)        area_get_status;
    fn String(int)     area_get_name;
    fn void(int, String, int) area_set_song;
    fn void(void*, int) force_move;
    fn void(void*, String) client_send_msg;
    fn void(void*, String) client_send_raw;
    fn int(void*)      client_get_uid;
    fn int(void*)      client_get_area;
    fn bool(void*)     client_is_mod;
    fn String(void*)   client_display_name;
    fn int(void*)      client_get_char_id;
    fn String(void*)   client_get_showname;
    fn String(void*)   client_get_char_name;
    fn bool(void*)     client_is_joined;
    fn void(void*, String) client_set_position;
    // Extended API (v2)
    fn void(String)    broadcast_all_msg;
    fn void(String)    broadcast_all_raw;
    fn int()           get_player_count;
    fn int(int)        get_area_player_count;
    fn String(void*)   client_get_ipid;
    fn String(void*, int) packet_get_field;
    fn int(void*)      packet_get_field_count;
    fn void(void*)     client_kick;
    fn void(void*)     client_mute;
    fn void(void*)     client_unmute;
    fn String(int)     area_get_background;
    fn void(int, String) area_set_background;
    fn int(int)        area_get_lock;
    fn void(int, int)  area_set_lock;
    fn void(int, int)  area_invite;
    // Appended after v2 — see "Version Compatibility". Old plugins that
    // stop at area_invite stay ABI-compatible; this field is just ignored.
    fn int(String, String*, int) args_split;
    fn int(String, char*, int)   to_lower;
}

PluginAPI* api;

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return { "Rules", "1.0.0", "Whisker Community", "Displays server rules" };
}

fn bool whisker_plugin_init(PluginAPI* a) @export("whisker_plugin_init") {
    api = a;
    api.register_command("rules", &cmd_rules, 0, "Show server rules", "Rules");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {}

fn void cmd_rules(void* c, String args) {
    api.client_send_msg(c, "=== Server Rules ===");
    api.client_send_msg(c, "1. Be respectful to all players.");
    api.client_send_msg(c, "2. No spamming or flooding.");
    api.client_send_msg(c, "3. Stay in character in IC chat.");
    api.client_send_msg(c, "4. Listen to moderators.");
    api.client_send_msg(c, "5. Have fun!");
    api.client_send_msg(c, "====================");
}
```

**Option A: project.json** (create a `rules/` subdirectory for it):
```json
{
    "version": "1.0.0",
    "langrev": "1",
    "targets": {
        "rules": {
            "type": "dynamic-lib",
            "sources-override": ["../rules.c3"],
            "linked-libraries": ["c"]
        }
    }
}
```

```bash
cd rules/
c3c build
cp out/rules.so /path/to/whisker/plugins/   # Linux
cp out/rules.dll /path/to/whisker/plugins/   # Windows
```

**Option B: Command-line** (no project.json needed):
```bash
c3c dynamic-lib rules.c3 -l c -o rules      # Linux
c3c dynamic-lib rules.c3 -o rules            # Windows
cp rules.so /path/to/whisker/plugins/        # Linux
cp rules.dll /path/to/whisker/plugins/       # Windows
```

---

### Example 2: Welcome Message (packet hook, no commands)

Sends a custom welcome message when a player finishes joining. Hooks the
`RD` packet (the last step of the join handshake).

```c3
// file: welcome.c3
module welcome;

// -- Standalone plugin types (must match server's plugin.c3) --
struct PluginInfo { String name; String version; String author; String description; }
alias CommandHandler = fn void(void* client, String args);
alias PacketHook     = fn bool(void* client, void* packet);

struct PluginAPI {
    fn void(String, CommandHandler, ulong, String, String) register_command;
    fn void(String, PacketHook, String)                    register_hook;
    fn void*(int)      find_client;
    fn void(int, String) broadcast_area_msg;
    fn void(int, String) broadcast_area_raw;
    fn void(int)       broadcast_arup;
    fn int()           get_area_count;
    fn bool(int, int)  area_is_cm;
    fn void(int, int)  area_add_cm;
    fn void(int, int)  area_remove_cm;
    fn int(int)        area_cm_count;
    fn void(int)       area_clear_cms;
    fn void(int, int)  area_uninvite;
    fn void(int, int)  area_set_status;
    fn int(int)        area_get_status;
    fn String(int)     area_get_name;
    fn void(int, String, int) area_set_song;
    fn void(void*, int) force_move;
    fn void(void*, String) client_send_msg;
    fn void(void*, String) client_send_raw;
    fn int(void*)      client_get_uid;
    fn int(void*)      client_get_area;
    fn bool(void*)     client_is_mod;
    fn String(void*)   client_display_name;
    fn int(void*)      client_get_char_id;
    fn String(void*)   client_get_showname;
    fn String(void*)   client_get_char_name;
    fn bool(void*)     client_is_joined;
    fn void(void*, String) client_set_position;
    // Extended API (v2)
    fn void(String)    broadcast_all_msg;
    fn void(String)    broadcast_all_raw;
    fn int()           get_player_count;
    fn int(int)        get_area_player_count;
    fn String(void*)   client_get_ipid;
    fn String(void*, int) packet_get_field;
    fn int(void*)      packet_get_field_count;
    fn void(void*)     client_kick;
    fn void(void*)     client_mute;
    fn void(void*)     client_unmute;
    fn String(int)     area_get_background;
    fn void(int, String) area_set_background;
    fn int(int)        area_get_lock;
    fn void(int, int)  area_set_lock;
    fn void(int, int)  area_invite;
    // Appended after v2 — see "Version Compatibility". Old plugins that
    // stop at area_invite stay ABI-compatible; this field is just ignored.
    fn int(String, String*, int) args_split;
    fn int(String, char*, int)   to_lower;
}

PluginAPI* api;

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return { "Welcome", "1.0.0", "Whisker Community", "Custom welcome message on join" };
}

fn void whisker_plugin_init(PluginAPI* a) @export("whisker_plugin_init") {
    api = a;
    api.register_hook("RD", &on_player_ready, "Welcome");
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {}

fn bool on_player_ready(void* c, void* pkt) {
    // We return false so the normal RD handler still processes
    // (allocates UID, sends DONE, etc.) — our message adds on top.
    int players = api.get_player_count();  // v2: show how many are online
    api.client_send_msg(c, "=============================");
    api.client_send_msg(c, "Welcome to the server!");
    api.client_send_msg(c, string::tformat("There are %d player(s) online.", players));
    api.client_send_msg(c, "Type /help for commands.");
    api.client_send_msg(c, "Type /rules to see server rules.");
    api.client_send_msg(c, "=============================");

    return false; // IMPORTANT: let the default handler run too
}
```

---

### Example 3: Warn Command (mod-only command)

Adds `/warn <uid> <reason>` that sends a visible warning to a player.
Requires MUTE permission (permission bit 1). Shows `api.args_split` turning the
raw argument string into a token list — quote a multi-word reason
(`/warn 5 "stop spamming"`).

```c3
// file: warn.c3
module warn_plugin;

import std::io;

struct PluginInfo { String name; String version; String author; String description; }
// ... PluginAPI struct same as Example 1 (omitted for brevity) ...

const ulong PERM_MUTE = 1;  // lowest mod tier
PluginAPI* api;

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return { "Warn", "1.0.0", "Whisker Community", "Adds /warn command for moderators" };
}

fn void whisker_plugin_init(PluginAPI* a) @export("whisker_plugin_init") {
    api = a;
    api.register_command("warn", &cmd_warn, PERM_MUTE, "Warn a player", "Warn");
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {}

fn void cmd_warn(void* c, String args) {
    // Let the server split the arguments — quote multi-word reasons,
    // e.g.  /warn 5 "stop spamming".
    String[8] argv;
    int n = api.args_split(args, &argv[0], 8);

    if (n < 1) {
        api.client_send_msg(c, "Usage: /warn <uid> \"<reason>\"");
        return;
    }

    int target_uid = argv[0].to_int() ?? -1;
    if (target_uid < 0) {
        api.client_send_msg(c, "Invalid UID.");
        return;
    }

    String reason = n >= 2 ? argv[1] : "No reason given.";

    void* target = api.find_client(target_uid);
    if (target != null) {
        api.client_send_msg(target, string::tformat(
            "=== WARNING from %s: %s ===", api.client_display_name(c), reason));
    }

    api.client_send_msg(c, string::tformat("WARNING sent to UID %d: %s", target_uid, reason));
    io::printfn("[warn] %s warned UID %d: %s", api.client_display_name(c), target_uid, reason);
}
```

---

### Example 4: MOTD Rotation (hook on join)

Rotate through a list of tips. Each player sees a different tip when
they join.

```c3
// file: motd_rotation.c3
module motd_rotation;

struct PluginInfo { String name; String version; String author; String description; }
// ... PluginAPI struct same as Example 1 (omitted for brevity) ...

PluginAPI* api;

const String[] TIPS = {
    "Tip: Use /pair <uid> to pair up for dual character scenes!",
    "Tip: Press Tab to cycle through emotes quickly.",
    "Tip: Type /areas to see all available rooms.",
    "Tip: You can /pm <uid> to privately message someone.",
    "Tip: Moderators are here to help. Use /modcall if needed.",
    "Tip: Use /roll 2d6 to roll dice during your case!",
    "Tip: Check /rules to see the server rules.",
};

int tip_counter = 0;

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return { "MOTD Rotation", "1.0.0", "Whisker Community", "Rotating tips on join" };
}

fn void whisker_plugin_init(PluginAPI* a) @export("whisker_plugin_init") {
    api = a;
    api.register_hook("RD", &on_join, "MOTD Rotation");
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {}

fn bool on_join(void* c, void* pkt) {
    int index = tip_counter % (int)TIPS.len;
    tip_counter++;
    api.client_send_msg(c, TIPS[index]);
    return false; // Let the normal join handler run
}
```

---

### Example 5: Music Logger (packet hook with field access)

Logs every music change to the server console **with the actual song name**.
Uses `packet_get_field()` (v2) to read the song from the MC packet. Before
v2, hooks couldn't inspect packet contents — this was one of the biggest gaps.

MC packet format: `MC#song_name#char_id#showname#looping#channel#effects#%`
Field 0 is the song name, field 1 is the character ID.

```c3
// file: music_logger.c3
module music_logger;

import std::io;

struct PluginInfo { String name; String version; String author; String description; }
// ... PluginAPI struct same as Example 1 (omitted for brevity) ...

PluginAPI* api;

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return { "Music Logger", "1.0.0", "Whisker Community", "Logs music changes with song names" };
}

fn void whisker_plugin_init(PluginAPI* a) @export("whisker_plugin_init") {
    api = a;
    api.register_hook("MC", &on_music_change, "Music Logger");
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {}

fn bool on_music_change(void* c, void* pkt) {
    // v2: read the actual song name from the packet
    String song = api.packet_get_field(pkt, 0);
    int area = api.client_get_area(c);

    io::printfn("[music-log] %s (UID %d) played \"%s\" in %s",
        api.client_display_name(c), api.client_get_uid(c),
        song, api.area_get_name(area));
    return false; // Always pass through — we're just logging
}
```

---

### Example 6: IC Spam Filter (v2 — moderation + packet inspection)

Auto-mutes players who spam IC chat. Tracks message timestamps per UID
and mutes anyone who sends more than 5 IC messages in 3 seconds. Mods
with kick permission can use `/unmute <uid>` to reverse it.

Uses v2 functions: `packet_get_field()`, `client_mute()`, `client_unmute()`,
`client_get_ipid()`, `broadcast_all_msg()`.

```c3
// file: spam_filter.c3
module spam_filter;

import std::io;
import std::time;

struct PluginInfo { String name; String version; String author; String description; }
// ... PluginAPI struct same as Example 1 (omitted for brevity) ...

const int MAX_TRACKED  = 256;
const int SPAM_LIMIT   = 5;     // messages within window = mute
const long SPAM_WINDOW = 3;     // seconds

const ulong PERM_KICK = 2;

struct SpamTracker {
    int uid;
    int count;
    long first_msg_time;
}

SpamTracker[MAX_TRACKED] trackers;
PluginAPI* api;

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return { "Spam Filter", "1.0.0", "Whisker Community", "Auto-mutes IC spammers" };
}

fn void whisker_plugin_init(PluginAPI* a) @export("whisker_plugin_init") {
    api = a;
    api.register_hook("MS", &on_ic_message, "Spam Filter");
    api.register_command("unmute", &cmd_unmute, PERM_KICK, "Unmute a player", "Spam Filter");
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {}

fn SpamTracker* find_tracker(int uid) {
    // Find existing or first empty slot
    SpamTracker* empty = null;
    for (int i = 0; i < MAX_TRACKED; i++) {
        if (trackers[i].uid == uid) return &trackers[i];
        if (empty == null && trackers[i].uid == 0) empty = &trackers[i];
    }
    if (empty != null) {
        empty.uid = uid;
        empty.count = 0;
        empty.first_msg_time = 0;
    }
    return empty;
}

fn bool on_ic_message(void* c, void* pkt) {
    int uid = api.client_get_uid(c);
    long now = (long)time::clock::now().to_seconds();

    SpamTracker* t = find_tracker(uid);
    if (t == null) return false; // tracker table full, let it through

    // Reset window if expired
    if (now - t.first_msg_time > SPAM_WINDOW) {
        t.count = 0;
        t.first_msg_time = now;
    }

    t.count++;

    if (t.count > SPAM_LIMIT) {
        api.client_mute(c);
        api.client_send_msg(c, "You have been auto-muted for spamming.");
        io::printfn("[spam-filter] Auto-muted %s (UID %d, IPID %s)",
            api.client_display_name(c), uid, api.client_get_ipid(c));
        return true; // consume the spammy message
    }

    return false;
}

fn void cmd_unmute(void* c, String args) {
    int target_uid = args.to_int() ?? -1;
    if (target_uid < 0) {
        api.client_send_msg(c, "Usage: /unmute <uid>");
        return;
    }
    void* target = api.find_client(target_uid);
    if (target == null) {
        api.client_send_msg(c, "Player not found.");
        return;
    }
    api.client_unmute(target);
    api.client_send_msg(target, "You have been unmuted.");
    api.client_send_msg(c, string::tformat("Unmuted UID %d.", target_uid));
}
```

---

### Example 7: Area Lockdown (v2 — area management + broadcasting)

Adds `/lockdown` (lock current area, only invited players can enter)
and `/open` (unlock it). Demonstrates area lock/unlock, invite management,
and server-wide announcements.

Uses v2 functions: `area_get_lock()`, `area_set_lock()`, `area_invite()`,
`area_get_background()`, `broadcast_all_msg()`, `get_area_player_count()`.

```c3
// file: lockdown.c3
module lockdown;

import std::io;

struct PluginInfo { String name; String version; String author; String description; }
// ... PluginAPI struct same as Example 1 (omitted for brevity) ...

const ulong PERM_MODIFY_AREA = 16;

// Lock states (match area::LockState)
const int LOCK_FREE        = 0;
const int LOCK_SPECTATABLE = 1;
const int LOCK_LOCKED      = 2;

PluginAPI* api;

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return { "Lockdown", "1.0.0", "Whisker Community", "Area lockdown commands" };
}

fn void whisker_plugin_init(PluginAPI* a) @export("whisker_plugin_init") {
    api = a;
    api.register_command("lockdown", &cmd_lockdown, PERM_MODIFY_AREA,
        "Lock current area", "Lockdown");
    api.register_command("open", &cmd_open, PERM_MODIFY_AREA,
        "Unlock current area", "Lockdown");
    api.register_command("areainvite", &cmd_invite, PERM_MODIFY_AREA,
        "Invite a player to locked area", "Lockdown");
    api.register_command("areastatus", &cmd_status, 0,
        "Show area lock and player info", "Lockdown");
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {}

fn void cmd_lockdown(void* c, String args) {
    int area = api.client_get_area(c);
    int current_lock = api.area_get_lock(area);

    if (current_lock == LOCK_LOCKED) {
        api.client_send_msg(c, "This area is already locked.");
        return;
    }

    api.area_set_lock(area, LOCK_LOCKED);
    String area_name = api.area_get_name(area);
    api.broadcast_area_msg(area, string::tformat(
        "=== %s has been locked down by %s ===",
        area_name, api.client_display_name(c)));
    api.broadcast_all_msg(string::tformat(
        "[Notice] %s is now locked.", area_name));

    io::printfn("[lockdown] %s locked by %s",
        area_name, api.client_display_name(c));
}

fn void cmd_open(void* c, String args) {
    int area = api.client_get_area(c);
    int current_lock = api.area_get_lock(area);

    if (current_lock == LOCK_FREE) {
        api.client_send_msg(c, "This area is already open.");
        return;
    }

    api.area_set_lock(area, LOCK_FREE);
    String area_name = api.area_get_name(area);
    api.broadcast_area_msg(area, string::tformat(
        "=== %s has been unlocked by %s ===",
        area_name, api.client_display_name(c)));

    io::printfn("[lockdown] %s unlocked by %s",
        area_name, api.client_display_name(c));
}

fn void cmd_invite(void* c, String args) {
    int target_uid = args.to_int() ?? -1;
    if (target_uid < 0) {
        api.client_send_msg(c, "Usage: /areainvite <uid>");
        return;
    }

    int area = api.client_get_area(c);
    api.area_invite(area, target_uid);

    void* target = api.find_client(target_uid);
    if (target != null) {
        api.client_send_msg(target, string::tformat(
            "You have been invited to %s.", api.area_get_name(area)));
    }
    api.client_send_msg(c, string::tformat("Invited UID %d.", target_uid));
}

fn void cmd_status(void* c, String args) {
    int area = api.client_get_area(c);
    String area_name = api.area_get_name(area);
    String bg = api.area_get_background(area);
    int lock = api.area_get_lock(area);
    int players = api.get_area_player_count(area);

    String lock_str = "FREE";
    if (lock == LOCK_SPECTATABLE) lock_str = "SPECTATABLE";
    if (lock == LOCK_LOCKED)      lock_str = "LOCKED";

    api.client_send_msg(c, string::tformat("--- %s ---", area_name));
    api.client_send_msg(c, string::tformat("Background: %s", bg));
    api.client_send_msg(c, string::tformat("Lock: %s", lock_str));
    api.client_send_msg(c, string::tformat("Players: %d", players));
}
```

---

### Example 8: Kick Vote (v2 — player counting + kick)

Players vote to kick someone with `/votekick <uid>`. If a majority of the
area votes, the target is kicked. Demonstrates `client_kick()`,
`get_area_player_count()`, and `broadcast_area_msg()`.

Uses v2 functions: `client_kick()`, `get_area_player_count()`,
`broadcast_area_msg()`.

```c3
// file: votekick.c3
module votekick;

import std::io;

struct PluginInfo { String name; String version; String author; String description; }
// ... PluginAPI struct same as Example 1 (omitted for brevity) ...

const int MAX_VOTES = 64;

struct VoteSession {
    int area_id;
    int target_uid;
    int[MAX_VOTES] voter_uids;  // UIDs who have voted
    int vote_count;
    bool active;
}

VoteSession current_vote;
PluginAPI* api;

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return { "Vote Kick", "1.0.0", "Whisker Community", "Democratic kick voting" };
}

fn void whisker_plugin_init(PluginAPI* a) @export("whisker_plugin_init") {
    api = a;
    api.register_command("votekick", &cmd_votekick, 0,
        "Start or join a kick vote", "Vote Kick");
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {}

fn bool has_voted(int uid) {
    for (int i = 0; i < current_vote.vote_count; i++) {
        if (current_vote.voter_uids[i] == uid) return true;
    }
    return false;
}

fn void cmd_votekick(void* c, String args) {
    int uid = api.client_get_uid(c);
    int area = api.client_get_area(c);
    int target_uid = args.to_int() ?? -1;

    if (target_uid < 0) {
        api.client_send_msg(c, "Usage: /votekick <uid>");
        return;
    }

    if (target_uid == uid) {
        api.client_send_msg(c, "You can't votekick yourself.");
        return;
    }

    // Start new vote or join existing one
    if (!current_vote.active || current_vote.target_uid != target_uid
            || current_vote.area_id != area) {
        // Start fresh vote
        current_vote = {
            .area_id = area,
            .target_uid = target_uid,
            .vote_count = 0,
            .active = true,
        };
    }

    if (has_voted(uid)) {
        api.client_send_msg(c, "You already voted.");
        return;
    }

    current_vote.voter_uids[current_vote.vote_count] = uid;
    current_vote.vote_count++;

    int area_players = api.get_area_player_count(area);
    int needed = area_players / 2 + 1; // simple majority

    api.broadcast_area_msg(area, string::tformat(
        "[Vote Kick] %s voted to kick UID %d (%d/%d votes)",
        api.client_display_name(c), target_uid,
        current_vote.vote_count, needed));

    if (current_vote.vote_count >= needed) {
        void* target = api.find_client(target_uid);
        if (target != null) {
            api.client_send_msg(target, "You have been vote-kicked.");
            api.client_kick(target);
        }
        api.broadcast_area_msg(area, string::tformat(
            "[Vote Kick] UID %d has been kicked by vote.", target_uid));
        current_vote.active = false;
        io::printfn("[votekick] UID %d kicked from area %d by vote",
            target_uid, area);
    }
}
```

---

### Example 9: Background Scheduler (v2 — area backgrounds + hooks)

Automatically changes the area background based on which song is playing.
Maps song names to backgrounds — when someone plays a "courtroom" song,
the background switches to match. Shows `packet_get_field()` combined
with `area_set_background()`.

Uses v2 functions: `packet_get_field()`, `area_set_background()`,
`area_get_background()`.

```c3
// file: bg_scheduler.c3
module bg_scheduler;

import std::io;

struct PluginInfo { String name; String version; String author; String description; }
// ... PluginAPI struct same as Example 1 (omitted for brevity) ...

const int MAX_MAPPINGS = 32;

struct SongMapping {
    String song_contains;   // substring to match in song name
    String background;      // background to switch to
}

// Configure your song-to-background mappings here
const SongMapping[] MAPPINGS = {
    { "trial",        "gs4-courtroom" },
    { "cross",        "gs4-courtroom" },
    { "objection",    "gs4-courtroom" },
    { "pursuit",      "gs4-courtroom" },
    { "lobby",        "gs4-lobbyoffice" },
    { "investigation","gs4-detention" },
    { "detention",    "gs4-detention" },
};

PluginAPI* api;

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return { "BG Scheduler", "1.0.0", "Whisker Community", "Auto-switches backgrounds with music" };
}

fn void whisker_plugin_init(PluginAPI* a) @export("whisker_plugin_init") {
    api = a;
    api.register_hook("MC", &on_music, "BG Scheduler");
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {}

fn bool on_music(void* c, void* pkt) {
    String song = api.packet_get_field(pkt, 0);
    int area = api.client_get_area(c);

    // Check each mapping for a substring match
    for (int i = 0; i < (int)MAPPINGS.len; i++) {
        // Simple substring search
        if (song.len >= MAPPINGS[i].song_contains.len) {
            bool found = false;
            for (usz j = 0; j <= song.len - MAPPINGS[i].song_contains.len; j++) {
                if (song[j..j + MAPPINGS[i].song_contains.len - 1] == MAPPINGS[i].song_contains) {
                    found = true;
                    break;
                }
            }
            if (found) {
                String current_bg = api.area_get_background(area);
                if (current_bg != MAPPINGS[i].background) {
                    api.area_set_background(area, MAPPINGS[i].background);
                    api.broadcast_area_msg(area, string::tformat(
                        "[BG] Background changed to %s", MAPPINGS[i].background));
                }
                break;
            }
        }
    }

    return false; // let the music change through
}
```

---

### Example 10: Join/Leave Announcer (lifecycle hooks, v3)

Shows the [lifecycle hook API](#registering-lifecycle-hooks-v3): announce when
players come and go, and note when someone picks a character — none of which a
packet hook can do reliably (a disconnect sends no packet). Shadow mods are
skipped so they stay invisible.

This example omits the `PluginAPI` struct for brevity. Unlike Examples 1–9,
copy the struct from **`OPTIONAL Plugins/player_list.c3`** — it includes the
three appended v3 fields (`register_lifecycle_hook`, `client_get_ooc_name`,
`client_is_hidden`) that this example needs. (The v2-era struct in Example 1 /
`case_manager.c3` stops at `to_lower` and won't have them.)

```c3
module announcer;

import std::io;

// ... PluginInfo, alias types, and the FULL PluginAPI struct
//     (copy from player_list.c3 — it has the v3 fields at the end) ...

// Lifecycle event codes — must match config::PLUGIN_EVENT_* in the server.
const int EVENT_JOIN   = 0;
const int EVENT_LEAVE  = 1;
const int EVENT_UPDATE = 2;

const int MAX_TRACK = 1024;

// Remember each listed player's last character so we only announce *real*
// character changes (UPDATE also fires on area moves and every OOC line).
struct Seen { bool used; int uid; char[64] character; }
Seen[MAX_TRACK] seen;
PluginAPI* api;

fn Seen* slot(int uid) {
    for (int i = 0; i < MAX_TRACK; i++) if (seen[i].used && seen[i].uid == uid) return &seen[i];
    return null;
}

// Append a String into buf (bounds-checked). Allocator-free, so it is safe on
// the plugin's server threads — string::tformat would PANIC here (the plugin's
// temp allocator isn't initialised on these threads; see the Threading section).
fn usz put(char[] buf, usz n, String s) {
    foreach (char ch : s) { if (n >= buf.len) break; buf[n] = ch; n++; }
    return n;
}

fn void on_lifecycle(void* c, int event) {
    if (api.client_is_hidden(c)) return;   // never announce shadow mods
    int uid = api.client_get_uid(c);
    char[256] m;
    usz n = 0;

    switch (event) {
        case EVENT_JOIN:
            for (int i = 0; i < MAX_TRACK; i++) {
                if (!seen[i].used) { seen[i].used = true; seen[i].uid = uid; seen[i].character[0] = 0; break; }
            }
            n = put(m[..], n, api.client_display_name(c));
            n = put(m[..], n, " connected.");
            api.broadcast_all_msg((String)m[0..n - 1]);

        case EVENT_LEAVE:
            Seen* sl = slot(uid);
            if (sl != null) sl.used = false;
            n = put(m[..], n, api.client_display_name(c));
            n = put(m[..], n, " disconnected.");
            api.broadcast_all_msg((String)m[0..n - 1]);

        case EVENT_UPDATE:
            Seen* su = slot(uid);
            if (su == null) return;
            String cur = api.client_get_char_name(c);
            // Compare against the stored copy; only announce a genuine change.
            int len = 0; while (su.character[len] != 0) len++;
            String old = len == 0 ? "" : (String)su.character[0..len - 1];
            if (old != cur && cur.len > 0) {
                int k = (int)cur.len < 63 ? (int)cur.len : 63;
                for (int i = 0; i < k; i++) su.character[i] = cur[i];
                su.character[k] = 0;
                n = put(m[..], n, api.client_display_name(c));
                n = put(m[..], n, " is now playing ");
                n = put(m[..], n, cur);
                api.broadcast_all_msg((String)m[0..n - 1]);
            }

        default:
            break;
    }
}

fn bool whisker_plugin_init(PluginAPI* plugin_api) @export("whisker_plugin_init") {
    api = plugin_api;
    for (int i = 0; i < MAX_TRACK; i++) seen[i].used = false;
    api.register_lifecycle_hook(&on_lifecycle, "Announcer");
    io::printn("[announcer] loaded");
    return true;
}

// whisker_plugin_info() and whisker_plugin_shutdown() as in Example 1.
```

For a complete, production-quality lifecycle plugin that pushes real protocol
packets (the AO2 2.11 player list) rather than chat lines, read
`OPTIONAL Plugins/player_list.c3` end to end.

## Best Practices

1. **Keep it focused.** One plugin per feature. Don't build a monolith.
2. **Don't break existing behavior.** If your hook returns `true`, the default handler doesn't run.
3. **Use named constants.** Define permission bits and status codes as `const` values.
4. **Handle errors gracefully.** Don't crash the server from a plugin.
5. **Document your commands.** Players should be able to `/help <your_command>`.
6. **Use the standalone pattern.** Define types locally so your plugin compiles independently.
7. **License as AGPL-3.0.** Keep the ecosystem open.

## Threading in Plugins

There are **two** thread hazards, both from the same root cause: a standalone
plugin is loaded via `dlopen`/`LoadLibrary`, so it gets its **own** copy of the
C3 runtime, whose temp allocator is thread-local and only initialised on the
*main* thread — which your plugin code never runs on.

**Hazard 1 — your handlers run on the server's per-client threads.** Command,
packet, **and lifecycle** handlers are all invoked on the thread that owns the
client, *not* the main thread. So `dstring::temp()` and `string::tformat()`
**panic** there too (*"Use @pool_init() to enable the temp allocator on a new
thread"*) — this is **not** limited to threads you spawn yourself. There are two
fixes, both used by the shipped plugins:

1. **Avoid the temp allocator — build into fixed `char[]` buffers** with manual
   formatting, as `player_list.c3` does (`put_str` / `put_int` / `put_escaped`),
   then hand the slice to the API. No allocator, no TLS — bulletproof.
2. **Open a temp-allocator scope yourself with `@pool_init`.** Wrap the handler
   body (or register a thin wrapper) in `@pool_init(mem, 64 * 1024) { ... };` —
   inside that scope `string::tformat` / `dstring::temp` work normally, because
   `@pool_init` *creates* a temp allocator for the current thread (using `mem`,
   the heap, as the backing store) and tears it down at scope end. This is what
   `casing.c3` and `case_manager.c3` do (see the `w_*` wrappers there), and it
   lets you keep handler code that already uses `tformat`:

   ```c3
   // Thin wrapper registered instead of the bare handler:
   fn void w_doc(void* c, String a) { @pool_init(mem, 64 * 1024) { cmd_doc(c, a); }; }
   // ...
   api.register_command("doc", &w_doc, 0, "Get/set case document", "Casing");
   ```

   (`@pool_init` and `mem` are `@builtin` — no import needed. Use option 2 only on
   the server's threads, as here; on threads you spawn yourself, see Hazard 2.)

Examples elsewhere in this guide that call `string::tformat` directly inside a
handler assume such a scope is in place — wrap them per option 2 (or convert to
option 1) for anything you actually ship.

**Hazard 2 — threads your plugin spawns** (e.g., a background heartbeat). Same
ban on the temp allocator, and you also shouldn't rely on C3 runtime services at
all. The safe pattern:

1. **Do all string building on the main thread** (inside `whisker_plugin_init`), where C3's
   temp allocator works normally.
2. **Store results in static buffers** (`char[N]` arrays) that survive past `init`.
3. **In the thread, use only C functions**: `system()`, `sleep()`, `puts()`, `printf()`.

```c3
// Static buffer — lives for the plugin's lifetime
char[4096] my_command_buf;

// C functions safe to call from any thread
extern fn CInt puts(ZString s);
extern fn CInt system(ZString cmd);
extern fn uint sleep_c(uint seconds) @cname("sleep");

fn bool whisker_plugin_init(PluginAPI* api) @export("whisker_plugin_init") {
    // Build strings HERE (main thread — temp allocator works)
    ZString cmd = string::tformat_zstr(`echo "hello %s"`, "world");

    // Copy to static buffer
    usz i = 0;
    while (i < 4095 && cmd[i] != 0) { my_command_buf[i] = cmd[i]; i++; }
    my_command_buf[i] = 0;

    // Start thread
    Thread t;
    if (catch t.create(&my_thread, null)) return false;
    t.detach();
    return true;
}

fn int my_thread(void* arg) {
    // ONLY use C functions here — no dstring::temp(), no string::tformat()
    sleep_c(5);
    while (true) {
        system((ZString)&my_command_buf[0]);
        sleep_c(60);
    }
    return 0;
}
```

See `server_advertiser.c3` for a complete real-world example of this pattern.

## Common Crashes (and How to Avoid Them)

Most plugin crashes aren't compiler errors — the plugin builds cleanly and then
takes the server down at runtime. These are the ones that bite people most
often. (Every one was hit by a real Rock-Paper-Scissors plugin during
development, and none of them showed up at compile time.)

### 1. Don't store borrowed argument slices

Your handler's `String args` — and every token `api.args_split` writes out — is
a **borrowed sub-slice of a temporary packet buffer**. It is valid *only for the
duration of the handler call*. The server reuses that buffer for the next packet
as soon as your handler returns.

```c3
String pending_choice;   // global

fn void cmd_rps(void* c, String args) {
    String[2] argv;
    int n = api.args_split(args, &argv[0], 2);
    pending_choice = argv[0];   // BUG: a borrowed slice escapes the call.
    // The next packet from ANY client overwrites that buffer, so a later
    // read of pending_choice sees garbage — or crashes.
}
```

If you need a value after the call returns, **copy it into storage you own** —
reduce it to a primitive (an `int`, a single `char`), or copy the bytes into a
fixed buffer:

```c3
char[64] saved_name_buf;
int      saved_name_len;

fn int store_str(char* buf, int cap, String s) {
    int n = (int)s.len;
    if (n > cap) n = cap;
    for (int i = 0; i < n; i++) buf[i] = s[i];
    return n;
}

// at call time:
saved_name_len = store_str(&saved_name_buf[0], 64, api.client_display_name(c));
// later (any call): String saved = (String)saved_name_buf[0..saved_name_len - 1];
```

The same lifetime rule applies to the Strings returned by
`api.client_display_name`, `client_get_showname`, `client_get_char_name`, and
`area_get_name`: they point into the server's own storage and are fine to use
immediately, but if you stash one and the client changes character or
disconnects, it dangles. Copy it if it must outlive the call.

### 2. `args_split`'s `max` must match your buffer size

`args_split(args, &buf[0], max)` writes up to `max` tokens into `buf`. The server
can't see how big `buf` is, so if `max` is larger than your array it writes past
the end and corrupts the stack.

```c3
String[2] argv;
api.args_split(args, &argv[0], 8);   // BUG: up to 8 tokens into a 2-slot buffer
api.args_split(args, &argv[0], 2);   // correct: max == buffer length
```

### 3. `!!` on an optional aborts the whole process

`to_int()` and the other `to_*` parsers return an **optional** — empty when the
input isn't a number. Unwrapping an empty optional with `!!` *panics and aborts
the entire server*. Never use `!!` on player-supplied input; use `??` with a
fallback and validate:

```c3
int uid = argv[0].to_int() ?? -1;   // safe: -1 on bad input
if (uid < 0) { api.client_send_msg(c, "Invalid UID."); return; }
```

Optionals also propagate *outward* through an expression. If you write
`string::format(..., argv[0].to_int())`, the bad-int optional makes the whole
`format` call optional, and a trailing `!!` will abort on bad input just the
same. Parse and validate first, then format.

### 4. `find_client` returns null for offline UIDs

`api.find_client(uid)` returns `null` when nobody with that UID is online. The
server's client wrappers guard against a null client pointer — they return a
harmless sentinel (`-1`, `false`, or `""`) instead of crashing — but you should
still null-check, because *acting* on a player who isn't there is a logic bug:
you'd silently message no one, or treat `-1` as if it were a real UID.

```c3
void* t = api.find_client(uid);
if (t == null) { api.client_send_msg(c, "Player not found."); return; }
api.client_send_msg(t, "hi");        // safe — t is a real, online client
```

> Older server builds did **not** null-guard these wrappers, so the same null
> would crash there. Null-checking in your plugin keeps it correct (and
> crash-free) across server versions.

## Timers Without Threads (the packet-hook pattern)

Plugins often want time-based behavior: expire a pending challenge, end a round
after N seconds, nudge idle players. The obvious approach — spawn a thread that
sleeps — runs straight into the temp-allocator-across-`dlopen` segfault from
[Threading in Plugins](#threading-in-plugins).

The robust alternative is to **drive time from a packet hook** instead of a
thread. Hooks run on the server's own packet threads — the same threads that run
your command handlers — so the temp allocator behaves normally there. Hook a
frequent packet such as `MS` (sent on every IC message) and check the clock each
time it fires:

```c3
import std::time;

const long TIMEOUT_US = 60_000_000;   // 60 seconds, in microseconds

bool      pending      = false;
long      started_us   = 0;
int       pending_area = 0;
char[160] expiry_buf;                 // message pre-built on the command thread
int       expiry_len   = 0;

fn void start_something(void* c) {
    pending      = true;
    started_us   = (long)time::now();
    pending_area = api.client_get_area(c);
    // Build any string the hook will need NOW (a command handler runs on a
    // server thread, so the temp allocator is safe) and copy it into a buffer
    // you own. The hook then only has to broadcast those bytes.
    String msg = string::tformat("The challenge expired — nobody joined in time.");
    expiry_len = store_str(&expiry_buf[0], 160, msg);
}

fn bool on_ic_message(void* c, void* pkt) {
    if (pending && expiry_len > 0) {
        if ((long)time::now() - started_us > TIMEOUT_US) {
            pending = false;
            api.broadcast_area_msg(pending_area, (String)expiry_buf[0..expiry_len - 1]);
        }
    }
    return false;   // never consume the IC message
}
```

Register the hook in `init`:

```c3
api.register_hook("MS", &on_ic_message, "My Plugin");
```

Two things to keep in mind:

- **The timer only advances when a packet arrives.** An `MS` hook ticks on each
  IC message, so a perfectly silent room won't fire the timeout until someone
  speaks. That's usually fine — nobody's waiting in an empty room — but if you
  need it to fire regardless of chatter, also hook `CH` (the client keepalive),
  which clients send periodically even while idle.
- **Pre-building strings on the command thread (above) sidesteps the temp
  allocator in the hook entirely.** Calling `string::tformat` directly inside a
  hook is also fine in practice (hooks run on server threads, not plugin-spawned
  ones — the `music_logger` and `bg_scheduler` examples above format strings in
  their hooks), but the pre-build pattern is the belt-and-suspenders version and
  the safest thing to teach.

## Reading Config Files

Plugins can read `config/config.toml` to get server settings. Since the plugin
runs on the main thread during init, you can use C3's standard library there.
For file I/O that avoids any runtime issues, use C functions directly:

```c3
extern fn void* fopen_c(ZString path, ZString mode) @cname("fopen");
extern fn char* fgets_c(char* buf, CInt size, void* stream) @cname("fgets");
extern fn CInt fclose_c(void* stream) @cname("fclose");
```

See `server_advertiser.c3` for a complete config parser that reads `[server]`,
`[websocket]`, and custom `[advertiser]` sections from `config.toml`.

## Debugging

- Whisker logs plugin loading at startup: `[plugins] X plugins loaded`
- Use `io::printfn("[my_plugin] ...")` for debug logging
- Check that your exported function names match exactly

```bash
# Check if your plugin was loaded (look at server startup output)
./out/whisker 2>&1 | grep -i plugin
# Should show: [plugins] Loaded: My Plugin v1.0.0
# and: [plugins] 1 plugins loaded

# Common issues:
# - "missing required exports" → your @export names don't match exactly
# - "Failed to load" → wrong architecture, missing libc linkage, or bad file path
# - "undefined symbol: atexit" → add "linked-libraries": ["c"] to project.json, or pass -l c on the command line
# - "Segmentation fault" after plugins load → thread using C3 temp allocator (see Threading section above)
# - Plugin silently not loading → check file extension (.so on Linux, .dll on Windows)

# List what's in the plugins directory
ls -la plugins/
# Should show your .so/.dll files
```

## Plugin Development Workflow

Here's a typical workflow for developing a plugin:

```bash
# 1. Create your plugin source and build directory
mkdir -p ~/my-plugins/my_cool_plugin
# Write your plugin source file:
nano ~/my-plugins/my_cool_plugin.c3

# 2. Create project.json in the build directory
cat > ~/my-plugins/my_cool_plugin/project.json << 'EOF'
{
    "version": "1.0.0",
    "langrev": "1",
    "targets": {
        "my_cool_plugin": {
            "type": "dynamic-lib",
            "sources-override": ["../my_cool_plugin.c3"],
            "linked-libraries": ["c"]
        }
    }
}
EOF

# 3. Build it (Option A: project.json)
cd ~/my-plugins/my_cool_plugin
c3c build
# Or without project.json (Option B: command-line):
# c3c dynamic-lib ../my_cool_plugin.c3 -l c -o my_cool_plugin

# 4. Deploy to Whisker
cp out/my_cool_plugin.so /path/to/whisker/plugins/   # Linux
# or: cp out/my_cool_plugin.dll /path/to/whisker/plugins/   # Windows

# 5. Reload or restart Whisker to load it
# Option A: Type /reload in the server console (no restart needed!)
# Option B: Ctrl+C the running server, then start it again:
cd /path/to/whisker
./out/whisker

# 6. Test your command in-game
# In the AO2 client OOC chat, type: /your_command

# 7. If something's wrong, check the server terminal for your debug prints
# Make changes, rebuild, redeploy, restart — rinse and repeat
```

One-liner for the build-deploy-restart cycle:
```bash
# Using project.json:
c3c build && cp out/my_cool_plugin.so /path/to/whisker/plugins/ && echo "Deployed! Restart Whisker."

# Using command-line (no project.json):
c3c dynamic-lib my_cool_plugin.c3 -l c -o my_cool_plugin && cp my_cool_plugin.so /path/to/whisker/plugins/ && echo "Deployed!"
```

## Standalone vs. In-Tree Plugins

There are two ways to build a plugin:

### Standalone (recommended)

All the examples above and the production plugins in `OPTIONAL Plugins/` use
the standalone pattern. The plugin defines all types locally and communicates
with the server entirely through function pointers. This is the recommended
approach for distributable plugins.

### In-Tree (imports from server)

You can also place a `.c3` file in the server's `src/` directory and import
from Whisker's modules (`whisker::plugin`, `whisker::client`, etc.). This is
simpler for prototyping but ties your plugin to a specific server version and
requires recompiling the entire server.

Advantages of standalone:
- The plugin source file is completely self-contained
- It can be compiled without the server source tree
- It only depends on the `PluginAPI` struct layout matching the server
- Client pointers are `void*` (opaque) — interact through API function pointers only

See `case_manager.c3` and `server_advertiser.c3` in `OPTIONAL Plugins/` for
complete production standalone examples. Example 1 above shows the full
`PluginAPI` struct definition you can copy into any standalone plugin.

## Architecture Notes

Plugins are loaded once at server startup via `dlopen`/`LoadLibrary`.
They stay loaded for the lifetime of the server. Hot-reload is supported
via the `/reload` console command — this unloads all plugins, then
re-scans and re-loads them from the `plugins/` directory.

Plugin commands are checked BEFORE built-in commands. If your plugin
registers a command with the same name as a built-in, your plugin wins.

Packet hooks run BEFORE the default handler. Multiple plugins can hook
the same packet — they run in load order. If any hook returns `true`,
later hooks and the default handler are skipped.

### Limits

The server enforces static limits on loaded plugins:

| Limit | Value |
|-------|-------|
| Max plugins | 64 |
| Max plugin commands | 256 |
| Max plugin hooks | 256 |

These are compile-time constants in `plugin.c3`. If you hit them, you've
probably got too many plugins — but you can recompile the server with
higher values if needed.

## Version Compatibility

Your `PluginAPI` struct layout **must exactly match** the server's definition
in `plugin.c3`. If the server adds, removes, or reorders fields in `PluginAPI`,
your plugin will read garbage from the wrong function pointer offsets — this
usually manifests as a crash or silent corruption.

**How to stay safe:**
1. When updating the server, check if `PluginAPI` in `plugin.c3` has changed
   (look at the git diff for that struct).
2. If it changed, update your plugin's local `PluginAPI` copy to match.
3. Rebuild and redeploy your plugin.

The production plugins in `OPTIONAL Plugins/` are always kept in sync with the
server's struct. Copy the struct from `case_manager.c3` for the v2 field set,
from `player_list.c3` if you need the v3 lifecycle fields, or from
**`ip_guard.c3`** for the full current struct including the v4 connection-filter
fields at the end.

**The append-only guarantee (why old plugins keep working).** Whisker only ever
**appends** new fields to the *end* of `PluginAPI` — existing fields never move
or change type. So a plugin compiled against an older, shorter struct still finds
every function pointer it knows about at the right offset; it simply stops
reading before the newer fields and never touches them. That means **already-compiled
`.dll`/`.so` plugins keep working across these additions with no recompile** — v1
→ v2 (+15), → `args_split`, → `to_lower`, → v3's three lifecycle fields
(`register_lifecycle_hook`, `client_get_ooc_name`, `client_is_hidden`), and now
→ v4's three connection-filter fields (`client_get_ip`, `register_conn_filter`,
`broadcast_perm_raw`) have all been added this way. The only thing you must never
do in your own struct copy is *insert* or *reorder* fields. You only need to
update your copy (and recompile) when you actually want to *call* something newly
added.

## What the Extended API (v2) Adds

The original PluginAPI (31 functions) let plugins **listen and talk** — register
commands, hook packets, send messages, and query basic client info. But there
were significant gaps that made certain plugin categories impossible to build.

The v2 extension (15 additional functions) fills those gaps:

| Gap | Problem | v2 Solution |
|-----|---------|-------------|
| **Packet inspection** | Hooks received `void* packet` but couldn't read its fields — hooks could only react to *which* packet arrived, not *what it contained* | `packet_get_field(pkt, index)`, `packet_get_field_count(pkt)` |
| **Moderation actions** | Plugins couldn't kick, mute, or unmute — no way to build auto-mod, spam filters, or custom moderation | `client_kick(c)`, `client_mute(c)`, `client_unmute(c)` |
| **Server-wide broadcasts** | Could only broadcast to a single area, not the whole server — no global announcements | `broadcast_all_msg(msg)`, `broadcast_all_raw(data)` |
| **Area manipulation** | Couldn't read or change backgrounds, lock/unlock areas, or manage invites — area-management plugins were impossible | `area_get_background()`, `area_set_background()`, `area_get_lock()`, `area_set_lock()`, `area_invite()` |
| **Player counting** | No way to query how many players were online or in a specific area | `get_player_count()`, `get_area_player_count(area_id)` |
| **Player identification** | Couldn't identify players across reconnects for ban-style logic | `client_get_ipid(c)` |

**Backwards compatibility:** All 15 new fields are appended at the *end* of the
`PluginAPI` struct. Old compiled plugins only know about the first 31 fields and
never touch the new ones — they keep working without recompilation. New plugins
can use all 46.

One more field was appended later, the same backwards-compatible way:
`args_split` (a quote-aware argument tokenizer — see
[Parsing command arguments](#parsing-command-arguments)), bringing the total to
**47**. Plugins compiled before it was added stop at `area_invite` and simply
never read it, so they keep working untouched. A later field, `to_lower` (an
ASCII lower-caser — see [Lower-casing text](#lower-casing-text-to_lower)), was
appended the same way, bringing the total to **48**; plugins that predate it
stop at `args_split` and never read it.

**What this unlocks:** With the v2 API, you can now build auto-moderators,
spam filters, area lockdown systems, player count monitors, welcome-back
messages for returning players, packet rewriting hooks, and server-wide
event systems — none of which were possible before.

## What Lifecycle Hooks (v3) Add

v2 still left one category impossible: **stateful presence tracking.** Every v2
hook is packet-driven, and packets have two blind spots — a disconnect sends no
packet at all, and the client keepalive is only every ~45 s. So you could never
reliably answer "who is in the room right now?" from a plugin.

v3 appends three fields to close that gap:

| Field | Signature | Purpose |
|-------|-----------|---------|
| `register_lifecycle_hook` | `fn void(fn void(void*, int), String)` | Subscribe one handler to JOIN / LEAVE / UPDATE events. |
| `client_get_ooc_name` | `fn String(void*)` | The client's current OOC display name (`""` if unset). |
| `client_is_hidden` | `fn bool(void*)` | `true` for shadow mods (SHADOW role) — omit from public lists. |

See [Registering Lifecycle Hooks](#registering-lifecycle-hooks-v3) for the event
semantics and [Example 10](#example-10-joinleave-announcer-lifecycle-hooks-v3)
for a worked plugin.

**What this unlocks:** live player lists (the AO2 2.11 feature — shipped as the
optional `player_list` plugin), join/leave announcers, Discord presence bridges,
auto-roles on join, accurate "online now" tracking, and anything else that needs
to follow players coming, going, and changing — driven by real events instead of
polling. Backwards compatible exactly like v2: appended at the end, old plugins
untouched.

## What Connection Filters (v4) Add

v3 and earlier all act on a client that has **already connected** — by the time
any command, packet, or lifecycle hook fires, the server has accepted the socket
and spent a handler thread on it. There was no way for a plugin to influence
*whether a connection is accepted at all*, and no way to even see a client's real
IP (only the one-way hashed IPID).

v4 appends three fields to close that gap:

| Field | Signature | Purpose |
|-------|-----------|---------|
| `client_get_ip` | `fn String(void*)` | The client's **raw** IP (v4 dotted-quad or v6 hex), not the hashed IPID. |
| `register_conn_filter` | `fn void(fn bool(String), String)` | Subscribe a predicate the server calls for every inbound connection at accept time; return `true` to reject it before a thread is spawned. |
| `broadcast_perm_raw` | `fn void(String, ulong)` | Send a pre-built packet only to connected clients holding all bits of a permission mask (role-gated staff notices). |

See [Registering Connection Filters](#registering-connection-filters-v4) for the
mechanics and `OPTIONAL Plugins/ip_guard.c3` for a full worked plugin.

**What this unlocks:** IP / CIDR / ASN / country blocklists (shipped as the
optional `ip_guard` plugin), allow-lists, connection-rate policies, and any
access control that should happen *before* a connection costs a thread — plus,
via `broadcast_perm_raw`, role-gated staff alerting from any plugin. Backwards
compatible exactly like v2/v3: appended at the end, old plugins untouched.

## Hookable Packet Headers

These are the AO2 packet headers the server processes. You can hook any
of them with `api.register_hook()`. Hooks on unrecognized headers will
simply never fire.

### Handshake packets (pre-join)

| Header | Description | Notes |
|--------|-------------|-------|
| `HI` | Client sends hardware ID | First packet from client |
| `ID` | Client sends software name/version | |
| `askchaa` | Client requests character count | |
| `RC` | Client requests character list | |
| `RM` | Client requests music list | |
| `RD` | Client signals ready to join | Last handshake step — hook this for welcome messages |

### In-game packets (post-join)

| Header | Description | Notes |
|--------|-------------|-------|
| `CC` | Character select | Player picks a character |
| `MS` | IC (in-character) message | The main chat — most common hook target |
| `CT` | OOC (out-of-character) message | Also triggers command dispatch |
| `MC` | Music change / area move | Dual purpose: plays music or moves to area |
| `CH` | Keepalive / check | Heartbeat from client |
| `HP` | Health bar update | Prosecution/defense health bars |
| `PE` | Add evidence | |
| `EE` | Edit evidence | |
| `DE` | Delete evidence | |
| `RT` | Testimony recording toggle | WT/CE (witness testimony / cross examination) |
| `ZZ` | Mod call | Player calls for moderator help |
| `CASEA` | Case announcement | Player announces a case |

**Example:** To log every IC message and every music change:
```c3
api.register_hook("MS", &on_ic_message, "My Plugin");
api.register_hook("MC", &on_music_change, "My Plugin");
```

## Troubleshooting Flowchart

Plugin not loading? Walk through this:

```
Plugin not loading?
│
├─ Is the file in the plugins/ directory?
│  └─ No → Copy .so/.dll to plugins/
│
├─ Is the file extension correct?
│  ├─ Linux: must be .so
│  └─ Windows: must be .dll
│
├─ Does the server log "missing required exports"?
│  └─ Yes → Check your @export names match exactly:
│           whisker_plugin_info, whisker_plugin_init
│
├─ Does the server log "Failed to load"?
│  ├─ "undefined symbol: atexit"
│  │  └─ Add -l c or "linked-libraries": ["c"] (Linux only)
│  ├─ Architecture mismatch
│  │  └─ Build on the same platform as your server
│  └─ Other dlopen/LoadLibrary error
│     └─ Check the error message in parentheses
│
├─ Plugin loads but crashes (segfault)?
│  ├─ After loading → PluginAPI struct layout mismatch
│  │  └─ Copy struct from case_manager.c3 or plugin.c3
│  └─ During command/hook → Thread using C3 temp allocator
│     └─ See Threading section above
│
├─ Plugin loads but command doesn't work?
│  ├─ Command not showing in /help
│  │  └─ Check register_command() is called in init
│  ├─ "No permission"
│  │  └─ Check required_perms — use 0 for no restriction
│  └─ Wrong behavior
│     └─ Add io::printfn() debug prints, check server console
│
└─ Plugin silently not loading?
   ├─ Check server startup output for [plugins] lines
   ├─ Is there a file in plugins/? → ls -la plugins/
   └─ File permissions? → chmod +r on Linux
```
