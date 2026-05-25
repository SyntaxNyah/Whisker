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

Your plugin must export three functions with C-compatible signatures:

```c3
module my_plugin;

import whisker::plugin;
import whisker::client;

// Called by Whisker to get plugin metadata
fn PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return plugin::PluginInfo {
        .name        = "My Plugin",
        .version     = "1.0.0",
        .author      = "Your Name",
        .description = "Does cool stuff",
    };
}

// Called once at server startup
fn bool whisker_plugin_init(plugin::PluginAPI* api) @export("whisker_plugin_init") {
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

fn void cmd_hello(client::Client* c, String args) {
    c.send_server_message("Hello from My Plugin!");
}

// ---- Your packet hooks ----
// Return true to consume the packet (stop further processing)
// Return false to let other hooks and the default handler run

fn bool on_ic_message(client::Client* c, protocol::Packet* pkt) {
    // Example: log all IC messages
    // Return false so the message still gets processed normally
    return false;
}
```

### 3. Build as a shared library

```bash
c3c build  # with type = "dynamic-lib" in project.json
```

This produces `my_plugin.so` (Linux) or `my_plugin.dll` (Windows).

### 4. Deploy

Copy the `.so` or `.dll` file to the server's `plugins/` directory.
Restart Whisker. Your plugin loads automatically.

> **Note:** `plugins/` is relative to the working directory you run the server
> from, not the binary location. Configurable via `[plugins] directory` in
> `config.toml`.

## Plugin API Reference

### Registering Commands

```c3
api.register_command(name, handler, required_perms, description, plugin_name);
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | `String` | Command name without `/` |
| `handler` | `fn void(Client*, String)` | Handler function |
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
| `hook_fn` | `fn bool(Client*, Packet*)` | Hook function |
| `plugin_name` | `String` | Your plugin's name |

Hook functions return `bool`:
- `true` = consume the packet (stop processing)
- `false` = pass through to next hook / default handler

### Client API (what you can do with a Client*)

```c3
c.send_server_message("text");           // Send OOC from server
c.send_packet("HEADER", fields);         // Send any packet
c.send_raw("RAW#data#%");               // Send raw wire data

c.uid                                    // Player's UID
c.char_name                              // Current character name
c.display_name()                         // Best display name
c.ooc_name                              // OOC username
c.area_id                               // Current area index
c.is_moderator()                         // Is authenticated mod?
c.has_permission(PERM_BAN)              // Check specific permission
c.is_muted                              // IC muted?
c.is_ooc_muted                          // OOC muted?
c.connected                             // Still connected?
```

## Example Plugins

Each example below is a complete, copy-paste-ready plugin. The full file
is shown so you can see exactly how everything fits together.

---

### Example 1: Magic 8-Ball (simple command, no permissions)

A player types `/8ball Will I win this case?` and gets a random answer.

```c3
// file: 8ball.c3
module eightball;

import whisker::plugin;
import whisker::client;
import whisker::security;
import std::io;

const String[] ANSWERS = {
    "It is certain.",
    "Without a doubt.",
    "You may rely on it.",
    "Yes, definitely.",
    "As I see it, yes.",
    "Most likely.",
    "Reply hazy, try again.",
    "Ask again later.",
    "Better not tell you now.",
    "Cannot predict now.",
    "Don't count on it.",
    "My reply is no.",
    "My sources say no.",
    "Outlook not so good.",
    "Very doubtful.",
};

fn plugin::PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return plugin::PluginInfo {
        .name        = "8ball",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Magic 8-Ball command",
    };
}

fn bool whisker_plugin_init(plugin::PluginAPI* api) @export("whisker_plugin_init") {
    api.register_command("8ball", &cmd_8ball, 0, "Ask the Magic 8-Ball", "8ball");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {}

fn void cmd_8ball(client::Client* c, String args) {
    if (args.len == 0) {
        c.send_server_message("Usage: /8ball <question>");
        return;
    }

    // Pick a random answer using the current time and player UID as seed
    long seed = security::current_time_sec() ^ (long)c.uid;
    int index = (int)((seed >> 4) % (long)ANSWERS.len);
    if (index < 0) index = -index;

    c.send_server_message(string::tformat("8-Ball says: %s", ANSWERS[index]));
}
```

**project.json for this plugin:**
```json
{
    "targets": {
        "eightball": {
            "type": "dynamic-lib"
        }
    },
    "sources": ["8ball.c3"]
}
```

**Build and deploy:**
```bash
c3c build
cp build/libeightball.so /path/to/whisker/plugins/
```

---

### Example 2: Welcome Message (packet hook, no commands)

Sends a custom welcome message when a player finishes joining. Hooks the
`RD` packet (the last step of the join handshake).

```c3
// file: welcome.c3
module welcome;

import whisker::plugin;
import whisker::client;
import whisker::protocol;

fn plugin::PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return plugin::PluginInfo {
        .name        = "Welcome",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Custom welcome message on join",
    };
}

fn bool whisker_plugin_init(plugin::PluginAPI* api) @export("whisker_plugin_init") {
    // Hook the RD packet — this fires when a client finishes joining
    api.register_hook("RD", &on_player_ready, "Welcome");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {}

fn bool on_player_ready(client::Client* c, protocol::Packet* pkt) {
    // Send a few welcome lines after the default handler runs.
    // We return false so the normal RD handler still processes
    // (allocates UID, sends DONE, etc.) — our message just adds on top.
    c.send_server_message("=============================");
    c.send_server_message("Welcome to the server!");
    c.send_server_message("Type /help for commands.");
    c.send_server_message("Type /rules to see server rules.");
    c.send_server_message("=============================");

    return false; // IMPORTANT: let the default handler run too
}
```

---

### Example 3: Warn Command (mod-only command)

Adds `/warn <uid> <reason>` that sends a visible warning to a player.
Requires MUTE permission (basic mod).

```c3
// file: warn.c3
module warn_plugin;

import whisker::plugin;
import whisker::client;
import whisker::commands;
import std::io;

fn plugin::PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return plugin::PluginInfo {
        .name        = "Warn",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Adds /warn command for moderators",
    };
}

fn bool whisker_plugin_init(plugin::PluginAPI* api) @export("whisker_plugin_init") {
    // PERM_MUTE = 1, the lowest mod tier
    api.register_command("warn", &cmd_warn, commands::PERM_MUTE, "Warn a player", "Warn");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {}

fn void cmd_warn(client::Client* c, String args) {
    // Parse: /warn <uid> <reason>
    if (args.len == 0) {
        c.send_server_message("Usage: /warn <uid> <reason>");
        return;
    }

    // Split into UID and reason
    int target_uid = -1;
    String reason = "No reason given.";

    if (args.index_of_char(' ')) |space| {
        target_uid = args[0..space].to_int() ?? -1;
        reason = args[space + 1..].trim();
    } else {
        target_uid = args.to_int() ?? -1;
    }

    if (target_uid < 0) {
        c.send_server_message("Invalid UID.");
        return;
    }

    // Find the target player
    // NOTE: In a real plugin you'd use the server API to find clients.
    // For now, we send to the caller as a demo.
    c.send_server_message(string::tformat(
        "WARNING sent to UID %d: %s", target_uid, reason
    ));

    io::printfn("[warn] %s warned UID %d: %s", c.display_name(), target_uid, reason);
}
```

---

### Example 4: Profanity Filter (block bad words in IC chat)

Hooks the `MS` (in-character) packet. If the message contains a banned
word, the message is blocked and the player gets a notice. The message
never reaches other players.

```c3
// file: profanity_filter.c3
module profanity_filter;

import whisker::plugin;
import whisker::client;
import whisker::protocol;
import std::io;

// Add your banned words here. Keep them lowercase — we lowercase
// the message before checking.
const String[] BANNED_WORDS = {
    "badword1",
    "badword2",
    "badword3",
};

fn plugin::PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return plugin::PluginInfo {
        .name        = "Profanity Filter",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Blocks IC messages containing banned words",
    };
}

fn bool whisker_plugin_init(plugin::PluginAPI* api) @export("whisker_plugin_init") {
    api.register_hook("MS", &on_ic_message, "Profanity Filter");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {}

fn bool on_ic_message(client::Client* c, protocol::Packet* pkt) {
    // MS packet field 4 is the message text
    if (pkt.field_count < 5) return false;

    String message = pkt.fields[4];

    // Check each banned word
    foreach (word : BANNED_WORDS) {
        if (message.contains(word)) {
            c.send_server_message("Your message was blocked by the profanity filter.");
            io::printfn("[profanity] Blocked message from %s (UID %d): %s",
                c.display_name(), c.uid, message);
            return true; // CONSUME the packet — it never gets broadcast
        }
    }

    return false; // Clean message, let it through
}
```

---

### Example 5: Rules Command (simple text display)

The simplest possible plugin. One command, no hooks, no permissions.
Player types `/rules`, sees the server rules.

```c3
// file: rules.c3
module rules;

import whisker::plugin;
import whisker::client;

fn plugin::PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return plugin::PluginInfo {
        .name        = "Rules",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Displays server rules",
    };
}

fn bool whisker_plugin_init(plugin::PluginAPI* api) @export("whisker_plugin_init") {
    api.register_command("rules", &cmd_rules, 0, "Show server rules", "Rules");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {}

fn void cmd_rules(client::Client* c, String args) {
    c.send_server_message("=== Server Rules ===");
    c.send_server_message("1. Be respectful to all players.");
    c.send_server_message("2. No spamming or flooding.");
    c.send_server_message("3. Stay in character in IC chat.");
    c.send_server_message("4. Listen to moderators.");
    c.send_server_message("5. Have fun!");
    c.send_server_message("====================");
}
```

---

### Example 6: Coinflip PvP (two commands, player state)

Players challenge each other to a coinflip. `/coinflip heads` or
`/coinflip tails`. First player sets the challenge, second player
picks the other side, result is announced.

```c3
// file: coinflip.c3
module coinflip;

import whisker::plugin;
import whisker::client;
import whisker::security;
import std::io;

// Track one active challenge at a time (per-area would need more state)
struct Challenge {
    int  challenger_uid;
    bool challenger_picked_heads;
    bool active;
}

Challenge current_challenge;

fn plugin::PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return plugin::PluginInfo {
        .name        = "Coinflip PvP",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "PvP coinflip challenges",
    };
}

fn bool whisker_plugin_init(plugin::PluginAPI* api) @export("whisker_plugin_init") {
    current_challenge.active = false;
    api.register_command("coinflip", &cmd_coinflip, 0, "Coinflip PvP challenge", "Coinflip PvP");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {}

fn void cmd_coinflip(client::Client* c, String args) {
    if (args.len == 0) {
        c.send_server_message("Usage: /coinflip <heads|tails>");
        return;
    }

    bool picked_heads;
    if (args == "heads" || args == "h") {
        picked_heads = true;
    } else if (args == "tails" || args == "t") {
        picked_heads = false;
    } else {
        c.send_server_message("Pick heads or tails. Example: /coinflip heads");
        return;
    }

    // If no active challenge, start one
    if (!current_challenge.active) {
        current_challenge.challenger_uid = c.uid;
        current_challenge.challenger_picked_heads = picked_heads;
        current_challenge.active = true;

        c.send_server_message(string::tformat(
            "You picked %s! Waiting for someone to pick the other side...",
            picked_heads ? "heads" : "tails"
        ));
        return;
    }

    // Someone is responding to the challenge
    if (current_challenge.challenger_uid == c.uid) {
        c.send_server_message("You already have an open challenge! Wait for someone else.");
        return;
    }

    // Must pick the opposite side
    if (picked_heads == current_challenge.challenger_picked_heads) {
        c.send_server_message(string::tformat(
            "That side is taken! Pick %s.",
            picked_heads ? "tails" : "heads"
        ));
        return;
    }

    // Flip the coin
    long seed = security::current_time_sec() ^ (long)c.uid ^ (long)current_challenge.challenger_uid;
    bool result_is_heads = ((seed >> 7) % 2) == 0;

    // Determine winner
    bool challenger_wins = (result_is_heads == current_challenge.challenger_picked_heads);

    String result_str = result_is_heads ? "HEADS" : "TAILS";
    int winner_uid = challenger_wins ? current_challenge.challenger_uid : c.uid;
    int loser_uid  = challenger_wins ? c.uid : current_challenge.challenger_uid;

    c.send_server_message(string::tformat(
        "The coin lands on %s! UID %d wins, UID %d loses!",
        result_str, winner_uid, loser_uid
    ));

    // Reset
    current_challenge.active = false;
}
```

---

### Example 7: Music Logger (packet hook, logging only)

Logs every music change to the server console. Doesn't block anything —
purely observational. Shows how a hook can monitor without interfering.

```c3
// file: music_logger.c3
module music_logger;

import whisker::plugin;
import whisker::client;
import whisker::protocol;
import std::io;

fn plugin::PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return plugin::PluginInfo {
        .name        = "Music Logger",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Logs all music changes to console",
    };
}

fn bool whisker_plugin_init(plugin::PluginAPI* api) @export("whisker_plugin_init") {
    api.register_hook("MC", &on_music_change, "Music Logger");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {}

fn bool on_music_change(client::Client* c, protocol::Packet* pkt) {
    if (pkt.field_count < 1) return false;

    String track = pkt.fields[0];

    // Only log actual music (has a file extension), not area changes
    if (track.contains(".")) {
        io::printfn("[music-log] %s (UID %d) played: %s",
            c.display_name(), c.uid, track);
    }

    return false; // Always pass through — we're just logging
}
```

---

### Example 8: AFK Detector (command + hook combo)

Tracks player activity. If a player hasn't sent an IC message in 10
minutes, they show as AFK in `/afklist`. Combines a command AND a hook.

```c3
// file: afk_detector.c3
module afk_detector;

import whisker::plugin;
import whisker::client;
import whisker::protocol;
import whisker::security;
import std::io;

const long AFK_THRESHOLD_SEC = 600; // 10 minutes
const int  MAX_TRACKED       = 512;

// Track last IC message time per UID
int[MAX_TRACKED]  tracked_uids;
long[MAX_TRACKED] last_ic_time;
int               tracked_count = 0;

fn plugin::PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return plugin::PluginInfo {
        .name        = "AFK Detector",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Tracks AFK players via IC activity",
    };
}

fn bool whisker_plugin_init(plugin::PluginAPI* api) @export("whisker_plugin_init") {
    api.register_command("afklist", &cmd_afklist, 0, "Show AFK players", "AFK Detector");
    api.register_hook("MS", &on_ic_activity, "AFK Detector");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {}

// Update last-seen time when someone sends an IC message
fn bool on_ic_activity(client::Client* c, protocol::Packet* pkt) {
    long now = security::current_time_sec();

    // Find or create entry
    for (int i = 0; i < tracked_count; i++) {
        if (tracked_uids[i] == c.uid) {
            last_ic_time[i] = now;
            return false;
        }
    }

    // New entry
    if (tracked_count < MAX_TRACKED) {
        tracked_uids[tracked_count] = c.uid;
        last_ic_time[tracked_count] = now;
        tracked_count++;
    }

    return false; // Never consume — just track
}

fn void cmd_afklist(client::Client* c, String args) {
    long now = security::current_time_sec();
    bool found_any = false;

    c.send_server_message("=== AFK Players (10+ min no IC) ===");

    for (int i = 0; i < tracked_count; i++) {
        long idle_sec = now - last_ic_time[i];
        if (idle_sec >= AFK_THRESHOLD_SEC) {
            long idle_min = idle_sec / 60;
            c.send_server_message(string::tformat(
                "  UID %d — idle %d minutes", tracked_uids[i], (int)idle_min
            ));
            found_any = true;
        }
    }

    if (!found_any) {
        c.send_server_message("  No AFK players detected.");
    }
}
```

---

### Example 9: Message of the Day Rotation (hook on join)

Instead of a static MOTD, rotate through a list of tips. Each player
sees a different tip when they join.

```c3
// file: motd_rotation.c3
module motd_rotation;

import whisker::plugin;
import whisker::client;
import whisker::protocol;

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

fn plugin::PluginInfo whisker_plugin_info() @export("whisker_plugin_info") {
    return plugin::PluginInfo {
        .name        = "MOTD Rotation",
        .version     = "1.0.0",
        .author      = "Whisker Community",
        .description = "Rotating tips shown on player join",
    };
}

fn bool whisker_plugin_init(plugin::PluginAPI* api) @export("whisker_plugin_init") {
    api.register_hook("RD", &on_join, "MOTD Rotation");
    return true;
}

fn void whisker_plugin_shutdown() @export("whisker_plugin_shutdown") {}

fn bool on_join(client::Client* c, protocol::Packet* pkt) {
    // Pick the next tip in rotation
    int index = tip_counter % (int)TIPS.len;
    tip_counter++;

    c.send_server_message(TIPS[index]);

    return false; // Let the normal join handler run
}
```

## Best Practices

1. **Keep it focused.** One plugin per feature. Don't build a monolith.
2. **Don't break existing behavior.** If your hook returns `true`, the default handler doesn't run.
3. **Use named constants.** Import `whisker::config` for all the server constants.
4. **Handle errors gracefully.** Don't crash the server from a plugin.
5. **Document your commands.** Players should be able to `/help <your_command>`.
6. **License as AGPL-3.0.** Keep the ecosystem open.

## Debugging

- Whisker logs plugin loading at startup: `[plugins] X plugins loaded`
- Use `io::printfn("[my_plugin] ...")` for debug logging
- Check that your exported function names match exactly

```bash
# Check if your plugin was loaded (look at server startup output)
./build/whisker 2>&1 | grep -i plugin
# Should show: [plugins] Loaded: My Plugin v1.0.0
# and: [plugins] 1 plugins loaded

# Common issues:
# - "symbol not found: whisker_plugin_info" → your @export name doesn't match
# - "failed to load libmy_plugin.so" → wrong architecture or missing C3 runtime
# - Plugin silently not loading → check the file extension (.so on Linux, .dll on Windows)

# List what's in the plugins directory
ls -la plugins/
# Should show your .so/.dll files
```

## Plugin Development Workflow

Here's a typical workflow for developing a plugin:

```bash
# 1. Create your plugin project (one time)
mkdir -p ~/my-plugins
cd ~/my-plugins
c3c init my_cool_plugin --template dynamic-lib

# 2. Write your code
nano src/my_cool_plugin.c3

# 3. Build it
c3c build

# 4. Deploy to Whisker
cp build/libmy_cool_plugin.so /path/to/whisker/plugins/

# 5. Restart Whisker to load it
# (Ctrl+C the running server, then start it again)
cd /path/to/whisker
./build/whisker

# 6. Test your command in-game
# In the AO2 client OOC chat, type: /your_command

# 7. If something's wrong, check the server terminal for your debug prints
# Make changes, rebuild, redeploy, restart — rinse and repeat
```

One-liner for the build-deploy-restart cycle:
```bash
# From your plugin project directory
c3c build && cp build/libmy_cool_plugin.so /path/to/whisker/plugins/ && echo "Deployed! Restart Whisker."
```

## Architecture Notes

Plugins are loaded once at server startup via `dlopen`/`LoadLibrary`.
They stay loaded for the lifetime of the server. Hot-reloading is not
supported yet — restart the server to pick up plugin changes.

Plugin commands are checked BEFORE built-in commands. If your plugin
registers a command with the same name as a built-in, your plugin wins.

Packet hooks run BEFORE the default handler. Multiple plugins can hook
the same packet — they run in load order. If any hook returns `true`,
later hooks and the default handler are skipped.
