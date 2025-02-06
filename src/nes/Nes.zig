const Nes = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;

const Cartridge = @import("Cartridge.zig");

cartridge: Cartridge,

pub fn init(allocator: Allocator) Nes {
    return Nes{
        .cartridge = Cartridge.init(allocator),
    };
}

pub fn deinit(self: *Nes) void {
    self.cartridge.deinit();
}
