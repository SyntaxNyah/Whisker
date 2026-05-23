// Whisker AO2 Server — Core Server
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The heart of Whisker. Manages listeners, client lifecycle,
// UID allocation, and broadcasting. One thread per client.

module whisker::server;

import whisker::config;
import whisker::client;
import whisker::area;
import whisker::protocol;
import whisker::security;
import whisker::packets;
import whisker::pairing;
import whisker::plugin;
import whisker::websocket;
import std::io;
import std::net::tcp;
import std::time;
import std::thread;

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

    // Initialize plugin manager
    plugin::PluginManager plugins = plugin::new_manager();
    plugin::load_all(&plugins, cfg.plugin_directory);

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
    srv.plugins      = plugins;
    srv.running      = true;
    srv.ip_tracker.init(
        cfg.conn_rate_limit,
        cfg.conn_rate_window_sec,
        cfg.flood_ban_threshold
    );
    srv.ban_list.init();
    return srv;
}

// ============================================================
// Main run loop
// ============================================================

fn void? Server.run(&self) {
    io::printfn("[whisker] === %s v%s ===",
        config::SERVER_SOFTWARE, config::SERVER_VERSION);
    io::printfn("[whisker] Server: %s", self.cfg.server_name);

    // Start TCP listener
    io::printfn("[whisker] Starting TCP listener on %s:%d...",
        self.cfg.bind_address, (int)self.cfg.tcp_port);

    tcp::TcpServerSocket tcp_server = tcp::listen(
        self.cfg.bind_address,
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

    io::printn("[whisker] Server is ready. Accepting connections.");
    io::printn("");

    // Accept loop
    while (self.running) {
        tcp::TcpSocket? incoming = tcp::accept(&tcp_server);
        if (catch incoming) {
            continue;
        }

        self.handle_new_connection(incoming, false);
    }
}

// ============================================================
// New connection handling
// ============================================================

fn void Server.handle_new_connection(&self, tcp::TcpSocket socket, bool is_websocket) {
    // Extract IP address
    String ip = "unknown";  // TODO: extract from socket peer address

    // Reverse proxy: extract real IP from headers (done during WS handshake)
    // For TCP, the socket IP is the real IP unless behind a PROXY protocol proxy

    // Connection rate limit check
    if (!self.ip_tracker.check_connection(ip)) {
        io::printfn("[security] Connection rate limited: %s", security::generate_ipid(ip));

        if (self.cfg.conn_flood_autoban && self.ip_tracker.should_autoban(ip)) {
            String ipid = security::generate_ipid(ip);
            self.ban_list.add(ipid, "", "Connection flood (automatic)", config::DEFAULT_BAN_DURATION_SEC);
            io::printfn("[security] Auto-banned flooding IP: %s", ipid);
        }

        (void)socket.close();
        return;
    }

    // Multiclient limit check
    String ipid = security::generate_ipid(ip);
    int existing = count_clients_by_ipid(self, ipid);
    if (existing >= self.cfg.multiclient_limit) {
        io::printfn("[security] Multiclient limit reached for %s (%d/%d)",
            ipid, existing, self.cfg.multiclient_limit);
        (void)socket.close();
        return;
    }

    // Create client
    client::Client* c = mem::new(client::Client);
    *c = client::new_client(socket, ip, is_websocket);
    c.ipid = ipid;

    // Configure rate limiters from server config
    c.msg_limiter.configure(self.cfg.msg_rate_limit, self.cfg.msg_rate_window_sec);
    c.ooc_limiter.configure(self.cfg.ooc_rate_limit, self.cfg.ooc_rate_window_sec);
    c.raw_pkt_limiter.configure(self.cfg.raw_pkt_rate_limit, self.cfg.raw_pkt_rate_window_sec);

    // Register client
    int slot = self.add_client(c);
    if (slot < 0) {
        io::printn("[server] Server full, rejecting connection.");
        (void)socket.close();
        mem::free(c);
        return;
    }

    io::printfn("[server] New %s connection from %s (slot %d)",
        is_websocket ? "WebSocket" : "TCP", ipid, slot);

    // Send the decryptor (tells client: no FantaCrypt encryption)
    c.send_raw(config::DECRYPTOR_PACKET);

    // Spawn a thread to handle this client
    ClientThreadArgs* args = mem::new(ClientThreadArgs);
    args.server = self;
    args.client = c;
    Thread t;
    if (catch t.create(&client_handler_thread, args)) {
        io::printn("[server] Failed to create handler thread");
        self.remove_client(c);
        c.disconnect();
        mem::free(c);
        mem::free(args);
        return;
    }
    (void)t.detach();
}

// ============================================================
// Thread helpers
// ============================================================

struct ClientThreadArgs {
    Server* server;
    client::Client* client;
}

fn int client_handler_thread(void* arg) {
    @pool_init() {
        ClientThreadArgs* args = (ClientThreadArgs*)arg;
        client_handler(args.server, args.client);
        mem::free(args);
    };
    return 0;
}

fn int ws_listener_thread(void* arg) {
    @pool_init() {
    Server* server = (Server*)arg;

    tcp::TcpServerSocket? ws_server = tcp::listen(
        server.cfg.bind_address,
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

        // Perform WebSocket handshake
        String ip = "unknown";
        websocket::WsHandshakeResult? hs = websocket::perform_handshake(
            &incoming, ip,
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

        // Use real IP from handshake if available
        server.handle_new_connection(incoming, true);
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

        // Read from socket
        sz? bytes_read = c.socket.read(&read_buf);
        if (catch bytes_read) {
            break; // Connection error or closed
        }
        if (bytes_read == 0) {
            break; // Client disconnected
        }

        c.last_activity = security::current_time_sec();

        // Feed bytes to packet buffer
        c.packet_buf.feed((String)read_buf[0..bytes_read]);

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
            if (catch pkt) continue; // Malformed packet, skip

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
