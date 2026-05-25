# Whisker

A clean, minimal Attorney Online 2 server written in C3.

## Goals

- **Simple**: No magic numbers, no unnecessary abstractions. Read the code and understand it.
- **Fast**: Built for speed with configurable rate limits and DDoS resilience.
- **Extensible**: Drop plugins into `plugins/` and they load at startup. No forks needed, but encouraged regardless!
- **Compatible**: Supports AO2 desktop client (TCP) and webAO (WebSocket/WSS).
- **Secure**: Cloudflare reverse proxy support, X-Forwarded-For, connection flood protection.

## Quick Start

```bash
# Build
c3c build

# Run (config/ directory included with defaults)
./out/whisker

# Custom config directory
./out/whisker -c /path/to/config
```
Note: This is just if you want to run a config file that's not in the default directory. For full build guide see here: https://github.com/SyntaxNyah/Whisker/blob/main/docs/BUILD_GUIDE.md

## Configuration

All config lives in `config/`:

| File | Purpose |
|------|---------|
| `config.toml` | Server settings, ports, rate limits, proxy |
| `areas.toml` | Area definitions |
| `characters.txt` | Character list (one per line) |
| `music.txt` | Music list (one per line) |
| `roles.toml` | Moderator role permissions |

### WebSocket / WSS / Reverse Proxy Setup

Whisker handles ws/wss the same way as Nyathena and other AO servers:

**Option 1: Cloudflare Tunnel** (easiest)
1. Set `enable_ws = true` in config, pick an internal port (e.g., 27017)
2. Create a Cloudflare tunnel pointing HTTP to `localhost:27017`
3. Enable `reverse_proxy_mode = true` in `[proxy]`
4. Clients connect via `wss://your-domain.com` — Cloudflare handles TLS

**Option 2: nginx + Let's Encrypt**
1. Set `enable_ws = true`, pick an internal port
2. Configure nginx to reverse proxy with WebSocket upgrade headers:
   ```nginx
   location / {
       proxy_pass http://localhost:27017;
       proxy_http_version 1.1;
       proxy_set_header Upgrade $http_upgrade;
       proxy_set_header Connection "Upgrade";
       proxy_set_header Host $host;
       proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
   }
   ```
3. Use certbot for Let's Encrypt TLS on nginx
4. Enable `reverse_proxy_mode = true` in `[proxy]`

**Option 3: Direct TLS**
1. Set `enable_wss = true`, provide `tls_cert_path` and `tls_key_path`
2. Whisker terminates TLS directly (no reverse proxy needed)

All three options extract the real client IP correctly.

**Tip for webAO users:** If `web.aceattorneyonline.com` (hosted on GitHub Pages)
blocks `ws://` connections due to mixed-content, try [webao.miku.pizza](https://webao.miku.pizza)
— a fork by LemmyAO that handles the HTTP/HTTPS issue so your browser doesn't block
the WebSocket connection.

For detailed step-by-step setup instructions with commands, see the [WSS Setup Guide](docs/WSS_SETUP.md).

## Plugins

The plugin system is the answer to AO server fragmentation. The AO community has been through this cycle too many times -- someone forks a server to add a feature, the fork drifts, the upstream moves on, and now there are two half-maintained codebases that nobody can combine. Players get stuck on whichever fork their server chose, and developers burn out maintaining code that only helps one community.

**Whisker's core is intentionally small and lightweight.** Connections, packets, areas, characters, moderation -- that's it. Everything else is a plugin. Want CM controls? Drop in `case_manager.dll`. Want your server listed on the master server? Drop in `server_advertiser.dll`. Don't want either? Don't drop anything in. Your server, your choice.

**How it works for server operators:**

1. Open the [`OPTIONAL Plugins`](OPTIONAL%20Plugins/) folder
2. Grab the `.dll` (Windows) or `.so` (Linux) for the plugins you want
3. Drag them into your server's `plugins/` directory
4. Restart -- done

No compiling, no config files (unless the plugin needs one), no source code. Every plugin includes documentation on what it does and how to set it up.

**For developers -- plugins first, core commits welcome:**

We welcome contributions to Whisker's core -- bug fixes, performance improvements, protocol support, and documentation always have a home here. But if you're building a **new feature**, we strongly recommend shipping it as a plugin:

- **Your work stays compatible.** A plugin built against the Plugin API works with every Whisker server. A feature buried in a fork only helps the people running that specific fork. When that fork gets abandoned (and forks always get abandoned), your work disappears with it.
- **Server operators get to choose.** Not every server wants every feature. Plugins let operators pick exactly what they need. A core commit forces a feature on everyone whether they want it or not.
- **You ship on your own schedule.** No waiting for PR reviews, no merge conflicts, no dependency on upstream release cycles. Build it, compile it, share the binary -- people can use it today.
- **It's trivial to remove.** Delete the file and restart. Compare that to reverting commits, resolving merge conflicts, and rebuilding from source.

The `OPTIONAL Plugins/` folder is where community plugins live -- source code, pre-compiled binaries for Windows and Linux, and documentation all in one place. If you build something useful, submit it there. The community gets a feature they can opt into, you get distribution to every Whisker server, and the core stays clean.

See the [Plugin Dev Guide](plugins/PLUGIN%20DEV%20GUIDE%20README.md) for the full development guide with 9 copy-paste examples, cross-compilation instructions, and troubleshooting.

## Protocol

Whisker implements the AO2 protocol. For a complete, plain-English reference of every packet, the handshake sequence, wire format, and more, see the [AO2 Protocol Reference](docs/AO2_PROTOCOL.md).

**Upstream protocol documentation**: [AO2 Protocol Docs](https://github.com/AttorneyOnline/docs)
by OmniTroid ([@omnitroid](https://github.com/omnitroid)) and the
[Attorney Online dev team](https://github.com/AttorneyOnline)

## Architecture

```
src/
  main.c3        Entry point
  config.c3      Configuration + all named constants
  server.c3      Core server, listeners, client lifecycle
  client.c3      Client state and connection management
  protocol.c3    AO2 FantaCode encoding/decoding
  area.c3        Area management and state
  packets.c3     All AO2 packet handlers
  commands.c3    OOC command dispatcher and player commands
  moderation.c3  Moderation commands (ban, kick, mute)
  pairing.c3     Persistent UID-based pairing system
  security.c3    Rate limiting, DDoS protection, connection filtering
  websocket.c3   WebSocket handshake + frame parsing
  plugin.c3      Runtime plugin loading system
```

## Credits

### Protocol Documentation
- **OmniTroid** ([@omnitroid](https://github.com/omnitroid)) and the
  **Attorney Online dev team** ([github.com/AttorneyOnline](https://github.com/AttorneyOnline))
- Protocol Spec: [github.com/AttorneyOnline/docs](https://github.com/AttorneyOnline/docs)

### Architectural Inspiration & Ideas
- **Athena** — [github.com/MangosArentLiterature/Athena](https://github.com/MangosArentLiterature/Athena)
  Lightweight AO2 server in Go. Clean architecture that informed Whisker's core design.
- **Nyathena** — [github.com/SyntaxNyah/Nyathena](https://github.com/SyntaxNyah/Nyathena)
  Feature-rich Athena fork. Inspired persistent UID-based pairing, configurable rate limiting,
  and the moderation command structure.
- **Ferris-AO** — [github.com/SyntaxNyah/Ferris-AO](https://github.com/SyntaxNyah/Ferris-AO)
  Privacy-first AO2 server in Rust. Inspired the transport abstraction, delta suppression for
  ARUP broadcasts, bounded backpressure design, and IP hashing approach.
- **KFO-Server** (tsuserver3 fork) — [github.com/AttorneyOnline/KFO-Server](https://github.com/AttorneyOnline/KFO-Server)
  The original Python AO2 server ecosystem. Informed the area/evidence/testimony model.
- **webAO** — [github.com/AttorneyOnline/webAO](https://github.com/AttorneyOnline/webAO)
  The web-based AO client. WebSocket compatibility requirements came from testing with webAO.
- **AO2-Client** — [github.com/AttorneyOnline/AO2-Client](https://github.com/AttorneyOnline/AO2-Client)
  The official AO2 desktop client. Packet compatibility is tested against this client.

### Community Resources
- **LemmyAO / webao.miku.pizza** — [webao.miku.pizza](https://webao.miku.pizza)
  A webAO fork that solves the HTTPS mixed-content issue with `web.aceattorneyonline.com`.
  Great alternative for players struggling to connect via the official webAO client.

## Documentation

| Guide | Description |
|-------|-------------|
| [Build Guide](docs/BUILD_GUIDE.md) | Installing C3, building, running, config, testing |
| [WSS Setup Guide](docs/WSS_SETUP.md) | Cloudflare Tunnel, nginx + Let's Encrypt, Direct TLS |
| [AO2 Protocol Reference](docs/AO2_PROTOCOL.md) | Every packet documented, wire format, handshake, security |
| [Plugin Dev Guide](plugins/PLUGIN%20DEV%20GUIDE%20README.md) | Writing plugins with 9 copy-paste examples |
| [Mod Guide](docs/MOD_GUIDE.md) | Server administration, commands, permissions, bans |
| [Development Guide](docs/DEVELOPMENT%20GUIDE%20FOR%20C3%20DEVS.md) | C3 crash course, architecture deep-dive, code patterns |

## License

GNU Affero General Public License v3.0 — see [LICENSE](LICENSE).
