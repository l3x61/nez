//! NES 2.0 file format (backwards compatible with iNES)
//! https://www.nesdev.org/wiki/NES_2.0
//!
//! TODO:
//!     - misc ROM is not implemented https://www.nesdev.org/wiki/NES_2.0#Miscellaneous_ROM_Area

const NesFile = @This();

const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const math = std.math;
const Allocator = std.mem.Allocator;

const header_size = 16;
const header_magic = "NES\x1A";
const trainer_size = 512;
const prg_rom_bank_size = 16 * 1024;
const chr_rom_bank_size = 8 * 1024;

const Error = error{
    FileFormatNotSupported,
};

const Format = enum {
    ines,
    nes2,

    pub fn format(self: @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("{s}", .{
            switch (self) {
                .ines => "iNES",
                .nes2 => "NES 2.0",
            },
        });
    }
};

const Header = struct {
    magic: [4]u8,
    prg_rom_size_lsb: u8,
    chr_rom_size_lsb: u8,
    flags_6: packed struct {
        nametable_layout: u1,
        battery: u1,
        trainer: u1,
        alternative_nametable: u1,
        mapper_lsb: u4,
    },
    flags_7: packed struct {
        console_type: enum(u2) {
            nes = 0,
            vs_system = 1,
            playchoice_10 = 2,
            extended_console_type = 3,

            pub fn format(self: @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
                _ = fmt;
                _ = options;
                try writer.print("{s}", .{
                    switch (self) {
                        .nes => "NES/Famicom",
                        .vs_system => "Nintendo Vs. System",
                        .playchoice_10 => "Nintendo Playchoice 10",
                        .extended_console_type => "Extended Console Type",
                    },
                });
            }
        },
        nes2_identifier: u2,
        mapper_mid: u4,
    },
    flags_8: packed struct {
        mapper_msb: u4,
        submapper: u4,
    },
    flags_9: packed struct {
        prg_rom_size_msb: u4,
        chr_rom_size_msb: u4,
    },
    flags_10: packed struct {
        prg_ram_size: u4,
        prg_nvram_size: u4,
    },
    flags_11: packed struct {
        chr_ram_size: u4,
        chr_nvram_size: u4,
    },
    flags_12: packed struct {
        timing_mode: enum(u2) {
            ntsc = 0,
            pal = 1,
            multi_region = 2,
            dendy = 3,

            pub fn format(self: @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
                _ = fmt;
                _ = options;
                try writer.print("{s}", .{
                    switch (self) {
                        .ntsc => "RP2C02 NTSC NES",
                        .pal => "RP2C07 Licensed PAL NES",
                        .multi_region => "Multiple-region",
                        .dendy => "UA6538 Dendy",
                    },
                });
            }
        },
        unused: u6,
    },
    flags_13: packed struct {
        ppu_kind: u4,
        hardware_kind: u4,
    },
    //    flags_13: union {
    //        vs: packed struct {
    //            ppu_kind: u4,
    //            hardware_kind: u4,
    //        },
    //        ext: packed struct {
    //            kind: u4,
    //            _: u4,
    //        },
    //    },
    flags_14: packed struct {
        misc_roms: u2,
        _: u6,
    },
    flags_15: packed struct {
        default_expansion_device: u6,
        _: u2,
    },

    /// assumes header starts with the correct MAGIC
    pub fn getFormat(self: *Header) Format {
        return switch (self.flags_7.nes2_identifier) {
            2 => .nes2,
            else => .ines,
        };
    }

    pub fn checkMagic(self: *Header) bool {
        return mem.eql(u8, header_magic, &self.magic);
    }

    pub fn hasTrainer(self: *Header) bool {
        return self.flags_6.trainer == 1;
    }

    pub fn prgRomSize(self: *Header) usize {
        return xxxRomSize(self.flags_9.prg_rom_size_msb, self.prg_rom_size_lsb, prg_rom_bank_size);
    }

    pub fn chrRomSize(self: *Header) usize {
        return xxxRomSize(self.flags_9.chr_rom_size_msb, self.chr_rom_size_lsb, chr_rom_bank_size);
    }

    fn xxxRomSize(msb: usize, lsb: usize, unit_multiplier: usize) usize {
        const nibble = @as(u4, @truncate(msb));
        switch (nibble) {
            0x0...0xE => {
                return ((msb << 8) | lsb) * unit_multiplier;
            },
            0xF => {
                const multiplier: usize = lsb & 0b0011;
                const exponent: usize = (lsb >> 2) & 0b0011_1111;
                return math.pow(usize, 2, exponent) * (multiplier * 2 + 1);
            },
        }
    }

    test "header size" {
        try std.testing.expectEqual(header_size, @sizeOf(@This()));
    }
};

allocator: Allocator = undefined,
filepath: []u8 = undefined,
header: Header = undefined,
format: Format = undefined,
trainer: []u8 = undefined,
prg_rom: []u8 = undefined,
chr_rom: []u8 = undefined,

/// opens a file relative to fs.cwd()
pub fn init(allocator: Allocator, filename: []const u8) !NesFile {
    const file = try fs.cwd().openFile(filename, .{});
    defer file.close();

    var self: NesFile = undefined;

    self.allocator = allocator;

    self.filepath = try fs.realpathAlloc(allocator, filename);

    // header
    _ = try file.read(mem.asBytes(&self.header));
    if (!self.header.checkMagic()) {
        return error.NesFileInvalidHeader;
    }

    self.format = self.header.getFormat();

    // trainer
    self.trainer = try allocator.alloc(u8, if (self.header.hasTrainer()) trainer_size else 0);
    _ = try file.read(self.trainer);

    // prg_rom
    self.prg_rom = try allocator.alloc(u8, self.header.prgRomSize());
    _ = try file.read(self.prg_rom);

    // chr_rom
    self.chr_rom = try allocator.alloc(u8, self.header.chrRomSize());
    _ = try file.read(self.chr_rom);

    // TODO: misc rom
    return self;
}

pub fn deinit(self: *NesFile) void {
    self.allocator.free(self.filepath);
    self.allocator.free(self.trainer);
    self.allocator.free(self.prg_rom);
    self.allocator.free(self.chr_rom);
}

const gui = @import("zgui");

pub fn draw(self: *NesFile) void {
    if (gui.begin("NES File", .{})) {
        defer gui.end();

        if (gui.collapsingHeader("Information", .{ .default_open = true })) {
            if (gui.beginTable("Table##Information", .{ .column = 2, .flags = .{ .resizable = true } })) {
                defer gui.endTable();

                gui.tableSetupColumn("Name", .{});
                gui.tableSetupColumn("Value", .{});

                // TODO: test on windows
                if (mem.lastIndexOf(u8, self.filepath, "/")) |idx| {
                    _ = gui.tableNextColumn();
                    gui.text("Name", .{});
                    _ = gui.tableNextColumn();
                    gui.text("{s}", .{self.filepath[idx + 1 ..]});

                    _ = gui.tableNextColumn();
                    gui.text("Path", .{});
                    _ = gui.tableNextColumn();
                    gui.text("{s}", .{self.filepath[0 .. idx + 1]});
                }

                _ = gui.tableNextColumn();
                gui.text("Format", .{});
                _ = gui.tableNextColumn();
                gui.text("{s}", .{self.format});

                _ = gui.tableNextColumn();
                gui.text("Trainer Area Size", .{});
                _ = gui.tableNextColumn();
                gui.text("{d} bytes", .{0});

                _ = gui.tableNextColumn();
                gui.text("PRG-ROM Size", .{});
                _ = gui.tableNextColumn();
                gui.text("{d} bytes", .{self.header.prgRomSize()});

                _ = gui.tableNextColumn();
                gui.text("CHR-ROM Size", .{});
                _ = gui.tableNextColumn();
                gui.text("{d} bytes", .{self.header.chrRomSize()});

                _ = gui.tableNextColumn();
                gui.text("Console Type", .{});
                _ = gui.tableNextColumn();
                gui.text("{s}", .{self.header.flags_7.console_type});

                _ = gui.tableNextColumn();
                gui.text("Timing Mode", .{});
                _ = gui.tableNextColumn();
                gui.text("{s}", .{self.header.flags_12.timing_mode});
            }
        }

        const header = mem.asBytes(&self.header);
        if (gui.collapsingHeader("Header", .{})) {
            if (gui.beginChild("HexTable##Header", .{
                .child_flags = .{
                    .auto_resize_x = true,
                    .auto_resize_y = true,
                },
            })) {
                defer gui.endChild();
                drawHexTable(header);
            }
        }

        const trainer = self.trainer;
        if (gui.collapsingHeader("Trainer", .{})) {
            if (gui.beginChild("HexTable##Trainer", .{
                .child_flags = .{
                    .auto_resize_x = true,
                    .auto_resize_y = true,
                },
            })) {
                defer gui.endChild();
                drawHexTable(trainer);
            }
        }

        const prg_rom = self.prg_rom;
        if (gui.collapsingHeader("PRG ROM", .{})) {
            if (gui.beginChild("HexTable##PRG ROM", .{
                .child_flags = .{
                    .auto_resize_x = true,
                    .auto_resize_y = true,
                },
            })) {
                defer gui.endChild();
                drawHexTable(prg_rom);
            }
        }

        const chr_rom = self.chr_rom;
        if (gui.collapsingHeader("CHR ROM", .{})) {
            if (gui.beginChild("HexTable##CHR ROM", .{
                .child_flags = .{
                    .auto_resize_x = true,
                    .auto_resize_y = true,
                },
            })) {
                defer gui.endChild();
                drawHexTable(chr_rom);
            }
        }
    }
}

fn drawHexTable(bytes: []const u8) void {
    if (bytes.len == 0) {
        gui.text("empty", .{});
        return;
    }
    const hex_columns = 16;
    var address: usize = 0;

    for (0.., bytes) |i, byte| {
        if (i % hex_columns == 0) {
            if (i > 0) {
                gui.newLine();
            }
            gui.text("{x:0>8}:", .{address});
            gui.sameLine(.{});
            address += hex_columns;
        }
        if ((i % 8 == 0) and (i % hex_columns != 0)) {
            gui.text(" ", .{});
            gui.sameLine(.{});
        }
        gui.text("{x:0>2}", .{byte});
        gui.sameLine(.{});
    }
    gui.newLine();
}
