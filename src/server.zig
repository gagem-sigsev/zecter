const std = @import("std");
const print = std.debug.print;
const Thread = std.Thread;
const Controller = @import("controller.zig");

pub const ZecterServer = struct {
    server_address: std.net.Address,
    connections: std.ArrayList(std.net.Server.Connection),
    streams: std.ArrayList(std.net.Stream),
    mutex: std.Thread.Mutex,

    var list_offset: i8 = -1; // index offset

    const Self = @This();
    pub fn newZecter(allocator: *std.mem.Allocator) !*ZecterServer {
        const zecter: *ZecterServer = try allocator.create(ZecterServer);
        zecter.server_address = try parse_address("127.0.0.1", 8080);
        zecter.connections = std.ArrayList(std.net.Server.Connection).init(allocator.*);
        zecter.streams = std.ArrayList(std.net.Stream).init(allocator.*);
        zecter.mutex = std.Thread.Mutex{};
        return zecter;
    }

    fn parse_address(ip: []const u8, port: u16) !std.net.Address {
        const address = try std.net.Address.parseIp4(ip, port);
        return address;
    }

    // TODO: IMPLEMENT SERVER FUNCTIONALITY IN SINGLE THREAD FOR STARTERS
    pub fn startServer(self: *Self) !void {
        // create a listener LISTENER IS SERVER TYPE
        const listener_opts = std.net.Address.ListenOptions{ .force_nonblocking = false, .kernel_backlog = 20, .reuse_address = true, .reuse_port = true };
        const listener = try std.net.Address.listen(self.server_address, listener_opts);
        // self.handleClient(@constCast(&listener)) catch |err| {
        // print("Error handling client: {any}\n", .{err});
        //};

        var accept_thread = try Thread.spawn(.{}, acceptClient, .{ self, @constCast(&listener) });
        var console_thread = try Thread.spawn(.{}, consoleListener, .{self});

        accept_thread.join();
        console_thread.join();
    }

    fn acceptClient(self: *Self, listener: *std.net.Server) !void {
        while (true) {

            // accept a client
            const conn = try listener.accept();

            self.mutex.lock();
            self.connections.append(conn) catch |err| {
                print("Error Adding Client to Connections List: {any}\n", .{err});
            };
            list_offset += 1;
            const stream = conn.stream;
            self.streams.append(stream) catch |err| {
                print("Error adding stream to streams: {any}\n", .{err});
            };
            std.Thread.sleep(1_000_000_000);
            self.mutex.unlock();

            //var thread = try Thread.spawn(.{}, handleClient, .{ self, conn.stream });
            //thread.join();
        }
        listener.deinit();
    }

    fn consoleListener(self: *Self) !void {
        const stdin = std.io.getStdIn().reader();
        const stdout = std.io.getStdOut().writer();

        while (true) {
            try stdout.print("Erebus ~>: ", .{});
            var line_buf: [128]u8 = undefined;
            const line = try stdin.readUntilDelimiterOrEof(&line_buf, '\n');

            if (line) |command| {
                if (std.mem.eql(u8, command, "connections")) {
                    self.mutex.lock();
                    Controller.listClients(self);
                    self.mutex.unlock();
                } else if (std.mem.eql(u8, command, "shutdown")) {
                    self.mutex.lock();
                    _ = try Controller.killServer(self);
                    self.mutex.unlock();
                } else if (std.mem.eql(u8, command, "!clear")) {
                    std.debug.print("\x1B[2J\x1B[H", .{});
                } else if (std.mem.startsWith(u8, command, "kill ")) {
                    self.mutex.lock();
                    const id_str = command[5..];
                    const id = try std.fmt.parseInt(usize, id_str, 10);
                    try Controller.killClient(self, id);
                    self.mutex.unlock();
                } else if (std.mem.startsWith(u8, command, "msg ")) {
                    self.mutex.lock();
                    Controller.msgClient(self, line_buf[4..5], line_buf[5..command.len]) catch |err| {
                        print("Error while writing to client: {any}\n", .{err});
                    };
                    self.mutex.unlock();
                } else {
                    try stdout.print("Unknown command: {s}\n", .{command});
                }
            }
        }
    }
};
