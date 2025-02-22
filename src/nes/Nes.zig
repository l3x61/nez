const Nes = @This();
const std = @import("std");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.nes);

const gui = @import("zgui");
pub const window_name: [:0]const u8 = "NES"[0.. :0];

const Cartridge = @import("Cartridge.zig");
const Cpu = @import("Cpu.zig");
const Ram = @import("Ram.zig");

allocator: Allocator = undefined,
cartridge: Cartridge = undefined,
cpu: Cpu = undefined,
ram: Ram = undefined,
power: bool = false,
first: bool = true,
run: bool = false,
steps: usize = 0,

pub fn init(allocator: Allocator) Nes {
    log.debug("init", .{});
    var self = Nes{};
    self.allocator = allocator;
    self.cartridge = Cartridge.init(allocator);
    self.cpu = Cpu.init(&self);
    self.ram = Ram.init(allocator);
    return self;
}

pub fn deinit(self: *Nes) void {
    log.debug("deinit", .{});
    self.cartridge.deinit();
}

// https://www.nesdev.org/wiki/CPU_memory_map

pub fn write(self: Nes, address: u16, data: u8) void {
    switch (address) {
        0x0000...0x1FFF => self.ram.write(address, data),
        else => unreachable,
    }
}

pub fn read(self: Nes, address: u16) u8 {
    return switch (address) {
        0x0000...0x1FFF => self.ram.read(address),
        else => unreachable,
    };
}

pub fn update(self: *Nes) void {
    if (!self.run and self.steps == 0) {
        return;
    }

    log.debug("update", .{});
    _ = self.cpu.update();
    if (self.steps > 0) {
        self.steps -= 1;
    }
}

pub fn draw(self: *Nes, dockspace_id: u32) !void {
    if (self.first) {
        self.first = false;
        gui.dockBuilderRemoveNode(dockspace_id);
        _ = gui.dockBuilderAddNode(dockspace_id, .{ .dock_space = true });

        const viewport_size = gui.getMainViewport().getSize();
        gui.dockBuilderSetNodeSize(dockspace_id, viewport_size);

        var dock_left: gui.Ident = undefined;
        var dock_right: gui.Ident = undefined;
        _ = gui.dockBuilderSplitNode(dockspace_id, .left, 0.5, &dock_left, &dock_right);

        gui.dockBuilderDockWindow(Nes.window_name, dock_left);
        gui.dockBuilderDockWindow(Cartridge.window_name, dock_right);
        gui.dockBuilderDockWindow(Ram.window_name, dock_right);
        gui.dockBuilderDockWindow(Cpu.window_name, dock_right);

        gui.dockBuilderFinish(dockspace_id);
    }

    try self.drawSelf();
    try self.cartridge.draw();
    self.cpu.draw();
    try self.ram.draw();
}

pub fn drawSelf(self: *Nes) !void {
    _ = gui.begin(Nes.window_name, .{});

    if (!self.cartridge.loaded) {
        if (gui.button("Insert Cartridge", .{})) {
            try self.cartridge.insert();
        }
    } else {
        if (gui.button("Remove Cartridge", .{})) {
            self.cartridge.remove();
            gui.end();
            return;
        }
    }

    if (gui.button("Power", .{})) {
        self.power = !self.power;
    }

    gui.sameLine(.{});

    gui.beginDisabled(.{ .disabled = !self.power });
    if (gui.button("Reset", .{})) {}
    gui.endDisabled();

    gui.separator();

    gui.beginDisabled(.{ .disabled = !self.power and self.run });
    if (gui.button("Run", .{})) {
        self.run = true;
        self.steps = 0;
    }
    gui.endDisabled();

    gui.sameLine(.{});

    gui.beginDisabled(.{ .disabled = !self.power and !self.run });
    if (gui.button("Stop", .{})) {
        self.run = false;
        self.steps = 0;
    }
    gui.endDisabled();

    gui.sameLine(.{});

    if (gui.button("Step", .{})) {
        self.run = false;
        self.steps = 1;
    }

    gui.end();
}
