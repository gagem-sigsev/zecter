const std = @import("std");
const print = std.debug.print;
const Packet = @import("packet.zig").Packet;
const Zecter = @import("server.zig").ZecterServer;

pub fn main() !void {
    // create a GPA
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_allocator = gpa.allocator();

    const zecter = try Zecter.newZecter(@constCast(&gpa_allocator));
    defer {
        zecter.streams.deinit();
        zecter.connections.deinit();
        gpa_allocator.destroy(zecter);
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) {
            print("Memory Leak! {any}\n", .{deinit_status});
        }
    }


    zecter.startServer() catch |err| {
        print("Error while starting server: {any}\n", .{err});
    };
}
