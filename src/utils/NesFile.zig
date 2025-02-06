//! NES 2.0 file format (backwards compatible with iNES)
//! https://www.nesdev.org/wiki/NES_2.0
//!
//! TODO
//! - misc ROM is not implemented https://www.nesdev.org/wiki/NES_2.0#Miscellaneous_ROM_Area

const NesFile = @This();

const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const math = std.math;

const header_size = 16;
const header_magic = "NES\x1A";
const trainer_size = 512;
const prg_rom_bank_size = 16 * 1024;
const chr_rom_bank_size = 8 * 1024;

const gui = @import("zgui");
const HexView = @import("HexView.zig");

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
    identifier: [4]u8,
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
    flags_14: packed struct {
        misc_roms: u2,
        _: u6,
    },
    flags_15: packed struct {
        default_expansion_device: u6,
        _: u2,
    },

    pub fn init(slice: *const [header_size]u8) Header {
        const header: *Header = @ptrCast(@constCast(slice));
        return header.*;
    }

    /// assumes header starts with the correct identifier
    pub fn getFormat(self: Header) Format {
        return switch (self.flags_7.nes2_identifier) {
            2 => .nes2,
            else => .ines,
        };
    }

    pub fn checkIdentifier(self: Header) bool {
        return mem.eql(u8, header_magic, &self.identifier);
    }

    pub fn hasTrainer(self: Header) bool {
        return self.flags_6.trainer == 1;
    }

    pub fn prgRomSize(self: Header) usize {
        return xxxRomSize(self.flags_9.prg_rom_size_msb, self.prg_rom_size_lsb, prg_rom_bank_size);
    }

    pub fn chrRomSize(self: Header) usize {
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

header: Header = undefined,
format: Format = undefined,
trainer: []u8 = undefined,
prg_rom: []u8 = undefined,
chr_rom: []u8 = undefined,

pub fn init(slice: []const u8) !NesFile {
    var offset: usize = 0;

    const header = Header.init(slice[0..header_size]);
    offset += header_size;

    if (!header.checkIdentifier()) {
        return Error.FileFormatNotSupported;
    }

    const format = header.getFormat();

    var trainer: []u8 = &.{};
    if (header.hasTrainer()) {
        trainer = @constCast(slice[offset .. offset + trainer_size]);
        offset += trainer_size;
    }

    const prg_rom_size = header.prgRomSize();
    const prg_rom = @constCast(slice[offset .. offset + prg_rom_size]);
    offset += prg_rom_size;

    const chr_rom_size = header.chrRomSize();
    const chr_rom = @constCast(slice[offset .. offset + chr_rom_size]);
    offset += chr_rom_size;

    // TODO: misc rom

    return NesFile{
        .header = header,
        .format = format,
        .trainer = trainer,
        .prg_rom = prg_rom,
        .chr_rom = chr_rom,
    };
}

pub fn draw(self: NesFile) void {
    if (gui.beginChild("ROM", .{})) {
        gui.text("File Format: {s}", .{self.format});

        gui.separator();

        gui.text("Console Type: {s}", .{self.header.flags_7.console_type});
        gui.text("Timing Mode: {s}", .{self.header.flags_12.timing_mode});

        gui.separator();

        gui.text("Trainer Size: {d} bytes", .{self.trainer.len});
        if (gui.collapsingHeader("Trainer", .{})) {
            HexView.draw("Trainer Memory", self.trainer);
        }

        gui.separator();

        gui.text("PRG ROM Size: {d} bytes", .{self.prg_rom.len});
        if (gui.collapsingHeader("PRG ROM", .{})) {
            HexView.draw("PRG ROM Memory", self.prg_rom);
        }

        gui.separator();

        gui.text("CHR ROM Size: {d} bytes", .{self.chr_rom.len});
        if (gui.collapsingHeader("CHR ROM", .{})) {
            HexView.draw("CHR ROM Memory", self.chr_rom);
        }
    }
    gui.endChild();
}
