# Whisker

## Project Overview

Whisker is an Attorney Online 2 (AO2) server written in C3. It implements the full AO2 protocol for both desktop clients (TCP) and web clients (WebSocket). The design prioritizes simplicity, zero magic numbers, and extensibility through plugins rather than forks.

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | C3 |
| Build | `c3c build` (project.json) |
| Protocol | AO2 FantaCode over TCP and WebSocket |
| Config | Simple TOML-like parser (built-in) |
| Plugins | Shared libraries (.so/.dll) loaded at runtime |

**No external dependencies.** Everything uses C3's standard library.

## Architecture

### Entry Point

`src/main.c3` — parses CLI flags, loads config, starts the server.

### Module Layout

| Module | File | Role |
|--------|------|------|
| `whisker` | `main.c3` | Entry point, CLI parsing |
| `whisker::config` | `config.c3` | Config loading + ALL named constants |
| `whisker::server` | `server.c3` | Core server: listeners, client lifecycle, broadcasting |
| `whisker::client` | `client.c3` | Client struct, atomic send (c_send + MSG_NOSIGNAL), display name |
| `whisker::protocol` | `protocol.c3` | FantaCode encode/decode, packet buffer |
| `whisker::area` | `area.c3` | Area state, evidence, CMs, lock |
| `whisker::packets` | `packets.c3` | All AO2 packet handlers |
| `whisker::commands` | `commands.c3` | OOC command dispatch, player commands |
| `whisker::args` | `args.c3` | Quote-aware command argument tokenizer |
| `whisker::moderation` | `moderation.c3` | Mod commands (ban, kick, mute) |
| `whisker::pairing` | `pairing.c3` | Persistent UID-based pairing |
| `whisker::security` | `security.c3` | Rate limiting, IP tracking, bans |
| `whisker::websocket` | `websocket.c3` | WebSocket handshake + frame parsing |
| `whisker::console` | `console.c3` | Server console, admin commands |
| `whisker::plugin` | `plugin.c3` | Plugin loading, hot reload, dispatch |

### Key Design Decisions

1. **No magic numbers.** Every constant is named in `config.c3`. Grep for `const` to find them all.
2. **Thread-per-client.** Simple model like Athena. Each connection gets its own handler thread with its own `@pool_init` memory pool. Client structs are created inside the handler's pool to prevent cross-pool memory corruption.
3. **Plugins over forks.** The plugin system lets you add commands, packet hooks, lifecycle hooks, connection filters, moderation actions, area management, and server-wide broadcasts without modifying core code. The PluginAPI exposes 54 function pointers covering registration, client operations, area operations, broadcasting, packet field access, moderation, argument splitting, ASCII lower-casing, client lifecycle events, and connection filtering. The extended API (v2) added 15 functions for packet inspection, moderation actions, server-wide broadcasts, area manipulation, player counting, and IPID access; later additions appended `args_split` (the quote-aware argument tokenizer) and `to_lower` (an ASCII lower-caser); a v3 block then appended **lifecycle hooks** (`register_lifecycle_hook` — JOIN/LEAVE/UPDATE events fired from `server::notify_client_*`, the only way a plugin can observe disconnects and state changes a packet hook can't) plus the `client_get_ooc_name` / `client_is_hidden` getters they need; a v4 block then appended **connection filters** (`register_conn_filter` — a predicate the server calls for every inbound connection at accept time, before a handler thread is spawned, returning whether to reject it) plus `client_get_ip` (the raw address, not the hashed IPID) and `broadcast_perm_raw` (a role-gated broadcast). All of these are appended at the end of the struct for backwards compatibility with existing compiled plugins — the optional player-list plugin is built entirely on the v3 lifecycle hooks, and the optional `ip_guard` plugin (IP/CIDR/ASN/country blocking) on the v4 connection filter.
4. **Arguments arrive as a list.** Command code never re-splits a raw string. `whisker::args` tokenizes the command tail once (quote-aware: `12 "ban evading" "3 days"` → three tokens) and built-in commands receive a parsed `Args`. The plugin command handler ABI stays `fn void(void*, String)` for binary stability, but plugins get the same splitter through `api.args_split`.
5. **UID-based pairing.** Pairs survive character changes and area moves (inspired by Nyathena).
6. **Multi-layer rate limiting.** Separate limits for IC messages, OOC, raw packets, and connections per IP.
7. **Reverse proxy aware.** Extracts real IPs from X-Forwarded-For, X-Real-IP, CF-Connecting-IP headers.
8. **SIGPIPE-safe.** Global `signal(SIGPIPE, SIG_IGN)` plus per-send `MSG_NOSIGNAL` flag. Writing to a broken socket marks the client disconnected instead of killing the server.
9. **Atomic WebSocket frames.** `send_raw` builds the complete WS frame (header + payload) in a single buffer and sends with one syscall to prevent frame interleaving during concurrent broadcasts.

### Protocol Flow

1. Client connects (TCP or WebSocket)
2. Server sends `decryptor#0#%`
3. Handshake: HI → ID → askchaa → SI → RC → SC → RM → SM → RD → DONE
4. Client selects character (CC → PV)
5. In-game: MS (IC), CT (OOC), MC (music/area), CH (keepalive), etc.

### Packet Format (FantaCode)

```
HEADER#field1#field2#...#%
```

Special characters in fields are escaped:
- `#` → `<num>`
- `&` → `<and>`
- `%` → `<percent>`
- `$` → `<dollar>`

## Build & Run

```bash
c3c build             # Build the server
./out/whisker         # Run with default config dir
./out/whisker -c /path/to/config  # Custom config directory
```

## Configuration

All config in `config/`:
- `config.toml` — server settings, ports, rate limits, proxy config
- `areas.toml` — area definitions
- `characters.txt` — one character name per line
- `music.txt` — one track filename per line
- `roles.toml` — permission role definitions

## Plugin System

Plugins are `.so` (Linux) or `.dll` (Windows) files in `plugins/`.

Each plugin exports:
- `whisker_plugin_info()` — name, version, author
- `whisker_plugin_init(api)` — register commands and hooks
- `whisker_plugin_shutdown()` — cleanup

The PluginAPI (defined in `plugin.c3`, wrappers in `server.c3`) exposes:
- **Registration**: commands, packet hooks, lifecycle hooks (JOIN/LEAVE/UPDATE)
- **Broadcasting**: per-area msg/raw, server-wide msg/raw, ARUP updates
- **Client ops**: send messages, get UID/area/IPID/character/OOC-name info, hidden state, kick, mute/unmute
- **Area ops**: CM management, lock/unlock, invite, background, status, song, force-move
- **Packet access**: read field count and individual fields from hooked packets
- **Server info**: player count, area count, per-area player count
- **Argument parsing**: `args_split` — quote-aware tokenizer so handlers don't split raw strings by hand

See `plugins/README.md` for the full development guide.

## Credits

- **Protocol Documentation**: OmniTroid ([@omnitroid](https://github.com/omnitroid)) and the [Attorney Online dev team](https://github.com/AttorneyOnline)
- **Protocol Spec**: https://github.com/AttorneyOnline/docs
- **Architectural Inspiration**:
  - [Athena](https://github.com/MangosArentLiterature/Athena) (Go)
  - [Nyathena](https://github.com/SyntaxNyah/Nyathena) (Go, fork of Athena)
  - [Ferris-AO](https://github.com/AO2-Client/Ferris-AO) (Rust)
  - [KFO-Server](https://github.com/AttorneyOnline/KFO-Server) (Python, tsuserver3 fork)
  - [webAO](https://github.com/AttorneyOnline/webAO) (JavaScript)
  - [AO2-Client](https://github.com/AttorneyOnline/AO2-Client) (C++)

## License

AGPL-3.0
