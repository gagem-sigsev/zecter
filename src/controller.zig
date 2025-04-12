const std = @import("std");
const ZecterServer = @import("./server.zig").ZecterServer;
const print = std.debug.print;

pub fn killServer(self: *ZecterServer) !void {
    const stdout = std.io.getStdOut().writer();
    _ = self;
    try stdout.print("Shutting down server", .{});
    std.Thread.sleep(1_000_000_000);
    try stdout.print(".", .{});
    std.Thread.sleep(1_000_000_000);
    try stdout.print(".", .{});
    std.Thread.sleep(1_000_000_000);
    try stdout.print(".", .{});
    std.Thread.sleep(1_000_000_000);
    try stdout.print("\n", .{});
    std.os.linux.exit_group(0);
}

// TODO: implement second function that will run in a thread to continously accept clients
// Handle Stream Interaction
pub fn msgClient(self: *ZecterServer, client: []const u8, msg: []const u8) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var list = std.ArrayList(u8).init(allocator);
    defer {
        list.deinit();
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) {
            print("Memory Leak: {any}\n", .{deinit_status});
        }
    }
    try list.appendSlice(msg);
    try list.appendSlice("\n");

    const payload: []const u8 = list.items;
    const c = try std.fmt.parseInt(usize, client, 10);
    const stream = self.streams.items[c];

    const result = try stream.write(payload[0..payload.len]); // catch |err| {
        //print("Failed to write to stream! {any}\n", .{err});
    //};
    print("Sent message to client with result: {any}\n", .{result});
    std.Thread.sleep(1_000_000_000); // Ensure there's a small pause if needed

}

pub fn clearScreen() void {
    std.debug.print("\x1B[2J\x1B[H", .{});
}

pub fn listClients(self: *ZecterServer) void {
    clearScreen(); // optional
    std.debug.print("Active Clients:\n", .{});
    for (self.connections.items, 0..) |conn, idx| {
        std.debug.print("  [{d}] Address: {any}\n", .{ idx, conn.address });
    }
}

pub fn killClient(self: *ZecterServer, index: usize) !void {
    if (index >= self.connections.items.len) {
        std.debug.print("Invalid client index.\n", .{});
        return;
    }

    const stream = self.streams.items[index];
    stream.close(); // close the connection
    _ = self.connections.swapRemove(index);
    _ = self.streams.swapRemove(index);

    std.debug.print("Killed client at index {d}.\n", .{index});
}
