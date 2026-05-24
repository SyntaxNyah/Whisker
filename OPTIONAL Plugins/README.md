# Optional Plugins

This folder contains **ready-to-use plugins** that add extra features to your Whisker server. They are completely optional -- your server works fine without them. Each plugin is already built and just needs to be dropped into your `plugins/` folder.

## Folder Structure

```
OPTIONAL Plugins/
  Windows/          ← .dll files for Windows servers
  Linux/            ← .so files for Linux servers
  *.c3              ← source code (learning exercise)
```

## How to Use

**To install a plugin:**

1. Open the `Windows/` or `Linux/` folder (whichever matches your server)
2. Drag the plugin file into your server's `plugins/` directory
3. Edit `config/config.toml` if the plugin requires configuration (check the plugin's section below)
4. Restart your server

**To remove a plugin:**

Delete the `.so` / `.dll` file from `plugins/` and restart.

**Don't want any of these?**

Delete this entire `OPTIONAL Plugins` folder. It won't affect your server.

---

## Available Plugins

### Server Advertiser

**Compiled:** `Windows/server_advertiser.dll` · `Linux/server_advertiser.so`
**Source:** `server_advertiser.c3`

Advertises your server to the Attorney Online master server so players can find it in the public server browser. Without this plugin, your server is unlisted -- players can only connect by entering your IP and port manually.

The `.c3` source file is included as a learning exercise -- if you want to try compiling a plugin yourself, this is a great one to start with. See the [Plugin Dev Guide](../plugins/PLUGIN%20DEV%20GUIDE%20README.md) for how to set up a C3 project and build it.

**Setup:**

1. Grab the `.dll` or `.so` from the appropriate folder and drop it into your server's `plugins/` directory
2. Add the following to your `config/config.toml`:

```toml
[advertiser]
masterserver = "https://servers.aceattorneyonline.com/servers"
```

3. Make sure your `[server]` section has a proper `name` and `description` set -- these are what players see in the server browser.
4. Restart the server.

The plugin will automatically advertise your server every 60 seconds. You'll see confirmation in the server console:

```
[advertiser] Advertising to: https://servers.aceattorneyonline.com/servers
[advertiser] Server listed successfully.
```

**Why is this a plugin and not built-in?**

Not every server wants to be public. Private servers, test servers, and LAN servers have no reason to advertise. Making it opt-in keeps the core server simple and puts you in control.

---

### Case Manager (CM)

**Compiled:** `Windows/case_manager.dll` · `Linux/case_manager.so`
**Source:** `case_manager.c3`

Gives players a **Case Manager (CM)** role for area control — inspired by [Akashi](https://github.com/AttorneyOnline/akashi)'s CM system. CM is a per-area role that any player can claim. It lets players run their own courtroom without needing a moderator present.

The `.c3` source file is included as a learning exercise. It's the most complete example of a standalone plugin using the full Plugin API (commands, area management, client operations). See the [Plugin Dev Guide](../plugins/PLUGIN%20DEV%20GUIDE%20README.md) for how to set up a C3 project and build it.

**What CM can do:**
- Lock and unlock the area (built-in `/lock` and `/unlock` already check for CM)
- Kick players from the area
- Play music
- Set the area status (IDLE, CASING, RP, etc.)
- Force player positions (def, pro, wit, jud, hld, hlp)
- Manage the area invite list

**How CM works:**
- Type `/cm` to become CM of an area — only works if no other CMs exist
- Existing CMs can promote others with `/cm <uid>`
- CM status is **automatically lost** when you leave the area or disconnect
- Multiple CMs can exist in one area
- Moderators bypass all CM permission checks

**Commands:**

| Command | Usage | Description |
|---------|-------|-------------|
| `/cm` | `/cm [uid]` | Become CM, or promote another player |
| `/uncm` | `/uncm [uid\|all]` | Remove CM from self, another player, or everyone |
| `/area_kick` | `/area_kick <uid>` | Kick a player from the area to the lobby |
| `/play` | `/play <song>` | Play a song in the area |
| `/status` | `/status [status]` | Set area status (idle, lfp, casing, recess, rp, gaming) |
| `/forcepos` | `/forcepos <uid> <pos>` | Force a player's position (def, pro, wit, jud, hld, hlp) |
| `/uninvite` | `/uninvite <uid>` | Remove a player from the area's invite list |

**Setup:**

1. Grab the `.dll` or `.so` from the appropriate folder and drop it into your server's `plugins/` directory
2. Restart the server. No configuration needed.

All commands automatically appear in `/help`.

**To remove it:**

Delete the `.dll` / `.so` file from `plugins/` and restart.

**Why is this a plugin and not built-in?**

Not every server wants players to self-manage areas. Some servers prefer moderator-only control. Keeping CM as a standalone plugin means you can add or remove it without touching the server code at all — just drop or delete the file.

**Design notes (for developers):**

- CM state is stored in the area's existing `cm_uids` / `cm_count` fields (see `area.c3`)
- The core server already strips CM on area change (`packets.c3:change_area`) and disconnect (`server.c3:client_cleanup`)
- The built-in `/lock` and `/unlock` commands already check for CM status — no duplication needed
- Area kick uses the Plugin API's `force_move` to send players to the lobby, and removes them from the invite list to prevent re-entry
- The plugin communicates with the server entirely through the `PluginAPI` function pointers — no imports from the server source

---

See the [Plugin Dev Guide](../plugins/PLUGIN%20DEV%20GUIDE%20README.md) for writing your own plugins.
