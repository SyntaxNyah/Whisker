// Whisker AO2 Server — Core Server
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The heart of Whisker. Manages listeners, client lifecycle,
// UID allocation, and broadcasting. One thread per client.

module whisker::server;

import whisker::config;
import whisker::client;
import whisker::area;
import whisker::args;
import whisker::protocol;
import whisker::security;
import whisker::packets;
import whisker::pairing;
import whisker::plugin;
import whisker::websocket;
import whisker::console;
import whisker::moderation;
import std::io;
import std::net::tcp;
import std::time;
import std::thread;

// ============================================================
// Peer IP extraction — getpeername via C interop
// ============================================================

extern fn int getpeername(int sock, void* addr, int* addrlen);
extern fn int setsockopt(int sock, int level, int optname, void* optval, int optlen);

const int SOL_TCP     = 6;
const int TCP_NODELAY = 1;

// Disable Nagle's algorithm so small packets (like the decryptor)
// are sent immediately instead of being buffered. Without this,
// localhost connections can stall because the client never receives
// the decryptor and the handshake deadlocks.
fn void set_tcp_nodelay(int fd) {
    int one = 1;
    setsockopt(fd, SOL_TCP, TCP_NODELAY, &one, 4);
}

fn int get_raw_fd(tcp::TcpSocket* sock) {
    return *(int*)sock;
}

fn String extract_peer_ip(tcp::TcpSocket* sock) {
    char[28] addr_buf;
    int addrlen = 28;
    int raw = get_raw_fd(sock);

    if (getpeername(raw, &addr_buf[0], &addrlen) != 0) return "unknown";

    // sockaddr_in: family(2) + port(2) + addr(4)
    ushort family = *(ushort*)&addr_buf[0];
    if (family != 2) return "unknown"; // AF_INET = 2

    return string::tformat("%d.%d.%d.%d",
        (int)(addr_buf[4] & 0xFF), (int)(addr_buf[5] & 0xFF),
        (int)(addr_buf[6] & 0xFF), (int)(addr_buf[7] & 0xFF));
}

// ============================================================
// Server state — the central shared state of Whisker
// ============================================================

const int MAX_SERVER_CLIENTS = 1024;

struct Server {
    // Config
    config::ServerConfig cfg;
    String               config_dir;

    // Clients
    client::Client*[MAX_SERVER_CLIENTS] clients;
    int                                  client_count;
    int                                  next_uid;

    // Areas
    area::Area[]       areas;
    int                area_count;

    // Assets
    String[]           characters;
    int                char_count;
    String[]           music;
    int                music_count;

    // Security
    security::IpTracker   ip_tracker;
    security::BanList     ban_list;

    // Plugins
    plugin::PluginManager plugins;
    plugin::PluginAPI     plugin_api;

    // State
    bool               running;
}

// ============================================================
// Server initialization
// ============================================================

fn Server*? init(String config_dir) {
    io::printn("[whisker] Loading configuration...");
    config::ServerConfig cfg = config::load(config_dir)!;

    io::printn("[whisker] Loading character list...");
    String[] characters = config::load_characters(config_dir) ?? {};
    if (characters.len == 0) {
        io::printn("[whisker] WARNING: No characters loaded. Add characters to config/characters.txt");
    }

    io::printn("[whisker] Loading music list...");
    String[] music_list = config::load_music(config_dir) ?? {};

    io::printn("[whisker] Loading areas...");
    area::Area[] areas = area::load_areas(config_dir, (int)characters.len) ?? {};

    io::printfn("[whisker] Loaded: %d characters, %d music tracks, %d areas",
        (int)characters.len, (int)music_list.len, (int)areas.len);

    Server* srv = mem::new(Server);
    srv.cfg          = cfg;
    srv.config_dir   = config_dir;
    srv.client_count = 0;
    srv.next_uid     = 0;
    srv.areas        = areas;
    srv.area_count   = (int)areas.len;
    srv.characters   = characters;
    srv.char_count   = (int)characters.len;
    srv.music        = music_list;
    srv.music_count  = (int)music_list.len;
    srv.plugins      = plugin::new_manager();
    srv.running      = true;
    srv.ip_tracker.init(
        cfg.conn_rate_limit,
        cfg.conn_rate_window_sec,
        cfg.flood_ban_threshold
    );
    srv.ban_list.init();

    // Load roles and accounts for authentication
    moderation::init_auth(config_dir);

    // Build the plugin API with all server helpers
    srv.plugin_api = build_plugin_api(srv);

    // Resolve plugin directory relative to project root (same as config).
    // config_dir is already resolved relative to the binary (e.g. "./out/../config"),
    // so going up one level from config gives us the project root. This way
    // plugins/ is found whether you run from the project root or from out/.
    srv.cfg.plugin_directory = string::tformat("%s/../%s", config_dir, cfg.plugin_directory);
    plugin::load_all(&srv.plugins, &srv.plugin_api, srv.cfg.plugin_directory);

    return srv;
}

// ============================================================
// Main run loop
// ============================================================

fn void? Server.run(&self) {
    io::printfn("[whisker] === %s v%s ===",
        config::SERVER_SOFTWARE, config::SERVER_VERSION);
    io::printfn("[whisker] Server: %s", self.cfg.server_name);

    // Default bind address if empty
    String bind_addr = self.cfg.bind_address;
    if (bind_addr.len == 0) bind_addr = "0.0.0.0";

    // Start TCP listener
    io::printfn("[whisker] Starting TCP listener on %s:%d...",
        bind_addr, (int)self.cfg.tcp_port);

    tcp::TcpServerSocket tcp_server = tcp::listen(
        bind_addr,
        self.cfg.tcp_port,
        config::DEFAULT_LISTEN_BACKLOG
    )!;

    io::printfn("[whisker] TCP listening on port %d", (int)self.cfg.tcp_port);

    if (self.cfg.enable_ws) {
        // Start WebSocket listener in a separate thread
        Thread ws_thread;
        if (catch ws_thread.create(&ws_listener_thread, self)) {
            io::printn("[websocket] WARNING: Failed to start WebSocket listener thread");
        } else {
            (void)ws_thread.detach();
        }
    }

    // Start the server console thread (reads stdin for admin commands)
    Thread console_t;
    if (catch console_t.create(&console::console_thread, self)) {
        io::printn("[console] WARNING: Failed to start console thread");
    } else {
        (void)console_t.detach();
    }

    io::printn("[whisker] Server is ready. Accepting connections.");
    io::printn("");

    // Accept loop
    while (self.running) {
        tcp::TcpSocket? incoming = tcp::accept(&tcp_server);
        if (catch incoming) {
            continue;
        }

        set_tcp_nodelay(get_raw_fd(&incoming));
        String ip = extract_peer_ip(&incoming);
        self.handle_new_connection(incoming, false, ip);
    }
}

// ============================================================
// New connection handling
// ============================================================

fn void Server.handle_new_connection(&self, tcp::TcpSocket socket, bool is_websocket, String ip) {

    // Ban check — reject banned IPs immediately before spawning a thread.
    // This prevents banned clients from consuming a thread + 256KB pool.
    String ipid = security::generate_ipid(ip);
    if (self.ban_list.is_banned_ipid(ipid)) {
        (void)socket.close();
        return;
    }

    // Connection rate limit check
    if (!self.ip_tracker.check_connection(ip)) {
        io::printfn("[security] Connection rate limited: %s", ipid);

        if (self.cfg.conn_flood_autoban && self.ip_tracker.should_autoban(ip)) {
            self.ban_list.add(ipid, "", "Connection flood (automatic)", config::DEFAULT_BAN_DURATION_SEC);
            io::printfn("[security] Auto-banned flooding IP: %s", ipid);
        }

        (void)socket.close();
        return;
    }

    // Multiclient limit check
    int existing = count_clients_by_ipid(self, ipid);
    if (existing >= self.cfg.multiclient_limit) {
        io::printfn("[security] Multiclient limit reached for %s (%d/%d)",
            ipid, existing, self.cfg.multiclient_limit);
        (void)socket.close();
        return;
    }

    // Server full check — reject before spawning a thread + 256KB pool
    if (self.client_count >= MAX_SERVER_CLIENTS) {
        (void)socket.close();
        return;
    }

    // Spawn handler thread — Client is created inside the handler's own
    // memory pool so all allocations (struct, DString, temps) live in one
    // allocator context. This prevents cross-pool corruption when the
    // DString grows during packet processing.
    ClientThreadArgs* args = mem::new(ClientThreadArgs);
    args.server = self;
    args.socket = socket;
    args.ip = ip;
    args.ipid = ipid;
    args.is_websocket = is_websocket;

    Thread t;
    if (catch t.create(&client_handler_thread, args)) {
        io::printn("[server] Failed to create handler thread");
        (void)socket.close();
        return;
    }
    (void)t.detach();
}

// ============================================================
// Thread helpers
// ============================================================

struct ClientThreadArgs {
    Server* server;
    tcp::TcpSocket socket;
    String ip;
    String ipid;
    bool is_websocket;
}

fn int client_handler_thread(void* arg) {
    @pool_init(mem, 1024 * 256) {
        ClientThreadArgs* args = (ClientThreadArgs*)arg;
        Server* srv = args.server;

        // Create Client inside this thread's pool so the DString and
        // all temporary memory share the same allocator. Prevents the
        // cross-pool free that was corrupting the WS listener thread.
        client::Client* c = mem::new(client::Client);
        *c = client::new_client(args.socket, args.ip, args.is_websocket);
        c.ipid = args.ipid;

        // Configure rate limiters from server config
        c.msg_limiter.configure(srv.cfg.msg_rate_limit, srv.cfg.msg_rate_window_sec);
        c.ooc_limiter.configure(srv.cfg.ooc_rate_limit, srv.cfg.ooc_rate_window_sec);
        c.raw_pkt_limiter.configure(srv.cfg.raw_pkt_rate_limit, srv.cfg.raw_pkt_rate_window_sec);

        // Register client
        int slot = srv.add_client(c);
        if (slot < 0) {
            io::printn("[server] Server full, rejecting connection.");
            c.disconnect();
            return 0;
        }

        io::printfn("[server] New %s connection from %s (slot %d)",
            args.is_websocket ? "WebSocket" : "TCP", c.ipid, slot);

        // Send the decryptor — send_raw handles both TCP and WebSocket framing
        c.send_raw(config::DECRYPTOR_PACKET);

        // Process client packets until disconnect
        client_handler(srv, c);

        // Pool cleanup frees Client, DString, and all temp memory at once
    };
    return 0;
}

fn int ws_listener_thread(void* arg) {
    @pool_init(mem, 1024 * 256) {
    Server* server = (Server*)arg;

    String ws_bind = server.cfg.bind_address;
    if (ws_bind.len == 0) ws_bind = "0.0.0.0";

    tcp::TcpServerSocket? ws_server = tcp::listen(
        ws_bind,
        server.cfg.ws_port,
        config::DEFAULT_LISTEN_BACKLOG
    );
    if (catch ws_server) {
        io::printfn("[websocket] Failed to bind WebSocket listener on port %d",
            (int)server.cfg.ws_port);
        return 1;
    }

    io::printfn("[websocket] WebSocket listening on port %d", (int)server.cfg.ws_port);

    while (server.running) {
        tcp::TcpSocket? incoming = tcp::accept(&ws_server);
        if (catch incoming) continue;

        // Disable Nagle buffering and extract peer IP
        set_tcp_nodelay(get_raw_fd(&incoming));
        String peer_ip = extract_peer_ip(&incoming);
        websocket::WsHandshakeResult? hs = websocket::perform_handshake(
            &incoming, peer_ip,
            server.cfg.reverse_proxy_mode,
            server.cfg.trusted_proxy_header
        );

        if (catch hs) {
            (void)incoming.close();
            continue;
        }

        if (!hs.success) {
            (void)incoming.close();
            continue;
        }

        // Use handshake's client_ip (may be updated from proxy headers)
        server.handle_new_connection(incoming, true, hs.client_ip);
    }

    }; // @pool_init
    return 0;
}

// ============================================================
// Client handler — processes packets for one client
// ============================================================

fn void client_handler(Server* server, client::Client* c) {
    char[4096] read_buf;

    // Handshake timeout: client must join within HANDSHAKE_TIMEOUT_MS
    long deadline = security::current_time_sec() + config::HANDSHAKE_TIMEOUT_MS / 1000;

    while (c.connected) {
        // Check handshake timeout
        if (!c.joined && security::current_time_sec() > deadline) {
            io::printfn("[server] Handshake timeout for %s", c.ipid);
            break;
        }

        if (c.is_websocket) {
            // WebSocket: read frames and extract payload
            websocket::WsFrame? frame = websocket::read_frame(&c.socket);
            if (catch frame) break; // Connection error

            if (frame.opcode == websocket::WS_OPCODE_PING) {
                websocket::send_pong(&c.socket, frame.payload);
                continue;
            }
            if (frame.opcode == websocket::WS_OPCODE_CLOSE) {
                websocket::send_close(&c.socket);
                break;
            }
            if (frame.opcode != websocket::WS_OPCODE_TEXT) {
                continue; // Ignore binary/continuation frames
            }

            c.last_activity = security::current_time_sec();

            // WebSocket text payload contains AO2 packets (with #% terminators)
            c.packet_buf.feed(frame.payload);
        } else {
            // TCP: read raw bytes
            sz? bytes_read = c.socket.read(&read_buf);
            if (catch bytes_read) break;
            if (bytes_read == 0) break;

            c.last_activity = security::current_time_sec();
            c.packet_buf.feed((String)read_buf[0..bytes_read - 1]);
        }

        // Process all complete packets in the buffer
        while (true) {
            String? raw_packet = c.packet_buf.next_packet();
            if (catch raw_packet) break; // No more complete packets

            // Raw packet rate limit
            if (!c.raw_pkt_limiter.check()) {
                io::printfn("[security] Raw packet rate limit exceeded: %s", c.ipid);
                c.send_server_message("Rate limit exceeded. Slow down.");
                c.connected = false;
                break;
            }

            // Parse the packet
            protocol::Packet? pkt = protocol::parse(raw_packet);
            if (catch pkt) {
                io::printfn("[debug] Malformed packet from %s", c.ipid);
                continue;
            }

            //io::printfn("[debug] Packet from %s: %s (fields: %d)",
               // c.ipid, pkt.header, (int)pkt.field_count);

            // Let plugins intercept first
            if (plugin::on_packet(&server.plugins, c, &pkt)) {
                continue; // Plugin consumed the packet
            }

            // Dispatch to handler
            packets::dispatch(server, c, &pkt);
        }
    }

    // Client disconnected — cleanup
    client_cleanup(server, c);
}

// ============================================================
// Client cleanup on disconnect
// ============================================================

fn void client_cleanup(Server* server, client::Client* c) {
    io::printfn("[server] Client disconnected: UID %d (%s)", c.uid, c.ipid);

    // Clean up pairing
    pairing::on_disconnect(c, &server.clients, server.client_count);

    // Release character in area
    if (c.char_id != config::NO_CHAR_SELECTED && c.area_id >= 0 && c.area_id < server.area_count) {
        server.areas[c.area_id].release_char(c.char_id);
        server.areas[c.area_id].player_count--;

        // Remove from CM list
        server.areas[c.area_id].remove_cm(c.uid);

        // Reset area if empty
        if (server.areas[c.area_id].player_count <= 0) {
            server.areas[c.area_id].reset();
        }
    }

    // Remove from client list
    server.remove_client(c);

    // Broadcast updated player counts
    broadcast_arup(server, config::ARUP_PLAYERS);

    // Close socket
    c.disconnect();
}

// ============================================================
// Client list management
// ============================================================

fn int Server.add_client(&self, client::Client* c) {
    for (int i = 0; i < MAX_SERVER_CLIENTS; i++) {
        if (self.clients[i] == null) {
            self.clients[i] = c;
            self.client_count++;
            return i;
        }
    }
    return -1; // Full
}

fn void Server.remove_client(&self, client::Client* c) {
    for (int i = 0; i < MAX_SERVER_CLIENTS; i++) {
        if (self.clients[i] == c) {
            self.clients[i] = null;
            self.client_count--;
            return;
        }
    }
}

// Allocate a unique player UID.
fn int Server.allocate_uid(&self) {
    int uid = self.next_uid;
    self.next_uid++;
    return uid;
}

fn int count_clients_by_ipid(Server* server, String ipid) {
    int count = 0;
    for (int i = 0; i < MAX_SERVER_CLIENTS; i++) {
        if (server.clients[i] != null && server.clients[i].ipid == ipid) {
            count++;
        }
    }
    return count;
}

// ============================================================
// Broadcasting — send packets to multiple clients
// ============================================================

// Send to all joined clients.
fn void broadcast(Server* server, String data) {
    for (int i = 0; i < MAX_SERVER_CLIENTS; i++) {
        if (server.clients[i] != null && server.clients[i].joined) {
            server.clients[i].send_raw(data);
        }
    }
}

// Send to all joined clients in a specific area.
fn void broadcast_area(Server* server, int area_id, String data) {
    for (int i = 0; i < MAX_SERVER_CLIENTS; i++) {
        client::Client* c = server.clients[i];
        if (c != null && c.joined && c.area_id == area_id) {
            c.send_raw(data);
        }
    }
}

// Send to all joined clients in an area except one.
fn void broadcast_area_except(Server* server, int area_id, int except_uid, String data) {
    for (int i = 0; i < MAX_SERVER_CLIENTS; i++) {
        client::Client* c = server.clients[i];
        if (c != null && c.joined && c.area_id == area_id && c.uid != except_uid) {
            c.send_raw(data);
        }
    }
}

// ============================================================
// ARUP broadcasting — Area Room Update Packets
// ============================================================

fn void broadcast_arup(Server* server, int update_type) {
    DString pkt = dstring::temp();
    pkt.append_string("ARUP");
    pkt.append_char('#');
    pkt.append_string(string::tformat("%d", update_type));

    for (int i = 0; i < server.area_count; i++) {
        pkt.append_char('#');
        switch (update_type) {
            case config::ARUP_PLAYERS:
                pkt.append_string(string::tformat("%d", server.areas[i].player_count));
            case config::ARUP_STATUS:
                pkt.append_string(server.areas[i].status.to_string());
            case config::ARUP_CM:
                if (server.areas[i].cm_count > 0) {
                    pkt.append_string("CM");
                } else {
                    pkt.append_string("FREE");
                }
            case config::ARUP_LOCK:
                pkt.append_string(server.areas[i].lock.to_string());
            default: break;
        }
    }
    pkt.append_string(config::PACKET_TERMINATOR);

    broadcast(server, pkt.str_view());
}

// Send all ARUP types to keep clients in sync.
fn void broadcast_all_arup(Server* server) {
    broadcast_arup(server, config::ARUP_PLAYERS);
    broadcast_arup(server, config::ARUP_STATUS);
    broadcast_arup(server, config::ARUP_CM);
    broadcast_arup(server, config::ARUP_LOCK);
}

// ============================================================
// Find client by UID
// ============================================================

fn client::Client* find_client_by_uid(Server* server, int uid) {
    for (int i = 0; i < MAX_SERVER_CLIENTS; i++) {
        if (server.clients[i] != null && server.clients[i].uid == uid) {
            return server.clients[i];
        }
    }
    return null;
}

// ============================================================
// Plugin API wrappers — bridge between plugins and server
// ============================================================
//
// Standalone plugins (.dll/.so) call these through the PluginAPI
// function pointers. Module-level _plugin_srv provides server
// context without requiring it as a parameter.

Server* _plugin_srv;

// -- Registration --

fn void _api_register_command(String name, plugin::CommandHandler handler, ulong perms, String desc, String plugin_name) {
    plugin::PluginManager* pm = &_plugin_srv.plugins;
    if (pm.command_count >= plugin::MAX_PLUGIN_COMMANDS) return;

    pm.commands[pm.command_count] = {
        .name = name,
        .handler = handler,
        .required_perms = perms,
        .description = desc,
        .plugin_name = plugin_name,
    };
    pm.command_count++;
}

fn void _api_register_hook(String header, plugin::PacketHook hook, String plugin_name) {
    plugin::PluginManager* pm = &_plugin_srv.plugins;
    if (pm.hook_count >= plugin::MAX_PLUGIN_HOOKS) return;

    pm.hooks[pm.hook_count] = {
        .header = header,
        .hook = hook,
        .plugin_name = plugin_name,
    };
    pm.hook_count++;
}

// -- Server operations --

fn void* _api_find_client(int uid) {
    return find_client_by_uid(_plugin_srv, uid);
}

fn void _api_broadcast_area_msg(int area_id, String msg) {
    if (area_id < 0 || area_id >= _plugin_srv.area_count) return;
    broadcast_area(_plugin_srv, area_id,
        protocol::build("CT", { config::SERVER_SOFTWARE, msg, "1" }));
}

fn void _api_broadcast_area_raw(int area_id, String data) {
    if (area_id < 0 || area_id >= _plugin_srv.area_count) return;
    broadcast_area(_plugin_srv, area_id, data);
}

fn void _api_broadcast_arup(int arup_type) {
    broadcast_arup(_plugin_srv, arup_type);
}

fn int _api_get_area_count() {
    return _plugin_srv.area_count;
}

// -- Area CM operations --

fn bool _api_area_is_cm(int area_id, int uid) {
    if (area_id < 0 || area_id >= _plugin_srv.area_count) return false;
    return _plugin_srv.areas[area_id].is_cm(uid);
}

fn void _api_area_add_cm(int area_id, int uid) {
    if (area_id < 0 || area_id >= _plugin_srv.area_count) return;
    _plugin_srv.areas[area_id].add_cm(uid);
}

fn void _api_area_remove_cm(int area_id, int uid) {
    if (area_id < 0 || area_id >= _plugin_srv.area_count) return;
    _plugin_srv.areas[area_id].remove_cm(uid);
}

fn int _api_area_cm_count(int area_id) {
    if (area_id < 0 || area_id >= _plugin_srv.area_count) return 0;
    return _plugin_srv.areas[area_id].cm_count;
}

fn void _api_area_clear_cms(int area_id) {
    if (area_id < 0 || area_id >= _plugin_srv.area_count) return;
    _plugin_srv.areas[area_id].cm_count = 0;
}

// -- Area management --

fn void _api_area_uninvite(int area_id, int uid) {
    if (area_id < 0 || area_id >= _plugin_srv.area_count) return;
    _plugin_srv.areas[area_id].uninvite(uid);
}

fn void _api_area_set_status(int area_id, int status) {
    if (area_id < 0 || area_id >= _plugin_srv.area_count) return;
    _plugin_srv.areas[area_id].status = (area::AreaStatus)status;
}

fn int _api_area_get_status(int area_id) {
    if (area_id < 0 || area_id >= _plugin_srv.area_count) return 0;
    return (int)_plugin_srv.areas[area_id].status;
}

fn String _api_area_get_name(int area_id) {
    if (area_id < 0 || area_id >= _plugin_srv.area_count) return "";
    return _plugin_srv.areas[area_id].name;
}

fn void _api_area_set_song(int area_id, String song, int player_uid) {
    if (area_id < 0 || area_id >= _plugin_srv.area_count) return;
    _plugin_srv.areas[area_id].current_song = song;
    _plugin_srv.areas[area_id].song_player_uid = player_uid;
}

// Force-move a client to another area (bypasses lock check).
// Handles all cleanup: char release, player counts, CM removal,
// area reset, char re-take, area state sync, and ARUP broadcast.
fn void _api_force_move(void* c, int new_area_id) {
    client::Client* target = (client::Client*)c;
    Server* srv = _plugin_srv;

    if (new_area_id < 0 || new_area_id >= srv.area_count) return;
    if (new_area_id == target.area_id) return;

    // Leave old area
    area::Area* old_area = &srv.areas[target.area_id];
    if (target.char_id != config::NO_CHAR_SELECTED) {
        old_area.release_char(target.char_id);
    }
    old_area.player_count--;
    old_area.remove_cm(target.uid);
    if (old_area.player_count <= 0) old_area.reset();

    // Enter new area
    target.area_id = new_area_id;
    area::Area* new_area = &srv.areas[new_area_id];
    new_area.player_count++;

    if (target.char_id != config::NO_CHAR_SELECTED) {
        if (!new_area.is_char_taken(target.char_id)) {
            new_area.take_char(target.char_id);
        } else {
            target.char_id = config::NO_CHAR_SELECTED;
            target.char_name = "";
        }
    }

    packets::send_area_state(srv, target);
    broadcast_all_arup(srv);
    target.send_server_message(string::tformat("Moved to %s.", new_area.name));
}

// -- Client operations --

fn void _api_client_send_msg(void* c, String msg) {
    ((client::Client*)c).send_server_message(msg);
}

fn void _api_client_send_raw(void* c, String data) {
    ((client::Client*)c).send_raw(data);
}

fn int _api_client_get_uid(void* c) {
    return ((client::Client*)c).uid;
}

fn int _api_client_get_area(void* c) {
    return ((client::Client*)c).area_id;
}

fn bool _api_client_is_mod(void* c) {
    return ((client::Client*)c).is_moderator();
}

fn String _api_client_display_name(void* c) {
    return ((client::Client*)c).display_name();
}

fn int _api_client_get_char_id(void* c) {
    return ((client::Client*)c).char_id;
}

fn String _api_client_get_showname(void* c) {
    return ((client::Client*)c).showname;
}

fn String _api_client_get_char_name(void* c) {
    return ((client::Client*)c).char_name;
}

fn bool _api_client_is_joined(void* c) {
    return ((client::Client*)c).joined;
}

fn void _api_client_set_position(void* c, String pos) {
    ((client::Client*)c).position = pos;
}

// -- Extended API (v2) --

fn void _api_broadcast_all_msg(String msg) {
    broadcast(_plugin_srv,
        protocol::build("CT", { config::SERVER_SOFTWARE, msg, "1" }));
}

fn void _api_broadcast_all_raw(String data) {
    broadcast(_plugin_srv, data);
}

fn int _api_get_player_count() {
    return _plugin_srv.client_count;
}

fn int _api_get_area_player_count(int area_id) {
    if (area_id < 0 || area_id >= _plugin_srv.area_count) return 0;
    return _plugin_srv.areas[area_id].player_count;
}

fn String _api_client_get_ipid(void* c) {
    return ((client::Client*)c).ipid;
}

fn String _api_packet_get_field(void* pkt, int index) {
    protocol::Packet* p = (protocol::Packet*)pkt;
    if (index < 0 || index >= (int)p.field_count) return "";
    return p.fields[index];
}

fn int _api_packet_get_field_count(void* pkt) {
    return (int)((protocol::Packet*)pkt).field_count;
}

fn void _api_client_kick(void* c) {
    client::Client* target = (client::Client*)c;
    target.send_raw(protocol::build("KK", { "Kicked by plugin." }));
    target.connected = false;
}

fn void _api_client_mute(void* c) {
    ((client::Client*)c).is_muted = true;
}

fn void _api_client_unmute(void* c) {
    ((client::Client*)c).is_muted = false;
}

fn String _api_area_get_background(int area_id) {
    if (area_id < 0 || area_id >= _plugin_srv.area_count) return "";
    return _plugin_srv.areas[area_id].background;
}

fn void _api_area_set_background(int area_id, String bg) {
    if (area_id < 0 || area_id >= _plugin_srv.area_count) return;
    _plugin_srv.areas[area_id].background = bg;
    broadcast_area(_plugin_srv, area_id, protocol::build("BN", { bg }));
}

fn int _api_area_get_lock(int area_id) {
    if (area_id < 0 || area_id >= _plugin_srv.area_count) return 0;
    return (int)_plugin_srv.areas[area_id].lock;
}

fn void _api_area_set_lock(int area_id, int lock_state) {
    if (area_id < 0 || area_id >= _plugin_srv.area_count) return;
    _plugin_srv.areas[area_id].lock = (area::LockState)lock_state;
    broadcast_arup(_plugin_srv, config::ARUP_LOCK);
}

fn void _api_area_invite(int area_id, int uid) {
    if (area_id < 0 || area_id >= _plugin_srv.area_count) return;
    _plugin_srv.areas[area_id].invite(uid);
}

// Split a raw argument string into a quote-aware token list, writing up to
// `max` tokens into the caller-provided buffer and returning the count.
// The written tokens are sub-slices of `input` (no allocation), so they stay
// valid for as long as the plugin holds the original string.
fn int _api_args_split(String input, String* out, int max) {
    if (out == null || max <= 0 || input == '') return 0;
    args::Args a = args::parse(input);
    int n = a.count < max ? a.count : max;
    for (int i = 0; i < n; i++) {
        out[i] = a.tokens[i];
    }
    return n;
}

// ============================================================
// Build the fully populated PluginAPI
// ============================================================

fn plugin::PluginAPI build_plugin_api(Server* srv) {
    _plugin_srv = srv;

    return {
        .register_command   = &_api_register_command,
        .register_hook      = &_api_register_hook,
        .find_client        = &_api_find_client,
        .broadcast_area_msg = &_api_broadcast_area_msg,
        .broadcast_area_raw = &_api_broadcast_area_raw,
        .broadcast_arup     = &_api_broadcast_arup,
        .get_area_count     = &_api_get_area_count,
        .area_is_cm         = &_api_area_is_cm,
        .area_add_cm        = &_api_area_add_cm,
        .area_remove_cm     = &_api_area_remove_cm,
        .area_cm_count      = &_api_area_cm_count,
        .area_clear_cms     = &_api_area_clear_cms,
        .area_uninvite      = &_api_area_uninvite,
        .area_set_status    = &_api_area_set_status,
        .area_get_status    = &_api_area_get_status,
        .area_get_name      = &_api_area_get_name,
        .area_set_song      = &_api_area_set_song,
        .force_move         = &_api_force_move,
        .client_send_msg    = &_api_client_send_msg,
        .client_send_raw    = &_api_client_send_raw,
        .client_get_uid     = &_api_client_get_uid,
        .client_get_area    = &_api_client_get_area,
        .client_is_mod      = &_api_client_is_mod,
        .client_display_name = &_api_client_display_name,
        .client_get_char_id  = &_api_client_get_char_id,
        .client_get_showname = &_api_client_get_showname,
        .client_get_char_name = &_api_client_get_char_name,
        .client_is_joined    = &_api_client_is_joined,
        .client_set_position = &_api_client_set_position,

        // Extended API (v2)
        .broadcast_all_msg     = &_api_broadcast_all_msg,
        .broadcast_all_raw     = &_api_broadcast_all_raw,
        .get_player_count      = &_api_get_player_count,
        .get_area_player_count = &_api_get_area_player_count,
        .client_get_ipid       = &_api_client_get_ipid,
        .packet_get_field      = &_api_packet_get_field,
        .packet_get_field_count = &_api_packet_get_field_count,
        .client_kick           = &_api_client_kick,
        .client_mute           = &_api_client_mute,
        .client_unmute         = &_api_client_unmute,
        .area_get_background   = &_api_area_get_background,
        .area_set_background   = &_api_area_set_background,
        .area_get_lock         = &_api_area_get_lock,
        .area_set_lock         = &_api_area_set_lock,
        .area_invite           = &_api_area_invite,
        .args_split            = &_api_args_split,
    };
}
