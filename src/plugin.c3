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
// C interop — shared library loading (platform-conditional)
// ============================================================

// Shared library loading — Windows
extern fn void* load_library_a(char* path) @cname("LoadLibraryA") @if(env::WIN32);
extern fn void* get_proc_address(void* handle, char* name) @cname("GetProcAddress") @if(env::WIN32);
extern fn int free_library(void* handle) @cname("FreeLibrary") @if(env::WIN32);

// Shared library loading — POSIX
extern fn void* dlopen(char* path, int flags) @if(!env::WIN32);
extern fn void* dlsym(void* handle, char* name) @if(!env::WIN32);
extern fn int dlclose(void* handle) @if(!env::WIN32);
extern fn char* dlerror() @if(!env::WIN32);

const int RTLD_NOW = 2;

// Directory scanning — Windows
extern fn void* win_popen(char* cmd, char* mode) @cname("_popen") @if(env::WIN32);
extern fn int win_pclose(void* stream) @cname("_pclose") @if(env::WIN32);

// Directory scanning — POSIX
extern fn void* popen(char* cmd, char* mode) @if(!env::WIN32);
extern fn int pclose(void* stream) @if(!env::WIN32);

extern fn char* fgets(char* buf, int n, void* stream);

// ============================================================
// Plugin export function pointer types
// ============================================================

alias PluginInfoFn     = fn PluginInfo();
alias PluginInitFn     = fn void(PluginAPI*);
alias PluginShutdownFn = fn void();

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

// -- Extended API (v2) --
// New fields appended at the end for backwards compatibility.
// Existing plugins compiled against v1 still work — they just
// don't see these fields.

// Broadcasting to all players
alias ApiBroadcastAllMsgFn   = fn void(String msg);
alias ApiBroadcastAllRawFn   = fn void(String data);

// Player counts
alias ApiGetPlayerCountFn      = fn int();
alias ApiGetAreaPlayerCountFn  = fn int(int area_id);

// Client identity
alias ApiClientGetIpidFn       = fn String(void* client);

// Packet field access (for hooks)
alias ApiPacketGetFieldFn      = fn String(void* packet, int index);
alias ApiPacketGetFieldCountFn = fn int(void* packet);

// Moderation from plugins
alias ApiClientKickFn          = fn void(void* client);
alias ApiClientMuteFn          = fn void(void* client);
alias ApiClientUnmuteFn        = fn void(void* client);

// Area background
alias ApiAreaGetBackgroundFn   = fn String(int area_id);
alias ApiAreaSetBackgroundFn   = fn void(int area_id, String bg);

// Area lock
alias ApiAreaGetLockFn         = fn int(int area_id);
alias ApiAreaSetLockFn         = fn void(int area_id, int lock_state);
alias ApiAreaInviteFn          = fn void(int area_id, int uid);

// Argument splitting — quote-aware tokenizer for command handlers.
// Plugin command handlers still receive the raw `String args` (the handler
// ABI is frozen), but this helper lets a plugin split it into a list the
// same way built-in commands do, without re-implementing the parser.
// Fills `out` (a caller-provided String buffer) and returns the token count.
alias ApiArgsSplitFn           = fn int(String args, String* out, int max);

// ASCII lower-casing — saves plugins from hand-rolling the `'A'..'Z' -> +32`
// loop just to compare user input case-insensitively. Like args_split it writes
// into a buffer the plugin owns (rather than returning an allocated String), so
// the result has no lifetime tied to the server's temp allocator. Copies `s`
// into `out` with every A–Z byte shifted to a–z, capped at `max` bytes, and
// returns how many bytes were written. Non-letters — digits, punctuation, and
// UTF-8 multibyte bytes — are copied through unchanged.
alias ApiToLowerFn             = fn int(String s, char* out, int max);

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

    // Extended API (v2) — appended for backwards compatibility
    ApiBroadcastAllMsgFn     broadcast_all_msg;
    ApiBroadcastAllRawFn     broadcast_all_raw;
    ApiGetPlayerCountFn      get_player_count;
    ApiGetAreaPlayerCountFn  get_area_player_count;
    ApiClientGetIpidFn       client_get_ipid;
    ApiPacketGetFieldFn      packet_get_field;
    ApiPacketGetFieldCountFn packet_get_field_count;
    ApiClientKickFn          client_kick;
    ApiClientMuteFn          client_mute;
    ApiClientUnmuteFn        client_unmute;
    ApiAreaGetBackgroundFn   area_get_background;
    ApiAreaSetBackgroundFn   area_set_background;
    ApiAreaGetLockFn         area_get_lock;
    ApiAreaSetLockFn         area_set_lock;
    ApiAreaInviteFn          area_invite;

    // Appended after the v2 block — see the ABI note above. Existing
    // compiled plugins never read this field, so they keep working.
    ApiArgsSplitFn           args_split;

    // Appended after args_split — same append-only ABI rule. Plugins compiled
    // before to_lower existed stop reading at args_split and never touch it.
    ApiToLowerFn             to_lower;
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

    // Runtime handles for hot reload
    void*[MAX_PLUGINS]                   handles;       // dlopen/LoadLibrary handles
    PluginShutdownFn[MAX_PLUGINS]        shutdown_fns;  // Shutdown callbacks
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

    // Use a shell command to list plugin files in the directory.
    // Windows: dir /b *.dll    POSIX: ls -1 *.so
    $if env::WIN32:
        String cmd = string::tformat("dir /b \"%s\\*.dll\" 2>nul", directory);
        void* pipe = win_popen(cmd.ptr, "r".ptr);
    $else
        String cmd = string::tformat("ls -1 \"%s/\"*.so 2>/dev/null", directory);
        void* pipe = popen(cmd.ptr, "r".ptr);
    $endif

    if (pipe != null) {
        char[256] name_buf;
        while (fgets(&name_buf[0], 256, pipe) != null) {
            // Trim trailing newline/whitespace and null-terminate.
            // dlopen/LoadLibrary read C strings (until \0), not C3
            // slices, so the buffer must be properly terminated.
            usz len = 0;
            while (len < 255 && name_buf[len] != 0 && name_buf[len] != '\n' && name_buf[len] != '\r') len++;
            if (len < 4) continue;
            name_buf[len] = 0; // Null-terminate for C interop

            String name = (String)name_buf[0..len - 1];

            // Build full path to the plugin file
            $if env::WIN32:
                // dir /b gives just filenames — prepend directory
                String full_path = string::tformat("%s\\%s", directory, name);
            $else
                // ls gives full relative paths (dir/file.so)
                String full_path = name;
            $endif

            load_single(pm, api, full_path);
        }

        $if env::WIN32:
            win_pclose(pipe);
        $else
            pclose(pipe);
        $endif
    }

    io::printfn("[plugins] %d plugins loaded, %d commands registered, %d hooks registered.",
        pm.plugin_count, pm.command_count, pm.hook_count);
}

// Load a single shared library plugin from the given path.
fn void load_single(PluginManager* pm, PluginAPI* api, String path) {
    if (pm.plugin_count >= MAX_PLUGINS) {
        io::printfn("[plugins] Max plugins (%d) reached, skipping: %s", MAX_PLUGINS, path);
        return;
    }

    // Open the shared library
    $if env::WIN32:
        void* handle = load_library_a(path.ptr);
    $else
        void* handle = dlopen(path.ptr, RTLD_NOW);
    $endif

    if (handle == null) {
        $if env::WIN32:
            io::printfn("[plugins] Failed to load: %s", path);
        $else
            char* err = dlerror();
            if (err != null) {
                usz err_len = 0;
                while (err_len < 512 && err[err_len] != 0) err_len++;
                if (err_len > 0) {
                    io::printfn("[plugins] Failed to load: %s (%s)", path, (String)err[0..err_len - 1]);
                } else {
                    io::printfn("[plugins] Failed to load: %s", path);
                }
            } else {
                io::printfn("[plugins] Failed to load: %s", path);
            }
        $endif
        return;
    }

    // Look up required exported functions
    $if env::WIN32:
        void* info_ptr     = get_proc_address(handle, "whisker_plugin_info".ptr);
        void* init_ptr     = get_proc_address(handle, "whisker_plugin_init".ptr);
        void* shutdown_ptr = get_proc_address(handle, "whisker_plugin_shutdown".ptr);
    $else
        void* info_ptr     = dlsym(handle, "whisker_plugin_info".ptr);
        void* init_ptr     = dlsym(handle, "whisker_plugin_init".ptr);
        void* shutdown_ptr = dlsym(handle, "whisker_plugin_shutdown".ptr);
    $endif

    if (info_ptr == null || init_ptr == null) {
        io::printfn("[plugins] '%s' missing required exports (whisker_plugin_info / whisker_plugin_init).", path);
        $if env::WIN32:
            free_library(handle);
        $else
            dlclose(handle);
        $endif
        return;
    }

    // Get plugin metadata
    PluginInfoFn info_fn = (PluginInfoFn)info_ptr;
    PluginInfo info = info_fn();

    // Store handle and shutdown callback
    int idx = pm.plugin_count;
    pm.handles[idx]      = handle;
    pm.shutdown_fns[idx] = shutdown_ptr != null ? (PluginShutdownFn)shutdown_ptr : null;

    // Initialize the plugin — it registers commands and hooks via the API
    PluginInitFn init_fn = (PluginInitFn)init_ptr;
    init_fn(api);

    // Register plugin info
    pm.plugins[idx] = info;
    pm.plugin_count++;

    io::printfn("[plugins] Loaded: %s v%s by %s", info.name, info.version, info.author);
}

// ============================================================
// Plugin unloading and hot reload
// ============================================================

// Unload all plugins: call shutdown, close handles, clear registrations.
fn void unload_all(PluginManager* pm) {
    // Call shutdown on each loaded plugin
    for (int i = 0; i < pm.plugin_count; i++) {
        if (pm.shutdown_fns[i] != null) {
            io::printfn("[plugins] Shutting down: %s", pm.plugins[i].name);
            pm.shutdown_fns[i]();
        }
    }

    // Close all library handles
    for (int i = 0; i < pm.plugin_count; i++) {
        if (pm.handles[i] != null) {
            $if env::WIN32:
                free_library(pm.handles[i]);
            $else
                dlclose(pm.handles[i]);
            $endif
            pm.handles[i] = null;
        }
        pm.shutdown_fns[i] = null;
    }

    // Clear all registrations
    pm.plugin_count  = 0;
    pm.command_count = 0;
    pm.hook_count    = 0;

    io::printn("[plugins] All plugins unloaded.");
}

// Hot-reload: unload everything, then re-scan and re-load.
fn void reload_all(PluginManager* pm, PluginAPI* api, String directory) {
    io::printn("[plugins] --- Hot reload started ---");
    unload_all(pm);
    load_all(pm, api, directory);
    io::printn("[plugins] --- Hot reload complete ---");
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
