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

// Server/Area operations
api.find_client(uid)                     // Find client by UID (void*)
api.broadcast_area_msg(area_id, "text")  // OOC message to entire area
api.broadcast_area_raw(area_id, "data")  // Raw packet to entire area
api.broadcast_arup(arup_type)            // Broadcast area update
api.get_area_count()                     // Number of areas (int)
api.force_move(c, new_area_id)           // Move client to area

// CM (Case Manager) operations
api.area_is_cm(area_id, uid)             // Is UID a CM? (bool)
api.area_add_cm(area_id, uid)            // Add UID as CM
api.area_remove_cm(area_id, uid)         // Remove UID from CM
api.area_cm_count(area_id)               // Number of CMs (int)
api.area_clear_cms(area_id)              // Remove all CMs
api.area_uninvite(area_id, uid)          // Remove from invite list
api.area_set_status(area_id, status)     // Set area status
api.area_get_status(area_id)             // Get area status (int)
api.area_get_name(area_id)               // Get area name (String)
api.area_set_song(area_id, song, uid)    // Set playing song
```

## Example Plugins

Each example below uses the standalone pattern — types defined locally,
`void*` handler parameters, PluginAPI function pointers. This is the
same pattern used by the production plugins in `OPTIONAL Plugins/`.

**Important:** The `PluginAPI` struct layout must exactly match the server's
definition in `plugin.c3`. For production plugins, copy the full struct from
`case_manager.c3` — it has every field correctly defined. The examples below
include the full struct so they are self-contained and copy-paste-ready.

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
}

PluginAPI* api;

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return { "Rules", "1.0.0", "Whisker Community", "Displays server rules" };
}

fn void whisker_plugin_init(PluginAPI* a) @export("whisker_plugin_init") {
    api = a;
    api.register_command("rules", &cmd_rules, 0, "Show server rules", "Rules");
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

> The `PluginAPI` struct is the same as Example 1 — omitted for brevity.
> Copy it from Example 1 or from `case_manager.c3`.

```c3
// file: welcome.c3
module welcome;

struct PluginInfo { String name; String version; String author; String description; }
// ... PluginAPI struct same as Example 1 (omitted for brevity) ...

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
    api.client_send_msg(c, "=============================");
    api.client_send_msg(c, "Welcome to the server!");
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

### Example 5: Music Logger (packet hook, logging only)

Logs every music change to the server console. Doesn't block anything —
purely observational. Shows how a hook can monitor without interfering.

```c3
// file: music_logger.c3
module music_logger;

import std::io;

struct PluginInfo { String name; String version; String author; String description; }
// ... PluginAPI struct same as Example 1 (omitted for brevity) ...

PluginAPI* api;

fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return { "Music Logger", "1.0.0", "Whisker Community", "Logs music changes to console" };
}

fn void whisker_plugin_init(PluginAPI* a) @export("whisker_plugin_init") {
    api = a;
    api.register_hook("MC", &on_music_change, "Music Logger");
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {}

fn bool on_music_change(void* c, void* pkt) {
    io::printfn("[music-log] %s (UID %d) changed music.",
        api.client_display_name(c), api.client_get_uid(c));
    return false; // Always pass through — we're just logging
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

# 5. Restart Whisker to load it
# (Ctrl+C the running server, then start it again)
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
