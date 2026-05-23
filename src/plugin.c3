// Whisker AO2 Server — Plugin System
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The plugin system is the answer to AO server fragmentation.
// Instead of forking the whole server to add features, write
// a plugin. Plugins are shared libraries (.so / .dll) that
// export a standard interface. Drop them in plugins/ and they
// load at startup.
//
// Plugin Development Guide: see plugins/README.md
//
// == Plugin Interface ==
//
// Every plugin must export these C-callable functions:
//
//   whisker_plugin_info()     → returns name, version, author
//   whisker_plugin_init(api)  → called once at startup
//   whisker_plugin_shutdown() → called on server shutdown
//
// Plugins can:
//   - Register new OOC commands
//   - Hook into packet processing (before/after)
//   - Send messages to clients
//   - Access server state through the API
//
// Plugins CANNOT modify core server code. This is by design.
// If you need something the API doesn't expose, open an issue.

module whisker::plugin;

import whisker::client;
import whisker::protocol;
import std::io;

// ============================================================
// Plugin info — what the plugin tells us about itself
// ============================================================

struct PluginInfo {
    String name;
    String version;
    String author;
    String description;
}

// ============================================================
// Command handler type — plugins register these
// ============================================================

alias CommandHandler = fn void(client::Client* c, String args);

// ============================================================
// Packet hook type — plugins can intercept packets
// ============================================================

// Returns true to consume the packet (stop further processing).
alias PacketHook = fn bool(client::Client* c, protocol::Packet* pkt);

// ============================================================
// Registered plugin command
// ============================================================

struct PluginCommand {
    String         name;
    CommandHandler handler;
    ulong          required_perms;
    String         description;
    String         plugin_name;
}

// ============================================================
// Registered packet hook
// ============================================================

struct PluginPacketHook {
    String     header;  // which packet header to hook ("MS", "CT", etc.)
    PacketHook hook;
    String     plugin_name;
}

// ============================================================
// Plugin Manager
// ============================================================

const int MAX_PLUGINS         = 64;
const int MAX_PLUGIN_COMMANDS = 256;
const int MAX_PLUGIN_HOOKS    = 256;

struct PluginManager {
    PluginInfo[MAX_PLUGINS]              plugins;
    int                                   plugin_count;

    PluginCommand[MAX_PLUGIN_COMMANDS]   commands;
    int                                   command_count;

    PluginPacketHook[MAX_PLUGIN_HOOKS]   hooks;
    int                                   hook_count;
}

fn PluginManager new_manager() {
    PluginManager pm;
    pm.plugin_count = 0;
    pm.command_count = 0;
    pm.hook_count = 0;
    return pm;
}

// ============================================================
// Plugin API — passed to plugins during init
// ============================================================

// This struct is the bridge between plugins and the server.
// Plugins call these function pointers to interact with Whisker.

struct PluginAPI {
    PluginManager* manager;
}

// Register a new OOC command from a plugin.
fn void PluginAPI.register_command(
    &self,
    String name,
    CommandHandler handler,
    ulong required_perms,
    String description,
    String plugin_name
) {
    PluginManager* pm = self.manager;
    if (pm.command_count >= MAX_PLUGIN_COMMANDS) return;

    pm.commands[pm.command_count] = {
        .name = name,
        .handler = handler,
        .required_perms = required_perms,
        .description = description,
        .plugin_name = plugin_name,
    };
    pm.command_count++;
}

// Register a packet hook from a plugin.
fn void PluginAPI.register_hook(
    &self,
    String header,
    PacketHook hook,
    String plugin_name
) {
    PluginManager* pm = self.manager;
    if (pm.hook_count >= MAX_PLUGIN_HOOKS) return;

    pm.hooks[pm.hook_count] = {
        .header = header,
        .hook = hook,
        .plugin_name = plugin_name,
    };
    pm.hook_count++;
}

// ============================================================
// Plugin loading — scan directory and load shared libraries
// ============================================================

fn void load_all(PluginManager* pm, String directory) {
    io::printfn("[plugins] Scanning '%s' for plugins...", directory);

    // In a full implementation, this would:
    // 1. List all .so / .dll files in the directory
    // 2. For each file:
    //    a. dlopen() / LoadLibrary() the file
    //    b. dlsym() / GetProcAddress() for whisker_plugin_info
    //    c. Call whisker_plugin_info() to get plugin metadata
    //    d. dlsym() for whisker_plugin_init
    //    e. Create a PluginAPI and call whisker_plugin_init(&api)
    //    f. Register the plugin
    //
    // Example (POSIX):
    //   void* handle = dlopen("plugins/my_plugin.so", RTLD_NOW);
    //   auto info_fn = (PluginInfoFn)dlsym(handle, "whisker_plugin_info");
    //   PluginInfo info = info_fn();
    //   auto init_fn = (PluginInitFn)dlsym(handle, "whisker_plugin_init");
    //   PluginAPI api = { .manager = pm };
    //   init_fn(&api);
    //
    // Example (Windows):
    //   HMODULE handle = LoadLibraryA("plugins\\my_plugin.dll");
    //   auto info_fn = GetProcAddress(handle, "whisker_plugin_info");
    //   ...
    //
    // C3 provides access to these via:
    //   import std::os::posix;   // dlopen, dlsym
    //   import std::os::win32;   // LoadLibraryA, GetProcAddress

    io::printfn("[plugins] %d plugins loaded, %d commands registered, %d hooks registered.",
        pm.plugin_count, pm.command_count, pm.hook_count);
}

// ============================================================
// Plugin dispatch — called by the server
// ============================================================

// Check if any plugin wants to handle this command.
// Returns true if a plugin consumed it.
fn bool on_command(PluginManager* pm, client::Client* c, String cmd_name, String args) {
    for (int i = 0; i < pm.command_count; i++) {
        if (pm.commands[i].name == cmd_name) {
            // Permission check
            if (pm.commands[i].required_perms != 0 &&
                !c.has_permission(pm.commands[i].required_perms)) {
                c.send_server_message("No permission.");
                return true;
            }

            pm.commands[i].handler(c, args);
            return true;
        }
    }
    return false;
}

// Check if any plugin wants to intercept this packet.
// Returns true if a plugin consumed it (stop processing).
fn bool on_packet(PluginManager* pm, client::Client* c, protocol::Packet* pkt) {
    for (int i = 0; i < pm.hook_count; i++) {
        if (pm.hooks[i].header == pkt.header) {
            if (pm.hooks[i].hook(c, pkt)) {
                return true; // Consumed
            }
        }
    }
    return false;
}
