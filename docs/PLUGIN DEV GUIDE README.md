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
Requires MUTE permission (permission bit 1).

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
    if (args.len == 0) {
        api.client_send_msg(c, "Usage: /warn <uid> <reason>");
        return;
    }

    int target_uid = -1;
    String reason = "No reason given.";

    if (try space = args.index_of_char(' ')) {
        target_uid = args[0..space - 1].to_int() ?? -1;
        reason = args[space + 1..].trim();
    } else {
        target_uid = args.to_int() ?? -1;
    }

    if (target_uid < 0) {
        api.client_send_msg(c, "Invalid UID.");
        return;
    }

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

## Best Practices

1. **Keep it focused.** One plugin per feature. Don't build a monolith.
2. **Don't break existing behavior.** If your hook returns `true`, the default handler doesn't run.
3. **Use named constants.** Define permission bits and status codes as `const` values.
4. **Handle errors gracefully.** Don't crash the server from a plugin.
5. **Document your commands.** Players should be able to `/help <your_command>`.
6. **Use the standalone pattern.** Define types locally so your plugin compiles independently.
7. **License as AGPL-3.0.** Keep the ecosystem open.

## Threading in Plugins

If your plugin spawns threads (e.g., for background tasks like heartbeats), you **must not**
use C3's temp allocator (`dstring::temp()`, `string::tformat()`, `@pool_init()`) in the
thread function. Standalone plugins are loaded via `dlopen`/`LoadLibrary`, which gives the
plugin its own copy of the C3 runtime. Thread-local storage (TLS) for the temp allocator
doesn't work correctly across this boundary, causing segfaults.

**The safe pattern:**

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

The production plugins in `OPTIONAL Plugins/` (especially `case_manager.c3`)
are always kept in sync with the server's struct. Copy the struct from there
when in doubt.

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

**What this unlocks:** With the v2 API, you can now build auto-moderators,
spam filters, area lockdown systems, player count monitors, welcome-back
messages for returning players, packet rewriting hooks, and server-wide
event systems — none of which were possible before.

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
