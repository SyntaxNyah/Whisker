# Whisker Development Guide

A beginner-friendly guide to understanding and developing the Whisker AO2 server.
Written for people who are new to the C3 programming language.

## Table of Contents

1. [What is Attorney Online?](#what-is-attorney-online)
2. [What is C3?](#what-is-c3)
3. [C3 Crash Course](#c3-crash-course)
4. [Project Structure](#project-structure)
5. [How the Server Works](#how-the-server-works)
6. [The AO2 Protocol](#the-ao2-protocol)
7. [Adding a New Command](#adding-a-new-command)
8. [Adding a New Packet Handler](#adding-a-new-packet-handler)
9. [Writing a Plugin](#writing-a-plugin)
10. [The Pairing System](#the-pairing-system)
11. [Security & Rate Limiting](#security--rate-limiting)
12. [WebSocket & Reverse Proxy](#websocket--reverse-proxy)
13. [Building & Testing](#building--testing)
14. [Common Patterns](#common-patterns)

---

## What is Attorney Online?

Attorney Online (AO) is a multiplayer courtroom roleplay game. Players pick characters
from the Ace Attorney series (or custom characters) and act out courtroom scenes
in real-time. The server manages:

- **Areas** (rooms like "Courtroom", "Lobby", etc.)
- **Characters** (Phoenix Wright, Edgeworth, etc.)
- **IC messages** (in-character: spoken dialogue with animations)
- **OOC messages** (out-of-character: chat without animations)
- **Music** (background tracks that play in areas)
- **Evidence** (items that can be presented)
- **Moderation** (banning, kicking, muting)

Clients connect via TCP (desktop AO2 client) or WebSocket (webAO browser client).

---

## What is C3?

C3 is a modern systems programming language that evolved from C. Think of it as
"C but with the sharp edges filed off." If you know C, C++, Rust, or Go, C3 will
feel familiar.

Key differences from C:
- **No header files.** Modules replace `#include`.
- **Built-in error handling.** Optionals (`Type?`) instead of error codes.
- **Slices.** `char[]` is a pointer + length, not just a pointer.
- **No preprocessor macros.** Use `const`, `enum`, and compile-time features instead.
- **Methods on structs.** You can define `fn void MyStruct.method(&self)`.

Install C3: https://c3-lang.org/

---

## C3 Crash Course

### Variables and Types

```c3
int x = 42;               // integer
float y = 3.14;           // float
bool flag = true;          // boolean
char ch = 'A';            // single character
String name = "Phoenix";   // string (char[] slice)
```

### Functions

```c3
fn int add(int a, int b) {
    return a + b;
}

fn void greet(String name) {
    io::printfn("Hello, %s!", name);
}
```

### Structs

```c3
struct Player {
    int uid;
    String name;
    bool is_online;
}

// Create a struct
Player p = Player {
    .uid = 1,
    .name = "Phoenix",
    .is_online = true,
};
```

### Methods on Structs

```c3
fn String Player.display_name(&self) {
    return self.name;
}

// Call it:
String name = p.display_name();
```

### Enums

```c3
enum Color : int {
    RED,
    GREEN,
    BLUE,
}

Color c = Color.RED;
```

### Error Handling (Optionals)

```c3
// A function that might fail returns Type?
fn int? parse_number(String s) {
    // ... might return an error
}

// Handle errors with 'if (catch)'
int? result = parse_number("42");
if (catch err = result) {
    io::printfn("Error: %s", err);
    return;
}
// After the catch block, 'result' is unwrapped to plain 'int'

// Or use '!' to propagate errors to the caller
int value = parse_number("42")!;

// Or use '??' for a default value
int value = parse_number("abc") ?? 0;
```

### Loops

```c3
// For loop
for (int i = 0; i < 10; i++) {
    io::printfn("%d", i);
}

// While loop
while (condition) {
    // ...
}

// Foreach (over arrays/slices)
String[] names = { "Phoenix", "Edgeworth", "Maya" };
foreach (name : names) {
    io::printfn("%s", name);
}
```

### Strings

```c3
String s = "Hello";
usz len = s.len;                    // length
bool has = s.contains("ell");       // substring check
String[] parts = s.tsplit(",");     // split (temp allocated)
String upper = s.to_upper();        // uppercase

// Dynamic strings (growable)
DString ds = dstring::temp();       // temp-allocated builder
ds.append_string("Hello ");
ds.append_string("World");
String result = ds.str_view();      // "Hello World"

// Formatting
String msg = string::tformat("UID %d: %s", 42, "test");
```

### Modules and Imports

```c3
module whisker::mymodule;  // Declare this file's module

import std::io;            // Import standard I/O
import whisker::config;    // Import another Whisker module
```

### Memory

C3 uses manual memory management with allocators:

```c3
// Heap allocation (lives until you free it)
Player* p = mem::new(Player);
mem::free(p);

// Temp allocation (freed at end of @pool scope)
@pool() {
    String s = string::tformat("hello %d", 42);
    // 's' is freed when this scope exits
}
```

For server code, we mostly use:
- `mem::new()` for long-lived data (server struct, areas)
- `@pool_init(mem, size)` for per-thread memory pools (each client handler thread gets its own)
- `dstring::temp()` for building strings within a request
- `string::tformat()` for temporary formatted strings

> **Important:** All allocations for a Client (struct, DString, temps)
> must happen inside the same `@pool_init` scope. Never allocate in one
> pool and free in another — this corrupts the allocator silently.

---

## Project Structure

```
Whisker/
├── project.json        C3 build configuration
├── CLAUDE.md           AI assistant project context
├── DEVELOPMENT.md      This file
├── README.md           Project overview
├── LICENSE             AGPL-3.0
├── config/
│   ├── config.toml     Server settings
│   ├── areas.toml      Area definitions
│   ├── characters.txt  Character list
│   ├── music.txt       Music list
│   └── roles.toml      Permission roles
├── plugins/
│   └── README.md       Plugin dev guide
├── logs/               Area logs (if enabled)
└── src/
    ├── main.c3         Entry point
    ├── config.c3       Config + named constants
    ├── server.c3       Core server logic
    ├── client.c3       Client state
    ├── protocol.c3     Packet encoding/decoding
    ├── area.c3         Area management
    ├── packets.c3      Packet handlers
    ├── commands.c3     Command system
    ├── args.c3         Quote-aware command argument parsing
    ├── moderation.c3   Mod commands
    ├── pairing.c3      Pairing system
    ├── security.c3     Rate limiting & protection
    ├── websocket.c3    WebSocket support
    ├── console.c3      Interactive server console
    └── plugin.c3       Plugin system
```

### Where Things Live

| "I want to..." | File |
|----------------|------|
| Change a constant/default | `config.c3` |
| Add a player command | `commands.c3` |
| Add a mod command | `moderation.c3` |
| Parse command arguments | `args.c3` |
| Handle a new AO2 packet | `packets.c3` |
| Change area behavior | `area.c3` |
| Change rate limits | `security.c3` + `config.c3` |
| Fix WebSocket issues | `websocket.c3` |
| Add something without editing core | Write a plugin! |

---

## How the Server Works

### Startup Flow

```
main() in main.c3
  └─ Parse CLI args (-c config dir, --help, --version)
  └─ server::init(config_dir) in server.c3
       ├─ Load config.toml
       ├─ Load characters.txt, music.txt
       ├─ Load areas.toml
       ├─ Load plugins from plugins/
       └─ Return Server struct
  └─ server.run() in server.c3
       ├─ Start TCP listener on configured port
       ├─ (Start WebSocket listener if enabled)
       └─ Accept loop: for each connection → handle_new_connection()
```

### Connection Flow

```
handle_new_connection()
  ├─ Ban check → reject banned IPs immediately (no thread spawned)
  ├─ Connection rate limit check → reject if flooding
  ├─ Multiclient limit check → reject if too many from same IP
  ├─ Server full check → reject if MAX_SERVER_CLIENTS reached
  └─ Spawn client_handler_thread (detached)

client_handler_thread()
  ├─ @pool_init — each thread gets its own memory pool
  ├─ Create Client struct inside the thread's pool
  ├─ Configure rate limiters from server config
  ├─ Register client in the server's client list
  ├─ Send decryptor packet (tells client: no encryption)
  └─ client_handler() — main packet loop
       ├─ Read bytes from socket (TCP) or WebSocket frames
       ├─ Feed to PacketBuffer
       ├─ Extract complete packets (delimited by %)
       ├─ Raw packet rate limit check
       ├─ Parse packet (FantaCode → Packet struct)
       ├─ Plugin hook check (plugins get first look)
       └─ Dispatch to handler in packets.c3
```

> **Why Client is created in the handler thread:** The Client struct and
> its DString buffers must live in the same `@pool_init` as the code that
> grows them. Creating Client in the accept loop and passing it to a
> handler thread causes cross-pool memory corruption — the DString grows
> in the handler's pool but was allocated in the listener's pool, and
> freeing across pools corrupts the listener's allocator.

### Sending Data & SIGPIPE

All outbound data goes through `Client.send_raw()` in `client.c3`, which
uses the C `send()` syscall directly with `MSG_NOSIGNAL` (Linux) to
prevent SIGPIPE from killing the process when writing to a broken socket.
Additionally, `main.c3` installs a global `signal(SIGPIPE, SIG_IGN)`
handler as a safety net.

For WebSocket clients, `send_raw` builds the complete WebSocket frame
(header + payload) in a single stack buffer and sends it atomically in
one `send()` call. This prevents frame interleaving when multiple threads
broadcast to the same client concurrently. Packets larger than 16 KB
(e.g., character/music lists) use two sends, which is safe because they
only occur during the single-threaded handshake phase.

### The Join Handshake

This is the sequence every AO2 client follows to connect:

```
Client                          Server
  │                               │
  │──── HI (hardware ID) ───────>│
  │                               │── Check bans
  │<──── ID (server info) ───────│
  │<──── PN (player count) ──────│
  │                               │
  │──── ID (client software) ──>│
  │<──── FL (feature list) ──────│
  │<──── ASS (asset URL) ────────│ (optional)
  │                               │
  │──── askchaa ────────────────>│
  │<──── SI (server info) ───────│ (char/music counts)
  │                               │
  │──── RC (request chars) ────>│
  │<──── SC (character list) ────│
  │                               │
  │──── RM (request music) ────>│
  │<──── SM (area + music list) ─│
  │                               │
  │──── RD (ready) ─────────────>│── Allocate UID
  │<──── DONE ───────────────────│── Join complete!
  │                               │
  │──── CC (pick character) ───>│
  │<──── PV (confirmed) ─────────│
  │                               │
  │   Now in-game. Can send:      │
  │   MS (IC), CT (OOC),         │
  │   MC (music), CH (keepalive) │
```

---

## The AO2 Protocol

### Packet Format (FantaCode)

Every packet looks like this on the wire:

```
HEADER#field1#field2#field3#%
```

- Fields are separated by `#`
- Packets end with `#%`
- Special characters in fields are escaped:
  - `#` → `<num>`
  - `&` → `<and>`
  - `%` → `<percent>`
  - `$` → `<dollar>`

### Key Packets

| Packet | Direction | Purpose |
|--------|-----------|---------|
| `HI` | C→S | Send hardware ID |
| `ID` | Both | Software identification |
| `FL` | S→C | Feature list |
| `SC` | S→C | Character list |
| `SM` | S→C | Area + music list |
| `CC` | C→S | Select character |
| `PV` | S→C | Confirm character |
| `MS` | Both | In-character message (the big one) |
| `CT` | Both | Out-of-character message |
| `MC` | Both | Music change / area change |
| `CH` | C→S | Keepalive ping |
| `CHECK` | S→C | Keepalive response |
| `HP` | Both | Penalty bar update |
| `BN` | S→C | Background change |
| `ARUP` | S→C | Area room update |
| `ZZ` | Both | Modcall |

The full protocol spec is maintained by OmniTroid and the AO dev team:
https://github.com/AttorneyOnline/docs

---

## Adding a New Command

Built-in commands receive a parsed **argument list**, not a raw string. The
dispatcher splits the command tail once — quote-aware — and hands every command
an `args::Args`. You never call `tsplit` or `index_of_char` yourself.

```c3
// The Args API (see args.c3)
argv.is_empty()             // true if no arguments were given
argv.count                  // number of tokens
argv.get(i)                 // token i, or "" if missing
argv.opt(i, "fallback")     // token i, or a fallback string
argv.get_int(i, -1)         // token i parsed as int, or a fallback
argv.rest(from)             // raw remainder from token `from` (free text)
argv.has("-flag")           // is "-flag" one of the tokens?
argv.value_of("-d", "3d")   // the token after "-d", or a fallback
```

Quotes group whitespace into one token, so `/ban 12 "ban evading" "3 days"`
arrives as the three tokens `12`, `ban evading`, `3 days`.

### Step 1: Add the handler in `commands.c3`

```c3
fn void cmd_coinflip(client::Client* c, args::Args* argv) {
    long seed = security::current_time_sec() * (long)c.uid;
    bool heads = (seed % 2) == 0;

    c.send_server_message(
        string::tformat("Coin flip: %s!", heads ? "Heads" : "Tails")
    );
}
```

A command that takes arguments just reads them from `argv`:

```c3
fn void cmd_slap(server::Server* srv, client::Client* c, args::Args* argv) {
    int uid = argv.get_int(0, -1);          // /slap <uid> [reason...]
    String reason = argv.rest(1);           // everything after the UID
    if (uid < 0) {
        c.send_server_message("Usage: /slap <uid> [reason]");
        return;
    }
    // ...
}
```

### Step 2: Register in the dispatch function

In `commands.c3`, find the `dispatch()` function and add a case. The parsed
list is already built as `argv` — pass a pointer to it:

```c3
case cmd_name == "coinflip":  cmd_coinflip(c, &argv);
```

### Step 3: Add to /help

In `cmd_help()`, add a line:

```c3
c.send_server_message("/coinflip        - Flip a coin");
```

That's it! Three steps. No configuration files, no registration framework, and
no hand-rolled argument splitting.

> **Plugins:** standalone plugin command handlers keep the frozen
> `fn void(void*, String)` signature for ABI stability, so they receive the raw
> argument string. They get the very same splitter through `api.args_split` —
> see the [Plugin Dev Guide](../plugins/PLUGIN%20DEV%20GUIDE%20README.md).

---

## Adding a New Packet Handler

Say you need to handle a custom packet `XY`:

### Step 1: Add handler in `packets.c3`

```c3
fn void handle_xy(server::Server* srv, client::Client* c, protocol::Packet* pkt) {
    if (pkt.field_count < 1) return;
    // Your logic here
}
```

### Step 2: Register in dispatch

In `packets.c3`, find `dispatch()` and add:

```c3
if (header == "XY") { handle_xy(srv, c, pkt); return; }
```

---

## Writing a Plugin

This is the recommended way to add features. See the [Plugin Dev Guide](../plugins/PLUGIN%20DEV%20GUIDE%20README.md) for
the full guide. Here's the short version:

1. Create a C3 dynamic library project
2. Export `whisker_plugin_info`, `whisker_plugin_init`, `whisker_plugin_shutdown`
3. In init, register your commands and packet hooks via the `PluginAPI`
4. Build as `.so` / `.dll`
5. Drop in `plugins/`, restart server

Plugins can:
- Add new `/commands`
- Intercept any packet before the default handler and read packet fields
- Send messages to individual clients or broadcast to areas / the whole server
- Kick, mute, and unmute players
- Read client info (UID, area, character, IPID, mod status)
- Manage areas (lock/unlock, set background, set status, invite, move players)
- Query server state (player counts, area counts, area player counts)

Plugins cannot:
- Modify core server code
- Access internal state not exposed through the API
- Ban players (bans require IPID + HDID handling that lives in core)

This is intentional. It keeps plugins stable across server updates.

---

## The Pairing System

Whisker uses persistent, UID-based pairing inspired by Nyathena:

1. Player A does `/pair 5` (requests pair with UID 5)
2. Player B does `/pair 3` (requests pair with UID 3 = Player A)
3. Both requests match → **mutual pair established**
4. Pair survives character changes and area moves
5. Pair dissolves on disconnect or `/unpair`

### How it works in code

In `pairing.c3`:
- `request_pair()` — sets `pair_wanted_uid`, checks for mutual match
- `cancel_pair()` — full bidirectional cleanup (clears all references)
- `resolve_pair()` — called during MS packet processing to find the active pair partner

In `packets.c3`, the `handle_ms()` function:
1. Calls `resolve_pair()` to find the partner
2. If partner exists, fills in `other_charid`, `other_name`, `other_emote`
3. Broadcasts the completed MS packet with pairing info

### Key fields in Client struct

```c3
pair_wanted_uid  // UID of player we requested to pair with
force_pair_uid   // UID of active pair partner (set when mutual)
```

Both default to `NO_PAIR` (-1).

---

## Security & Rate Limiting

### Multi-Layer Rate Limiting

Whisker has separate rate limiters for different actions:

| Layer | What it limits | Default |
|-------|---------------|---------|
| Raw packet | All AO2 packets | 20 per 2s |
| IC/Music | In-character messages | 20 per 10s |
| OOC | Out-of-character chat | 4 per 1s |
| Connection | New connections per IP | 10 per 10s |

Each uses a **sliding window counter** (see `security.c3`):
- Keeps timestamps of recent actions in a circular buffer
- Counts how many fall within the window
- Rejects if count exceeds limit

### Connection Flood Protection

If an IP exceeds the connection rate limit repeatedly:
1. Connections are rejected
2. Rejection counter increments
3. If rejections exceed `flood_ban_threshold` → auto-ban

### IP Hashing

Raw IP addresses are **never stored**. They're immediately hashed into
an IPID (IP identifier) using FNV-1a. The IPID is used for:
- Ban matching
- Rate limit tracking
- Multiclient detection
- Logging

### Reverse Proxy Support

When behind Cloudflare, nginx, or another proxy:
1. Set `reverse_proxy_mode = true` in config
2. Whisker extracts the real IP from headers (checked in order):
   - `CF-Connecting-IP` (Cloudflare)
   - `X-Forwarded-For` (first IP in chain)
   - `X-Real-IP` (nginx)

---

## WebSocket & Reverse Proxy

### How WebSocket Works

When a webAO client connects:
1. Client sends an HTTP GET with `Upgrade: websocket` header
2. Server reads the `Sec-WebSocket-Key` header
3. Server computes accept key: `SHA-1(key + magic GUID)` → base64
4. Server sends HTTP 101 Switching Protocols
5. Connection upgrades to WebSocket framing

After upgrade, each WebSocket text frame contains one or more AO2 packets.
Unlike TCP, we don't need the `%` delimiter — WebSocket provides message boundaries.

### WSS via Reverse Proxy (Recommended)

The recommended setup for secure WebSocket:

```
Internet (wss://) → Cloudflare/nginx (TLS termination) → Whisker (ws://)
```

1. Whisker listens on a plain WebSocket port (e.g., 27017)
2. The proxy handles TLS certificates and encryption
3. The proxy forwards plain WebSocket to Whisker
4. Whisker reads `X-Forwarded-For` to get the real client IP

This is the same approach used by Nyathena, KFO-Server, and other AO2 servers.

---

## Building & Testing

### Prerequisites

- Install C3: https://c3-lang.org/ (see [Build Guide](BUILD_GUIDE.md) for step-by-step)
- Clone this repo

### Build

```bash
c3c build           # Build the server
```

Output binary: `out/whisker` (or `out/whisker.exe` on Windows)

### Run

```bash
./out/whisker                    # Use config/ directory
./out/whisker -c /other/config   # Custom config path
./out/whisker --help             # Show CLI options
./out/whisker --version          # Show version
```

### Test with AO2 Client

1. Start Whisker: `./out/whisker`
2. Open the AO2 desktop client
3. Connect to `localhost:27016` (TCP) or use "Direct Connect"
4. You should see the character select screen

### Test with webAO

1. Make sure `enable_ws = true` in `config/config.toml`
2. Start Whisker: `./out/whisker`
3. Open webAO: `https://web.aceattorneyonline.com/client.html?mode=join&connect=ws://localhost:27017`
4. If the official webAO gives you mixed-content errors (HTTPS page trying to connect
   to ws://), use [webao.miku.pizza](https://webao.miku.pizza) instead — it's a fork
   by SyntaxNyah that handles the HTTP/HTTPS issue.

### Quick Network Tests

```bash
# Test TCP connection (you should see "decryptor#0#%")
nc localhost 27016

# Test WebSocket connection
wscat --connect ws://localhost:27017

# Check if ports are listening
ss -tlnp | grep -E "27016|27017"
```

### Useful Dev Commands

```bash
# Rebuild after code changes
c3c build

# Rebuild and run in one line
c3c build && ./out/whisker

# Search for a function in the source
grep -rn "fn.*handle_ms" src/

# Search for a constant
grep -rn "const.*PENALTY" src/config.c3

# See all packet handlers
grep -n "fn void handle_" src/packets.c3

# See all commands
grep -n "case cmd_name ==" src/commands.c3

# See all mod commands
grep -n "fn void cmd_" src/moderation.c3

# Count lines of code
wc -l src/*.c3
```

---

## Common Patterns

### Sending messages to a client

```c3
// OOC message from the server
c.send_server_message("Hello!");

// Any packet
String[] fields = { "value1", "value2" };
c.send_packet("HEADER", fields);

// Raw wire data
c.send_raw("HEADER#value1#value2#%");
```

### Broadcasting to an area

```c3
server::broadcast_area(srv, area_id, packet_string);
```

### Broadcasting to everyone

```c3
server::broadcast(srv, packet_string);
```

### Finding a client by UID

```c3
client::Client* target = server::find_client_by_uid(srv, uid);
if (target == null) {
    c.send_server_message("Player not found.");
    return;
}
```

### Checking permissions

```c3
if (!c.has_permission(commands::PERM_BAN)) {
    c.send_server_message("No permission.");
    return;
}
```

### Parsing command arguments

Built-in command handlers receive an already-parsed `args::Args*` — never split
the raw string yourself:

```c3
// /kick <uid>
int uid = argv.get_int(0, -1);
if (uid < 0) {
    c.send_server_message("Usage: /kick <uid>");
    return;
}

// /pm <uid> <message> — message is free text after the UID
int target = argv.get_int(0, -1);
String message = argv.rest(1);

// /ban <uid> [reason] [duration] — quotes group multi-word tokens
String reason   = argv.opt(1, "No reason given.");
long   duration = argv.count >= 3 ? security::parse_duration(argv.get(2)) : 0;
```

### Building a packet

```c3
// With the protocol module
String pkt = protocol::build("CT", { "Server", "Hello!", "1" });

// Or manually for complex packets
DString pkt = dstring::temp();
pkt.append_string("ARUP#0");
for (int i = 0; i < srv.area_count; i++) {
    pkt.append_char('#');
    pkt.append_string(string::tformat("%d", srv.areas[i].player_count));
}
pkt.append_string("#%");
```

### No Magic Numbers

Every numeric or string constant is defined in `config.c3` with a descriptive name.
Never write bare numbers in game logic:

```c3
// BAD:
if (bar < 0 || bar > 10) return;

// GOOD:
if (value < config::PENALTY_BAR_MIN || value > config::PENALTY_BAR_MAX) return;
```

---

## Protocol Documentation Credits

The AO2 protocol specification used to build this server was written and
maintained by **OmniTroid** ([@omnitroid](https://github.com/omnitroid)) and the
**Attorney Online developer team** ([github.com/AttorneyOnline](https://github.com/AttorneyOnline)).

Full protocol docs: [github.com/AttorneyOnline/docs](https://github.com/AttorneyOnline/docs)

## Further Reading

- [AO2 Protocol Reference](AO2_PROTOCOL.md) — Every packet documented, wire format, handshake, security
- [C3 Language Documentation](https://c3-lang.org/)
- [Upstream AO2 Protocol Spec](https://github.com/AttorneyOnline/docs)
- [Plugin Development Guide](../plugins/PLUGIN%20DEV%20GUIDE%20README.md)
- [Build Guide](BUILD_GUIDE.md) — Installing, building, running, testing
- [WSS Setup Guide](WSS_SETUP.md) — Cloudflare Tunnel, nginx + Let's Encrypt
- [Mod Guide](MOD_GUIDE.md) — Server administration and moderation
- [Cloudflare Tunneling for AO](https://github.com/AttorneyOnline/docs/blob/master/docs/Server%20Hosting/cloudflare-tunneling.md)
- [Secure WebSockets Setup](https://github.com/AttorneyOnline/docs/blob/master/docs/Server%20Hosting/secure-websockets.md)
- [webao.miku.pizza](https://webao.miku.pizza) — Lemmy AO. SyntaxNyah's webAO fork (solves HTTPS mixed-content issue)
