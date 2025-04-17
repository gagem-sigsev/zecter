const std = @import("std");
const print = std.debug.print;
const Thread = std.Thread;
const Client = @import("client.zig").Client;

const Controller = @import("controller.zig");

pub const ZecterServer = struct {
    server_address: std.net.Address,
    connections: std.ArrayList(std.net.Server.Connection),
    streams: std.ArrayList(std.net.Stream),
    active_users: std.ArrayList([]const u8),
    clients: std.ArrayList(*Client),
    mutex: std.Thread.Mutex,


    const Self = @This();
    pub fn newZecter(allocator: *std.mem.Allocator) !*ZecterServer {
        const zecter: *ZecterServer = try allocator.create(ZecterServer);
        zecter.server_address = try parseAddress("127.0.0.1", 8080);
        zecter.connections = std.ArrayList(std.net.Server.Connection).init(allocator.*);
        zecter.streams = std.ArrayList(std.net.Stream).init(allocator.*);
        zecter.active_users = std.ArrayList([]const u8).init(allocator.*);
        zecter.clients = std.ArrayList(*Client).init(allocator.*);
        zecter.mutex = std.Thread.Mutex{};
        return zecter;
    }

    fn parseAddress(ip: []const u8, port: u16) !std.net.Address {
        const address = try std.net.Address.parseIp4(ip, port);
        return address;
    }

    pub fn startServer(self: *Self) !void {
        // create a listener LISTENER IS SERVER TYPE
        const listener_opts = std.net.Address.ListenOptions{ .force_nonblocking = false, .kernel_backlog = 20, .reuse_address = true, .reuse_port = true };
        const listener = try std.net.Address.listen(self.server_address, listener_opts);

        var accept_thread = try Thread.spawn(.{}, acceptClient, .{ self, @constCast(&listener) });
        var console_thread = try Thread.spawn(.{}, consoleListener, .{self});

        accept_thread.join();
        console_thread.join();
    }

    fn acceptClient(self: *Self, listener: *std.net.Server) !void {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const allocator = gpa.allocator();
        while (true) {

            // accept a client
            const conn = try listener.accept();
            
            // Lock the mutex to protect shared data
            self.mutex.lock();
            
            // Append the new client connection into the connections array list
            self.connections.append(conn) catch |err| {
                print("Error Adding Client to Connections List: {any}\n", .{err});
            };
           
            // obtain the stream from the connection 
            const stream = conn.stream;
            self.streams.append(stream) catch |err| {
                print("Error adding stream to streams: {any}\n", .{err});
            };

            // allocate memory for the username from the client 
            print("Allocating buffer for client username...\n", .{});
            const user_name = try allocator.alloc(u8, 1024);
            
            // send the username prompt to the client 
            print("Buffer allocated with 1024 bytes, Prompting for client input...\n", .{});
            const bytes_sent = try stream.write("Username->: ");
            
            // receive the username from the client 
            print("Sent {d} bytes to client...\n", .{bytes_sent});
            const bytes_read = try stream.read(user_name);
            
            // resize the memory to prevent memory waste
            print("Client input received, resizing buffer to {d} bytes...\nClient username: {s}\n", .{ bytes_read, user_name[0 .. bytes_read - 1] });
            const resize_status = allocator.resize(user_name, bytes_read);
            _ = resize_status;
            print("Buffer resized to bytes_read - 1 = {d} bytes. Null terminator eliminated...\nCreating client structure...\n", .{bytes_read - 1});
            
            // append the username to active users array list 
            self.active_users.append(user_name[0 .. bytes_read - 1]) catch |err| {
                print("Unable to append user to active users list: {any}\n", .{err});
            };
            
            // unlock the mutex to allow shared resources to be available for other threads
            self.mutex.unlock();
        }
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
