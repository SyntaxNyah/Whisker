# AO2 Protocol Reference

A plain-English guide to every packet in the Attorney Online 2 protocol, as implemented by Whisker.

**Who is this for?** Client developers, bot authors, plugin writers, or anyone curious about what's actually going over the wire when you play AO.

**Protocol docs credit:** [OmniTroid](https://github.com/omnitroid) and the [Attorney Online dev team](https://github.com/AttorneyOnline) — [github.com/AttorneyOnline/docs](https://github.com/AttorneyOnline/docs)

---

## Table of Contents

- [Wire Format (FantaCode)](#wire-format-fantacode)
- [TCP vs WebSocket](#tcp-vs-websocket)
- [Connection Lifecycle](#connection-lifecycle)
- [Handshake Packets](#handshake-packets)
- [In-Game Packets](#in-game-packets)
  - [CC — Pick a Character](#cc--pick-a-character)
  - [MS — In-Character Message](#ms--in-character-message)
  - [CT — Out-of-Character Chat](#ct--out-of-character-chat)
  - [MC — Music / Area Change](#mc--music--area-change)
  - [CH — Keepalive Ping](#ch--keepalive-ping)
  - [HP — Penalty Bars](#hp--penalty-bars)
  - [PE / EE / DE — Evidence](#pe--ee--de--evidence)
  - [RT — Judge Animation](#rt--judge-animation)
  - [ZZ — Modcall](#zz--modcall)
  - [CASEA — Case Announcement](#casea--case-announcement)
  - [SETCASE — Set Case Preferences](#setcase--set-case-preferences)
- [Server-to-Client Packets](#server-to-client-packets)
  - [BN — Background](#bn--background)
  - [CharsCheck — Character Availability](#charscheck--character-availability)
  - [ARUP — Area Updates](#arup--area-updates)
  - [LE — Evidence List](#le--evidence-list)
  - [BD / KK / KB — Disconnect Packets](#bd--kk--kb--disconnect-packets)
  - [AUTH — Login Result](#auth--login-result)
- [OOC Commands](#ooc-commands)
- [Pairing System](#pairing-system)
- [Area Change Logic](#area-change-logic)
- [Rate Limiting](#rate-limiting)
- [Security](#security)
- [Protocol Constants](#protocol-constants)

---

## Wire Format (FantaCode)

Every AO2 packet looks like this on the wire:

```
HEADER#field1#field2#field3#%
```

- **Header** — A short string that identifies the packet type (`MS`, `CT`, `MC`, etc.)
- **Fields** — Separated by `#`
- **Terminator** — Every packet ends with `#%`

### Escaping

Since `#` and `%` have special meaning, they need to be escaped when they appear inside field values:

| Character | Escape | Why |
|-----------|--------|-----|
| `#` | `<num>` | Would be confused with field separator |
| `%` | `<percent>` | Would be confused with packet terminator |
| `&` | `<and>` | Used as sub-field separator in some packets |
| `$` | `<dollar>` | Reserved |

**Example:** If a player's message is `"price is #100"`, it goes on the wire as `"price is <num>100"`.

When the receiver parses the packet, it unescapes `<num>` back to `#`.

### Limits

| What | Limit |
|------|-------|
| Max packet size | 8,192 bytes |
| Max fields per packet | 1,024 |

---

## TCP vs WebSocket

Whisker supports both raw TCP (for the desktop AO2 client) and WebSocket (for webAO).

**TCP:** Packets arrive as a raw byte stream. The `%` character marks the end of each packet. Since `%` is always escaped in field values, a bare `%` is always a packet boundary.

**WebSocket:** Each WebSocket text frame contains one AO2 packet. The framing handles message boundaries, so the `%` terminator is technically redundant but still included.

| | TCP | WebSocket |
|---|---|---|
| Port | 27016 (default) | 27017 (default) |
| Message boundary | `%` character | Frame boundary |
| Client masking | N/A | Required (RFC 6455) |
| Server masking | N/A | Not masked |
| Ping/pong | CH/CHECK packets | WS ping/pong frames + CH/CHECK |
| TLS | Not built-in | Via reverse proxy (Cloudflare/nginx) or direct WSS |

---

## Connection Lifecycle

Here's what happens from the moment someone connects to when they're chatting in-game:

```
CLIENT                                          SERVER
  |                                                |
  |  ---- TCP connect or WS handshake -----------> |
  |  <--- decryptor#34#%  (legacy, no encryption)   |
  |                                                |
  |  ---- HI#<hardware_id>#% -------------------> |  Ban check happens here
  |  <--- ID#<players>#Whisker#0.1.0#%             |
  |  <--- PN#<players>#<max>#<description>#%       |
  |                                                |
  |  ---- ID#<client_name>#<version>#% ----------> |
  |  <--- FL#yellowtext#flipping#...#%             |  Feature list
  |  <--- ASS#<asset_url>#%                        |  (if configured)
  |                                                |
  |  ---- askchaa#% -----------------------------> |  Full check happens here
  |  <--- SI#<chars>#0#<music_count>#%             |
  |                                                |
  |  ---- RC#% ---------------------------------> |  Request characters
  |  <--- SC#<char1>&&&#<char2>&&&#...#%           |
  |                                                |
  |  ---- RM#% ---------------------------------> |  Request music
  |  <--- SM#<area1>#<area2>#...#<song1>#...#%     |
  |                                                |
  |  ---- RD#% ---------------------------------> |  "I'm ready"
  |  <--- DONE#%                                   |
  |  <--- BN#<background>#%                        |  Area state
  |  <--- HP#1#<defense_hp>#%                      |
  |  <--- HP#2#<prosecution_hp>#%                  |
  |  <--- LE#<evidence>#%                          |
  |  <--- CharsCheck#0#0#-1#0#...#%               |
  |  <--- CT#Whisker#<motd>#1#%                    |  MOTD (if set)
  |                                                |
  |  ---- CC#0#<char_id>#% ----------------------> |  Pick character
  |  <--- PV#<uid>#CID#<char_id>#%                 |
  |                                                |
  |  (now in-game, can send MS/CT/MC/etc.)         |
```

The handshake must complete within **60 seconds** or the connection is dropped.

---

## Handshake Packets

These packets happen in order during connection setup. You can't skip any.

### decryptor (Server -> Client)

```
decryptor#34#%
```

A legacy artifact from when the protocol supported FantaCrypt encryption. The value `34` is a numeric key matching the Akashi/tsuserver convention. The `noencryption` feature in the FL packet tells clients not to encrypt. Sent immediately when a client connects.

### HI (Client -> Server)

```
HI#<hardware_id>#%
```

The client sends its hardware ID (a unique device identifier). The server hashes it and checks the ban list.

| Field | Index | What it is |
|-------|-------|------------|
| Hardware ID | 0 | Unique device string (hashed server-side for privacy) |

**If banned:** Server sends `BD#<reason>#%` and closes the connection.

### ID (Both directions)

**Server -> Client** (response to HI):

```
ID#<player_count>#Whisker#0.1.0#%
```

| Field | Index | What it is |
|-------|-------|------------|
| Player count | 0 | How many people are online |
| Server software | 1 | Always "Whisker" |
| Server version | 2 | Version string |

**Client -> Server** (client identifies itself):

```
ID#<client_name>#<client_version>#%
```

| Field | Index | What it is |
|-------|-------|------------|
| Client name | 0 | e.g., "AO2-Client", "webAO" |
| Client version | 1 | Version string |

### PN (Server -> Client)

```
PN#<current_players>#<max_players>#<description>#%
```

Sent right after the server's ID packet. Tells the client about server capacity.

| Field | Index | What it is |
|-------|-------|------------|
| Current players | 0 | Players online right now |
| Max players | 1 | Server capacity |
| Description | 2 | Server description from config |

### FL (Server -> Client)

```
FL#yellowtext#flipping#customobjections#fastloading#noencryption#deskmod#evidence#cccc_ic_support#arup#casing_alerts#modcall_reason#looping_sfx#additive#effects#y_offset#expanded_desk_mods#auth_packet#%
```

Feature list. Each field is a feature the server supports. Clients use this to know what they can do. Whisker sends all 17 standard features.

### ASS (Server -> Client)

```
ASS#<url>#%
```

Asset URL. Points to a CDN where clients can download character assets, themes, etc. Only sent if configured in `config.toml`.

### askchaa (Client -> Server)

```
askchaa#%
```

"Can I join?" — No fields. The server checks if there's room. If the server is full, it sends `BD` and closes.

### SI (Server -> Client)

```
SI#<character_count>#0#<music_and_area_count>#%
```

Server info. Tells the client how many characters and music tracks to expect.

| Field | Index | What it is |
|-------|-------|------------|
| Character count | 0 | Total characters available |
| Evidence count | 1 | Always 0 during handshake |
| Music + area count | 2 | Total music tracks plus areas |

### RC / SC (Character list)

**Client sends:** `RC#%` ("give me the character list")

**Server responds:** `SC#Phoenix&&&#Miles Edgeworth&&&#...#%`

Each character name is followed by `&&` (legacy placeholder for description and evidence, always empty).

### RM / SM (Music list)

**Client sends:** `RM#%` ("give me the music list")

**Server responds:** `SM#Lobby#Courtroom#...#Trial.mp3#Pursuit.mp3#...#%`

Areas come first (no file extension), then music tracks (with extensions like `.mp3`, `.opus`).

### RD / DONE (Ready)

**Client sends:** `RD#%` ("I'm ready to join")

**Server does:**
1. Assigns the player a unique **UID** (starts at 0, increments)
2. Places them in the first area (area 0)
3. Marks them as joined
4. Sends `DONE#%`
5. Sends area state (background, penalty bars, evidence, character availability)
6. Sends MOTD if configured
7. Broadcasts ARUP updates to everyone

After `DONE`, the player is in-game and can pick a character.

---

## In-Game Packets

These only work after the handshake is complete.

### CC -- Pick a Character

**Direction:** Client -> Server

```
CC#0#<character_id>#%
```

| Field | Index | What it is |
|-------|-------|------------|
| (unused) | 0 | Legacy field, ignored |
| Character ID | 1 | Index into the character list (0-based) |
| Password | 2 | Character password (optional, not validated) |

**What happens:**
1. Server checks the character isn't already taken in this area
2. Releases your previous character (if any)
3. Claims the new one
4. Sends back `PV#<your_uid>#CID#<char_id>#%`
5. Broadcasts updated `CharsCheck` to the area

You can't send IC messages until you've picked a character.

---

### MS -- In-Character Message

**Direction:** Client -> Server (then broadcast to area)

This is the big one — the most complex packet in the protocol. It carries everything about an IC message: the text, animations, effects, sound, and pairing info.

```
MS#0#preemote#stance#emote#Hello world#def#0#-1#0#wit#Phoenix#Nick#0#sfx.wav#0#%
```

| Field | Index | What it is | Limits |
|-------|-------|------------|--------|
| Message type | 0 | 0=normal, 1=objection, 2=hold it, 3=take that | |
| Pre-animation | 1 | Animation played before talking | |
| Stance | 2 | Character stance/pose | |
| Emote | 3 | Emote name or ID | |
| **Message text** | 4 | **The actual dialogue** | Max 256 chars |
| Side | 5 | def/pro (ignored by server) | |
| Screenshake | 6 | Shake intensity | |
| Evidence ID | 7 | Attached evidence (-1 = none) | |
| Flipped | 8 | 0=normal, 1=mirror image | |
| Position | 9 | Stage position (wit, def, pro, jud, hld, hlp) | |
| Character name | 10 | Internal character name | |
| Showname | 11 | Display name above text | Max 30 chars |
| Preamble | 12 | Text before message | |
| SFX | 13 | Sound effect filename | |
| Color | 14 | Text color code | |
| Other char ID | 15 | **Paired character** (set by server) | |
| Other name | 16 | **Paired char name** (set by server) | |
| Other emote | 17 | **Paired char emote** (set by server) | |

**Fields 15-17 are injected by the server.** If you're paired with someone, the server fills in their character info so the client can render both characters side-by-side.

**What happens when you send this:**
1. Mute check — if you're muted, rejected
2. Character check — must have picked a character first
3. Rate limit — max 20 IC messages per 10 seconds
4. Message length — truncated to 256 chars if longer
5. Pairing — server looks up your pair partner and fills fields 15-17
6. Broadcast — sent to everyone in your area

---

### CT -- Out-of-Character Chat

**Direction:** Client -> Server (then broadcast to area)

```
CT#Phoenix_Wright#Hey everyone!#%
```

| Field | Index | What it is | Limits |
|-------|-------|------------|--------|
| OOC name | 0 | Your out-of-character name | 1-30 chars |
| Message | 1 | The message text | 1-256 chars |

**Rate limit:** 4 OOC messages per second.

**Special behavior:** If the message starts with `/`, it's treated as a command (see [OOC Commands](#ooc-commands)) and is NOT broadcast.

If you're OOC-muted, the packet is silently dropped.

---

### MC -- Music / Area Change

**Direction:** Client -> Server (then broadcast to area)

```
MC#Trial.mp3#-1#Nick#1#0#0#%
```

This packet does double duty — it changes music OR moves you to a different area, depending on whether the name has a file extension.

| Field | Index | What it is |
|-------|-------|------------|
| Name | 0 | Music filename OR area name |
| Character ID | 1 | Who's playing it (-1 for area change) |
| Showname | 2 | Display name (optional) |
| Looping | 3 | 0=once, 1=loop (server forces 1) |
| Channel | 4 | Audio channel (server forces 0) |
| Effects | 5 | Effect flags (server forces 0) |

**How the server decides:**
- Name contains `.` (like `Trial.mp3`) -> **music change**, broadcast to area
- Name has no extension (like `Courtroom`) -> **area change**, move the player

---

### CH -- Keepalive Ping

**Direction:** Client -> Server

```
CH#%
```

No fields. Just a heartbeat. Server responds with:

```
CHECK#%
```

The server expects a keepalive within 30 seconds. If it doesn't get one, the connection is dropped.

---

### HP -- Penalty Bars

**Direction:** Client -> Server (then broadcast to area)

```
HP#1#7#%
```

| Field | Index | What it is |
|-------|-------|------------|
| Bar ID | 0 | 1 = defense, 2 = prosecution |
| Value | 1 | Penalty points (0-10) |

Updates the penalty bar for the current area. Both bars start at 10 (full health) and decrease as penalties are given.

---

### PE / EE / DE -- Evidence

Three packets for managing evidence in the current area.

**PE -- Add Evidence** (Client -> Server):

```
PE#Murder Weapon#A bloody knife found at the scene#knife.png#%
```

| Field | Index | What it is | Limits |
|-------|-------|------------|--------|
| Name | 0 | Evidence display name | Max 255 chars |
| Description | 1 | Description text | Max 255 chars |
| Image | 2 | Image filename | Max 255 chars |

**EE -- Edit Evidence** (Client -> Server):

```
EE#0#Updated Name#New description#new_image.png#%
```

| Field | Index | What it is |
|-------|-------|------------|
| Evidence ID | 0 | Which evidence to edit (0-based index) |
| Name | 1 | New name |
| Description | 2 | New description |
| Image | 3 | New image |

**DE -- Delete Evidence** (Client -> Server):

```
DE#0#%
```

| Field | Index | What it is |
|-------|-------|------------|
| Evidence ID | 0 | Which evidence to delete (0-based index) |

After any evidence change, the server broadcasts the full evidence list using the **LE** packet (see [Server-to-Client Packets](#le--evidence-list)).

Max 128 evidence items per area.

---

### RT -- Judge Animation

**Direction:** Client -> Server (then broadcast to area)

```
RT#testimony1#%
```

Triggers a judge/witness stand animation (like "Witness Testimony" or "Cross-Examination" splash screens). Server takes all fields as-is and broadcasts to the area.

---

### ZZ -- Modcall

**Direction:** Client -> Server (then to moderators only)

```
ZZ#Someone is spamming#%
```

| Field | Index | What it is |
|-------|-------|------------|
| Reason | 0 | Why you need a mod (optional) |

**What happens:**
1. Server logs: `[MODCALL] UID 5 (Phoenix) in area 'Courtroom': Someone is spamming`
2. Every online moderator gets a notification (both a CT message and a ZZ packet for the audio cue)
3. You get a confirmation message

This is NOT broadcast to regular players — only mods see it.

---

### CASEA -- Case Announcement

**Direction:** Client -> Server (then broadcast to ALL players)

```
CASEA#field1#field2#field3#field4#field5#field6#%
```

Broadcasts a case announcement to **every connected player** (not just your area). Used for the caseflow/announcement system.

---

### SETCASE -- Set Case Preferences

**Direction:** Client -> Server

```
SETCASE#...#%
```

Acknowledged by the server but currently does nothing. Reserved for future use.

---

## Server-to-Client Packets

These packets are only sent by the server. Clients never send them.

### BN -- Background

```
BN#courtroom#%
```

| Field | Index | What it is |
|-------|-------|------------|
| Background | 0 | Background image name for the current area |

Sent when you join an area or when a mod changes the background with `/bg`.

### CharsCheck -- Character Availability

```
CharsCheck#0#0#-1#0#-1#0#%
```

One field per character in the character list:
- `0` = available (free to pick)
- `-1` = taken (someone else is using it)

Sent when you join an area or when someone picks/releases a character.

### ARUP -- Area Updates

```
ARUP#0#3#0#1#5#0#%
```

Bulk update about all areas at once. One data field per area.

| First field (type) | What each area field means |
|---|---|
| `0` (Players) | Player count in that area |
| `1` (Status) | Area status: `IDLE`, `LOOKING-FOR-PLAYERS`, `CASING`, `RECESS`, `RP`, `GAMING` |
| `2` (CM) | `CM` if a case manager is present, `FREE` otherwise |
| `3` (Lock) | `FREE`, `SPECTATABLE`, or `LOCKED` |

Broadcast to all joined players whenever someone joins, leaves, or area state changes.

### LE -- Evidence List

```
LE#Murder Weapon&A bloody knife&knife.png#Autopsy Report&Time of death: 9PM&autopsy.png#%
```

Full evidence list for the area. Each evidence item has three sub-fields separated by `&`:
- Name
- Description
- Image

Sent when you enter an area or after any evidence change (PE/EE/DE).

### BD / KK / KB -- Disconnect Packets

These all mean "you're being disconnected" with different reasons:

**BD -- Ban Disconnect** (during handshake):
```
BD#You are banned from this server.#%
```
Sent if your IP or hardware ID is banned, or if the server is full.

**KK -- Kicked:**
```
KK#You have been kicked.#%
```
Sent by a moderator's `/kick` command.

**KB -- Banned:**
```
KB#Banned for 3 days: Spamming#%
```
Sent by a moderator's `/ban` command.

After any of these, the server closes your connection.

### AUTH -- Login Result

```
AUTH#1#%
```

| Value | Meaning |
|-------|---------|
| `1` | Login successful -- you're a mod now |
| `0` | Login failed -- wrong password |
| `-1` | Logged out |

Sent in response to `/login` or `/logout` commands.

### SP -- Position Set

```
SP#def#%
```

| Field | Index | What it is |
|-------|-------|------------|
| Position | 0 | Stage position: `def`, `pro`, `wit`, `jud`, `hld`, `hlp` |

Sent when you use `/pos` to change your IC position.

### PV -- Player View (Character Selected)

```
PV#5#CID#3#%
```

| Field | Index | What it is |
|-------|-------|------------|
| UID | 0 | Your player ID |
| Literal | 1 | Always "CID" |
| Character ID | 2 | The character you picked |

Sent after you successfully pick a character with CC.

---

## OOC Commands

When an OOC message (CT packet) starts with `/`, it's treated as a command. The message is NOT broadcast — only you see the result.

### Player Commands

| Command | What it does |
|---------|-------------|
| `/help [command]` | Lists all commands, or shows help for a specific one |
| `/about` | Shows server name, version, and credits |
| `/area [name]` | Shows your current area, or moves you to a named area |
| `/areas` | Lists all areas with player counts and status |
| `/pos [position]` | Shows or sets your IC position (def, pro, wit, jud, hld, hlp) |
| `/ga` or `/players` | Lists everyone in your area with UIDs and character names |
| `/gas` | Lists all players in all areas (grouped by area) |
| `/charselect` | Go back to character select (releases your character) |
| `/global <message>` | Send an OOC message to everyone on the server |
| `/pm <uid> <message>` | Private message a player by their UID |
| `/pair <uid>` | Request to pair with someone for dual-character scenes |
| `/unpair` | Cancel your current pair |
| `/roll [NdM]` | Roll dice (default: 1d6). Example: `/roll 2d20` rolls 2 twenty-sided dice |

### Moderator Commands

You must `/login` first to use these.

| Command | What it does |
|---------|-------------|
| `/login <user> <pass>` | Authenticate as a moderator |
| `/logout` | De-authenticate |
| `/kick <uid>` | Immediately disconnect a player |
| `/ban <uid> [-d duration] [reason]` | Ban a player (default: 3 days) |
| `/unban <index>` | Remove a ban by its index number |
| `/mute <uid>` | Prevent a player from sending IC messages |
| `/unmute <uid>` | Restore IC messaging |
| `/oocmute <uid>` | Prevent a player from sending OOC messages |
| `/oocunmute <uid>` | Restore OOC messaging |
| `/lock` | Lock the current area (requires CM or mod) |
| `/unlock` | Unlock the current area |
| `/invite <uid>` | Invite a player into a locked area |
| `/bg <background>` | Change the area's background image |
| `/forcepair <uid1> <uid2>` | Force two players into a pair |
| `/forceunpair <uid>` | Break a forced pair |

### Ban Duration Format

The `/ban` command accepts a `-d` flag with these formats:

| Format | Duration |
|--------|----------|
| `30s` | 30 seconds |
| `5m` | 5 minutes |
| `1h` | 1 hour |
| `3d` | 3 days (default) |
| `1w` | 1 week |

Example: `/ban 5 -d 1h Spamming the courtroom`

---

## Pairing System

Pairing lets two players appear side-by-side during IC messages (like Phoenix and Maya). There are two types:

### Player Pairing (Mutual Request)

1. Player A types `/pair 5` (where 5 is Player B's UID)
2. Player B types `/pair 3` (where 3 is Player A's UID)
3. Both have requested each other — pair is now active
4. Their IC messages now include each other's character info in fields 15-17

Both players must be in the same area for the pair to be active. Either player can `/unpair` to cancel.

### Forced Pairing (Moderator)

A mod types `/forcepair 3 5` to force two players into a pair. This:
- Takes effect immediately (no mutual request needed)
- Persists across character changes and area moves
- Only breaks with `/forceunpair` or disconnect

### How Pairing Shows Up in Packets

When Player A sends an MS packet and is paired with Player B, the server:
1. Looks up Player B's character info
2. Sets field 15 to Player B's character ID
3. Sets field 16 to Player B's character name
4. Sets field 17 to Player B's last emote

The client then renders both characters on screen.

---

## Area Change Logic

When you move to a new area (via `/area` or the MC packet), here's what happens step by step:

1. **Area exists?** Server checks the area name is valid
2. **Lock check:** If the area is `LOCKED`:
   - Rejected unless you're on the invite list or you're a moderator
3. **Leave old area:**
   - Your character is released (marked free for others to pick)
   - Player count decremented
   - If the area is now empty, it resets (status -> IDLE, lock -> FREE, penalty bars -> 10)
4. **Enter new area:**
   - Player count incremented
   - If your character is free in the new area, you keep it. Otherwise, you become a spectator
5. **State sync:** Server sends you:
   - `BN` (background)
   - `HP` x2 (both penalty bars)
   - `LE` (evidence list)
   - `CharsCheck` (character availability)
6. **Broadcast:** ARUP updates sent to all players (player counts changed)

---

## Rate Limiting

Whisker enforces rate limits to prevent spam and abuse. Each uses a sliding window.

| What | Limit | Window | What happens if exceeded |
|------|-------|--------|--------------------------|
| IC messages (MS) | 20 | 10 seconds | "You are sending messages too fast." |
| OOC messages (CT) | 4 | 1 second | "OOC rate limit. Slow down." |
| Raw packets (any) | 20 | 2 seconds | Disconnected immediately |
| New connections (per IP) | 10 | 10 seconds | Connection refused |

If someone keeps hammering connections past the limit, and `conn_flood_autoban` is enabled, they get auto-banned after 6 violations.

---

## Security

### IP and Hardware ID Hashing

Whisker never stores raw IPs or hardware IDs. Both are hashed:

- **IPID** — Hashed from the client's IP address. Used for IP bans.
- **HDID** — Hashed from the hardware ID the client sends in the HI packet. Used for hardware bans.

Banning a player creates entries for both, so they can't just change their IP to get around it.

### Reverse Proxy Support

When behind Cloudflare or nginx (`reverse_proxy_mode = true`), Whisker reads the real client IP from these headers (in priority order):

1. `X-Forwarded-For` (first IP in the comma-separated list)
2. `X-Real-IP`
3. `CF-Connecting-IP`

This ensures bans work correctly even behind a proxy.

### Ban Expiration

Bans have a duration and expire automatically. Expired bans are pruned from the ban list. The default ban duration is 3 days.

### Multiclient Limit

Max 16 connections from the same IP address. Prevents a single person from flooding the server with alt accounts.

---

## Protocol Constants

For reference, here are all the hardcoded limits in the protocol:

```
Network
  Default TCP port:           27016
  Default WebSocket port:     27017
  Default WSS port:           443
  Max players:                100

Timeouts
  Handshake timeout:          60,000 ms (60 seconds)
  Keepalive interval:         10,000 ms (10 seconds)
  Keepalive timeout:          30,000 ms (30 seconds)
  WebSocket ping interval:    30,000 ms (30 seconds)

Packet Limits
  Max packet size:            8,192 bytes
  Max fields per packet:      1,024

Message Limits
  Max IC message length:      256 characters
  Max OOC message length:     256 characters
  Max OOC name length:        30 characters
  Max showname length:        30 characters

Evidence Limits
  Max evidence name:          255 characters
  Max evidence description:   255 characters
  Max evidence image name:    255 characters
  Max evidence per area:      128

Penalty Bars
  Min value:                  0
  Max value:                  10
  Defense bar ID:             1
  Prosecution bar ID:         2

Security
  Max connections per IP:     16
  Connection rate limit:      10 per 10 seconds
  Flood ban threshold:        6 violations

FantaCode Escaping
  # (hash)        ->  <num>
  % (percent)     ->  <percent>
  & (ampersand)   ->  <and>
  $ (dollar)      ->  <dollar>
```

---

## WebSocket Frame Details

For client/bot developers who need to implement the WebSocket layer directly.

### Handshake

Standard HTTP upgrade:

```
GET / HTTP/1.1
Host: server.example.com
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
Sec-WebSocket-Version: 13
```

Server responds with `101 Switching Protocols` and the accept key (SHA-1 of your key + the magic GUID `258EAFA5-E914-47DA-95CA-C5AB0DC85B11`, base64 encoded).

### Frame Format

```
Byte 0:  [FIN:1][RSV:3][Opcode:4]
Byte 1:  [MASK:1][Length:7]
Bytes 2+: Extended length (if needed) + Mask key (if masked) + Payload
```

| Opcode | Meaning |
|--------|---------|
| `0x1` | Text frame (AO2 packets go here) |
| `0x8` | Close |
| `0x9` | Ping (server auto-responds with pong) |
| `0xA` | Pong |

Max frame size: 65,536 bytes.

Client-to-server frames must be masked. Server-to-client frames are never masked.

---

*Protocol documentation based on the work of [OmniTroid](https://github.com/omnitroid) and the [Attorney Online dev team](https://github.com/AttorneyOnline). Adapted and expanded for Whisker.*
