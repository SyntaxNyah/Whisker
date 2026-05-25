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
| `whisker::moderation` | `moderation.c3` | Mod commands (ban, kick, mute) |
| `whisker::pairing` | `pairing.c3` | Persistent UID-based pairing |
| `whisker::security` | `security.c3` | Rate limiting, IP tracking, bans |
| `whisker::websocket` | `websocket.c3` | WebSocket handshake + frame parsing |
| `whisker::console` | `console.c3` | Server console, admin commands |
| `whisker::plugin` | `plugin.c3` | Plugin loading, hot reload, dispatch |

### Key Design Decisions

1. **No magic numbers.** Every constant is named in `config.c3`. Grep for `const` to find them all.
2. **Thread-per-client.** Simple model like Athena. Each connection gets its own handler thread with its own `@pool_init` memory pool. Client structs are created inside the handler's pool to prevent cross-pool memory corruption.
3. **Plugins over forks.** The plugin system lets you add commands and packet hooks without modifying core code.
4. **UID-based pairing.** Pairs survive character changes and area moves (inspired by Nyathena).
5. **Multi-layer rate limiting.** Separate limits for IC messages, OOC, raw packets, and connections per IP.
6. **Reverse proxy aware.** Extracts real IPs from X-Forwarded-For, X-Real-IP, CF-Connecting-IP headers.
7. **SIGPIPE-safe.** Global `signal(SIGPIPE, SIG_IGN)` plus per-send `MSG_NOSIGNAL` flag. Writing to a broken socket marks the client disconnected instead of killing the server.
8. **Atomic WebSocket frames.** `send_raw` builds the complete WS frame (header + payload) in a single buffer and sends with one syscall to prevent frame interleaving during concurrent broadcasts.

### Protocol Flow

1. Client connects (TCP or WebSocket)
2. Server sends `decryptor#34#%`
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
c3c build              # Build the server
./build/whisker        # Run with default config dir
./build/whisker -c /path/to/config  # Custom config directory
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
