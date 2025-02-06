const Nes = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;

const Cartridge = @import("Cartridge.zig");
const Sram = @import("Sram.zig");

cartridge: Cartridge,
sram: Sram,

pub fn init(allocator: Allocator) Nes {
    return Nes{ .cartridge = Cartridge.init(allocator), .sram = Sram.init(std.crypto.random) };
}

pub fn deinit(self: *Nes) void {
    self.cartridge.deinit();
}

pub fn draw(self: *Nes) !void {
    try self.cartridge.draw();
    self.sram.draw();
}
