# Optional Plugins

This folder contains **free, pre-built plugins** that add extra features to your Whisker server. They are completely optional -- your server works fine without them.

## How to Use

**To install a plugin:**

1. Copy the plugin's `.c3` source file into your own C3 project
2. Build it as a dynamic library (`c3c build` with `"type": "dynamic-lib"` in your `project.json`)
3. Copy the resulting `.so` (Linux) or `.dll` (Windows) file into your server's `plugins/` directory
4. Edit `config/config.toml` if the plugin requires configuration (check the plugin's section below)
5. Restart your server

**To remove a plugin:**

Delete the `.so` / `.dll` file from `plugins/` and restart.

**Don't want any of these?**

Delete this entire `OPTIONAL Plugins` folder. It won't affect your server.

---

## Available Plugins

### Server Advertiser

**File:** `server_advertiser.c3`

Advertises your server to the Attorney Online master server so players can find it in the public server browser. Without this plugin, your server is unlisted -- players can only connect by entering your IP and port manually.

**Setup:**

1. Build and deploy the plugin (see above)
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

See the [Plugin Dev Guide](../plugins/PLUGIN%20DEV%20GUIDE%20README.md) for how to build and deploy plugins.
