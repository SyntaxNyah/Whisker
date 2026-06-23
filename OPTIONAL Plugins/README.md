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
`build_plugins.sh`). A Linux runner builds **every** plugin — native `.so`
**and** cross-compiled `.dll` (via the MSVC SDK) — and commits the refreshed
binaries straight back into `Linux/` and `Windows/`. So adding or editing a
plugin and pushing is enough; the compiled binaries update themselves. (The
auto-commit is tagged `[skip ci]` and only touches the binary folders, so it
never triggers itself.)

**Future plugins are picked up automatically.** Both `build_plugins.sh` and the
CI **auto-discover** plugins — there is no list to maintain. Any subdirectory of
`OPTIONAL Plugins/` that contains a `project.json` is treated as a plugin (its
output name matches the folder name by convention). To add a new one:

1. Create `OPTIONAL Plugins/<name>.c3` (the source).
2. Create `OPTIONAL Plugins/<name>/project.json` (copy an existing one; point
   `sources-override` at `../<name>.c3` and name the target `<name>`).
3. Commit and push — CI discovers it, builds `Linux/<name>.so` and
   `Windows/<name>.dll`, and commits them back. Done.

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
- `"linked-libraries": ["c"]` — links libc (**Linux only**, to avoid `undefined symbol: atexit`). The Windows build does **not** use this: MSVC has no `c.lib` and links its CRT implicitly, so `build_plugins.sh windows` builds the `.dll` with a plain `c3c dynamic-lib` (no `-l c`).

> **Cross-compiling notes:**
> - **Linux `.so` must be built natively on Linux** (with `-l c`). Cross-compiling a `.so` *from Windows* does **not** produce working binaries.
> - **Windows `.dll` can be cross-compiled from Linux**, but c3c links it against the **MSVC SDK**, which it downloads behind an interactive license prompt. Run `c3c fetch-sdk windows --accept-license` once first (the CI does this automatically), then build **without** `-l c`.

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

### IP Guard

**Compiled:** `Windows/ip_guard.dll` · `Linux/ip_guard.so`
**Source:** `ip_guard.c3`

Blocks connections by **IP address, CIDR range, ASN (whole networks), and country**
— for both **IPv4 and IPv6** — at the moment they connect, before the server
spends a thread on them. It is the reference example of a **connection-filter**
plugin (the v4 `register_conn_filter` hook): it runs on the accept path, exactly
where the built-in IPID ban runs, so a blocked address costs nothing more than a
fast lookup.

**Why you'd want this**

AO servers attract a specific kind of abuse that per-user bans lose to:

- **Datacenter / cloud abuse.** One bad actor cycles through a provider's
  address pool (a fresh IP every reconnect). Block the provider's **ASN** or
  CIDRs and the whole pool is gone at once, instead of chasing one address at a
  time.
- **VPN / proxy "countries."** For many communities, certain countries appear in
  AO traffic almost entirely as commercial VPN exit nodes with ~zero real
  players. An operator who knows their community can drop those **countries**
  wholesale and cut a large amount of ban-evasion and spam at the door.
- **Ban evasion.** A user hopping addresses within one ISP or region is stopped
  by a range/ASN/country rule where a single-IP ban never would be.

This is deliberately a blunt, opinionated tool — country/ASN blocking **will**
also block innocent people who share an ASN or country with abusers, and the
right policy differs wildly between servers. That's exactly why it's an **opt-in
plugin** and not core behaviour: servers that want it drop the file in; everyone
else never thinks about it.

**Plug-and-play — no database to install**

ASN/country rules need to know which network/country an IP belongs to. The
plugin handles that itself: on first run a background thread downloads the small
public-domain [iptoasn](https://iptoasn.com) datasets (redistributed by
[sapics/ip-location-db](https://github.com/sapics/ip-location-db), PDDL-1.0, no
API key) with `curl`, caches them next to your config, and refreshes them every
`update_interval_days`. You just pick countries/ASNs; the plugin fetches the
data. If the download fails (offline / no curl), it says so loudly and runs with
your `ip`/`cidr`/`allow` rules only — those need no database.

**Configuration — `config/ip_guard.txt`**

A plain text file (auto-created with a commented template on first run). One rule
per line:

```text
ip       203.0.113.7          # a single address (v4 or v6)
cidr     203.0.113.0/24       # a CIDR range
cidr     2001:db8::/32        # IPv6 works too
asn      AS14061              # every range announced by an ASN
country  CN                   # every range geolocated to a country (ISO 3166-1)
allow    198.51.100.10        # exception: never block this (wins over all)
```

Options (all optional, sensible defaults): `alert_blocked`, `alert_permission`,
`alert_interval_sec`, `block_unknown`, `auto_update`, `update_interval_days`, and
overridable `*_db_url` source URLs. See the comments in the generated file or the
[Mod Guide](../docs/MOD_GUIDE.md#ip-guard-plugin) for the full list.

**Commands** (require the **BAN** permission):

| Command | Usage | Description |
|---------|-------|-------------|
| `/ipban` | `/ipban <ip\|cidr> [note]` | Block an address/range live (also saved to the config file) |
| `/ipunban` | `/ipunban <ip\|cidr>` | Remove a live `/ipban` rule |
| `/ipbanlist` | `/ipbanlist` | Show rule counts, geo-DB status, total blocked |
| `/ipbanlog` | `/ipbanlog` | Show the most recent blocked connection attempts |
| `/ipbanreload` | `/ipbanreload` | Re-read the config + refresh the geo/ASN database |

**Optional staff alerts (off by default)**

Set `alert_blocked true` to have the server post an OOC notice when it blocks a
connection — handy as proof the filter works and to learn which ranges to add
next ("*4 connections blocked — latest 203.0.113.9 (country CN)*"). Alerts are
**coalesced on a timer**, never sent per-connection, so enabling them can't slow
the accept path even under a flood. `alert_permission` gates **which role sees
them** (a permissions bitmask, matching `roles.toml`; defaults to the BAN bit).

**Setup**

1. Drop `ip_guard.dll` / `ip_guard.so` into your server's `plugins/` directory.
2. Restart. A commented `config/ip_guard.txt` template is created on first run.
3. Edit `config/ip_guard.txt`, uncomment the rules you want, and `/ipbanreload`.

**To remove it:** delete the `.dll` / `.so` from `plugins/` and restart.

**IPv6 note.** IP Guard matches IPv6 fully, but your server only *receives* IPv6
if it listens on one — set `[server] addr = "::"`. On Linux that also accepts
IPv4 clients (as v4-mapped, which the core normalises back to dotted-quad); on
Windows `::` is IPv6-only by default. IPs arriving through a trusted reverse
proxy (X-Forwarded-For / CF-Connecting-IP) are matched as forwarded, so
geo-blocking works behind Cloudflare/nginx regardless of the listen socket.

**Two ban systems, no conflict.** The core `/ban` keys on the hashed **IPID**
(great for "ban this user"); IP Guard keys on the **real address / range / ASN /
country** (great for "ban this network"). They run independently and don't
interfere.

**Why is this a plugin and not built-in?**

Country/ASN blocking is heavy, opinionated, and community-specific — forcing it
on every server would be wrong. As a plugin, the policy lives entirely outside
the core: the core only gained a small, dormant, general-purpose connection-filter
hook (useful to any plugin), and all the "who to block" logic stays opt-in.

**Performance**

- When no connection filter is registered the core does **zero** extra work.
- With the plugin loaded, each connection is an O(log n) binary search over
  sorted, de-duplicated ranges (a handful of comparisons even for country-scale
  lists) plus a tiny scan of ad-hoc `/ipban` entries — and a blocked connection
  never costs a thread or 256 KB pool, so it's a net *saving* under abuse.
- Downloading/parsing the database and sending alerts happen on a background
  thread, never on the accept path.

**Design notes (for developers):**

- Built on the **connection-filter hook** (`register_conn_filter`, v4) — the
  filter runs at accept time and returns "block/allow". It also uses the v4
  `client_get_ip` (real address, not the hashed IPID) and `broadcast_perm_raw`
  (role-gated staff alerts).
- IPv4 and IPv6 share one 128-bit code path (IPv4 is stored as a v4-mapped
  address), so there is a single parse/search implementation.
- The filter is **allocation-free** — it runs on the accept thread where the
  plugin's temp allocator isn't initialised, so it only touches stack and
  pre-built tables (same discipline as `player_list`).
- Tables are lockless, matching the rest of the server: the operator's explicit
  `ip`/`cidr`/`allow` rules are built once at startup and never blink; the geo
  tables are rebuilt on a background thread publishing their count last; ad-hoc
  `/ipban` entries are append-only.
- Talks to the server only through the `PluginAPI` function pointers — no imports
  from the server source.

**Limits:**

| Limit | Value |
|-------|-------|
| Geo ranges per source (country/ASN), IPv4 | 300,000 |
| Geo ranges per source (country/ASN), IPv6 | 150,000 |
| Manual `ip`/`cidr` rules (config) | 16,384 |
| `allow` rules (config) | 8,192 |
| Ad-hoc `/ipban` rules (runtime) | 1,024 |
| Selected countries / ASNs | 256 / 512 |
| Recent-blocks log (`/ipbanlog`) | 64 (ring buffer) |

**Data credit:** geolocation/ASN data from [iptoasn.com](https://iptoasn.com)
via [sapics/ip-location-db](https://github.com/sapics/ip-location-db)
(PDDL-1.0 — public domain, no attribution required; credited here as a courtesy).

---

### AFK

**Compiled:** `Windows/afk.dll` · `Linux/afk.so`
**Source:** `afk.c3`

Marks idle or away players as **AFK** and shows it where other players look: a
`[AFK]` tag after their name in `/ga` and `/gas`, and — when the `player_list`
plugin is also installed — on the 2.11 player-list widget.

- **Auto-AFK:** a player who hasn't typed for `timeout_seconds` is marked AFK.
- **Manual:** `/afk` marks you AFK immediately.
- **Return:** typing anything (IC or OOC) clears your AFK automatically.

**Configuration — `config.toml` `[afk]`** (every part is a toggle):

| Key | Default | Meaning |
|-----|---------|---------|
| `auto_afk` | `true` | The inactivity timer. **Set `false` to keep ONLY `/afk`.** |
| `timeout_seconds` | `300` | Idle seconds before auto-AFK |
| `manual_command` | `true` | Enable the `/afk` command |
| `playerlist_indicator` | `true` | Show `[AFK]` on the 2.11 player list (needs `player_list`) |
| `gas_indicator` | `true` | Show `[AFK]` in `/ga` and `/gas` |
| `announce` | `false` | Broadcast "X is now AFK / back" to the area |
| `label` | `[AFK]` | The tag text |

You can run auto-AFK only, manual `/afk` only, both, or neither.

**Commands:**

| Command | Description |
|---------|-------------|
| `/afk` | Mark yourself AFK. Type anything to return. |

**Setup:**

1. Drop `afk.dll` / `afk.so` into your server's `plugins/` directory.
2. (Optional) adjust the `[afk]` section in `config/config.toml`.
3. Restart.

**To remove it:** delete the `.dll` / `.so` from `plugins/` and restart.

**Why is this a plugin and not built-in?**

AFK is genuinely divisive. Plenty of communities think `/afk` is pointless —
"you can already tell someone's gone when they stop talking" — and don't want an
auto-timer quietly tagging lurkers. Others want a clear away indicator. Making it
opt-in (and every part a toggle) means each server decides; the core stays
neutral. The only core support it needs is a small, generic per-client **status
tag** (added in the v5 Plugin API) that `/ga` and `/gas` render — useful to any
plugin, dormant when unused.

**Design notes (for developers):**

- A roster (uid → last-activity / is-afk) is driven by the core's **lifecycle
  hooks** (JOIN/LEAVE), so even a silent lurker is tracked from the moment they
  join. `MS` (IC) and `CT` (OOC) **packet hooks** detect typing — they return
  `false`, so they never consume chat or commands.
- The `/gas` tag uses the v5 **`client_set_status_tag`** API, so the core keeps
  rendering `/gas` from its own complete client list — the tag stays correct even
  after a `/reload` (a plugin re-implementing `/gas` from a roster could not,
  since a reload empties the roster).
- The player-list tag is a `PU` packet folded into the OOC-name field (the 2.11
  list has no dedicated status field); a background thread runs the inactivity
  timer and keeps that tag refreshed.
- State is lockless, matching the rest of the server. AFK state lives only in the
  plugin, so a `/reload` clears it (everyone shows not-AFK until the timer
  re-fires) — the same limitation `player_list` has.

**Limits:**

| Limit | Value |
|-------|-------|
| Tracked players | 1024 (matches the server's client cap) |
| Label length | 31 bytes |

---

### Lockdown

**Compiled:** `Windows/lockdown.dll` · `Linux/lockdown.so`
**Source:** `lockdown.c3`

A moderator **"known players only"** switch. While lockdown is ON, any IPID that
has **never joined before** is turned away with a friendly *"this is not a ban,
try again later"* notice; everyone who has joined before still gets in. It's a
door to slam shut during an incident so a bad actor can't keep cycling fresh
IPs/IPIDs to dodge bans — without locking out your regulars.

**How it learns who's "known":** the plugin remembers every IPID that
successfully joins, in a persistent file (`config/lockdown_known.txt`). It builds
this allowlist automatically as people play — you never curate it by hand.

> ⚠️ **Let it learn first.** The allowlist only contains IPIDs that joined *while
> this plugin was installed*. If you enable lockdown right after installing it,
> the list is empty and you'll lock out **everyone, including your regulars**.
> Install it, let people play for a while, check `/lockdown status` shows a
> healthy count, then use it. `/lockdown on` always reports the count it's about
> to enforce as a safety check.

**Commands** (require a mod permission — `permission` in config, default = BAN):

| Command | Description |
|---------|-------------|
| `/lockdown on [duration]` | Known IPIDs only. Optional auto-off timer, e.g. `/lockdown on 30m`. |
| `/lockdown off` | Back to normal — everyone can join. |
| `/lockdown status` | Show on/off, time remaining, and how many IPIDs are known. |
| `/lockdown purge` | Wipe the known-IPID list entirely (start fresh). |

When lockdown toggles, a notice is posted in OOC to **moderators only**.

**Configuration — `config.toml` `[lockdown]`:**

| Key | Default | Meaning |
|-----|---------|---------|
| `permission` | `4` | Permission bits to use `/lockdown` (4 = BAN; matches `roles.toml`) |
| `default_duration` | `0` | `/lockdown on` with no time: `0` = until `/lockdown off` (e.g. `30m`, `2h`) |
| `announce` | `true` | Post a mods-only OOC notice when lockdown toggles |
| `persist` | `true` | Remember known IPIDs across restarts (`config/lockdown_known.txt`) |
| `message` | *(sane default)* | The notice shown to a blocked new IPID |

**Setup:**

1. Drop `lockdown.dll` / `lockdown.so` into your server's `plugins/` directory.
2. Restart and **let it run** so it learns your regulars' IPIDs.
3. When you need it: a mod runs `/lockdown on` (check the reported known count first).

**To remove it:** delete the `.dll` / `.so` from `plugins/` and restart.

**Why is this a plugin and not built-in?**

A "known IPIDs only" lockdown is a heavy, situational tool. Private/whitelisted
servers don't need it, many public servers never want it, and it **will** turn
away genuine first-time visitors while it's on. IPID is a per-IP hash, so it's
coarse by design (a regular on a new network looks "new"). Opt-in keeps it out of
everyone else's way. It complements — doesn't replace — the core ban list ("ban
this user") and `ip_guard` ("block this network/country").

**Performance:** the gate runs once per *join* (not per packet), an O(n) scan of
the known set that's microseconds at human join rates; volumetric abuse is the
core's connection rate-limit / flood-autoban job (and `ip_guard`'s), not
lockdown's. Nothing runs on the per-packet path.

**Design notes (for developers):**

- One **lifecycle JOIN hook** does both jobs: record new IPIDs, and (during
  lockdown) kick unknown ones with a custom reason via the v6 **`client_kick_msg`**
  API. Gating at JOIN (not the raw socket) is deliberate — `KK` with a custom
  reason is reliably shown there, which is what makes the "not a ban" message
  actually reach the user. The brief player-list flicker on a blocked newcomer is
  the accepted cost.
- The mods-only notice uses the v4 **`broadcast_perm_raw`** (role-gated).
- The known set is append-only + linear scan, lockless like the rest of the
  server; a background thread runs the auto-off timer.

**Limits:**

| Limit | Value |
|-------|-------|
| Known IPIDs | 131,072 |

---

### Roll (tabletop dice)

**Compiled:** `Windows/roll.dll` · `Linux/roll.so`
**Source:** `roll.c3`

Adds dice-rolling commands for DnD / tabletop play on top of the courtroom. A
roll is broadcast to the whole area so the table can see and trust it.

**Commands:**

| Command | Usage | Description |
|---------|-------|-------------|
| `/roll` | `/roll [NdS[+/-M]]` | Roll dice (default `1d20`), shown to the area. e.g. `/roll 2d6+3`, `/roll d20`, `/roll 4d10-2`. |
| `/rollp` | `/rollp <dice>` | Same, but the result is sent only to you (a private / GM roll). |

Output looks like `Phoenix rolls 2d6+3: [4, 5] + 3 = 12`. Rolls are capped at
**100 dice** and **1000 sides** so a single command can't flood the area (the
first 30 individual dice are listed, then summarised).

**Setup:** drop `roll.dll` / `roll.so` into `plugins/` and restart. No config.

**To remove it:** delete the file and restart.

**Why is this a plugin and not built-in?**

Dice aren't part of the AO2 protocol — they're a gameplay feature. Pure
courtroom and social servers don't want dice (and an uncapped roller is a spam
vector), so it's opt-in. Tabletop/DnD servers drop it in; everyone else never
sees it.

**Limits:**

| Limit | Value |
|-------|-------|
| Max dice per roll | 100 |
| Max sides per die | 1000 |
| Dice individually listed | 30 (then summarised) |

---

### Global Chat + Private Messages

**Compiled:** `Windows/global_chat.dll` · `Linux/global_chat.so`
**Source:** `global_chat.c3`

Cross-area social tooling: a server-wide global OOC channel, one-to-one private
messages, and a per-player mute for the global channel.

**Commands:**

| Command | Usage | Description |
|---------|-------|-------------|
| `/g` | `/g <message>` | Send an OOC message to **every** area. Shows as `[Global] <name>: <message>`. |
| `/pm` | `/pm <uid> <message>` | Privately message one player by UID. Only the two of you see it. |
| `/toggleglobal` | `/toggleglobal` | Hide/show the global channel for yourself (you can still send while hidden). |

**Setup:** drop the file into `plugins/` and restart. No config.

**To remove it:** delete the file and restart.

**Why is this a plugin and not built-in?**

Cross-area chatter changes a server's culture. Some communities deliberately
keep areas siloed for roleplay immersion or casing focus, and private messages
raise their own moderation questions (harassment via DM). Opt-in lets each
server choose.

**Design notes (for developers):**

- To honour `/toggleglobal`, `/g` must deliver to each recipient individually
  (so it can skip muters) — `broadcast_all_msg` can't filter per-player. Since
  the Plugin API has no "enumerate all clients" call, the plugin keeps its own
  roster of online **UIDs** from the lifecycle JOIN/LEAVE hooks and resolves
  uid → client with `find_client` at send time. It stores UIDs, never client
  pointers (a stored pointer to a disconnected client is a use-after-free).
- **Reload limitation:** a `/reload` empties the roster (and everyone's mute
  state). To shrink that window, any `MS`/`CT`/`CH` packet re-adds its sender, so
  activity (or a keepalive) re-tracks players within seconds — but a silent
  lurker could miss global messages until they next speak. Same limitation
  `player_list` / `afk` have.

**Limits:**

| Limit | Value |
|-------|-------|
| Tracked players | 1024 (matches the server's client cap) |

---

### Chat Logger

**Compiled:** `Windows/chat_logger.dll` · `Linux/chat_logger.so`
**Source:** `chat_logger.c3`

Appends every IC and OOC message to per-area log files for moderation / audit,
one file per area (`logs/area<idx>_<name>.log`):

```
[2026-06-23 14:05:01 UTC] [Courtroom 1] IC uid=5 ipid=ab12cd34 char=Phoenix show=Nick: Objection!
[2026-06-23 14:05:10 UTC] [Courtroom 1] OOC uid=5 ipid=ab12cd34 name=PhoenixFan: brb one sec
```

Files are append-only and flushed per line, so a crash never loses prior lines.
**OOC lines that start with `/` (commands) are never logged** — deliberately, so
a mistyped `/login <password>` can't leak into the logs.

**Configuration — `config/config.toml` `[chat_logger]`:**

| Key | Default | Meaning |
|-----|---------|---------|
| `enabled` | `true` | Master switch. |
| `log_ic` | `true` | Log IC (in-character) messages. |
| `log_ooc` | `true` | Log OOC messages (never commands). |
| `include_ipid` | `true` | Include the hashed IPID per line (set `false` for stricter privacy). |
| `directory` | `logs` | Where the per-area files go (created if missing). |

**Setup:** drop the file into `plugins/`, optionally add a `[chat_logger]`
section to `config.toml`, restart.

**To remove it:** delete the file and restart.

**Why is this a plugin and not built-in?**

Persistent chat logging — especially tied to an IPID — is a policy choice, not a
default. Many AO/RP communities consider it invasive, some have privacy
obligations, others just don't want the disk usage. It ships opt-in so the
operator decides consciously. **Tell your players if you enable it.**

**Limits:**

| Limit | Value |
|-------|-------|
| Per-line length | ~760 bytes (longer messages truncated) |

---

### TOR Blocker

**Compiled:** `Windows/tor_blocker.dll` · `Linux/tor_blocker.so`
**Source:** `tor_blocker.c3`

Blocks **Tor exit nodes** (and any other downloaded IP blocklist — e.g. a VPN /
proxy feed) at connect time, before a connection costs the server a thread. It is
the same shape as `ip_guard` (a v4 connection filter on the accept path); the
difference is that the list is **downloaded** rather than hand-curated. By
default it uses the official Tor bulk exit list
(`https://check.torproject.org/torbulkexitlist`); add more feeds with extra
`list <url>` lines. The plugin downloads and refreshes the list(s) itself with
`curl` on a background thread — no API key, nothing to install.

**Commands** (require the **BAN** permission):

| Command | Usage | Description |
|---------|-------|-------------|
| `/torstatus` | `/torstatus` | Show list/blocklist/manual/allow counts, last refresh, total blocked. |
| `/torreload` | `/torreload` | Re-read config + re-download the blocklist(s) in the background. |
| `/torblocklog` | `/torblocklog` | Show recent blocked connection attempts. |
| `/torblock` | `/torblock <ip\|cidr>` | Manually block an address/range live (saved to the config). |
| `/torunblock` | `/torunblock <ip\|cidr>` | Remove a manual block. |

**Configuration — `config/tor_blocker.txt`** (auto-created with a commented
template on first run): `list <url>`, `allow <ip|cidr>`, `block <ip|cidr>`, plus
options `alert_blocked`, `alert_permission`, `alert_interval_sec`,
`block_unknown`, `auto_update`, `update_interval_hours` (default 6 — Tor's exit
set churns).

**Setup:** drop the file into `plugins/`, restart, edit `config/tor_blocker.txt`
if you want extra feeds, `/torreload`.

**To remove it:** delete the file and restart.

**Why is this a plugin and not built-in (and a warning)?**

Blocking Tor is a **blunt instrument** and a policy call. Plenty of legitimate
users reach AO through Tor for privacy or to evade censorship, and blocking it
turns them all away to stop the few who abuse it. That's right for some servers
and wrong for others, so it's opt-in — never core. Prefer the `allow` list for
known-good addresses. It complements the core `/ban` (hashed IPID) and `ip_guard`
(IP/CIDR/ASN/country) without interfering.

**Limits:**

| Limit | Value |
|-------|-------|
| Downloaded blocklist ranges | 300,000 |
| Manual `block` rules | 4,096 |
| `allow` rules | 4,096 |
| Distinct list URLs | 8 |
| Recent-blocks log | 64 (ring buffer) |

---

### Discord Modcall Webhook

**Compiled:** `Windows/discord_modcall.dll` · `Linux/discord_modcall.so`
**Source:** `discord_modcall.c3`

Forwards every in-game **modcall** (the `ZZ` packet — what a player sends when
they click "Call Mod") to a Discord channel via an incoming webhook, as a rich
embed. AO moderators are very often not watching the server console; a Discord
ping reaches them on their phone. The in-game modcall is **unaffected** — online
mods are still notified the normal way; this only *adds* the Discord notice.

**What the embed contains:** area name, UID, character, showname, OOC name, IPID
(toggleable), the modcall reason, and — optionally — the last *N* messages in
that area so the mod has context. The embed colour is configurable.

**Configuration — `config/discord.txt`** (auto-created with a commented template
on first run; the plugin is **inactive until `webhook_url` is set**):

| Key | Default | Meaning |
|-----|---------|---------|
| `webhook_url` | *(unset)* | Your Discord channel's webhook URL. Required to activate. |
| `username` | `Whisker Modcall` | Name the webhook posts under. |
| `color` | `#E74C3C` | Embed colour (`#hex` or decimal). |
| `include_logs` | `true` | Include recent area messages in the embed. |
| `log_count` | `10` | How many recent messages (max 25). |
| `include_ipid` | `true` | Include the caller's IPID. |
| `mention` | *(unset)* | Optional content ping, e.g. `<@&ROLEID>`, to alert a role. |

**Setup:** drop the file into `plugins/`, restart once (it writes the template),
paste your webhook URL into `config/discord.txt`, restart again. In Discord:
*Channel → Edit → Integrations → Webhooks → New Webhook → Copy URL*.

**To remove it:** delete the file and restart.

**Why is this a plugin — and why you might NOT want to rely on Discord:**

Routing modcalls to Discord is genuinely useful, but it's the wrong default for
many servers, which is exactly why it's opt-in:

- **It's a third-party dependency.** If Discord is down, rate-limits you, or the
  webhook is deleted, the Discord notices silently stop. The **in-game** modcall
  always still works (this never replaces it) — but anyone who *relies* on the
  Discord side has a single point of failure outside their control. Treat Discord
  as a convenience, not your only alerting.
- **It sends player data off your server.** Area names, charnames, shownames, OOC
  names, message context, and (unless disabled) the IPID leave your machine for
  Discord's infrastructure, under Discord's terms — not yours. Some communities
  have privacy expectations that make that a problem. Consider
  `include_ipid = false` / `include_logs = false`, and tell your players.
- **The webhook is a small secret.** Anyone with the URL can post to your
  channel, so it lives in server-side config, never in the client.
- **Not every server even has a staff Discord.**

**Design notes (for developers):**

- The `ZZ` hook builds the Discord embed JSON **allocation-free** (it runs on a
  per-client thread with no plugin temp allocator) and hands it to a background
  worker thread, which writes it to a temp file and POSTs it with
  `curl --data-binary @file`. The temp-file approach sidesteps shell-escaping of
  the JSON and the cmd.exe command-line length limit, and the payload file is
  deleted right after sending (it holds player data).
- The webhook URL is validated (`https://`, a `discord(app).com` host, no
  shell-dangerous bytes) before it ever reaches the shell.
- Recent-message context comes from a per-area ring filled by `MS`/`CT` hooks
  (OOC commands are excluded). UTF-8 is never split when capping names/messages,
  so the JSON stays valid.

**Limits:**

| Limit | Value |
|-------|-------|
| Tracked areas (for context) | 256 |
| Recent messages kept per area | 25 |
| Recent messages sent in an embed | up to `log_count` (max 25) |
| Queued webhook posts | 8 |

---

### Modcall Guard

**Compiled:** `Windows/modcall_guard.dll` · `Linux/modcall_guard.so`
**Source:** `modcall_guard.c3`

Rate-limits modcalls (the `ZZ` packet) per player and drops duplicate spam, so one
user mashing "Call Mod" can't bury staff in notifications.

**Configuration — `config/config.toml` `[modcall_guard]`:**

| Key | Default | Meaning |
|-----|---------|---------|
| `enabled` | `true` | Master switch. |
| `cooldown_seconds` | `30` | Minimum gap between one player's modcalls. |
| `dedupe` | `true` | Also drop an identical reason repeated soon after. |
| `notify` | `true` | Tell the player their modcall was held (and that staff were already alerted). |

**Setup:** drop into `plugins/`, restart. **To remove:** delete the file and restart.

**Why is this a plugin and not built-in?** Small servers with attentive staff
don't need it, and a cooldown can briefly delay a *legitimate* follow-up
modcall — so the policy is opt-in.

> **Heads-up (hook order):** a held modcall is consumed before it reaches staff.
> Because packet hooks run in load order and a consumed packet skips later hooks,
> whether it pre-empts `discord_modcall` depends on which loaded first
> (filesystem order); it always limits the core's in-game modcall but can't
> *guarantee* beating another `ZZ` hook. See the dev-guide note on hook ordering.

---

### Connection Cap

**Compiled:** `Windows/conn_cap.dll` · `Linux/conn_cap.so`
**Source:** `conn_cap.c3`

Limits how many concurrent client **sessions** a single IP may hold. A new
connection from an address already at the cap is rejected at accept time (the
`ip_guard` pattern) — before it costs a thread.

**Configuration — `config/config.toml` `[conn_cap]`:**

| Key | Default | Meaning |
|-----|---------|---------|
| `enabled` | `true` | Master switch. |
| `max_per_ip` | `3` | Max concurrent sessions per IP. |

**Command:** `/capstatus` (BAN perm) — shows the cap, active IPs, and total rejected.

**Setup:** drop into `plugins/`, restart. **To remove:** delete the file and restart.

**Why is this a plugin and not built-in?** Many servers legitimately have several
people behind one IP (households, schools, shared networks), and a cap turns the
extras away — so the right number, if any, is server-specific. The core already
has connection *rate* limiting; this adds a *concurrency* cap on top.

> **Behind a reverse proxy:** the cap keys on the **real client IP**, so make sure
> your proxy forwards `X-Forwarded-For` / `CF-Connecting-IP` (Whisker resolves
> these). Otherwise every client appears to share the proxy's IP and the cap
> locks them all out. It counts concurrent *joined* sessions, so a connection that
> never finishes the handshake isn't counted.

---

### Client Gate

**Compiled:** `Windows/client_gate.dll` · `Linux/client_gate.so`
**Source:** `client_gate.c3`

Allow- or block-lists connecting clients by the software name they report in the
AO2 `ID` handshake packet (e.g. `AO2-Client`, `webAO`, a custom/script client). A
rejected client is kicked with a reason and the handshake is halted.

**Configuration — `config/client_gate.txt`** (auto-created with a template):

| Directive | Meaning |
|-----------|---------|
| `mode blocklist` / `mode allowlist` | block the listed clients, or admit **only** the listed clients |
| `client <pattern>` | case-insensitive substring matched against the client name (repeatable) |
| `message <text>` | kick reason shown to a rejected client |
| `enabled true/false` | master switch |

**Setup:** drop into `plugins/`, restart (writes the template), edit the file,
restart. **To remove:** delete the file and restart.

**Why is this a plugin and not built-in?** Gating clients is community-specific
and double-edged: blocking script/abusive clients stops griefing, but an
*allowlist* also turns away players on perfectly good third-party clients you
didn't list. Some servers want only the official client; others welcome every
fork. So it's opt-in.

> **Note:** the client name is self-reported, so this stops casual mismatches and
> known-bad clients, not a determined attacker who spoofs the field. Pair it with
> `ip_guard` / `tor_blocker` / `conn_cap` for connection-level control.

---

### Link Filter

**Compiled:** `Windows/link_filter.dll` · `Linux/link_filter.so`
**Source:** `link_filter.c3`

Blocks IC/OOC messages that contain links (`http`, `https`, `www.`,
`discord.gg`), with an allowlist of domains you do permit. Anti-advertising /
anti-grief. It **blocks** the message (consume + a "no links" notice to the
sender) rather than rewriting it, so logging/relay plugins stay coherent.

**Configuration — `config/link_filter.txt`** (auto-created with a template):

| Directive | Default | Meaning |
|-----------|---------|---------|
| `allow <domain>` | — | Permit this domain (repeatable). |
| `block_ic` | `true` | Filter IC messages. |
| `block_ooc` | `true` | Filter OOC messages (commands are never touched). |
| `exempt_mods` | `true` | Let authenticated mods post links. |
| `message <text>` | sane default | Notice shown to the sender. |
| `enabled` | `true` | Master switch. |

**Setup:** drop into `plugins/`, restart, edit the file, restart. **To remove:**
delete the file and restart.

**Why is this a plugin and not built-in?** Plenty of servers *want* links (music,
references, evidence images), so a blanket filter is wrong for them; others are
plagued by advert spam. Opt-in lets each decide.

---

### Name Filter

**Compiled:** `Windows/name_filter.dll` · `Linux/name_filter.so`
**Source:** `name_filter.c3`

Rejects players whose **showname**, **character**, or **OOC name** matches a
blacklist of patterns from a text file. Two actions: `drop` (their messages
silently don't go out until they rename) or `kick` (disconnect with a reason).

> **No ban:** the Plugin API has no ban primitive, so the strongest action here is
> a kick. Pair it with the core `/ban` for an actual ban.

**Configuration — `config/name_filter.txt`** (auto-created):

| Directive | Default | Meaning |
|-----------|---------|---------|
| `bad <pattern>` | — | Blocked substring, case-insensitive (repeatable). |
| `action drop` / `action kick` | `kick` | Drop their messages, or disconnect them. |
| `check_showname` / `check_charname` / `check_oocname` | `true` | Which names to inspect. |
| `message <text>` | sane default | Shown on kick / on a dropped message. |
| `enabled` | `true` | Master switch. |

**Setup:** drop into `plugins/`, restart, edit the file, restart. **To remove:**
delete the file and restart.

**Why is this a plugin and not built-in?** What counts as an unacceptable name is
community-specific, and a heavy-handed blacklist false-positives on innocent
names (the Scunthorpe problem) — so each server curates its own list, opt-in.

---

### Word Filter

**Compiled:** `Windows/word_filter.dll` · `Linux/word_filter.so`
**Source:** `word_filter.c3`

Filters a configurable word blacklist out of IC/OOC chat, with optional
escalation to auto-mute repeat offenders. Two modes:

- **`block`** (default, clean) — the offending message never goes out; the sender
  gets a notice.
- **`censor`** — matched words become `****` and the line is re-broadcast.

**Configuration — `config/word_filter.txt`** (auto-created):

| Directive | Default | Meaning |
|-----------|---------|---------|
| `bad <word>` | — | Word/substring to filter, case-insensitive (repeatable). |
| `mode block` / `mode censor` | `block` | Block the message, or asterisk the words. |
| `filter_ic` / `filter_ooc` | `true` | Which chat to filter (commands never touched). |
| `exempt_mods` | `true` | Skip authenticated mods. |
| `escalate` | `false` | Auto-mute repeat offenders. |
| `threshold` / `window_seconds` | `3` / `30` | Violations within the window before a mute. |
| `message <text>` | sane default | Notice shown on a blocked message. |
| `enabled` | `true` | Master switch. |

**Setup:** drop into `plugins/`, restart, edit the file, restart. **To remove:**
delete the file and restart.

**Why is this a plugin and not built-in?** Acceptable language varies wildly by
community (a mature RP server and a kid-friendly one want opposite defaults), and
filters always false-positive — so each server brings its own list, opt-in.

> **`censor` caveat:** censoring *rebuilds* the message (a plugin can't edit a
> packet in place), so a censored line loses the core's pairing for that line and
> is invisible to logging/relay plugins. `block` has neither issue — prefer it
> unless you specifically need the censored line to still appear. See the
> dev-guide note on packet rewriting.

---

### Unicode Guard

**Compiled:** `Windows/unicode_guard.dll` · `Linux/unicode_guard.so`
**Source:** `unicode_guard.c3`

Defends against **zalgo** — messages or shownames stacked with dozens of
combining diacritics that smear across the screen. Two actions: `block` (the
message is held; clean default) or `strip` (the combining marks are removed and
the message re-broadcast). It targets the common combining block U+0300–U+036F,
so normal accented text (which uses precomposed characters) is unaffected.

**Configuration — `config/unicode_guard.txt`** (auto-created):

| Directive | Default | Meaning |
|-----------|---------|---------|
| `action block` / `action strip` | `block` | Hold the message, or strip the marks. |
| `max_combining` | `4` | Combining marks tolerated before flagging. |
| `filter_ic` / `filter_ooc` | `true` | Which chat to inspect. |
| `exempt_mods` | `true` | Skip authenticated mods. |
| `message <text>` | sane default | Notice shown on a held message. |
| `enabled` | `true` | Master switch. |

**Setup:** drop into `plugins/`, restart, edit the file, restart. **To remove:**
delete the file and restart.

**Why is this a plugin and not built-in?** Most servers never see zalgo, and the
detection is necessarily heuristic (a high `max_combining` is needed for scripts
that legitimately stack marks) — so it's opt-in, with `strip` carrying the same
packet-rebuild caveat as the word filter's censor mode.

---

### Mod Toys

**Compiled:** `Windows/mod_toys.dll` · `Linux/mod_toys.so`
**Source:** `mod_toys.c3`

Light, reversible "punishment" toys a moderator can apply to one player, in the
tsuserver tradition. Rewrites only the *targeted* player's lines.

**Commands** (require MUTE permission):

| Command | Effect |
|---------|--------|
| `/gimp <uid>` | Replace their messages with random nonsense. |
| `/disemvowel <uid>` | Strip the vowels out of their messages. |
| `/parrot <uid>` | Echo each message back, doubled and annoying. |
| `/untoy <uid>` | Clear any toy. |

A toy clears automatically when the player disconnects.

**Setup:** drop into `plugins/`, restart. No config. **To remove:** delete the
file and restart.

**Why is this a plugin and not built-in?** These are deliberately silly, and many
servers consider public humiliation the wrong moderation style — they'd rather
warn/mute/kick. Opt-in keeps that choice with the operator.

> **Note:** a toyed line is rebuilt, so it loses pairing for that line and isn't
> seen by logging/relay plugins — expected, since the whole point is to alter what
> the punished user says.

---

### Slowmode

**Compiled:** `Windows/slowmode.dll` · `Linux/slowmode.so`
**Source:** `slowmode.c3`

Per-area IC slow mode. When a room's message rate spikes (or a mod turns it on),
IC messages are spaced out so slow / webAO clients keep up instead of falling
behind or skipping.

**Command** (MODIFY_AREA perm): `/slowmode [on [seconds] | off | status]` —
controls the caller's current area.

**Configuration — `config/config.toml` `[slowmode]`:**

| Key | Default | Meaning |
|-----|---------|---------|
| `enabled` | `true` | Master switch. |
| `auto` | `true` | Auto-enable on a rate spike. |
| `trigger_count` / `trigger_window` | `10` / `5` | Messages within N seconds that trip auto-slowmode. |
| `gap_seconds` | `2` | Minimum gap between IC messages while active. |
| `duration_seconds` | `30` | How long auto-slowmode stays on. |
| `queue` | `false` | **Experimental.** Hold extra messages and release them spaced, instead of dropping them. |

**Two behaviours when a message is too fast:**
- **throttle** (default): the extra message is dropped with a "slow down" notice.
  Allowed messages pass through the core untouched (full pairing, seen by all hooks).
- **queue** (experimental): while active, *all* messages in the area are held and
  released one per `gap`. This preserves order, but released lines are rebuilt (no
  pairing, invisible to logging/relay plugins) and add latency — enable only if
  dropping is worse for you than delay.

**Setup:** drop into `plugins/`, optional `[slowmode]` config, restart. **To
remove:** delete the file and restart.

**Why is this a plugin and not built-in?** The core already rate-limits IC per
*client*; this is a per-*area* pacing policy that only some servers (big, busy,
webAO-heavy rooms) need, with very server-specific thresholds.

---

### Captcha

**Compiled:** `Windows/captcha.dll` · `Linux/captcha.so`
**Source:** `captcha.c3`

Makes a newly-connected player answer a one-line challenge in OOC before they can
chat — a simple anti-bot / anti-driveby-spam gate. Once an IPID answers correctly
it's remembered for the rest of the server's run, so regulars are challenged at
most once.

**Configuration — `config/config.toml` `[captcha]`:**

| Key | Default | Meaning |
|-----|---------|---------|
| `enabled` | `true` | Master switch. |
| `mode` | `math` | `math` (random `a + b = ?`) or `word` (fixed answer). |
| `word` | `GREEN` | The answer in `word` mode. |
| `prompt` | sane default | OOC prompt shown in `word` mode. |

**Setup:** drop into `plugins/`, optional `[captcha]` config, restart. **To
remove:** delete the file and restart.

**Why is this a plugin and not built-in?** A captcha adds friction for every new
player, which most healthy servers don't want — it's a tool for when you're
actively under bot/spam pressure. Opt-in keeps the front door frictionless by
default.

> **Note:** after a `/reload` the pending-challenge state resets, so already-
> connected players are treated as verified (fail-open); new joiners are still
> challenged. The verified-IPID memory is per server run (not persisted).

---

### Jukebox

**Compiled:** `Windows/jukebox.dll` · `Linux/jukebox.so`
**Source:** `jukebox.c3`

The classic AO **blockdj** mod tool plus a song **request queue**.

**Commands:**

| Command | Perm | Description |
|---------|------|-------------|
| `/blockdj <uid>` | MUTE | Stop a player changing the area's music. |
| `/unblockdj <uid>` | MUTE | Restore their music control. |
| `/request <song>` | anyone | Queue a song. |
| `/queue` | anyone | Show the area's request queue. |
| `/skip` | MUTE | Play the next queued song. |
| `/djclear` | MUTE | Clear the queue. |

The queue is per-area and advanced manually with `/skip` (AO2 doesn't tell the
server when a track ends, so there's no auto-advance). `blockdj` clears on
disconnect.

**Setup:** drop into `plugins/`, restart. No config. **To remove:** delete the
file and restart.

**Why is this a plugin and not built-in?** Music griefing (DJ spam) is a real
problem on some servers and a non-issue on others, and a request queue is a
gameplay nicety not every community wants. Opt-in keeps the core music path
simple.

---

> **Note on `/reload`:** the plugins above that spawn a background thread
> (`tor_blocker`, `discord_modcall`) share the same small `/reload` caveat as the
> existing `server_advertiser` / `ip_guard` plugins — a hot-reload can briefly
> race the background thread as the library is unloaded. A full server restart is
> the clean way to update these; `/reload` is fine for the command/hook-only
> plugins (`roll`, `global_chat`, `chat_logger`).

See the [Plugin Dev Guide](../plugins/PLUGIN%20DEV%20GUIDE%20README.md) for writing your own plugins.
