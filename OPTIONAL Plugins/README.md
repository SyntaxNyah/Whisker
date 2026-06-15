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

Then start the server:

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

> **Note:** The server automatically resolves the `plugins/` path relative to the
> project root (same as `config/`), so it works whether you run from the project
> root or from `out/`. You can customize the path in `config.toml` under
> `[plugins] directory = "plugins"`.

### Removing a plugin

Delete the `.so` / `.dll` file from `plugins/` and restart. That's it.

### Don't want any of these?

Delete this entire `OPTIONAL Plugins` folder. It won't affect your server.

## Rebuilding Plugins (for developers)

The pre-built binaries in `Windows/` and `Linux/` are ready to use. If you need to rebuild them (e.g., after modifying the source), you'll need [c3c](https://c3-lang.org/) installed.

**Easiest: let CI do it (no local toolchain needed).** The
[`Build Plugins`](../.github/workflows/plugins.yml) workflow runs whenever you
push a change to a plugin's source (`*.c3`, a `project.json`, or
`build_plugins.sh`). A Linux runner builds every plugin — native `.so` **and**
cross-compiled `.dll` — and commits the refreshed binaries straight back into
`Linux/` and `Windows/`. So adding or editing a plugin and pushing is enough;
the compiled binaries update themselves. (The auto-commit is tagged `[skip ci]`
and only touches the binary folders, so it never triggers itself.)

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

### Casing

**Compiled:** `Windows/casing.dll` · `Linux/casing.so`
**Source:** `casing.c3`

Adds Attorney Online 2 casing commands to Whisker — testimony recording/playback, case documents, notecards, case advertisements, WT/CE blocking, and a judge action log. Inspired by [Akashi](https://github.com/AttorneyOnline/akashi) and [Nyathena](https://github.com/SyntaxNyah/Nyathena)'s casing systems.

The `.c3` source file is included as a learning exercise. It's a comprehensive example of a standalone plugin using the full Plugin API including hooks, packet field inspection, and server-wide broadcasts. See the [Plugin Dev Guide](../plugins/PLUGIN%20DEV%20GUIDE%20README.md) for how to set up a C3 project and build it.

**What this plugin adds:**

- **Testimony recording & cross-examination** — Record IC messages as testimony statements, then replay them during cross-examination with automatic navigation. Supports editing (add/update/delete) statements mid-cross-examination.
- **Case documents** — A per-area text field for sharing case info, links, or notes.
- **Notecards** — Players write hidden notecards that a CM can reveal all at once (great for verdict voting).
- **Case advertisements** — `/need` broadcasts a server-wide message that your area needs players.
- **WT/CE blocking** — Block specific players from using Witness Testimony / Cross Examination judge controls.
- **Judge log** — View the last 10 WT/CE and penalty bar actions in the area.

**Commands:**

| Command | Usage | Permission | Description |
|---------|-------|------------|-------------|
| `/testify` | `/testify` | CM/mod | Start recording testimony. Clears old testimony, sends WT splash. |
| `/examine` | `/examine` | Anyone | Begin cross-examination. Sends CE splash, plays first statement. |
| `/pause` | `/pause` | CM/mod | Stop recording or playback. |
| `/testimony` | `/testimony` | Anyone | View all recorded testimony statements. |
| `/add` | `/add` | CM/mod | Next IC message inserts after the current statement (during CE). |
| `/update` | `/update` | CM/mod | Next IC message replaces the current statement (during CE). |
| `/delete` | `/delete` | CM/mod | Delete the current statement (during CE). |
| `/doc` | `/doc [text]` | View: anyone, Set: CM/mod | Get or set the area's case document. |
| `/cleardoc` | `/cleardoc` | CM/mod | Clear the case document. |
| `/need` | `/need <message>` | CM/mod | Broadcast a case advertisement to the entire server. |
| `/notecard` | `/notecard <text>` | Anyone | Write a hidden notecard. |
| `/notecardreveal` | `/notecardreveal` | CM/mod | Reveal all notecards in the area, then clear them. |
| `/notecardclear` | `/notecardclear` | Anyone | Clear your own notecard. |
| `/blockwtce` | `/blockwtce <uid>` | CM/mod | Block a player from using WT/CE controls. |
| `/unblockwtce` | `/unblockwtce <uid>` | CM/mod | Unblock a player from WT/CE controls. |
| `/judgelog` | `/judgelog` | CM/mod | View the last 10 judge actions (WT/CE plays, HP changes). |

**How testimony works:**

1. A CM types `/testify` — the Witness Testimony splash plays, recording begins.
2. Each IC message in the area is recorded as a testimony statement (up to 30).
3. The CM types `/pause` to stop recording.
4. Anyone types `/examine` — the Cross-Examination splash plays, the first statement replays.
5. During cross-examination, each IC message advances to the next recorded statement.
6. When the last statement is reached, it loops back to the first and re-sends the CE splash.
7. CMs can edit the testimony mid-CE with `/add`, `/update`, and `/delete`.
8. Testimony auto-pauses if all CMs leave the area (safety feature).

**How notecards work:**

1. Players type `/notecard <text>` to write a hidden notecard (one per player per area).
2. A CM types `/notecardreveal` to reveal all notecards at once.
3. After reveal, all notecards are cleared automatically.
4. Use case: the judge asks for verdicts — each player writes their vote, then the judge reveals them simultaneously.

**Setup:**

1. Grab the `.dll` or `.so` from the appropriate folder and drop it into your server's `plugins/` directory.
2. Restart the server. No configuration needed.

All commands automatically appear in `/help`.

**To remove it:**

Delete the `.dll` / `.so` file from `plugins/` and restart.

**Why is this a plugin and not built-in?**

Not every AO2 server is a casing server. Roleplay servers, social servers, and general-purpose servers don't need testimony recording, notecards, or cross-examination commands. Making casing opt-in keeps the core server lightweight and avoids forcing 16 commands on servers that will never use them.

**Design notes (for developers):**

- All casing state (testimony, documents, notecards, blocks, logs) is stored in a per-area static array inside the plugin — the core server has no knowledge of it.
- The testimony system hooks the MS (IC message) packet to intercept messages during recording and playback. During recording, messages pass through normally and are also stored. During playback, incoming messages are consumed and replaced with the stored statement.
- Stored testimony statements are full outgoing-format MS packets with empty pairing fields, escaped for the AO2 wire format. This ensures faithful replay of character, emote, message, and effects.
- The RT (WT/CE) hook enforces per-area WT/CE blocks and logs judge actions.
- The HP (penalty bar) hook logs penalty bar changes to the judge log.
- Auto-pause safety: if all CMs leave the area, the next IC message auto-pauses any active testimony to prevent stuck state.
- The plugin communicates with the server entirely through the `PluginAPI` function pointers — no imports from the server source.

**Limits:**

| Limit | Value |
|-------|-------|
| Max tracked areas | 128 |
| Max testimony statements | 30 per area |
| Max notecards | 32 per area |
| Max WT/CE blocks | 32 per area |
| Judge log entries | 10 per area (ring buffer) |

---

### Player List

**Compiled:** `Windows/player_list.dll` · `Linux/player_list.so`
**Source:** `player_list.c3`

Implements the Attorney Online **2.11 player list** — the live roster the 2.11
desktop client shows in the top-left of the courtroom (when the theme provides
the widget). Inspired by the player lists in [Akashi](https://github.com/AttorneyOnline/akashi)
and [Nyathena](https://github.com/SyntaxNyah/Nyathena).

It is the reference example of a **lifecycle-hook** plugin: it holds no commands
and speaks pure protocol. When a player joins, picks a character, changes area,
sets an OOC name, or leaves, it pushes the matching AO2 2.11 `PR`/`PU` packets to
every client. See [PR / PU — Player List](../docs/AO2_PROTOCOL.md#pr--pu--player-list-211)
in the protocol reference and the [Lifecycle Hooks](../plugins/PLUGIN%20DEV%20GUIDE%20README.md#registering-lifecycle-hooks-v3)
section of the Plugin Dev Guide.

**What this plugin adds:**

- **Live player roster** — every 2.11 client sees who is present, their
  character, and which area they're in, updated in real time.
- **Instant join/leave** — players appear the moment they enter the courtroom
  and vanish the moment they disconnect (driven by core lifecycle events, not
  the slow 45-second keepalive).
- **Shadow-mod hiding** — players with the SHADOW role ("hidden from player
  lists") receive the list but are never shown on it.

**Commands:** none. This plugin has no OOC commands — it works entirely over the
protocol, so there is nothing to type and nothing in `/help`.

**Setup:**

1. Grab the `.dll` or `.so` from the appropriate folder and drop it into your
   server's `plugins/` directory.
2. Restart the server. No configuration needed.
3. The list appears for players on a 2.11+ client whose theme defines the player
   list widget. Older clients ignore it harmlessly.

**To remove it:**

Delete the `.dll` / `.so` file from `plugins/` and restart. The list disappears
for everyone.

**Why is this a plugin and not built-in?**

A player list is genuinely divisive, so Whisker ships it as opt-in rather than
forcing it on every server:

- **Privacy / lurking.** Many communities consider it normal to watch a case
  quietly. A public roster exposes every spectator by name — some servers (and
  players) specifically don't want that.
- **Roleplay immersion.** Some servers want presence felt in-character only, with
  no out-of-character sidebar listing who's in the room.
- **Moderation style.** On some servers only mods should see who's present;
  showing everyone to everyone changes that dynamic.
- **Lightweight servers.** The feature adds a small broadcast on every join,
  leave, character swap, area move, and name change. Tiny, but a minimal server
  may simply not want the traffic.
- **Client/theme dependent.** It only renders on 2.11+ clients with a supporting
  theme, so for many users it does nothing anyway.

Servers that want it drop in the plugin; servers that don't, don't — without
anyone forking the server to add or remove it.

**Design notes (for developers):**

- Built entirely on the core's **plugin lifecycle hooks** (`register_lifecycle_hook`
  — JOIN/LEAVE/UPDATE). A plain packet hook can't see disconnects (no packet is
  sent when a socket closes) and the client keepalive is only every 45 s, so
  lifecycle hooks are what make an accurate live list possible.
- Keeps a small in-memory roster (uid → character / area / OOC-name snapshot) and
  diffs on UPDATE so it only broadcasts real changes — the OOC-name event in
  particular fires on every OOC line.
- State is lockless, matching the rest of the server (the core's own
  broadcast/client-list code doesn't lock either).
- Talks to the server only through the `PluginAPI` function pointers — no imports
  from the server source.

**Limits:**

| Limit | Value |
|-------|-------|
| Max listed players | 1024 (matches the server's client cap) |
| Character / OOC-name snapshot | 63 bytes each |

---

See the [Plugin Dev Guide](../plugins/PLUGIN%20DEV%20GUIDE%20README.md) for writing your own plugins.
