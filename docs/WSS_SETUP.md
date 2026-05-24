# Whisker WSS Setup Guide

How to set up secure WebSocket (wss://) for Whisker so webAO clients can
connect without browser security warnings.

## Why WSS?

The webAO client runs on `https://web.aceattorneyonline.com`. Modern
browsers block connections from HTTPS pages to plain `ws://` servers.
You need `wss://` (WebSocket over TLS) for webAO to work properly.

**Quick workaround:** If you just want to test or play, try
[webao.miku.pizza](https://webao.miku.pizza) — it's a fork by @SyntaxNyah
that handles the HTTP/HTTPS mixed-content issue. It does the nginx
HTTP/HTTPS trick without your browser blocking the connection. Great for
players who struggle to connect via `web.aceattorneyonline.com` (which is
hosted on GitHub Pages and enforces HTTPS). WSS setup is still recommended
for production servers.

There are three ways to set up WSS properly. Pick the one that fits your situation.

---

## Option 1: Cloudflare Tunnel (Easiest, Free)

Best for: Servers behind NAT, home servers, no public IP needed.

Cloudflare Tunnel creates a secure connection from your machine to
Cloudflare's edge network. Cloudflare handles TLS, DNS, and DDoS
protection. You don't need to open any ports on your router.

### Prerequisites
- A Cloudflare account (free)
- A domain registered in Cloudflare (cheap, ~$10/year)

### Step 1: Set Up Whisker

In `config/config.toml`:
```toml
[websocket]
enable_ws = true
ws_port = 27017

[proxy]
reverse_proxy_mode = true
```

### Step 2: Install cloudflared

Download from https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/

**Windows:**
Download the `.msi` installer and run it. It installs as a Windows service automatically.
```cmd
:: Verify it installed (open a new terminal)
cloudflared --version
:: Should print: cloudflared version 2024.x.x
```

**Linux (Debian/Ubuntu):**
```bash
# Download the .deb package
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o cloudflared.deb

# Install it
sudo dpkg -i cloudflared.deb

# Verify
cloudflared --version

# Clean up the downloaded file
rm cloudflared.deb
```

**Linux (other distros / manual):**
```bash
# Download the binary directly
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared

# Make it executable
chmod +x cloudflared

# Move to a system path
sudo mv cloudflared /usr/local/bin/

# Verify
cloudflared --version
```

### Step 3: Create a Tunnel

1. Go to https://one.dash.cloudflare.com/
2. Choose the free plan
3. Click **Networks** → **Tunnels** → **Add a tunnel**
4. Choose **Cloudflared** (not WARP)
5. Name your tunnel (e.g., your server name)
6. Follow the install instructions for your OS
7. Once cloudflared is running, you'll see it under "Connectors"

### Step 4: Configure the Tunnel Route

On the tunnel config page:
- **Subdomain**: `ao` (or whatever you want)
- **Domain**: your domain from the dropdown
- **Type**: `HTTP`
- **URL**: `localhost:27017`

Click **Save**.

### Step 5: Test It

Start Whisker, then test the tunnel:

```bash
# First, make sure Whisker is running
./build/whisker

# In another terminal, test with curl (checks if the tunnel is reachable)
curl -v https://ao.yourdomain.com
# You should get some response (even if it's garbage — WebSocket isn't HTTP)
# The important thing is NO "connection refused" or DNS errors

# Test with wscat (best test)
npm install -g wscat        # install if you haven't already
wscat --connect wss://ao.yourdomain.com
# Should see: decryptor#NOENCRYPT#%
# Type anything and press Enter to send a raw packet (it'll probably error, that's fine)
# Press Ctrl+C to disconnect

# Test DNS resolution (make sure your domain points to Cloudflare)
nslookup ao.yourdomain.com
# or
dig ao.yourdomain.com
```

Connect with webAO:
```
https://web.aceattorneyonline.com/client.html?mode=join&connect=wss://ao.yourdomain.com
```

Or use [webao.miku.pizza](https://webao.miku.pizza) if the official webAO gives you trouble.

### How Real IPs Work with Cloudflare

When `reverse_proxy_mode = true`, Whisker reads these headers (in order):
1. `CF-Connecting-IP` — Cloudflare's header with the real client IP
2. `X-Forwarded-For` — Standard proxy header (first IP in chain)
3. `X-Real-IP` — Alternative header

This means bans, rate limits, and multiclient detection all work on the
real client IP, not Cloudflare's IP.

---

## Option 2: nginx + Let's Encrypt (Self-Hosted, Free TLS)

Best for: Dedicated servers with a public IP and a domain name.

nginx acts as a reverse proxy. It accepts `wss://` connections from the
internet, terminates TLS, and forwards plain `ws://` to Whisker locally.
Let's Encrypt provides free TLS certificates.

### Prerequisites
- A server with a public IP
- A domain name pointing to your server (A record in DNS)
- nginx installed
- certbot installed

### Step 1: Set Up Whisker

In `config/config.toml`:
```toml
[websocket]
enable_ws = true
ws_port = 27017

[proxy]
reverse_proxy_mode = true
```

### Step 2: Install nginx

**Debian/Ubuntu:**
```bash
sudo apt update
sudo apt install nginx
sudo systemctl enable nginx      # start on boot
sudo systemctl start nginx       # start now

# Check it's running
sudo systemctl status nginx
# Should say: active (running)

# Check it's listening on port 80
sudo ss -tlnp | grep :80
# Should show nginx listening
```

Verify by visiting `http://your-server-ip/` in a browser — you should see the nginx welcome page.

```bash
# Find your server's public IP if you don't know it
curl ifconfig.me
```

### Step 3: Get a TLS Certificate with Let's Encrypt

```bash
# Install certbot and the nginx plugin
sudo apt install certbot python3-certbot-nginx

# Verify certbot installed
certbot --version
```

Before running certbot, make sure:
1. Your domain's DNS A record points to your server's IP
2. Port 80 is open (certbot needs it for verification)

```bash
# Check that DNS is pointing to your server
dig +short ao.yourdomain.com
# Should print your server's IP address

# Check port 80 is open
sudo ufw status           # if using ufw
sudo ufw allow 80         # open it if needed
```

Get a certificate:
```bash
sudo certbot --nginx -d ao.yourdomain.com
```

Follow the prompts (enter your email, agree to terms). certbot will:
1. Verify you own the domain (via HTTP challenge on port 80)
2. Download a TLS certificate
3. Auto-configure nginx to use it
4. Set up automatic renewal (runs twice daily via systemd timer)

Verify the cert:
```bash
# List all certificates certbot manages
sudo certbot certificates

# Check the cert expiry date
echo | openssl s_client -connect ao.yourdomain.com:443 2>/dev/null | openssl x509 -noout -dates

# Test that auto-renewal works
sudo certbot renew --dry-run
```

### Step 4: Configure nginx as a WebSocket Reverse Proxy

Create or edit the nginx config for your domain:

```bash
sudo nano /etc/nginx/sites-available/ao.yourdomain.com
```

Paste this config:

```nginx
# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name ao.yourdomain.com;
    return 301 https://$server_name$request_uri;
}

# WSS reverse proxy
server {
    listen 443 ssl;
    server_name ao.yourdomain.com;

    # Let's Encrypt certificates (certbot fills these in)
    ssl_certificate /etc/letsencrypt/live/ao.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/ao.yourdomain.com/privkey.pem;

    # Modern TLS settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        # Forward to Whisker's WebSocket port
        proxy_pass http://127.0.0.1:27017;

        # WebSocket upgrade headers — REQUIRED
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";

        # Pass the real client IP to Whisker
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Timeouts (AO2 keepalive is every 10s, so 60s is plenty)
        proxy_read_timeout 60s;
        proxy_send_timeout 60s;
    }
}
```

Enable the site and reload nginx:
```bash
# Create a symlink to enable the site
sudo ln -sf /etc/nginx/sites-available/ao.yourdomain.com /etc/nginx/sites-enabled/

# IMPORTANT: Test the config for syntax errors before reloading!
sudo nginx -t
# Should say: syntax is ok / test is successful
# If it says there's an error, fix the config before continuing

# Reload nginx to pick up the new config (no downtime)
sudo systemctl reload nginx

# Verify it's still running
sudo systemctl status nginx
```

If `nginx -t` shows errors:
```bash
# Common fix: remove the default site if it conflicts
sudo rm /etc/nginx/sites-enabled/default

# Re-test
sudo nginx -t
sudo systemctl reload nginx
```

### Step 5: Test It

Start Whisker, then test each layer:

```bash
# 1. Check Whisker is running and listening
sudo ss -tlnp | grep 27017
# Should show whisker listening on port 27017

# 2. Check nginx is listening on 443
sudo ss -tlnp | grep :443
# Should show nginx listening

# 3. Test TLS from the command line
echo | openssl s_client -connect ao.yourdomain.com:443 -brief
# Should show: CONNECTION ESTABLISHED, protocol version, cipher

# 4. Test WebSocket through nginx
wscat --connect wss://ao.yourdomain.com
# Should see: decryptor#NOENCRYPT#%

# 5. Check nginx access log for your connection
sudo tail -5 /var/log/nginx/access.log
```

webAO URL:
```
https://web.aceattorneyonline.com/client.html?mode=join&connect=wss://ao.yourdomain.com
```

Or use [webao.miku.pizza](https://webao.miku.pizza) if you have trouble with the official client.

### Step 6: Firewall

Make sure ports 80 and 443 are open:
```bash
# Check current firewall rules
sudo ufw status

# Open the required ports
sudo ufw allow 80/tcp      # HTTP (needed for Let's Encrypt renewal)
sudo ufw allow 443/tcp     # HTTPS/WSS

# Verify
sudo ufw status
```

You do NOT need to open port 27017 (Whisker's WebSocket port) to the
internet — nginx handles the public-facing connection and forwards
internally. In fact, it's more secure to keep 27017 closed.

```bash
# Verify that only nginx can reach Whisker's WebSocket port (from outside)
# This should FAIL (port not open publicly) — that's correct!
# Run this from a DIFFERENT machine:
nc -zv your-server-ip 27017
# Expected: Connection refused (good! nginx handles public access)

# This should SUCCEED (nginx forwards locally):
# Run this ON the server:
nc -zv localhost 27017
# Expected: Connection succeeded
```

### How Real IPs Work with nginx

The nginx config above sets two headers:
- `X-Real-IP` — the direct client IP
- `X-Forwarded-For` — the full proxy chain

When `reverse_proxy_mode = true`, Whisker reads these and uses the real
client IP for bans, rate limits, and multiclient detection.

---

## Option 3: Direct TLS (No Reverse Proxy)

Best for: Simple setups where you don't want nginx at all.

Whisker can terminate TLS directly if you provide a certificate and key.

### Step 1: Get a Certificate

Use certbot standalone mode:
```bash
sudo certbot certonly --standalone -d ao.yourdomain.com
```

Or use any other method to get `fullchain.pem` and `privkey.pem`.

### Step 2: Configure Whisker

In `config/config.toml`:
```toml
[websocket]
enable_wss = true
wss_port = 443
tls_cert_path = "/etc/letsencrypt/live/ao.yourdomain.com/fullchain.pem"
tls_key_path = "/etc/letsencrypt/live/ao.yourdomain.com/privkey.pem"

[proxy]
reverse_proxy_mode = false
```

### Step 3: Run

```bash
# Port 443 needs root on Linux (ports below 1024 are privileged)
sudo ./build/whisker

# Alternative: use a high port to avoid needing root
# Change wss_port to 8443 in config.toml, then:
./build/whisker
# Players connect to: wss://ao.yourdomain.com:8443

# Alternative: use setcap to allow non-root to bind port 443
sudo setcap 'cap_net_bind_service=+ep' ./build/whisker
./build/whisker    # now works on port 443 without sudo
```

### Downsides
- Need root for port 443 (or use a high port like 8443, or setcap)
- No Cloudflare DDoS protection
- Must handle certificate renewal yourself (set up a cron job)
- Less flexible than nginx (can't host other services)

Certificate renewal cron job (if using this option):
```bash
# Edit crontab
crontab -e

# Add this line to renew the cert monthly and restart Whisker
0 3 1 * * certbot renew --quiet && systemctl restart whisker
```

---

## Which Option Should I Pick?

| Situation | Recommendation |
|-----------|---------------|
| Home server, no public IP | **Cloudflare Tunnel** |
| VPS/dedicated, want DDoS protection | **Cloudflare Tunnel** |
| VPS/dedicated, full control | **nginx + Let's Encrypt** |
| Quick test, already have certs | **Direct TLS** |
| Running multiple services | **nginx + Let's Encrypt** |

Most AO servers use either Cloudflare Tunnel or nginx. Both are
battle-tested and used by Nyathena, KFO-Server, and other AO servers.

---

## Advertising Your Server

Once WSS is working, players can find your server if you advertise it
to the AO master server. Configure the master server settings in your
config to include your WSS hostname so clients auto-connect via secure
WebSocket.

For manual connections, share this URL:
```
https://web.aceattorneyonline.com/client.html?mode=join&connect=wss://ao.yourdomain.com&serverName=Your+Server+Name
```

---

## Troubleshooting

**"WebSocket connection failed" in browser console**
- Is Whisker running with `enable_ws = true`?
  ```bash
  grep "enable_ws" config/config.toml
  # Should show: enable_ws = true
  ```
- Is nginx running?
  ```bash
  sudo systemctl status nginx
  # Should say: active (running)
  ```
- Check nginx error log:
  ```bash
  sudo tail -20 /var/log/nginx/error.log
  # Look for "connection refused" or "upstream" errors
  ```
- Is the certificate valid?
  ```bash
  sudo certbot certificates
  # Check the expiry date
  ```

**Browser says "Not Secure"**
- Your certificate may have expired:
  ```bash
  sudo certbot renew
  sudo systemctl reload nginx
  ```
- Check the certificate dates:
  ```bash
  echo | openssl s_client -connect ao.yourdomain.com:443 2>/dev/null | openssl x509 -noout -dates
  ```

**"502 Bad Gateway" from nginx**
- Whisker isn't running, or it's on a different port:
  ```bash
  # Check if Whisker is listening
  sudo ss -tlnp | grep 27017
  # If empty, Whisker isn't running or is on a different port

  # Check what port is configured
  grep "ws_port" config/config.toml
  # Make sure it matches the proxy_pass port in your nginx config

  # Check if Whisker is running at all
  ps aux | grep whisker
  ```

**Bans not working behind proxy**
- Make sure `reverse_proxy_mode = true` in config.toml:
  ```bash
  grep "reverse_proxy_mode" config/config.toml
  # Should show: reverse_proxy_mode = true
  ```
- Verify the proxy headers are being set (check nginx config above)
- Test: connect from two different IPs and check they get different IPIDs

**Certificate renewal fails**
- certbot needs port 80 open for HTTP challenges:
  ```bash
  sudo ufw allow 80/tcp
  sudo certbot renew --dry-run   # test without actually renewing
  ```
- If using Cloudflare, you may need to pause Cloudflare proxy during renewal,
  or use DNS challenge instead:
  ```bash
  sudo apt install python3-certbot-dns-cloudflare
  sudo certbot certonly --dns-cloudflare -d ao.yourdomain.com
  ```

**wscat works but webAO doesn't**
- webAO's origin must be allowed. Check `allowed_origin` in config.toml
  (set to `*` to allow all origins)
- Some ad blockers interfere with WebSocket connections — try in incognito mode
- **Try [webao.miku.pizza](https://webao.miku.pizza)** — LemmyAO's fork solves
  the HTTPS mixed-content issue that `web.aceattorneyonline.com` (GitHub Pages)
  has. If wscat works but the official webAO doesn't, this is likely the fix.

**DNS not resolving**
```bash
# Check if your domain resolves
nslookup ao.yourdomain.com
# or
dig ao.yourdomain.com

# If it doesn't resolve, check your DNS settings at your registrar
# The A record should point to your server's public IP
curl ifconfig.me    # find your public IP
```

**"Connection refused" on port 443**
```bash
# Check if anything is listening on 443
sudo ss -tlnp | grep :443

# If empty, nginx might not have loaded the SSL config
sudo nginx -t           # check for config errors
sudo systemctl restart nginx
sudo ss -tlnp | grep :443   # check again
```

---

## Further Reading

- [AO2 Protocol Reference](AO2_PROTOCOL.md) — Every packet documented, wire format, handshake, security
- [Build Guide](BUILD_GUIDE.md) — Building Whisker from source
- [Mod Guide](MOD_GUIDE.md) — Server administration and moderation
- [Cloudflare Tunnel Docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
- [nginx WebSocket Proxying](https://nginx.org/en/docs/http/websocket.html)
- [certbot Instructions](https://certbot.eff.org/)
- [AO2 Cloudflare Tunneling Guide](https://github.com/AttorneyOnline/docs) — by OmniTroid and the AO dev team
- [webao.miku.pizza](https://webao.miku.pizza) — LemmyAO's webAO fork that handles the HTTPS/ws:// issue
