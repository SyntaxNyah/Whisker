# Whisker Mod Guide

Everything you need to know to set up, run, and moderate your Whisker AO2 server.

---

## Table of Contents

1. [First-Time Setup](#first-time-setup)
2. [Admin Password](#admin-password)
3. [Logging In as a Moderator](#logging-in-as-a-moderator)
4. [Roles and Permissions](#roles-and-permissions)
5. [Moderation Commands](#moderation-commands)
6. [Area Management](#area-management)
7. [Server Configuration](#server-configuration)
8. [Rate Limiting and Anti-DDoS](#rate-limiting-and-anti-ddos)
9. [Bans and Ban Management](#bans-and-ban-management)
10. [Plugins](#plugins)
11. [Reverse Proxy and WSS](#reverse-proxy-and-wss)
12. [Tips and Best Practices](#tips-and-best-practices)

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

### 4. Set your admin password

**This is the most important step.** See the next section.

### 5. Run the server

```bash
./build/whisker
```

Or with a custom config directory:

```bash
./build/whisker -c /path/to/my/config
```

---

## Admin Password

**CHANGE THE DEFAULT PASSWORD IMMEDIATELY.**

The default moderator password is `changeme`. If you leave this, anyone who guesses it has full control of your server.

### Where to change it

Open `src/moderation.c3` and find this line:

```c3
const String DEFAULT_MOD_PASSWORD = "changeme";
```

Change `"changeme"` to your own password:

```c3
const String DEFAULT_MOD_PASSWORD = "your_secure_password_here";
```

Then rebuild the server:

```bash
c3c build
```

### Password tips

- Use something long and hard to guess. This isn't a user-facing login page  -- it's typed in OOC chat, so convenience matters less than security.
- Don't use the same password you use for other services.
- Don't share the password in public channels. Give it to trusted moderators only.
- The password is compiled into the binary. If someone gets access to your binary, they could extract it. Run your server on a machine you trust.

### Future improvements

The current auth system is intentionally minimal. The code comments say:

> "In production, use bcrypt/argon2 and a proper account DB. This is the minimal viable implementation -- extend via plugins."

For now, the single-password approach works fine for small to medium servers. If you need per-user accounts, role-based passwords, or database-backed auth, that's what the plugin system is for.

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
/login Admin your_secure_password_here
```

- `<username>` can be anything -- it's a display label for logs, not an account system.
- `<password>` must match the password you set in `moderation.c3`.

On success, you'll see:

```
Logged in as Admin.
```

You now have full moderator permissions. The server console will log:

```
[mod] a1b2c3d4 logged in as 'Admin' (UID 0)
```

### Logout

```
/logout
```

This immediately removes all your permissions for the rest of the session.

### Important notes

- Login is per-session. If you disconnect, you need to log in again.
- Your login is not visible to other players. Only the server console logs it.
- Failed login attempts are also logged on the server console, so you can see if someone is trying to guess the password.

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

### Current login behavior

Right now, `/login` grants ALL moderator permissions (MUTE through ADMIN) if the password matches. The roles in `roles.toml` are defined for future use when per-user accounts are implemented. To customize what `/login` grants, edit the permission assignment in `src/moderation.c3`.

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
/ban <uid> [-d duration] [reason]
```

Bans the player by IP hash (IPID) and hardware ID (HDID). They cannot reconnect until the ban expires or is removed.

**Duration format:**
- `30s` = 30 seconds
- `5m` = 5 minutes
- `1h` = 1 hour
- `3d` = 3 days (default)
- `1w` = 1 week

**Examples:**

```
/ban 5                          # Ban UID 5 for 3 days (default), no reason
/ban 5 Spamming                 # Ban UID 5 for 3 days, reason: Spamming
/ban 5 -d 1h Flooding chat      # Ban UID 5 for 1 hour, reason: Flooding chat
/ban 5 -d 0 Permanent ban       # Ban UID 5 permanently
```

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

Or specify per-ban with the `-d` flag:

```
/ban <uid> -d 1w Reason here
```

Use `-d 0` for permanent bans.

### Removing bans

Use `/unban <ban-index>` to remove a ban. The ban index is assigned when the ban is created.

---

## Plugins

Whisker supports runtime plugins as shared libraries (`.so` on Linux, `.dll` on Windows).

### Installing plugins

1. Place the plugin file in the `plugins/` directory
2. Restart the server
3. The plugin loads automatically at startup

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

### Writing your own plugins

See the [Plugin Dev Guide](../plugins/PLUGIN%20DEV%20GUIDE%20README.md) for the full development guide with 9 copy-paste examples.

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

1. **Change the admin password.** Cannot stress this enough.
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

- **Never share your admin password** in public channels or in-game.
- **Keep your server binary private.** The password is compiled in.
- **Use a reverse proxy** (Cloudflare Tunnel) to hide your server's real IP.
- **Enable connection flood protection** (`conn_flood_autoban = true`).
- **Keep multiclient_limit reasonable** (8-16 is fine for most servers).

### If you get DDoS'd

1. Connection flood auto-ban handles most basic floods automatically.
2. Put your server behind Cloudflare Tunnel for free DDoS protection.
3. Lower `conn_rate_limit` and `flood_ban_threshold` temporarily.
4. Check your server console for the offending IPs (shown as hashed IPIDs).
