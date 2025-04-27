const std = @import("std");
const ZecterServer = @import("server.zig").ZecterServer;
const Controller = @import("controller.zig");

const print = std.debug.print;

pub const Client = struct {
    username: []const u8,
    user_id: i8,
    client_connection: std.net.Server.Connection,

    pub fn newClient(username: []const u8, user_id: i8, client_connection: *std.net.Server.Connection, allocator: *std.mem.Allocator) !*Client {
        const client: *Client = try allocator.create(Client);
        client.username = username;
        client.client_connection = client_connection.*;
        client.user_id = user_id;
        return client;
    
    }
};
