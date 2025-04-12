const std = @import("std");
const print = std.debug.print;

pub const Packet = struct {
    src: []const u8,
    dst: []const u8,
    payload: []const u8,
    length: u32,
    checksum: u16,
    flag: c_short,
};
