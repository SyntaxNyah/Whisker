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
// Handler types — plugins register these
// ============================================================

// Command handler. Client pointer is void* for ABI compatibility
// with standalone plugins (.dll/.so).
alias CommandHandler = fn void(void* client, String args);

// Packet hook. Returns true to consume the packet (stop processing).
// Both pointers are void* for standalone plugin compatibility.
alias PacketHook = fn bool(void* client, void* packet);

// ============================================================
// Plugin API function pointer types
// ============================================================
//
// These define the function signatures for the PluginAPI struct.
// The server fills these in with wrapper functions during init.
// Standalone plugins call these to interact with the server.

// -- Registration --
alias ApiRegisterCommandFn = fn void(String name, CommandHandler handler, ulong perms, String desc, String plugin_name);
alias ApiRegisterHookFn    = fn void(String header, PacketHook hook, String plugin_name);

// -- Server operations --
alias ApiFindClientFn        = fn void*(int uid);
alias ApiBroadcastAreaMsgFn  = fn void(int area_id, String msg);
alias ApiBroadcastAreaRawFn  = fn void(int area_id, String data);
alias ApiBroadcastArupFn     = fn void(int arup_type);
alias ApiGetAreaCountFn      = fn int();

// -- Area operations --
alias ApiAreaIsCmFn         = fn bool(int area_id, int uid);
alias ApiAreaAddCmFn        = fn void(int area_id, int uid);
alias ApiAreaRemoveCmFn     = fn void(int area_id, int uid);
alias ApiAreaCmCountFn      = fn int(int area_id);
alias ApiAreaClearCmsFn     = fn void(int area_id);
alias ApiAreaUninviteFn     = fn void(int area_id, int uid);
alias ApiAreaSetStatusFn    = fn void(int area_id, int status);
alias ApiAreaGetStatusFn    = fn int(int area_id);
alias ApiAreaGetNameFn      = fn String(int area_id);
alias ApiAreaSetSongFn      = fn void(int area_id, String song, int player_uid);
alias ApiForceMoveFn        = fn void(void* client, int new_area_id);

// -- Client operations --
alias ApiClientSendMsgFn     = fn void(void* client, String msg);
alias ApiClientSendRawFn     = fn void(void* client, String data);
alias ApiClientGetUidFn      = fn int(void* client);
alias ApiClientGetAreaFn     = fn int(void* client);
alias ApiClientIsModFn       = fn bool(void* client);
alias ApiClientDisplayNameFn = fn String(void* client);
alias ApiClientGetCharIdFn   = fn int(void* client);
alias ApiClientGetShownameFn = fn String(void* client);
alias ApiClientGetCharNameFn = fn String(void* client);
alias ApiClientIsJoinedFn    = fn bool(void* client);
alias ApiClientSetPositionFn = fn void(void* client, String pos);

// ============================================================
// Plugin API — passed to plugins during init
// ============================================================
//
// This struct is the bridge between standalone plugins and the
// server. Each field is a function pointer that the server fills
// in during initialization. Plugins store the API pointer and
// call these functions to interact with Whisker.

struct PluginAPI {
    // Registration
    ApiRegisterCommandFn  register_command;
    ApiRegisterHookFn     register_hook;

    // Server
    ApiFindClientFn       find_client;
    ApiBroadcastAreaMsgFn broadcast_area_msg;
    ApiBroadcastAreaRawFn broadcast_area_raw;
    ApiBroadcastArupFn    broadcast_arup;
    ApiGetAreaCountFn     get_area_count;

    // Area
    ApiAreaIsCmFn         area_is_cm;
    ApiAreaAddCmFn        area_add_cm;
    ApiAreaRemoveCmFn     area_remove_cm;
    ApiAreaCmCountFn      area_cm_count;
    ApiAreaClearCmsFn     area_clear_cms;
    ApiAreaUninviteFn     area_uninvite;
    ApiAreaSetStatusFn    area_set_status;
    ApiAreaGetStatusFn    area_get_status;
    ApiAreaGetNameFn      area_get_name;
    ApiAreaSetSongFn      area_set_song;
    ApiForceMoveFn        force_move;

    // Client
    ApiClientSendMsgFn     client_send_msg;
    ApiClientSendRawFn     client_send_raw;
    ApiClientGetUidFn      client_get_uid;
    ApiClientGetAreaFn     client_get_area;
    ApiClientIsModFn       client_is_mod;
    ApiClientDisplayNameFn client_display_name;
    ApiClientGetCharIdFn   client_get_char_id;
    ApiClientGetShownameFn client_get_showname;
    ApiClientGetCharNameFn client_get_char_name;
    ApiClientIsJoinedFn    client_is_joined;
    ApiClientSetPositionFn client_set_position;
}

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
// Plugin loading — scan directory and load shared libraries
// ============================================================

fn void load_all(PluginManager* pm, PluginAPI* api, String directory) {
    io::printfn("[plugins] Scanning '%s' for plugins...", directory);

    // In a full implementation, this would:
    // 1. List all .so / .dll files in the directory
    // 2. For each file:
    //    a. dlopen() / LoadLibrary() the file
    //    b. dlsym() / GetProcAddress() for whisker_plugin_info
    //    c. Call whisker_plugin_info() to get plugin metadata
    //    d. dlsym() for whisker_plugin_init
    //    e. Call whisker_plugin_init(api) — pass the full API
    //    f. Register the plugin info
    //
    // Example (POSIX):
    //   void* handle = dlopen("plugins/my_plugin.so", RTLD_NOW);
    //   auto info_fn = (PluginInfoFn)dlsym(handle, "whisker_plugin_info");
    //   PluginInfo info = info_fn();
    //   auto init_fn = (PluginInitFn)dlsym(handle, "whisker_plugin_init");
    //   init_fn(api);
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
