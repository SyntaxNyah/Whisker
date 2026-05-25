# Optional Plugins

This folder contains **ready-to-use plugins** that add extra features to your Whisker server. They are completely optional -- your server works fine without them. Each plugin is already built and just needs to be dropped into your `plugins/` folder.

## Philosophy: Plugins Over Forks

The AO server community has a long history of fragmentation. Servers get forked to add a feature, the fork diverges, the original moves on, and now you've got two incompatible codebases that both slowly rot. Players lose. Server operators lose. Developers burn out maintaining forks nobody else can use.

**Whisker's answer is the plugin system.** The core server is intentionally kept small and lightweight -- it handles connections, packets, areas, characters, and moderation. Everything else is a plugin. If you want a feature that isn't built in, you write a plugin for it. If someone else already wrote one, you drag the file into your `plugins/` folder and restart.

This matters for a few reasons:

- **No more abandoned forks.** When a feature lives in a plugin, it doesn't matter if the person who wrote it moves on. The plugin still works with every version of Whisker that supports the Plugin API. You're not stuck on some fork from 2019 that nobody maintains.
- **Server operators choose their own features.** One server wants CM controls, another doesn't. One server wants a profanity filter, another wants a casino system. With plugins, every server can pick exactly the features it needs -- no bloat, no unused code, no compromise.
- **The core stays stable.** A smaller core means fewer bugs, faster updates, and less surface area for things to break. When the core server gets a security fix or protocol update, every server benefits regardless of which plugins they run.
- **Your work reaches more people.** A plugin that works with Whisker works with *every* Whisker server. A feature buried in a fork only helps the people running that fork. Plugins are portable, shareable, and composable.

### Contributing: Plugins First, Core Commits Welcome

We encourage contributions to Whisker upstream -- bug fixes, performance improvements, protocol support, and documentation are always welcome. But if you're adding a **new feature**, we strongly recommend building it as a plugin first.

Here's why:

- **Plugins ship independently.** You don't need to wait for a PR review cycle to get your feature into people's hands. Build it, compile it, share the `.dll`/`.so`, done.
- **Plugins are opt-in by design.** Not every server wants every feature. A plugin lets server operators decide. A core commit forces it on everyone.
- **Plugins are easy to remove.** Delete the file. That's it. No merge conflicts, no reverting commits, no rebuilding from source.
- **Plugins survive upstream changes.** If Whisker's core gets refactored, plugins that use the stable Plugin API keep working. Code welded into the core has to be updated alongside everything else.

If your feature genuinely belongs in the core (security, protocol compliance, fundamental server behavior), by all means submit a PR. But for gameplay features, moderation tools, integrations, and quality-of-life additions -- a plugin is almost always the better path. The community gets choice, your work stays compatible, and the core stays clean.

### How Plugin Distribution Works

When a plugin is ready for general use, we include it here in the `OPTIONAL Plugins` folder:

1. The **source code** (`.c3` file) goes in this folder -- both as documentation and as a learning exercise for other plugin developers
2. The **compiled binaries** go in `Windows/` (`.dll`) and `Linux/` (`.so`) so server operators can grab them without needing to set up a compiler
3. The **documentation** goes in this README, explaining what the plugin does, how to install it, and how to configure it

Server operators never need to touch source code. They open the right folder, drag the file, and restart. That's the whole workflow.

## Folder Structure

```
OPTIONAL Plugins/
  Windows/              ← .dll files for Windows servers
  Linux/                ← .so files for Linux servers
  *.c3                  ← source code (learning exercise)
  <plugin>/project.json ← build config for each plugin
  build_plugins.sh      ← script to rebuild all plugins
```

## How to Use

**All plugins are already compiled and ready to go.** You don't need a compiler, you don't need to build anything. Just drag and drop.

### Linux

The `Linux/` folder contains pre-built `.so` files. Copy them into your server's `plugins/` directory:

```bash
cp "OPTIONAL Plugins/Linux/"*.so plugins/
```

Then start the server — **you MUST run from the Whisker root directory**:

```bash
cd ~/Whisker && ./out/whisker
```

That's it. You should see the plugins load in the console output:

```
[plugins] Scanning 'plugins' for plugins...
[case_manager] Case Manager plugin loaded (7 commands).
[plugins] Loaded: Case Manager v1.0.0 by Whisker Community
[advertiser] Heartbeat thread started (interval: 60s).
[plugins] Loaded: Server Advertiser v1.0.0 by Whisker Community
[plugins] 2 plugins loaded, 7 commands registered, 0 hooks registered.
```

### Windows

The `Windows/` folder contains pre-built `.dll` files. Copy them into your server's `plugins/` folder, then run:

```powershell
.\out\whisker.exe
```

### **IMPORTANT: Do NOT run the server from inside `out/`!**

The `plugins/` folder is relative to the directory you run the server from (your **working directory**), NOT relative to the binary. If you `cd` into `out/` first, the server looks for `out/plugins/` which doesn't exist and **no plugins will load**.

**Correct:**
```bash
cd ~/Whisker && ./out/whisker
```

**Wrong:**
```bash
cd ~/Whisker/out && ./whisker    # plugins/ won't be found!
```

You can change this path in `config.toml` under `[plugins] directory = "plugins"`.

### Removing a plugin

Delete the `.so` / `.dll` file from `plugins/` and restart. That's it.

### Don't want any of these?

Delete this entire `OPTIONAL Plugins` folder. It won't affect your server.

## Rebuilding Plugins (for developers)

The pre-built binaries in `Windows/` and `Linux/` are ready to use. If you need to rebuild them (e.g., after modifying the source), you'll need [c3c](https://c3-lang.org/) installed.

**Quick rebuild (all plugins, both platforms):**
```bash
./build_plugins.sh all
```

**Build for a single platform:**
```bash
./build_plugins.sh linux     # Linux .so files only
./build_plugins.sh windows   # Windows .dll files only
./build_plugins.sh native    # Current platform only (default)
```

**Manual build (single plugin) — Option A: project.json:**
```bash
cd case_manager/             # or server_advertiser/
c3c build                    # builds for current platform
# Output: out/case_manager.so (Linux) or out/case_manager.dll (Windows)
```

**Manual build — Option B: command-line (no project.json needed):**
```bash
# Linux (the -l c flag is required to link against libc)
c3c dynamic-lib case_manager.c3 -l c -o case_manager
cp case_manager.so /path/to/whisker/plugins/

# Windows
c3c dynamic-lib case_manager.c3 -o case_manager
cp case_manager.dll /path/to/whisker/plugins/
```

Each plugin has its own `project.json` in a subdirectory (e.g., `case_manager/project.json`). Key settings:
- `"type": "dynamic-lib"` — produces a `.so` / `.dll` instead of an executable
- `"linked-libraries": ["c"]` — links against libc (**required on Linux** to avoid `undefined symbol: atexit`)

> **Note:** Cross-compiling Linux `.so` files from Windows does **not** produce working
> binaries. Always build `.so` files natively on your Linux server. Windows `.dll` files
> can be cross-compiled from Linux without issues.

---

## Available Plugins

### Server Advertiser

**Compiled:** `Windows/server_advertiser.dll` · `Linux/server_advertiser.so`
**Source:** `server_advertiser.c3`

Advertises your server to the Attorney Online master server so players can find it in the public server browser. Without this plugin, your server is unlisted -- players can only connect by entering your IP and port manually.

The `.c3` source file is included as a learning exercise -- if you want to try compiling a plugin yourself, this is a great one to start with. See the [Plugin Dev Guide](../plugins/PLUGIN%20DEV%20GUIDE%20README.md) for how to set up a C3 project and build it.

**Setup:**

1. Grab the `.dll` or `.so` from the appropriate folder and drop it into your server's `plugins/` directory
2. Restart the server. That's it.

The plugin automatically reads your `config/config.toml` to get the server name, description, TCP port, and WebSocket ports. It uses whatever you already have configured in `[server]` and `[websocket]`.

**Optional:** To use a custom master server URL, add to your `config/config.toml`:

```toml
[advertiser]
masterserver = "https://servers.aceattorneyonline.com/servers"
```

If omitted, it defaults to the official AO master server.

The plugin advertises your server every 60 seconds. You'll see confirmation in the server console:

```
[advertiser] Config loaded from config.toml.
[advertiser] Advertising to: https://servers.aceattorneyonline.com/servers
[advertiser] Server: My Server (TCP:27016 WS:27017 WSS:443)
[advertiser] Heartbeat sent successfully.
```

**What gets advertised:**
- Server name and description from `[server]`
- TCP port from `[server] port`
- WS port from `[websocket] ws_port` (if `enable_ws = true`)
- WSS port from `[websocket] wss_port` (if `enable_wss = true`, takes priority over WS)

**Why is this a plugin and not built-in?**

Not every server wants to be public. Private servers, test servers, and LAN servers have no reason to advertise. Making it opt-in keeps the core server simple and puts you in control.

---

### Case Manager (CM)

**Compiled:** `Windows/case_manager.dll` · `Linux/case_manager.so`
**Source:** `case_manager.c3`

Gives players a **Case Manager (CM)** role for area control — inspired by [Akashi](https://github.com/AttorneyOnline/akashi)'s CM system. CM is a per-area role that any player can claim. It lets players run their own courtroom without needing a moderator present.

The `.c3` source file is included as a learning exercise. It's the most complete example of a standalone plugin using the full Plugin API (commands, area management, client operations). See the [Plugin Dev Guide](../plugins/PLUGIN%20DEV%20GUIDE%20README.md) for how to set up a C3 project and build it.

**What CM can do:**
- Lock and unlock the area (built-in `/lock` and `/unlock` already check for CM)
- Kick players from the area
- Play music
- Set the area status (IDLE, CASING, RP, etc.)
- Force player positions (def, pro, wit, jud, hld, hlp)
- Manage the area invite list

**How CM works:**
- Type `/cm` to become CM of an area — only works if no other CMs exist
- Existing CMs can promote others with `/cm <uid>`
- CM status is **automatically lost** when you leave the area or disconnect
- Multiple CMs can exist in one area
- Moderators bypass all CM permission checks

**Commands:**

| Command | Usage | Description |
|---------|-------|-------------|
| `/cm` | `/cm [uid]` | Become CM, or promote another player |
| `/uncm` | `/uncm [uid\|all]` | Remove CM from self, another player, or everyone |
| `/area_kick` | `/area_kick <uid>` | Kick a player from the area to the lobby |
| `/play` | `/play <song>` | Play a song in the area |
| `/status` | `/status [status]` | Set area status (idle, lfp, casing, recess, rp, gaming) |
| `/forcepos` | `/forcepos <uid> <pos>` | Force a player's position (def, pro, wit, jud, hld, hlp) |
| `/uninvite` | `/uninvite <uid>` | Remove a player from the area's invite list |

**Setup:**

1. Grab the `.dll` or `.so` from the appropriate folder and drop it into your server's `plugins/` directory
2. Restart the server. No configuration needed.

All commands automatically appear in `/help`.

**To remove it:**

Delete the `.dll` / `.so` file from `plugins/` and restart.

**Why is this a plugin and not built-in?**

Not every server wants players to self-manage areas. Some servers prefer moderator-only control. Keeping CM as a standalone plugin means you can add or remove it without touching the server code at all — just drop or delete the file.

**Design notes (for developers):**

- CM state is stored in the area's existing `cm_uids` / `cm_count` fields (see `area.c3`)
- The core server already strips CM on area change (`packets.c3:change_area`) and disconnect (`server.c3:client_cleanup`)
- The built-in `/lock` and `/unlock` commands already check for CM status — no duplication needed
- Area kick uses the Plugin API's `force_move` to send players to the lobby, and removes them from the invite list to prevent re-entry
- The plugin communicates with the server entirely through the `PluginAPI` function pointers — no imports from the server source

---

See the [Plugin Dev Guide](../plugins/PLUGIN%20DEV%20GUIDE%20README.md) for writing your own plugins.
