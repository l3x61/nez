//! NES 2.0 file format (backwards compatible with iNES)
//! https://www.nesdev.org/wiki/NES_2.0
//!
//! TODO:
//! misc rom is not implemented https://www.nesdev.org/wiki/NES_2.0#Miscellaneous_ROM_Area

const Nes2 = @This();

const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const math = std.math;
const Allocator = std.mem.Allocator;

const header_size = 16;
const header_magic = "NES\x1A";
const trainer_size = 512;
const prg_rom_bank_size = 16384;
const chr_rom_bank_size = 8192;

const Error = error{
    FileFormatNotSupported,
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
        },
    },
    flags_13: union {
        vs: packed struct {
            ppu_kind: u4,
            hardware_kind: u4,
        },
        ext: packed struct {
            kind: u4,
            _: u4,
        },
    },
    flags_14: packed struct {
        misc_roms: u2,
        _: u6,
    },
    flags_15: packed struct {
        default_expansion_device: u6,
        _: u2,
    },

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
header: Header = undefined,
trainer: []u8 = undefined,
prg_rom: []u8 = undefined,
chr_rom: []u8 = undefined,

pub fn init(allocator: Allocator, path: []const u8) !Nes2 {
    const file = try fs.cwd().openFile(path, .{});
    defer file.close();

    var self = Nes2{};

    self.allocator = allocator;

    // header
    _ = try file.read(mem.asBytes(&self.header));
    if (!self.header.checkMagic()) {
        return error.NesFileInvalidHeader;
    }

    // trainer
    if (self.header.hasTrainer()) {
        self.trainer = try allocator.alloc(u8, trainer_size);
        _ = try file.read(self.trainer);
    }

    // prg_rom
    self.prg_rom = try allocator.alloc(u8, self.header.prgRomSize());
    _ = try file.read(self.prg_rom);

    // chr_rom
    self.chr_rom = try allocator.alloc(u8, self.header.chrRomSize());
    _ = try file.read(self.chr_rom);

    // TODO: misc rom
    return self;
}

pub fn deinit(self: *Nes2) void {
    self.allocator.free(self.trainer);
    self.allocator.free(self.prg_rom);
    self.allocator.free(self.chr_rom);
}
