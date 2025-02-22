const Ram = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const gui = @import("zgui");
const HexView = @import("../utils/HexView.zig");

const size = 0x0800;
pub const window_name: [:0]const u8 = "RAM"[0.. :0];

allocator: Allocator,
bytes: [size]u8,

pub fn init(allocator: Allocator) Ram {
    return Ram{
        .allocator = allocator,
        .bytes = .{0} ** size,
    };
}

pub fn read(self: Ram, address: u16) u8 {
    return self.bytes[address % size];
}

pub fn write(self: *Ram, address: u16, value: u8) void {
    self.bytes[address % size] = value;
}

pub fn draw(self: Ram) !void {
    _ = gui.begin(Ram.window_name, .{});
    try HexView.draw("Trainer Memory", self.allocator, &self.bytes, -1);
    gui.end();
}
