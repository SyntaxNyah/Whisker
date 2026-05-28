# Whisker Security & DDoS Protection

How Whisker protects itself from abuse, and how to harden your deployment.

---

## Built-in Protection Layers

Whisker uses defense-in-depth: multiple independent layers that each catch
different attack patterns. Every check runs **before** expensive operations
(thread creation, memory allocation) so rejected connections cost almost nothing.

### Layer 1: Early Reject (before thread spawn)

When a new TCP or WebSocket connection arrives, `handle_new_connection()` runs
these checks **in the accept thread** — no resources are allocated yet:

| Check | What it does | Default |
|-------|-------------|---------|
| **Ban check** | Rejects banned IPIDs instantly | — |
| **Connection rate limit** | Max connections per IP per window | 10 per 10s |
| **Flood autoban** | Auto-bans IPs that keep hitting the rate limit | After 6 rejections |
| **Multiclient limit** | Max simultaneous connections from one IP | 16 |
| **Server full** | Rejects if `MAX_SERVER_CLIENTS` (1024) reached | — |

A rejected connection is just a `close()` call — no thread, no memory pool,
no packet parsing.

### Layer 2: Handshake Gate

After the thread spawns, the client has 60 seconds (`HANDSHAKE_TIMEOUT_MS`)
to complete the AO2 join handshake. If the client just opens a socket and
sits idle (slowloris-style), the handler thread exits and reclaims its
256 KB memory pool.

During the handshake, the `HI` packet triggers an HDID (hardware ID) ban
check. This catches ban evasion when someone changes their IP but keeps the
same hardware ID.

### Layer 3: Packet Rate Limiting

Once connected, every client has independent sliding-window rate limiters:

| Limiter | What it limits | Default |
|---------|---------------|---------|
| **Raw packet** | Total packets of any kind | 20 per 2s |
| **IC message** | In-character chat (MS packets) | 20 per 10s |
| **OOC message** | Out-of-character chat (CT packets) | 4 per 1s |

Exceeding the raw packet limit disconnects the client. IC/OOC limits silently
drop the excess message.

### Layer 4: Protocol Limits

Hard caps prevent oversized or malformed packets from consuming memory:

| Limit | Value |
|-------|-------|
| Max packet size | 8,192 bytes |
| Max packet fields | 1,024 |
| Max IC message length | 256 chars |
| Max OOC message length | 256 chars |
| Max showname length | 30 chars |

Packets exceeding these limits are dropped.

### Layer 5: Crash Resistance

Even under attack, Whisker won't crash from network errors:

- **SIGPIPE immunity**: Global `signal(SIGPIPE, SIG_IGN)` in `main.c3` plus
  per-send `MSG_NOSIGNAL` flag. Writing to a broken socket marks the client
  disconnected instead of killing the server process.
- **Atomic WebSocket frames**: `send_raw()` builds complete WS frames in a
  single buffer and sends with one syscall. This prevents frame corruption
  when multiple threads broadcast concurrently.
- **Pool-isolated threads**: Each client handler runs in its own `@pool_init`
  memory pool. A crash or corruption in one client's memory cannot affect
  other clients or the accept loop.

---

## Config Tuning

All rate limits are configurable in `config/config.toml` under `[ratelimit]`:

```toml
[ratelimit]
# Connection rate limiting (per IP)
conn_rate_limit = 10        # max connections per window
conn_rate_window = 10        # window in seconds

# Flood autoban
conn_flood_autoban = true    # auto-ban flooding IPs
flood_ban_threshold = 6      # rejections before autoban

# Packet rate limiting (per client)
raw_pkt_rate_limit = 20      # max raw packets per window
raw_pkt_rate_window = 2      # window in seconds
msg_rate_limit = 20          # max IC messages per window
msg_rate_window = 10         # window in seconds
ooc_rate_limit = 4           # max OOC messages per window
ooc_rate_window = 1          # window in seconds
```

Under `[server]`:

```toml
[server]
max_players = 100            # max joined players
multiclient_limit = 16       # max connections per IP
```

### Tightening for High-Risk Servers

If you're a target for abuse, consider:

```toml
[ratelimit]
conn_rate_limit = 5          # stricter connection rate
conn_rate_window = 30        # longer window
flood_ban_threshold = 3      # faster autoban
raw_pkt_rate_limit = 10      # stricter packet rate

[server]
multiclient_limit = 3        # most players only need 1-2
```

---

## Infrastructure Protection (Recommended)

Whisker's built-in protection handles **application-level abuse** — spammy
players, reconnect spam, packet floods from known IPs. But it cannot stop
**volumetric DDoS attacks** (thousands of IPs flooding your network). No
application server can. This is the same for every AO2 server (Athena,
tsuserver, Nyathena).

For real DDoS protection, you need infrastructure-level defenses:

### Cloudflare (Recommended, Free Tier Works)

Cloudflare absorbs volumetric attacks before traffic reaches your server.
For WebSocket (webAO) connections, Cloudflare provides full protection:

1. Point your domain's DNS to Cloudflare
2. Enable the proxy (orange cloud) for your WebSocket subdomain
3. Configure Whisker with `reverse_proxy_mode = true`
4. Set `trusted_header = "CF-Connecting-IP"`

See [WSS_SETUP.md](https://github.com/SyntaxNyah/Whisker/blob/main/docs/WSS_SETUP.md) for the full Cloudflare + nginx setup.

> **Note:** Cloudflare only proxies HTTP/WebSocket traffic. Raw TCP (desktop
> client on port 27016) goes direct. For TCP protection, use Cloudflare
> Spectrum (paid) or iptables rules.

### iptables / nftables (Linux Kernel-Level)

Rate limit connections at the kernel level — much faster than any application:

```bash
# Limit new TCP connections to 10/sec per IP on AO2 ports
iptables -A INPUT -p tcp --dport 27016 -m connlimit --connlimit-above 10 -j DROP
iptables -A INPUT -p tcp --dport 27017 -m connlimit --connlimit-above 10 -j DROP

# Rate limit new connections globally (burst of 50, then 25/sec)
iptables -A INPUT -p tcp --dport 27016 -m state --state NEW -m limit --limit 25/sec --limit-burst 50 -j ACCEPT
iptables -A INPUT -p tcp --dport 27016 -m state --state NEW -j DROP

# Drop obviously invalid packets
iptables -A INPUT -m state --state INVALID -j DROP
```

### fail2ban

Watch Whisker's output for rate limit messages and auto-block at the firewall:

```ini
# /etc/fail2ban/filter.d/whisker.conf
[Definition]
failregex = \[security\] Connection rate limited: <HOST>
            \[security\] Auto-banned flooding IP: <HOST>
```

```ini
# /etc/fail2ban/jail.d/whisker.conf
[whisker]
enabled = true
filter = whisker
logpath = /path/to/whisker.log
maxretry = 5
bantime = 3600
```

> **Note:** Whisker currently logs to stdout. Redirect to a file for fail2ban:
> `./whisker 2>&1 | tee whisker.log`

### AWS / Cloud Provider

If running on EC2 or similar:
- **Security Groups**: Only allow ports 27016, 27017, and SSH
- **AWS Shield**: Free basic DDoS protection for all EC2 instances
- **AWS WAF**: Web Application Firewall for WebSocket traffic (optional)

### OVH Cloud / Bare Metal VPS hosting provider

- If you can't use Cloudflare or AWS, try searching for a VPS that has dedicated DDoS protection built in.
- OVH is a proven choice that works well on AO. No configuration is required other than deciding which ports you want open
- OVH stops any AO user from crashing your server and is more than enough if you don't want to mess with cloudflare.
- Most Minecraft servers use them for a reason. https://www.ovhcloud.com/en-gb/security/anti-ddos/

## What Whisker Does NOT Protect Against

Honest Limitations:

| Attack | Why Whisker can't stop it | Mitigation |
|--------|--------------------------|------------|
| Distributed DDoS (1000+ IPs) | Thread-per-client model exhausts resources before rate limits build up | Cloudflare, iptables |
| SYN flood | Kernel handles TCP handshake before Whisker sees it | `net.ipv4.tcp_syncookies=1` (default on modern Linux) |
| Bandwidth saturation | Application can't help if the pipe is full | Cloudflare, ISP-level filtering |
| Slowloris (slow sends) | Handshake timeout helps but threads are still occupied | iptables `connlimit`, Cloudflare |
| IP spoofing | TCP requires completed handshake, so spoofed IPs can't complete connections | Not a real concern for TCP |

---

## Security Checklist

For a production AO2 server to better protect against DDoS attacks doing any of these steps will make your server more secure:

- [ ] Cloudflare or equivalent Anti DDoS in front of WebSocket port
- [ ] iptables `connlimit` rules on both ports
- [ ] `reverse_proxy_mode = true` if behind a proxy
- [ ] `conn_flood_autoban = true` (default)
- [ ] Reasonable `multiclient_limit` (3-5 for most servers)
- [ ] Redirect logs to file for fail2ban monitoring
- [ ] Firewall blocks all ports except 27016, 27017, WSS PORT and SSH
- [ ] Run Whisker as a non-root user
- [ ] Keep C3 and OS packages updated

---

*Whisker's security model is on par with or better than other AO2 servers
(Athena, Nyathena, Akashi, tsuserver and KFO-Server). The real difference in DDoS
resilience comes from your infrastructure setup, not the application.*
