# Whisker Mod Guide

Everything you need to know to set up, run, and moderate your Whisker AO2 server.

---

## Table of Contents

1. [First-Time Setup](#first-time-setup)
2. [Server Console](#server-console)
3. [Account Management](#account-management)
4. [Logging In as a Moderator](#logging-in-as-a-moderator)
5. [Roles and Permissions](#roles-and-permissions)
6. [Moderation Commands](#moderation-commands)
7. [Area Management](#area-management)
8. [Server Configuration](#server-configuration)
9. [Rate Limiting and Anti-DDoS](#rate-limiting-and-anti-ddos)
10. [Bans and Ban Management](#bans-and-ban-management)
11. [Plugins](#plugins)
12. [Plugin Hot Reloading](#plugin-hot-reloading)
13. [Reverse Proxy and WSS](#reverse-proxy-and-wss)
14. [Tips and Best Practices](#tips-and-best-practices)

---

## First-Time Setup

### 1. Build the server

```bash
c3c build
```

### 2. Check your config directory

Whisker ships with a `config/` directory containing everything you need:

| File | What it does |
|------|-------------|
| `config.toml` | Server name, ports, rate limits, proxy settings |
| `areas.toml` | Area (room) definitions |
| `characters.txt` | Character list, one per line |
| `music.txt` | Music list, one per line |
| `roles.toml` | Role definitions with permission bits |

### 3. Set your server name and description

Open `config/config.toml` and edit the `[server]` section:

```toml
[server]
name = "My Server"
description = "An Attorney Online 2 server powered by Whisker"
motd = "Welcome! Type /help for commands."
```

The `name` is what players see in the server browser. The `motd` is the first message players see when they join.

### 4. Run the server

```bash
./out/whisker
```

Or with a custom config directory:

```bash
./out/whisker -c /path/to/my/config
```

---

## Server Console

When Whisker starts, it launches an interactive console in the terminal. This is where you manage accounts, reload plugins, and monitor the server -- all without connecting as a player.

### Console commands

| Command | Description |
|---------|-------------|
| `addmod <user> <pass> [role]` | Create a moderator account (default role: `moderator`) |
| `removemod <username>` | Remove a moderator account |
| `listmods` | List all moderator accounts and their roles |
| `reload` | Hot-reload all plugins without restarting |
| `status` | Show player count, areas, loaded plugins |
| `help` | Show available commands and roles |
| `quit` / `exit` / `stop` | Shut down the server |

### First thing to do after starting

Create an admin account:

```
addmod Admin your_secure_password admin
```

This creates an account named `Admin` with the `admin` role (full permissions). You can now log in from the game client with `/login Admin your_secure_password`.

### Examples

```
addmod Admin secretpass123 admin        # Full admin
addmod Mod1 modpass moderator           # Standard moderator
addmod DJ1 djpass dj                    # Music/background only
removemod Mod1                          # Remove an account
listmods                                # See all accounts
reload                                  # Reload plugins after dropping in a new .dll/.so
status                                  # Check server state
```

> Console arguments are split the same quote-aware way as in-game commands, so a
> password (or any value) containing spaces can be wrapped in quotes:
> `addmod Admin "my long passphrase" admin`.

---

## Account Management

Whisker uses a console-managed account system. Accounts are stored in `config/accounts.txt` and persist across restarts.

### How it works

1. Create accounts from the server console with `addmod`
2. Each account has a **username**, **password**, and **role**
3. Roles define which permissions the account gets (see [Roles and Permissions](#roles-and-permissions))
4. Players log in from the game client with `/login <username> <password>`

### Account file format

Accounts are stored in `config/accounts.txt`:

```
# Whisker moderator accounts
# Format: username:password:role
Admin:secretpass123:admin
Mod1:modpass:moderator
```

This file is managed by the server console. Do not edit it while the server is running -- changes made via `addmod`/`removemod` are written automatically.

### Legacy fallback

If `accounts.txt` is empty (no accounts configured), Whisker falls back to the legacy single-password auth from `moderation.c3`. This is for backwards compatibility -- once you add your first account via `addmod`, the legacy password is ignored and only accounts are used.

### Extending the auth system

The built-in account system is intentionally simple -- plain text passwords, file-based storage. If you need bcrypt/argon2 hashing, database-backed auth, OAuth, or any other advanced authentication, build it as a **plugin**. The Plugin API gives you full access to client operations (messaging, kicking, muting, reading IPIDs), area management (locking, backgrounds, invites), packet interception (read any field from any packet), and server-wide broadcasting -- so a plugin can intercept `/login` and implement any auth flow you want.

---

## Logging In as a Moderator

Once your server is running and you're connected as a player:

### Login

Type this in OOC chat:

```
/login <username> <password>
```

Example:

```
/login Admin secretpass123
```

- `<username>` must match an account created via `addmod` in the server console.
- `<password>` must match the password for that account.

On success, you'll see:

```
Logged in as Admin (admin).
```

You receive the permissions defined by your account's role. The server console logs:

```
[mod] a1b2c3d4 logged in as 'Admin' [admin] (UID 0)
```

### Logout

```
/logout
```

This immediately removes all your permissions for the rest of the session.

### Important notes

- Login is per-session. If you disconnect, you need to log in again.
- Your login is not visible to other players. Only the server console logs it.
- Failed login attempts are also logged on the server console.
- Different accounts can have different roles -- an `admin` has more permissions than a `moderator`.

---

## Roles and Permissions

Whisker uses a bitfield permission system. Each permission is a power of 2, and roles combine them.

### Permission bits

| Permission | Bit | Value | What it allows |
|-----------|-----|-------|---------------|
| MUTE | 0 | 1 | Mute/unmute players, force pair/unpair |
| KICK | 1 | 2 | Kick players |
| BAN | 2 | 4 | Ban and unban players |
| MOVE_USERS | 3 | 8 | Force-move players between areas |
| MODIFY_AREA | 4 | 16 | Lock areas, change backgrounds, area settings |
| BAN_INFO | 5 | 32 | View ban records and details |
| ADMIN | 6 | 64 | Full server control |
| SHADOW | 7 | 128 | Hidden from player lists |
| DJ | 8 | 256 | Music and background permissions |

### Default roles (in `config/roles.toml`)

```toml
[[role]]
name = "moderator"
permissions = 39  # MUTE + KICK + BAN + MOVE_USERS (1+2+4+32)

[[role]]
name = "admin"
permissions = 127  # All except SHADOW and DJ

[[role]]
name = "dj"
permissions = 256  # DJ only
```

### How permissions combine

Permissions are added together as a bitfield. For example:

- MUTE + KICK = `1 + 2` = `3`
- MUTE + KICK + BAN = `1 + 2 + 4` = `7`
- Everything = `1 + 2 + 4 + 8 + 16 + 32 + 64 + 128 + 256` = `511`

To create a custom role, add a new `[[role]]` block to `roles.toml`:

```toml
[[role]]
name = "helper"
permissions = 3  # MUTE + KICK only
```

### How login uses roles

When you create an account with `addmod Admin password admin`, the `admin` role is looked up in `roles.toml` and its permission bits are stored with the account. When the player logs in with `/login Admin password`, they receive exactly those permissions -- no more, no less.

To give someone limited permissions, assign them a role with fewer bits. For example, a `moderator` (perms=39) can mute, kick, ban, and move users, but cannot modify areas or access admin functions.

---

## Moderation Commands

All moderation commands require `/login` first.

### Kick

```
/kick <uid>
```

Immediately disconnects the player. They can reconnect.

### Ban

```
/ban <uid> [reason] [duration]
```

Bans the player by IP hash (IPID) and hardware ID (HDID). They cannot reconnect until the ban expires or is removed.

Arguments are a list, not one blob of text — **wrap any multi-word reason or duration in quotes** so it stays a single argument:

```
/ban 12 "ban evading" "3 days"
```

**Duration format:**
- `30s` = 30 seconds
- `5m` = 5 minutes
- `1h` = 1 hour
- `3d` = 3 days (the default if you omit the duration)
- `1w` = 1 week
- `3 days`, `1 week`, `2 hours` — long forms work too (quote them)
- `0` = permanent

**Examples:**

```
/ban 5                          # Ban UID 5 for 3 days (default), no reason
/ban 5 Spamming                 # Ban UID 5 for 3 days, reason: Spamming
/ban 5 "Flooding chat" 1h       # Ban UID 5 for 1 hour, reason: Flooding chat
/ban 5 "Ban evading" 0          # Ban UID 5 permanently
```

> The reason comes before the duration. A single bare word after the UID is
> treated as the reason; add a quoted duration (or a bare `3d`/`1w`) as the
> third argument to set the length.

### Unban

```
/unban <ban-index>
```

Removes a ban by its index number.

### Mute / Unmute

```
/mute <uid>       # Mute IC (in-character) chat
/unmute <uid>     # Unmute IC chat
/oocmute <uid>    # Mute OOC (out-of-character) chat
/oocunmute <uid>  # Unmute OOC chat
```

A muted player can still see messages but cannot send them.

### Force Pair / Force Unpair

```
/forcepair <uid1> <uid2>   # Force two players into a pair
/forceunpair <uid>         # Break a player's pair
```

Useful for resolving pairing disputes or helping players who are having trouble with `/pair`.

---

## Area Management

### Lock an area

```
/lock
```

Locks the area you're currently in. Only players who were in the area when it was locked (or who are invited) can enter. Everyone currently inside is auto-invited.

### Unlock an area

```
/unlock
```

Opens the area to everyone again and clears the invite list.

### Invite a player

```
/invite <uid>
```

Adds a player to the invite list for a locked area so they can enter.

### Change background

```
/bg <background_name>
```

Changes the background for the area you're in. All players in the area see the change immediately.

### Editing areas

Areas are defined in `config/areas.toml`:

```toml
[[area]]
name = "Lobby"
background = "gs4"

[[area]]
name = "Courtroom"
background = "gs4"

[[area]]
name = "Defendant Lobby"
background = "gs4"
```

Add, remove, or rename areas by editing this file and restarting the server.

---

## Server Configuration

### Full config.toml reference

```toml
[server]
name = "My Whisker Server"           # Server name (shown in server browser)
description = "Powered by Whisker"    # Server description
motd = "Welcome! Type /help."        # Message of the day
addr = ""                             # Bind address ("" = all interfaces)
port = 27016                          # TCP port
max_players = 100                     # Maximum player count
multiclient_limit = 16                # Max connections per IP
asset_url = ""                        # Asset URL prefix (for custom assets)
default_ban_duration = "3d"           # Default ban length

[websocket]
enable_ws = true                      # Enable plain WebSocket (ws://)
ws_port = 27017                       # WebSocket port
enable_wss = false                    # Enable secure WebSocket (wss://)
wss_port = 443                        # WSS port
tls_cert_path = ""                    # TLS certificate path
tls_key_path = ""                     # TLS key path
allowed_origin = "*"                  # CORS origin for WebSocket

[ratelimit]
msg_rate_limit = 20                   # IC/OOC messages per window
msg_rate_window = 10                  # Window in seconds
ooc_rate_limit = 4                    # OOC messages per window
ooc_rate_window = 1                   # Window in seconds
conn_rate_limit = 10                  # Connections per IP per window
conn_rate_window = 10                 # Window in seconds
raw_pkt_rate_limit = 20               # All packets per window
raw_pkt_rate_window = 2               # Window in seconds
conn_flood_autoban = true             # Auto-ban flooding IPs
flood_ban_threshold = 6               # Rejections before auto-ban

[proxy]
reverse_proxy_mode = false            # Enable for Cloudflare/nginx
trusted_header = "X-Forwarded-For"    # Header for real IP

[moderation]
automod_enabled = false               # Enable automatic moderation
automod_wordlist = "config/banned_words.txt"
automod_action = "kick"               # Action: kick, mute, or ban

[logging]
enable_area_logging = false           # Log area activity to files
log_directory = "logs"                # Log file directory

[plugins]
directory = "plugins"                 # Plugin directory
```

### Characters and music

**Characters** are listed in `config/characters.txt`, one per line:

```
Phoenix
Edgeworth
Maya
```

Players pick from this list when they join.

**Music** is listed in `config/music.txt`, one per line:

```
Pursuit ~ Cornered.opus
Objection! 2001.opus
```

These appear in the music list in the client.

---

## Rate Limiting and Anti-DDoS

Whisker has multiple layers of protection built in.

### Message rate limiting

Separate limits for IC messages, OOC messages, and raw packets. If a player exceeds the limit, their messages are silently dropped until the window resets. Configure these in the `[ratelimit]` section.

### Connection flood protection

If `conn_flood_autoban = true`, Whisker automatically bans IPs that repeatedly exceed the connection rate limit. The `flood_ban_threshold` controls how many rejections trigger the auto-ban (default: 6).

### Multiclient limit

`multiclient_limit = 16` means at most 16 connections from the same IP. This prevents one person from filling up the server. Lower it if you want stricter control.

### Reverse proxy support

If you're behind Cloudflare or nginx, enable `reverse_proxy_mode = true` so Whisker reads the real client IP from proxy headers instead of seeing every connection as coming from the proxy.

---

## Bans and Ban Management

### How bans work

Whisker bans by **IPID** (a hash of the player's IP address) and **HDID** (hardware ID hash). This means:

- Bans persist across reconnections
- IP addresses are never stored in plain text -- only their hashed form
- Players can't trivially evade bans by changing their display name

### Ban duration

Default ban duration is 3 days. Change the default in `config.toml`:

```toml
default_ban_duration = "3d"
```

Or specify it per-ban as the third argument (after the UID and reason):

```
/ban <uid> "Reason here" 1w
```

Use `0` as the duration for permanent bans.

### Removing bans

Use `/unban <ban-index>` to remove a ban. The ban index is assigned when the ban is created.

### IP Guard plugin

The built-in `/ban` works on the hashed **IPID** of one connected player — perfect
for "ban this user," but it can't express "this whole range," "this datacenter,"
or "this country," and it loses to an abuser who reconnects on a fresh IP. The
**optional `ip_guard` plugin** (in `OPTIONAL Plugins/`) fills that gap: it blocks
connections by **IP, CIDR range, ASN, or country** — IPv4 and IPv6 — at the moment
they connect, before they cost the server a thread.

It's optional and off until you opt in — drop `ip_guard.dll` / `ip_guard.so` into
`plugins/`, restart, then edit `config/ip_guard.txt` (a commented template is
created on first run) and run `/ipbanreload`.

**When to reach for it:**

- A single abuser keeps reconnecting from new addresses in the same cloud
  provider → block the provider's **ASN** (`asn AS14061`) and the whole pool is
  gone at once.
- A country shows up in your traffic only as VPN/proxy exit nodes with no real
  players → block it (`country CN`). This is a blunt instrument and **will** also
  block genuine visitors from there, so decide deliberately; use `allow` lines to
  whitelist trusted regulars who'd otherwise be caught.
- You want to drop a known-bad subnet outright → `cidr 203.0.113.0/24`.

**Commands** (need the **BAN** permission):

| Command | Description |
|---------|-------------|
| `/ipban <ip\|cidr> [note]` | Block an address/range live (also saved to `config/ip_guard.txt`) |
| `/ipunban <ip\|cidr>` | Remove a live `/ipban` rule |
| `/ipbanlist` | Show rule counts, geo-database status, and total blocked |
| `/ipbanlog` | Show the most recent blocked connection attempts |
| `/ipbanreload` | Re-read `config/ip_guard.txt` and refresh the geo/ASN database |

**Config (`config/ip_guard.txt`) at a glance** — one rule per line, `#` for
comments:

```text
ip       203.0.113.7
cidr     203.0.113.0/24
cidr     2001:db8::/32
asn      AS14061
country  CN
allow    198.51.100.10        # exception: never block this (wins over all)
```

Options: `alert_blocked` (off by default — post a coalesced OOC notice to staff
when a connection is blocked, so you can see it working and learn what to block
next), `alert_permission` (which role's permission bits see those alerts; a
bitmask matching `roles.toml`, default = the BAN bit), `alert_interval_sec`,
`block_unknown` (drop connections whose IP can't be read at all — *not* IPv6
support; IPv6 is matched normally), `auto_update` / `update_interval_days`, and
overridable database URLs.

**Plug-and-play geolocation.** Country/ASN rules need to know which network a
given IP belongs to. The plugin downloads the public-domain
[iptoasn](https://iptoasn.com) database itself (via `curl`) on first run and
caches it next to your config — no account, no API key, nothing to install. If
the download can't run, the plugin says so in the console and keeps working with
your `ip`/`cidr`/`allow` rules (which need no database).

**IPv6.** Matching is full-stack, but you only *receive* IPv6 connections if the
server listens on IPv6 — set `addr = "::"` in `[server]`. On Linux that also
accepts IPv4 (as v4-mapped, normalised back to dotted-quad); on Windows `::` is
IPv6-only by default. Behind a trusted reverse proxy (Cloudflare/nginx), the real
forwarded IP is what gets matched, so geo-blocking works there regardless.

**Performance.** Blocked connections are rejected at accept time with an
O(log n) lookup and never cost a thread, so this *reduces* load under abuse;
when the plugin isn't installed the core does no extra work at all. See the
[Optional Plugins README](../OPTIONAL%20Plugins/README.md#ip-guard) for the full
reference.

---

## Plugins

Whisker supports runtime plugins as shared libraries (`.so` on Linux, `.dll` on Windows).

### Installing plugins

1. Place the plugin file in the `plugins/` directory
2. Restart the server -- or type `reload` in the console to hot-reload
3. The plugin loads automatically

### Plugin directory

Change where Whisker looks for plugins in `config.toml`:

```toml
[plugins]
directory = "plugins"
```

### Checking loaded plugins

When the server starts, it logs which plugins were loaded:

```
[plugins] Loaded: My Plugin v1.0.0
[plugins] 3 plugins loaded
```

### What plugins can do

Plugins have access to a comprehensive API that lets them:

- **Add commands** — register new `/commands` with permission requirements
- **Hook packets** — intercept and read any AO2 packet before the server handles it
- **Moderate** — kick, mute, and unmute players programmatically
- **Broadcast** — send messages to a single area or the entire server
- **Manage areas** — lock/unlock, change backgrounds, set status, invite players, force-move
- **Read player info** — UID, IPID (for persistent tracking), character, area, mod status
- **Query server state** — total player count, per-area player count, area count

### Writing your own plugins

See the [Plugin Dev Guide](../plugins/PLUGIN%20DEV%20GUIDE%20README.md) for the full development guide with copy-paste examples.

For details on how packets work under the hood, see the [AO2 Protocol Reference](AO2_PROTOCOL.md).

---

## Plugin Hot Reloading

Whisker supports hot-reloading plugins without restarting the server. This means you can add, update, or remove plugins while the server is running and players are connected.

### How to hot-reload

1. Drop new `.dll`/`.so` files into `plugins/`, or replace existing ones
2. Type `reload` in the server console

```
reload
```

The server will:
1. Call `whisker_plugin_shutdown()` on every loaded plugin
2. Close all shared library handles
3. Clear all registered plugin commands and hooks
4. Re-scan the `plugins/` directory
5. Load and initialize all plugins fresh

### What happens to players

- Players stay connected -- hot reload does not disconnect anyone
- Plugin commands become temporarily unavailable during reload (milliseconds)
- After reload, all plugin commands and hooks are re-registered
- Server state (areas, bans, connections) is not affected

### When to use hot-reload

- **Adding a new plugin**: Drop the file in and `reload`
- **Updating a plugin**: Replace the file and `reload`
- **Removing a plugin**: Delete the file from `plugins/` and `reload`
- **Debugging**: Rebuild your plugin and `reload` to test changes instantly

### Limitations

- Core server code cannot be hot-reloaded -- only plugins
- If a plugin stores internal state, that state is lost on reload (the plugin's `whisker_plugin_shutdown` should handle cleanup)
- On Windows, you may need to stop the server to replace a `.dll` that's currently loaded (Windows locks open files). Workaround: rename the old file first, drop in the new one, then `reload`

---

## Reverse Proxy and WSS

For players using webAO (the browser client), you need WebSocket support. For secure connections, you need WSS.

### Quick summary of options

| Option | Difficulty | Best for |
|--------|-----------|----------|
| Cloudflare Tunnel | Easiest | Most servers |
| nginx + Let's Encrypt | Medium | Self-hosted with existing nginx |
| Direct TLS | Advanced | No reverse proxy wanted |

See the full [WSS Setup Guide](WSS_SETUP.md) for step-by-step instructions.

### The short version

1. Set `enable_ws = true` in config.toml
2. Set up a reverse proxy (Cloudflare Tunnel is the easiest)
3. Enable `reverse_proxy_mode = true` in `[proxy]`
4. Players connect via `wss://your-domain.com`

---

## Tips and Best Practices

### Before going public

1. **Create an admin account.** Run `addmod Admin yourpassword admin` in the server console immediately.
2. **Test your server locally** before opening it to the public.
3. **Set up WSS** if you want webAO players to connect.
4. **Customize your areas** in `areas.toml` to match your server's theme.
5. **Add your character list** to `characters.txt`.
6. **Set a clear MOTD** that tells players the rules or where to find them.

### During operation

- **Check the server console** regularly for warnings, mod actions, and suspicious activity.
- **Use /gas** to see who's in which area.
- **Mute before you kick, kick before you ban.** Escalate proportionally.
- **Log mod actions.** The server console prints every login, kick, ban, and mute with timestamps and IPIDs.

### Security

- **Never share moderator passwords** in public channels or in-game.
- **Use strong passwords** for admin accounts. They're typed in OOC chat, so make them long and unique.
- **Give each moderator their own account** rather than sharing one password. This way you can revoke access individually with `removemod`.
- **Use a reverse proxy** (Cloudflare Tunnel) to hide your server's real IP.
- **Enable connection flood protection** (`conn_flood_autoban = true`).
- **Keep multiclient_limit reasonable** (8-16 is fine for most servers).

### If you get DDoS'd

1. Connection flood auto-ban handles most basic floods automatically.
2. Put your server behind Cloudflare Tunnel for free DDoS protection.
3. Lower `conn_rate_limit` and `flood_ban_threshold` temporarily.
4. Check your server console for the offending IPs (shown as hashed IPIDs).
