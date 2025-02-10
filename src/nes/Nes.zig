const std = @import("std");
const Allocator = std.mem.Allocator;

const gui = @import("zgui");

const Cartridge = @import("Cartridge.zig");
const Cpu = @import("Cpu.zig");
window_name: [:0]const u8 = "NES"[0.. :0],

cartridge: Cartridge = undefined,
cpu: Cpu = undefined,
power: bool = false,
first: bool = true,

pub fn init(allocator: Allocator) @This() {
    var self = @This(){};
    self.cartridge = Cartridge.init(allocator);
    self.cpu = Cpu.init(&self);
    return self;
}

pub fn deinit(self: *@This()) void {
    self.cartridge.deinit();
}

pub fn write(self: @This(), address: u16, data: u8) void {
    _ = self;
    _ = address;
    _ = data;
    unreachable;
}

pub fn read(self: @This(), address: u16) u8 {
    _ = self;
    _ = address;
    unreachable;
}

pub fn update(self: *@This()) void {
    self.cpu.update();
}

pub fn draw(self: *@This(), dockspace_id: u32) !void {
    if (self.first) {
        self.first = false;
        gui.dockBuilderRemoveNode(dockspace_id);
        _ = gui.dockBuilderAddNode(dockspace_id, .{ .dock_space = true });

        gui.dockBuilderDockWindow(self.window_name, dockspace_id);
        gui.dockBuilderDockWindow(self.cartridge.window_name, dockspace_id);
        gui.dockBuilderDockWindow(self.cpu.window_name, dockspace_id);

        gui.dockBuilderSetNodeSize(dockspace_id, gui.getMainViewport().getSize());
        gui.dockBuilderFinish(dockspace_id);
    }

    try self.drawSelf();
    try self.cartridge.draw();
    self.cpu.draw();
}

pub fn drawSelf(self: *@This()) !void {
    _ = gui.begin(self.window_name, .{});
    if (gui.button("Power", .{})) {
        self.power = !self.power;
        self.cpu.powerUp();
    }
    gui.sameLine(.{});
    gui.beginDisabled(.{ .disabled = !self.power });
    if (gui.button("Reset", .{})) {
        self.cpu.reset();
    }
    gui.endDisabled();

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
    gui.end();
}
