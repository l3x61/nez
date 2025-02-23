// TODO: add a `search_path` that saves where the last ROM was

const Cartridge = @This();

const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const math = std.math;
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.cartridge);

const gui = @import("zgui");
const osd = @import("zosdialog");
const NesFile = @import("../utils/NesFile.zig");

pub const window_name: [:0]const u8 = "Cartridge"[0.. :0];

allocator: Allocator = undefined,
file_path: [:0]u8 = undefined,
file_name: []const u8 = undefined,
file_data: []u8 = undefined,
file_nes: NesFile = undefined, // fields  point to `file_data`
trainer: []u8 = undefined,
prg_rom: []u8 = undefined,
chr_rom: []u8 = undefined,
loaded: bool = false,
filters: osd.Filters = undefined,

pub fn init(allocator: Allocator) Cartridge {
    log.debug("init", .{});
    return Cartridge{
        .allocator = allocator,
        .filters = osd.Filters.init("NES ROM:NES,nes,ROM,rom;All Files:*"),
    };
}

pub fn deinit(self: *Cartridge) void {
    log.debug("deinit", .{});
    self.remove();
    self.filters.deinit();
}

pub fn insert(self: *Cartridge) !void {
    self.remove();
    log.info("insert", .{});
    if (try osd.file(self.allocator, .open, .{ .path = "./assets/roms/tests/cpu_reset", .filters = self.filters })) |file_path| {
        var file = try fs.openFileAbsoluteZ(file_path, .{});
        defer file.close();
        self.file_path = file_path;
        self.file_data = try file.readToEndAlloc(self.allocator, math.maxInt(u32));
        self.file_name = fs.path.basename(file_path)[0..]; //TODO: removes sentinel
        self.loaded = true;

        self.file_nes = NesFile.init(self.file_data) catch |err| {
            print("{!}\n", .{err}); // TODO: add a notification system and notify the user
            self.remove();
            return;
        };
        self.trainer = self.file_nes.trainer;
        self.prg_rom = self.file_nes.prg_rom;
        self.chr_rom = self.file_nes.chr_rom;
    }
}

pub fn remove(self: *Cartridge) void {
    if (!self.loaded) return;
    log.info("remove", .{});
    self.allocator.free(self.file_path);
    self.allocator.free(self.file_data);
    self.loaded = false;
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

pub fn draw(self: *Cartridge) !void {
    _ = gui.begin(Cartridge.window_name, .{});
    if (!self.loaded) {
        if (gui.button("Insert Cartridge", .{})) {
            try self.insert();
        }
    } else {
        if (gui.button("Remove Cartridge", .{})) {
            self.remove();
            gui.end();
            return;
        }
        if (gui.collapsingHeader("File Information", .{ .default_open = true })) {
            gui.text("File Name: {s}", .{self.file_name});
            gui.text("File Size: {d} bytes", .{self.file_data.len});

            gui.separator();

            try self.file_nes.draw(self.allocator);
        }
    }
    gui.end();
}
