# Whisker Build Guide

Step-by-step guide to building and running Whisker from source.

## Prerequisites

### Install C3

C3 is the programming language Whisker is written in. You need the C3 compiler (`c3c`).

**Windows:**
1. Go to https://c3-lang.org/
2. Download the latest release for Windows (the `.zip` file)
3. Extract the zip somewhere permanent, like `C:\c3c\`
4. Add that folder to your PATH:
   - Press `Win + S`, search "Environment Variables"
   - Click "Environment Variables..."
   - Under "User variables", select `Path`, click "Edit"
   - Click "New", paste `C:\c3c\`
   - Click OK on all dialogs
5. Open a **new** terminal (old ones won't see the change) and verify:
```cmd
c3c --version
```
You should see something like `c3c version 0.6.x`.

**Linux (Debian/Ubuntu):**
```# Download the latest release
wget https://github.com/c3lang/c3c/releases/latest/download/c3-linux.tar.gz

# Extract it
tar xzf c3-linux.tar.gz

# Check where the binary is (it might be in c3/bin/c3c or directly in c3/)
find c3 -name "c3c" -type f

# Move the entire c3 directory to /opt (recommended)
sudo mv c3 /opt/

# Create a symlink to make c3c available system-wide
sudo ln -s /opt/c3/c3c /usr/local/bin/c3c  # If binary is directly in c3/
# OR
sudo ln -s /opt/c3/bin/c3c /usr/local/bin/c3c  # If binary is in c3/bin/

# Set the library path so c3c can find its standard library
echo 'export C3_LIB_PATH=/opt/c3/lib' >> ~/.bashrc
source ~/.bashrc

# Verify it works
c3c --version
# Should show: C3 Compiler Version: 0.8.x
```

**macOS:**
```bash
# With Homebrew (easiest)
brew install c3c

# Or download manually from https://c3-lang.org/
# and move to /usr/local/bin/ like the Linux instructions

c3c --version
```

### Verify Install

```bash
c3c --version
# Should print something like: c3c version 0.6.x
```

If you get `command not found`, the compiler isn't in your PATH. Double-check the install steps above.

## Building Whisker

### Clone the Repository

```bash
# Make sure you have git installed
git --version
# If not: sudo apt install git (Linux) or download from https://git-scm.com (Windows)

# Clone the repo
git clone https://github.com/SyntaxNyah/Whisker.git

# Enter the project folder
cd Whisker

# Check what's inside (you should see src/, config/, project.json, etc.)
ls
```

### Build

```bash
c3c build
```

That's it. No CMake. No configure scripts. No dependency management.
The output binary is in `out/whisker` (or `out/whisker.exe` on Windows).

```bash
# Verify the binary was created
ls -la out/
# You should see: whisker (Linux/macOS) or whisker.exe (Windows)
```

### Build Modes

```bash
c3c build              # Default build (O2 optimization, safety checks on)
```

To change build settings, edit `project.json`:
```json
{
    "targets": {
        "whisker": {
            "type": "executable",
            "opt": "O2",        // O0 (debug) to O5 (max speed)
            "safe": true         // false to disable bounds checking
        }
    }
}
```

Quick reference:
```bash
# Edit project.json to change settings
nano project.json       # Linux/macOS
notepad project.json    # Windows
```

## Running Whisker

### First Run

The `config/` directory is included with sensible defaults. Just run:

```bash
# Linux/macOS
./out/whisker

# Windows (from the Whisker folder)
.\build\whisker.exe
```

You should see:
```
  ╦ ╦┬ ┬┬┌─┐┬┌─┌─┐┬─┐
  ║║║├─┤│└─┐├┴┐├┤ ├┬┘
  ╚╩╝┴ ┴┴└─┘┴ ┴└─┘┴└─
  Attorney Online 2 Server

[whisker] === Whisker v0.1.0 ===
[whisker] Server: My Whisker Server
[whisker] TCP listening on port 27016
[whisker] WebSocket enabled on port 27017
[whisker] Server is ready. Accepting connections.
```

If you see that, you're good! The server is running.

To stop it, press `Ctrl+C` in the terminal.

### Custom Config Directory

```bash
# Use a different config folder (maybe for a second server instance)
./out/whisker -c /path/to/my/config

# Example: run a test server with separate config
cp -r config/ config-test/
nano config-test/config.toml   # change the port to 27018
./out/whisker -c ./config-test
```

### CLI Options

```bash
./out/whisker --help      # Show all options
./out/whisker --version   # Show version
./out/whisker -c ./config # Custom config directory (default: config)
```

### Running in the Background (Linux)

If you want the server to keep running after you close the terminal:

```bash
# Simple way: use screen
sudo apt install screen          # install screen if you don't have it
screen -S whisker                # create a named screen session
./out/whisker                  # start the server
# Press Ctrl+A, then D to detach (server keeps running)
screen -r whisker                # re-attach later to see output

# Alternative: use tmux
sudo apt install tmux
tmux new -s whisker
./out/whisker
# Press Ctrl+B, then D to detach
tmux attach -t whisker           # re-attach later

# Alternative: use systemd (see below for a service file)
```

#### Systemd Service File (Linux)

Create `/etc/systemd/system/whisker.service`:
```ini
[Unit]
Description=Whisker AO2 Server
After=network.target

[Service]
Type=simple
User=your_username
WorkingDirectory=/home/your_username/Whisker
ExecStart=/home/your_username/Whisker/out/whisker
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Then:
```bash
# Edit the file (replace your_username with your actual username!)
sudo nano /etc/systemd/system/whisker.service

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable whisker     # start on boot
sudo systemctl start whisker      # start now
sudo systemctl status whisker     # check if it's running
sudo journalctl -u whisker -f     # watch logs in real-time
```

## Configuration

All config files live in the `config/` directory:

| File | What It Does |
|------|-------------|
| `config.toml` | Server name, ports, rate limits, proxy settings |
| `areas.toml` | Define the rooms on your server |
| `characters.txt` | One character name per line |
| `music.txt` | One music track filename per line |
| `roles.toml` | Moderator role permission definitions |

```bash
# See all config files
ls config/

# Edit any config file
nano config/config.toml        # Linux/macOS
notepad config\config.toml     # Windows
```

### Minimal config.toml

The defaults work out of the box. If you want to customize:

```toml
[server]
name = "My Server"
port = 27016
max_players = 100

[websocket]
enable_ws = true
ws_port = 27017
```

### Adding Characters

Edit `config/characters.txt`, one name per line:

```bash
nano config/characters.txt
```

```
Phoenix
Edgeworth
Maya
Judge
```

These names must match the character folder names that AO2 clients have installed.

Want to see what characters other servers use? Check `base/characters/` in your
AO2 client install folder — those folder names are exactly what goes in this file.

```bash
# Quick way to count how many characters you have
wc -l config/characters.txt
# Output: 16 config/characters.txt  (means 16 characters)

# Quick way to search for a character
grep -i "phoenix" config/characters.txt
```

### Adding Areas

Edit `config/areas.toml`:

```bash
nano config/areas.toml
```

```toml
[[area]]
name = "Lobby"
background = "gs4"

[[area]]
name = "Courtroom 1"
background = "gs4"

[[area]]
name = "Courtroom 2"
background = "gs4"
```

Backgrounds must match what AO2 clients have installed (look in `base/background/`
in the client folder).

### Adding Music

Edit `config/music.txt`, one track per line:

```bash
nano config/music.txt
```

```
~stop.mp3
Trial.mp3
Pursuit.mp3
Objection.mp3
```

`~stop.mp3` is the standard "stop music" track that all AO2 clients recognize.

Music filenames must match files in `base/sounds/music/` in the AO2 client.

```bash
# Count your music tracks
wc -l config/music.txt
```

### Editing Roles

```bash
nano config/roles.toml
```

The default `roles.toml` defines three roles with permission bits:
- `moderator` (permissions = 39) — can mute, kick, ban, move users, modify areas
- `admin` (permissions = 127) — all moderator powers + admin flag
- `dj` (permissions = 256) — can only change music

See comments in `roles.toml` for the full permission bit breakdown.

## Testing Your Server

### With AO2 Desktop Client

1. Start Whisker: `./out/whisker`
2. Open the AO2 desktop client
3. Go to **Favorites** or **Direct Connect**
4. Enter: `localhost` port `27016`
5. Connect — you should see the character select screen

### With webAO

1. Make sure `enable_ws = true` in your config.toml
2. Start Whisker: `./out/whisker`
3. Open this URL in your browser:
   ```
   https://web.aceattorneyonline.com/client.html?mode=join&connect=ws://localhost:27017
   ```

**Important note about webAO:** The official `web.aceattorneyonline.com` is hosted
on GitHub Pages (HTTPS). Modern browsers block `ws://` connections from HTTPS pages.
This means connecting to a local `ws://` server may get blocked by your browser.

**Workarounds:**
- Use [webao.miku.pizza](https://webao.miku.pizza) instead — it's a fun fork by
  LemmyAO that handles the HTTP/HTTPS issue so your browser doesn't freak out.
  Great for testing and for players who struggle to connect via `web.aceattorneyonline.com`.
- Set up WSS (secure WebSocket) — see the [WSS Setup Guide](WSS_SETUP.md).
- For local testing only, you can open `http://localhost` in your browser (not HTTPS)
  and it'll allow `ws://` connections fine.

### Quick Network Test

These tools help you verify the server is actually listening:

```bash
# Test if the TCP port is open (install netcat if needed: sudo apt install netcat)
nc -zv localhost 27016
# Expected: Connection to localhost 27016 port [tcp/*] succeeded!

# Connect to TCP and see the handshake
nc localhost 27016
# Expected output: decryptor#0#%
# Press Ctrl+C to disconnect

# Test if the WebSocket port is open
nc -zv localhost 27017
# Expected: Connection to localhost 27017 port [tcp/*] succeeded!
```

If you have `wscat` installed (great for WebSocket testing):

```bash
# Install wscat (requires Node.js)
npm install -g wscat

# Connect to the WebSocket
wscat --connect ws://localhost:27017
# Expected output: decryptor#0#%
# Press Ctrl+C to disconnect
```

If you don't want to install Node.js, you can also test with `curl`:

```bash
# Check if the WebSocket port responds at all
curl -v http://localhost:27017
# You'll get garbage output (it's not HTTP), but no "Connection refused" = good
```

### Testing from Another Machine

If you want someone else to connect to your server:

```bash
# Find your local IP address
# Linux:
ip addr show | grep "inet " | grep -v 127.0.0.1
# or
hostname -I

# macOS:
ifconfig | grep "inet " | grep -v 127.0.0.1

# Windows (in cmd, not bash):
ipconfig | findstr /i "IPv4"
```

Then they connect to `YOUR_IP:27016` in the AO2 client.

If they're outside your local network, you'll need to **port forward** 27016
(TCP) and 27017 (WebSocket) on your router, or use a Cloudflare Tunnel (see
[WSS Setup Guide](WSS_SETUP.md)).

```bash
# Check if your ports are open from outside (run this on a different machine)
nc -zv YOUR_PUBLIC_IP 27016
nc -zv YOUR_PUBLIC_IP 27017

# Or use an online port checker — search "check open port" on Google
```

### Checking Server Logs

While the server is running, it outputs logs to the terminal:

```
[whisker] Client connected from 192.168.1.100 (IPID: a1b2c3)
[whisker] Client 1 joined area 0 (Lobby)
[whisker] Client 1 picked character: Phoenix
[moderation] Client 1 (Phoenix) was kicked by Admin
```

To save logs to a file:

```bash
# Log to file AND terminal at the same time
./out/whisker 2>&1 | tee whisker.log

# Log to file only (background)
./out/whisker > whisker.log 2>&1 &

# View a running log file
tail -f whisker.log
```

## Building Plugins

Plugins are separate C3 projects compiled as shared libraries.

```bash
# Create a new plugin project (this creates a folder with project.json)
c3c init my_plugin --template dynamic-lib

# Enter the plugin folder
cd my_plugin

# List what was created
ls
# You should see: project.json  src/

# Write your plugin code
nano src/my_plugin.c3

# Build it
c3c build

# Check that the shared library was built
ls out/
# Linux: my_plugin.so
# Windows: my_plugin.dll

# Deploy: copy the library to Whisker's plugins directory
cp out/my_plugin.so /path/to/whisker/plugins/

# Restart Whisker to load the plugin (or use the `reload` console command)
```

See the [Plugin Dev Guide](../plugins/PLUGIN%20DEV%20GUIDE%20README.md) for 9 complete copy-paste plugin examples including a
Magic 8-Ball, profanity filter, AFK detector, and more.

## Troubleshooting

**"c3c: command not found"**
- Make sure `c3c` is in your PATH
- On Windows, restart your terminal after adding to PATH
- Check: `which c3c` (Linux/macOS) or `where c3c` (Windows)

**"Cannot bind to port 27016"**
- Another process is using that port. Find out what:
  ```bash
  # Linux — find what's using port 27016
  sudo lsof -i :27016
  # or
  sudo ss -tlnp | grep 27016

  # Windows (in cmd)
  netstat -ano | findstr 27016
  ```
- Change `port` in config.toml to something else (e.g., 27020)
- On Linux, ports below 1024 need root. Use a port above 1024.

**"No characters loaded"**
- Make sure `config/characters.txt` exists and has at least one name
  ```bash
  cat config/characters.txt    # should print character names
  wc -l config/characters.txt  # should be > 0
  ```

**AO2 client can't connect**
- Is the server running? Check the terminal output.
- Is the port correct? Default TCP is 27016.
- Test the connection:
  ```bash
  nc -zv localhost 27016          # quick port check
  telnet localhost 27016          # interactive test
  ```
- Is a firewall blocking the port?
  ```bash
  # Linux: check ufw status
  sudo ufw status

  # Allow the port if needed
  sudo ufw allow 27016/tcp
  ```
- Windows: check Windows Firewall settings and add an inbound rule for port 27016.

**webAO can't connect**
- Is `enable_ws = true` in config.toml?
  ```bash
  grep "enable_ws" config/config.toml
  ```
- Is the WebSocket port correct? Default is 27017.
- If using HTTPS (webAO is HTTPS), you need WSS — see the [WSS Setup Guide](WSS_SETUP.md).
- **Browser blocking ws://?** Try [webao.miku.pizza](https://webao.miku.pizza)
  instead of `web.aceattorneyonline.com`. It's a fork by LemmyAO that handles
  the HTTP/HTTPS mixed-content issue, so `ws://` connections work without your
  browser blocking them.

**Server crashes on startup**
- Check that all config files exist and are valid:
  ```bash
  ls config/
  # Should show: config.toml  areas.toml  characters.txt  music.txt  roles.toml

  # Check for syntax errors in TOML files
  cat config/config.toml | head -20    # eyeball the first 20 lines
  ```

**Permission denied when running**
```bash
# Make the binary executable (Linux/macOS)
chmod +x out/whisker

# Then run
./out/whisker
```

## Useful Linux Commands Reference

Quick reference for commands you'll use often when running Whisker:

```bash
# --- Process management ---
./out/whisker &              # Run in background
jobs                           # List background jobs
fg                             # Bring back to foreground
kill %1                        # Kill background job #1
pkill whisker                  # Kill all whisker processes
ps aux | grep whisker          # Find running whisker process

# --- File management ---
ls -la config/                 # List config files with details
cp config/config.toml config/config.toml.bak   # Backup config before editing
diff config/config.toml config/config.toml.bak # Compare after editing

# --- Networking ---
ss -tlnp | grep 27016         # Check if port 27016 is listening
curl ifconfig.me               # Find your public IP
ping your-domain.com           # Test DNS resolution

# --- Logs ---
./out/whisker 2>&1 | tee server.log   # Log to file AND screen
tail -f server.log                        # Watch log file live
grep "ERROR" server.log                   # Search for errors
grep "kicked" server.log                  # Search for moderation actions
```

## Next Steps

- [AO2 Protocol Reference](AO2_PROTOCOL.md) — Every packet documented, wire format, handshake, security
- [WSS Setup Guide](WSS_SETUP.md) — Set up secure WebSocket with nginx/Cloudflare
- [Plugin Development Guide](../plugins/PLUGIN%20DEV%20GUIDE%20README.md) — Write plugins to extend Whisker
- [Development Guide](DEVELOPMENT%20GUIDE%20FOR%20C3%20DEVS.md) — Deep dive into the codebase
