const Cpu = @This();

const std = @import("std");

const Nes = @import("Nes.zig");

const u8max = std.math.maxInt(u8);

pub const window_name: [:0]const u8 = "CPU"[0.. :0];

const page_mask: u16 = 0xFF00;
const zeropage_mask: u16 = 0x00FF;

const P = packed struct {
    c: u1,
    z: u1,
    i: u1,
    d: u1,
    b: u1,
    _: u1,
    v: u1,
    n: u1,

    pub fn updateNZ(self: *P, value: u8) void {
        self.z = if (value == 0) 1 else 0;
        self.n = if (value & 0x80 != 0) 1 else 0;
    }
};

a: u8 = undefined,
x: u8 = undefined,
y: u8 = undefined,
p: P = undefined,
sp: u8 = undefined,
pc: u16 = undefined,
nes: *Nes = undefined,

pub fn init(nes: *Nes) Cpu {
    return Cpu{
        .a = 0,
        .x = 0,
        .y = 0,
        .p = P{
            .c = 0,
            .z = 0,
            .i = 0,
            .d = 0,
            .b = 0,
            ._ = 0,
            .v = 0,
            .n = 0,
        },
        .sp = 0xFD,
        .pc = 0,
        .nes = nes,
    };
}

pub fn update(self: *Cpu) Cycles {
    const opcode = self.read(self.pc);
    self.pc +%= 1;
    if (instruction_map[opcode]) |instruction| {
        const mode = instruction.mode;
        const operation = instruction.operation;
        const cycles = operation(self, mode);
        return cycles + instruction.cycles;
    }
    unreachable;
}

pub fn read(self: *Cpu, address: u16) u8 {
    _ = self;
    _ = address;
    unreachable;
}

pub fn write(self: *Cpu, address: u16, data: u8) void {
    _ = self;
    _ = address;
    _ = data;
    unreachable;
}

pub fn draw(self: *Cpu) void {
    const gui = @import("zgui");
    _ = gui.begin(Cpu.window_name, .{});
    gui.text("PC:{x:0<4}", .{self.pc});
    gui.text("A:{x:0<2}", .{self.a});
    gui.text("X:{x:0<2}", .{self.x});
    gui.text("Y:{x:0<2}", .{self.y});
    gui.end();
}

const Opcode = enum {
    adc,
    @"and",
    asl,
    bcc,
    bcs,
    beq,
    bit,
    bmi,
    bne,
    bpl,
    brk,
    bvc,
    bvs,
    clc,
    cld,
    cli,
    clv,
    cmp,
    cpx,
    cpy,
    dec,
    dex,
    dey,
    eor,
    inc,
    inx,
    iny,
    jmp,
    jsr,
    lda,
    ldx,
    ldy,
    lsr,
    nop,
    ora,
    pha,
    php,
    pla,
    plp,
    rol,
    ror,
    rti,
    rts,
    sbc,
    sec,
    sed,
    sei,
    sta,
    stx,
    sty,
    tax,
    tay,
    tsx,
    txa,
    txs,
    tya,

    pub fn format(self: Opcode, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("{s}", .{@tagName(self)});
    }
};

const AddressingMode = enum {
    implied,
    accumulator,
    immediate,
    zero_page,
    zero_page_x,
    zero_page_y,
    relative,
    absolute,
    absolute_x,
    absolute_y,
    indirect,
    indexed_indirect,
    indirect_indexed,
};

const AddressCycles = struct {
    address: u16,
    cycles: Cycles,
};

fn getAddressCycles(self: *Cpu, mode: AddressingMode) AddressCycles {
    switch (mode) {
        .immediate => {
            defer self.pc +%= 1;
            return .{
                .address = self.pc,
                .cycles = 0,
            };
        },
        .zero_page => {
            defer self.pc +%= 1;
            return .{
                .address = self.pc & zeropage_mask,
                .cycles = 0,
            };
        },
        .zero_page_x => {
            defer self.pc +%= 1;
            return .{
                .address = (self.pc +% self.x) & zeropage_mask,
                .cycles = 0,
            };
        },
        .zero_page_y => {
            defer self.pc +%= 1;
            return .{
                .address = (self.pc +% self.y) & zeropage_mask,
                .cycles = 0,
            };
        },
        .relative => {
            const offset: i8 = self.read(self.pc);
            self.pc +%= 1;
            const address = self.pc +% offset;
            const cycles = if (address & 0xFF00 != self.pc & 0xFF00) 1 else 0;
            return .{
                .address = address,
                .cycles = cycles,
            };
        },
        .absolute => {
            const ll: u16 = self.read(self.pc);
            const hh: u16 = self.read(self.pc + 1) << 8;
            self.pc +%= 2;
            return .{
                .address = hh | ll,
                .cycles = 0,
            };
        },
        .absolute_x => {
            const ll: u16 = self.read(self.pc);
            const hh: u16 = self.read(self.pc + 1) << 8;
            self.pc +%= 2;
            const address = hh | ll +% self.x;
            const cycles = if (address & 0xFF00 != hh) 1 else 0;
            return .{
                .address = address,
                .cycles = cycles,
            };
        },
        .absolute_y => {
            const ll: u16 = self.read(self.pc);
            const hh: u16 = self.read(self.pc + 1) << 8;
            self.pc +%= 2;
            const address = hh | ll +% self.y;
            const cycles = if (address & 0xFF00 != hh) 1 else 0;
            return .{
                .address = address,
                .cycles = cycles,
            };
        },
        .indirect => {
            var ll: u16 = self.read(self.pc);
            var hh: u16 = self.read(self.pc + 1) << 8;
            self.pc +%= 2;
            var address = hh | ll;

            ll = self.read(address);
            if (ll == 0xFF) {
                hh = self.read(address & page_mask) << 8;
            } else {
                hh = self.read(address + 1) << 8;
            }
            address = hh | ll;

            return .{
                .address = address,
                .cycles = 0,
            };
        },
        .indexed_indirect => {
            var index: u16 = self.read(self.pc);
            self.pc +%= 1;
            index += self.x;
            index &= zeropage_mask;

            const ll: u16 = self.read(index);
            const hh: u16 = self.read((index + 1) & zeropage_mask) << 8;

            return .{
                .address = hh | ll,
                .cycles = 0,
            };
        },
        .indirect_indexed => {
            unreachable;
        },
        else => unreachable,
    }
}

const Operation = struct {
    pub fn adc(self: *Cpu, mode: AddressingMode) Cycles {
        _ = self;
        _ = mode;
        return 0;
    }

    pub fn @"and"(self: *Cpu, mode: AddressingMode) Cycles {
        _ = self;
        _ = mode;
        return 0;
    }

    pub fn asl(self: *Cpu, mode: AddressingMode) Cycles {
        _ = self;
        _ = mode;
        return 0;
    }

    pub fn bcc(self: *Cpu, mode: AddressingMode) Cycles {
        _ = self;
        _ = mode;
        return 0;
    }

    pub fn bcs(self: *Cpu, mode: AddressingMode) Cycles {
        _ = self;
        _ = mode;
        return 0;
    }

    pub fn beq(self: *Cpu, mode: AddressingMode) Cycles {
        _ = self;
        _ = mode;
        return 0;
    }

    pub fn bit(self: *Cpu, mode: AddressingMode) Cycles {
        _ = self;
        _ = mode;
        return 0;
    }

    pub fn bmi(self: *Cpu, mode: AddressingMode) Cycles {
        _ = self;
        _ = mode;
        return 0;
    }

    pub fn bne(self: *Cpu, mode: AddressingMode) Cycles {
        _ = self;
        _ = mode;
        return 0;
    }

    pub fn bpl(self: *Cpu, mode: AddressingMode) Cycles {
        _ = self;
        _ = mode;
        return 0;
    }

    pub fn brk(self: *Cpu, mode: AddressingMode) Cycles {
        _ = self;
        _ = mode;
        return 0;
    }

    pub fn bvc(self: *Cpu, mode: AddressingMode) Cycles {
        _ = self;
        _ = mode;
        return 0;
    }

    pub fn bvs(self: *Cpu, mode: AddressingMode) Cycles {
        _ = self;
        _ = mode;
        return 0;
    }

    pub fn clc(self: *Cpu, _: AddressingMode) Cycles {
        self.p.c = 0;
        return 0;
    }

    pub fn cld(self: *Cpu, _: AddressingMode) Cycles {
        self.p.d = 0;
        return 0;
    }

    pub fn cli(self: *Cpu, _: AddressingMode) Cycles {
        self.p.i = 0;
        return 0;
    }

    pub fn clv(self: *Cpu, _: AddressingMode) Cycles {
        self.p.v = 0;
        return 0;
    }

    pub fn cmp(self: *Cpu, mode: AddressingMode) Cycles {
        _ = self;
        _ = mode;
        return 0;
    }

    pub fn cpx(self: *Cpu, mode: AddressingMode) Cycles {
        _ = self;
        _ = mode;
        return 0;
    }

    pub fn cpy(self: *Cpu, mode: AddressingMode) Cycles {
        _ = self;
        _ = mode;
        return 0;
    }

    pub fn dec(self: *Cpu, mode: AddressingMode) Cycles {
        _ = self;
        _ = mode;
        return 0;
    }

    pub fn dex(self: *Cpu, _: AddressingMode) Cycles {
        self.x -= 1;
        self.p.updateNZ(self.x);
        return 0;
    }

    pub fn dey(self: *Cpu, _: AddressingMode) Cycles {
        self.y -= 1;
        self.p.updateNZ(self.y);
        return 0;
    }

    pub fn eor(self: *Cpu, mode: AddressingMode) Cycles {
        _ = self;
        _ = mode;
        return 0;
    }

    pub fn inc(self: *Cpu, mode: AddressingMode) Cycles {
        _ = self;
        _ = mode;
        return 0;
    }

    pub fn inx(self: *Cpu, _: AddressingMode) Cycles {
        self.x += 1;
        self.p.updateNZ(self.x);
        return 0;
    }

    pub fn iny(self: *Cpu, _: AddressingMode) Cycles {
        self.y += 1;
        self.p.updateNZ(self.y);
        return 0;
    }

    pub fn jmp(self: *Cpu, mode: AddressingMode) Cycles {
        _ = self;
        _ = mode;
        return 0;
    }

    pub fn jsr(self: *Cpu, mode: AddressingMode) Cycles {
        _ = self;
        _ = mode;
        return 0;
    }

    pub fn lda(self: *Cpu, mode: AddressingMode) Cycles {
        _ = self;
        _ = mode;
        return 0;
    }

    pub fn ldx(self: *Cpu, mode: AddressingMode) Cycles {
        _ = self;
        _ = mode;
        return 0;
    }

    pub fn ldy(self: *Cpu, mode: AddressingMode) Cycles {
        _ = self;
        _ = mode;
        return 0;
    }

    pub fn lsr(self: *Cpu, mode: AddressingMode) Cycles {
        _ = self;
        _ = mode;
        return 0;
    }

    pub fn nop(_: *Cpu, _: AddressingMode) Cycles {
        return 0;
    }

    pub fn ora(self: *Cpu, mode: AddressingMode) Cycles {
        _ = self;
        _ = mode;
        return 0;
    }

    pub fn pha(self: *Cpu, mode: AddressingMode) Cycles {
        _ = self;
        _ = mode;
        return 0;
    }

    pub fn php(self: *Cpu, mode: AddressingMode) Cycles {
        _ = self;
        _ = mode;
        return 0;
    }

    pub fn pla(self: *Cpu, mode: AddressingMode) Cycles {
        _ = self;
        _ = mode;
        return 0;
    }

    pub fn plp(self: *Cpu, mode: AddressingMode) Cycles {
        _ = self;
        _ = mode;
        return 0;
    }

    pub fn rol(self: *Cpu, mode: AddressingMode) Cycles {
        _ = self;
        _ = mode;
        return 0;
    }

    pub fn ror(self: *Cpu, mode: AddressingMode) Cycles {
        _ = self;
        _ = mode;
        return 0;
    }

    pub fn rti(self: *Cpu, mode: AddressingMode) Cycles {
        _ = self;
        _ = mode;
        return 0;
    }

    pub fn rts(self: *Cpu, mode: AddressingMode) Cycles {
        _ = self;
        _ = mode;
        return 0;
    }

    pub fn sbc(self: *Cpu, mode: AddressingMode) Cycles {
        _ = self;
        _ = mode;
        return 0;
    }

    pub fn sec(self: *Cpu, _: AddressingMode) Cycles {
        self.p.c = 1;
        return 0;
    }

    pub fn sed(self: *Cpu, _: AddressingMode) Cycles {
        self.p.d = 1;
        return 0;
    }

    pub fn sei(self: *Cpu, _: AddressingMode) Cycles {
        self.p.i = 1;
        return 0;
    }

    pub fn sta(self: *Cpu, mode: AddressingMode) Cycles {
        _ = self;
        _ = mode;
        return 0;
    }

    pub fn stx(self: *Cpu, mode: AddressingMode) Cycles {
        _ = self;
        _ = mode;
        return 0;
    }

    pub fn sty(self: *Cpu, mode: AddressingMode) Cycles {
        _ = self;
        _ = mode;
        return 0;
    }

    pub fn tax(self: *Cpu, _: AddressingMode) Cycles {
        self.x = self.a;
        self.p.updateNZ(self.x);
        return 0;
    }

    pub fn tay(self: *Cpu, _: AddressingMode) Cycles {
        self.y = self.a;
        self.p.updateNZ(self.y);
        return 0;
    }

    pub fn tsx(self: *Cpu, _: AddressingMode) Cycles {
        self.x = self.sp;
        self.p.updateNZ(self.x);
        return 0;
    }

    pub fn txa(self: *Cpu, _: AddressingMode) Cycles {
        self.a = self.x;
        self.p.updateNZ(self.a);
        return 0;
    }

    pub fn txs(self: *Cpu, _: AddressingMode) Cycles {
        self.sp = self.x;
        return 0;
    }

    pub fn tya(self: *Cpu, _: AddressingMode) Cycles {
        self.a = self.y;
        self.p.updateNZ(self.a);
        return 0;
    }
};

const Cycles = u32;
const Instruction = struct {
    opcode: Opcode,
    mode: AddressingMode,
    operation: *const fn (*Cpu, AddressingMode) Cycles,
    cycles: Cycles,
};

const instruction_map = generateInstructionMap();
fn generateInstructionMap() [u8max]?Instruction {
    var map: [u8max]?Instruction = .{null} ** u8max;

    map[0x69] = Instruction{ .opcode = .adc, .mode = .immediate, .operation = Operation.adc, .cycles = 2 };
    map[0x65] = Instruction{ .opcode = .adc, .mode = .zero_page, .operation = Operation.adc, .cycles = 3 };
    map[0x75] = Instruction{ .opcode = .adc, .mode = .zero_page_x, .operation = Operation.adc, .cycles = 4 };
    map[0x6D] = Instruction{ .opcode = .adc, .mode = .absolute, .operation = Operation.adc, .cycles = 4 };
    map[0x7D] = Instruction{ .opcode = .adc, .mode = .absolute_x, .operation = Operation.adc, .cycles = 4 };
    map[0x79] = Instruction{ .opcode = .adc, .mode = .absolute_y, .operation = Operation.adc, .cycles = 4 };
    map[0x61] = Instruction{ .opcode = .adc, .mode = .indexed_indirect, .operation = Operation.adc, .cycles = 6 };
    map[0x71] = Instruction{ .opcode = .adc, .mode = .indirect_indexed, .operation = Operation.adc, .cycles = 5 };

    map[0x29] = Instruction{ .opcode = .@"and", .mode = .immediate, .operation = Operation.@"and", .cycles = 2 };
    map[0x25] = Instruction{ .opcode = .@"and", .mode = .zero_page, .operation = Operation.@"and", .cycles = 3 };
    map[0x35] = Instruction{ .opcode = .@"and", .mode = .zero_page_x, .operation = Operation.@"and", .cycles = 4 };
    map[0x2D] = Instruction{ .opcode = .@"and", .mode = .absolute, .operation = Operation.@"and", .cycles = 4 };
    map[0x3D] = Instruction{ .opcode = .@"and", .mode = .absolute_x, .operation = Operation.@"and", .cycles = 4 };
    map[0x39] = Instruction{ .opcode = .@"and", .mode = .absolute_y, .operation = Operation.@"and", .cycles = 4 };
    map[0x21] = Instruction{ .opcode = .@"and", .mode = .indexed_indirect, .operation = Operation.@"and", .cycles = 6 };
    map[0x31] = Instruction{ .opcode = .@"and", .mode = .indirect_indexed, .operation = Operation.@"and", .cycles = 5 };

    map[0x0A] = Instruction{ .opcode = .asl, .mode = .accumulator, .operation = Operation.asl, .cycles = 2 };
    map[0x06] = Instruction{ .opcode = .asl, .mode = .zero_page, .operation = Operation.asl, .cycles = 5 };
    map[0x16] = Instruction{ .opcode = .asl, .mode = .zero_page_x, .operation = Operation.asl, .cycles = 6 };
    map[0x0E] = Instruction{ .opcode = .asl, .mode = .absolute, .operation = Operation.asl, .cycles = 6 };
    map[0x1E] = Instruction{ .opcode = .asl, .mode = .absolute_x, .operation = Operation.asl, .cycles = 7 };

    map[0x90] = Instruction{ .opcode = .bcc, .mode = .relative, .operation = Operation.bcc, .cycles = 2 };

    map[0xB0] = Instruction{ .opcode = .bcs, .mode = .relative, .operation = Operation.bcs, .cycles = 2 };

    map[0xF0] = Instruction{ .opcode = .beq, .mode = .relative, .operation = Operation.beq, .cycles = 2 };

    map[0x24] = Instruction{ .opcode = .bit, .mode = .zero_page, .operation = Operation.bit, .cycles = 3 };

    map[0x30] = Instruction{ .opcode = .bmi, .mode = .relative, .operation = Operation.bmi, .cycles = 2 };

    map[0xD0] = Instruction{ .opcode = .bne, .mode = .relative, .operation = Operation.bne, .cycles = 2 };

    map[0x10] = Instruction{ .opcode = .bpl, .mode = .relative, .operation = Operation.bpl, .cycles = 2 };

    map[0x00] = Instruction{ .opcode = .brk, .mode = .implied, .operation = Operation.brk, .cycles = 7 };

    map[0x50] = Instruction{ .opcode = .bvc, .mode = .relative, .operation = Operation.bvc, .cycles = 2 };

    map[0x70] = Instruction{ .opcode = .bvs, .mode = .relative, .operation = Operation.bvs, .cycles = 2 };

    map[0x18] = Instruction{ .opcode = .clc, .mode = .implied, .operation = Operation.clc, .cycles = 2 };

    map[0xD8] = Instruction{ .opcode = .cld, .mode = .implied, .operation = Operation.cld, .cycles = 2 };

    map[0x58] = Instruction{ .opcode = .cli, .mode = .implied, .operation = Operation.cli, .cycles = 2 };

    map[0xB8] = Instruction{ .opcode = .clv, .mode = .implied, .operation = Operation.clv, .cycles = 2 };

    map[0xC9] = Instruction{ .opcode = .cmp, .mode = .immediate, .operation = Operation.cmp, .cycles = 2 };
    map[0xC5] = Instruction{ .opcode = .cmp, .mode = .zero_page, .operation = Operation.cmp, .cycles = 3 };
    map[0xD5] = Instruction{ .opcode = .cmp, .mode = .zero_page_x, .operation = Operation.cmp, .cycles = 4 };
    map[0xCD] = Instruction{ .opcode = .cmp, .mode = .absolute, .operation = Operation.cmp, .cycles = 4 };
    map[0xDD] = Instruction{ .opcode = .cmp, .mode = .absolute_x, .operation = Operation.cmp, .cycles = 4 };
    map[0xD9] = Instruction{ .opcode = .cmp, .mode = .absolute_y, .operation = Operation.cmp, .cycles = 4 };
    map[0xC1] = Instruction{ .opcode = .cmp, .mode = .indexed_indirect, .operation = Operation.cmp, .cycles = 6 };
    map[0xD1] = Instruction{ .opcode = .cmp, .mode = .indirect_indexed, .operation = Operation.cmp, .cycles = 5 };

    map[0xE0] = Instruction{ .opcode = .cpx, .mode = .immediate, .operation = Operation.cpx, .cycles = 2 };
    map[0xE4] = Instruction{ .opcode = .cpx, .mode = .zero_page, .operation = Operation.cpx, .cycles = 3 };
    map[0xEC] = Instruction{ .opcode = .cpx, .mode = .absolute, .operation = Operation.cpx, .cycles = 4 };

    map[0xC0] = Instruction{ .opcode = .cpy, .mode = .immediate, .operation = Operation.cpy, .cycles = 2 };
    map[0xC4] = Instruction{ .opcode = .cpy, .mode = .zero_page, .operation = Operation.cpy, .cycles = 3 };
    map[0xCC] = Instruction{ .opcode = .cpy, .mode = .absolute, .operation = Operation.cpy, .cycles = 4 };

    map[0xC6] = Instruction{ .opcode = .dec, .mode = .zero_page, .operation = Operation.dec, .cycles = 5 };
    map[0xD6] = Instruction{ .opcode = .dec, .mode = .zero_page_x, .operation = Operation.dec, .cycles = 6 };
    map[0xCE] = Instruction{ .opcode = .dec, .mode = .absolute, .operation = Operation.dec, .cycles = 6 };
    map[0xDE] = Instruction{ .opcode = .dec, .mode = .absolute_x, .operation = Operation.dec, .cycles = 7 };

    map[0xCA] = Instruction{ .opcode = .dex, .mode = .implied, .operation = Operation.dex, .cycles = 2 };

    map[0x88] = Instruction{ .opcode = .dey, .mode = .implied, .operation = Operation.dey, .cycles = 2 };

    map[0x49] = Instruction{ .opcode = .eor, .mode = .immediate, .operation = Operation.eor, .cycles = 2 };
    map[0x45] = Instruction{ .opcode = .eor, .mode = .zero_page, .operation = Operation.eor, .cycles = 3 };
    map[0x55] = Instruction{ .opcode = .eor, .mode = .zero_page_x, .operation = Operation.eor, .cycles = 4 };
    map[0x4D] = Instruction{ .opcode = .eor, .mode = .absolute, .operation = Operation.eor, .cycles = 4 };
    map[0x5D] = Instruction{ .opcode = .eor, .mode = .absolute_x, .operation = Operation.eor, .cycles = 4 };
    map[0x59] = Instruction{ .opcode = .eor, .mode = .absolute_y, .operation = Operation.eor, .cycles = 4 };
    map[0x41] = Instruction{ .opcode = .eor, .mode = .indexed_indirect, .operation = Operation.eor, .cycles = 6 };
    map[0x51] = Instruction{ .opcode = .eor, .mode = .indirect_indexed, .operation = Operation.eor, .cycles = 5 };

    map[0xE6] = Instruction{ .opcode = .inc, .mode = .zero_page, .operation = Operation.inc, .cycles = 5 };
    map[0xF6] = Instruction{ .opcode = .inc, .mode = .zero_page_x, .operation = Operation.inc, .cycles = 6 };
    map[0xEE] = Instruction{ .opcode = .inc, .mode = .absolute, .operation = Operation.inc, .cycles = 6 };
    map[0xFE] = Instruction{ .opcode = .inc, .mode = .absolute_x, .operation = Operation.inc, .cycles = 7 };

    map[0xE8] = Instruction{ .opcode = .inx, .mode = .implied, .operation = Operation.inx, .cycles = 2 };

    map[0xC8] = Instruction{ .opcode = .iny, .mode = .implied, .operation = Operation.iny, .cycles = 2 };

    map[0x4C] = Instruction{ .opcode = .jmp, .mode = .absolute, .operation = Operation.jmp, .cycles = 3 };
    map[0x6C] = Instruction{ .opcode = .jmp, .mode = .indirect, .operation = Operation.jmp, .cycles = 5 };

    map[0x20] = Instruction{ .opcode = .jsr, .mode = .absolute, .operation = Operation.jsr, .cycles = 6 };

    map[0xA9] = Instruction{ .opcode = .lda, .mode = .immediate, .operation = Operation.lda, .cycles = 2 };
    map[0xA5] = Instruction{ .opcode = .lda, .mode = .zero_page, .operation = Operation.lda, .cycles = 3 };
    map[0xB5] = Instruction{ .opcode = .lda, .mode = .zero_page_x, .operation = Operation.lda, .cycles = 4 };
    map[0xAD] = Instruction{ .opcode = .lda, .mode = .absolute, .operation = Operation.lda, .cycles = 4 };
    map[0xBD] = Instruction{ .opcode = .lda, .mode = .absolute_x, .operation = Operation.lda, .cycles = 4 };
    map[0xB9] = Instruction{ .opcode = .lda, .mode = .absolute_y, .operation = Operation.lda, .cycles = 4 };
    map[0xA1] = Instruction{ .opcode = .lda, .mode = .indexed_indirect, .operation = Operation.lda, .cycles = 6 };
    map[0xB1] = Instruction{ .opcode = .lda, .mode = .indirect_indexed, .operation = Operation.lda, .cycles = 5 };
    map[0xA2] = Instruction{ .opcode = .ldx, .mode = .immediate, .operation = Operation.ldx, .cycles = 2 };
    map[0xA6] = Instruction{ .opcode = .ldx, .mode = .zero_page, .operation = Operation.ldx, .cycles = 3 };
    map[0xB6] = Instruction{ .opcode = .ldx, .mode = .zero_page_y, .operation = Operation.ldx, .cycles = 4 };
    map[0xAE] = Instruction{ .opcode = .ldx, .mode = .absolute, .operation = Operation.ldx, .cycles = 4 };
    map[0xBE] = Instruction{ .opcode = .ldx, .mode = .absolute_y, .operation = Operation.ldx, .cycles = 4 };

    map[0xA0] = Instruction{ .opcode = .ldy, .mode = .immediate, .operation = Operation.ldy, .cycles = 2 };
    map[0xA4] = Instruction{ .opcode = .ldy, .mode = .zero_page, .operation = Operation.ldy, .cycles = 3 };
    map[0xB4] = Instruction{ .opcode = .ldy, .mode = .zero_page_x, .operation = Operation.ldy, .cycles = 4 };
    map[0xAC] = Instruction{ .opcode = .ldy, .mode = .absolute, .operation = Operation.ldy, .cycles = 4 };
    map[0xBC] = Instruction{ .opcode = .ldy, .mode = .absolute_x, .operation = Operation.ldy, .cycles = 4 };

    map[0x4A] = Instruction{ .opcode = .lsr, .mode = .accumulator, .operation = Operation.lsr, .cycles = 2 };
    map[0x46] = Instruction{ .opcode = .lsr, .mode = .zero_page, .operation = Operation.lsr, .cycles = 5 };
    map[0x56] = Instruction{ .opcode = .lsr, .mode = .zero_page_x, .operation = Operation.lsr, .cycles = 6 };
    map[0x4E] = Instruction{ .opcode = .lsr, .mode = .absolute, .operation = Operation.lsr, .cycles = 6 };
    map[0x5E] = Instruction{ .opcode = .lsr, .mode = .absolute_x, .operation = Operation.lsr, .cycles = 7 };

    map[0xEA] = Instruction{ .opcode = .nop, .mode = .implied, .operation = Operation.nop, .cycles = 2 };

    map[0x09] = Instruction{ .opcode = .ora, .mode = .immediate, .operation = Operation.ora, .cycles = 2 };
    map[0x05] = Instruction{ .opcode = .ora, .mode = .zero_page, .operation = Operation.ora, .cycles = 3 };
    map[0x15] = Instruction{ .opcode = .ora, .mode = .zero_page_x, .operation = Operation.ora, .cycles = 4 };
    map[0x0D] = Instruction{ .opcode = .ora, .mode = .absolute, .operation = Operation.ora, .cycles = 4 };
    map[0x1D] = Instruction{ .opcode = .ora, .mode = .absolute_x, .operation = Operation.ora, .cycles = 4 };
    map[0x19] = Instruction{ .opcode = .ora, .mode = .absolute_y, .operation = Operation.ora, .cycles = 4 };
    map[0x01] = Instruction{ .opcode = .ora, .mode = .indexed_indirect, .operation = Operation.ora, .cycles = 6 };
    map[0x11] = Instruction{ .opcode = .ora, .mode = .indirect_indexed, .operation = Operation.ora, .cycles = 5 };

    map[0x48] = Instruction{ .opcode = .pha, .mode = .implied, .operation = Operation.pha, .cycles = 3 };

    map[0x08] = Instruction{ .opcode = .php, .mode = .implied, .operation = Operation.php, .cycles = 3 };

    map[0x68] = Instruction{ .opcode = .pla, .mode = .implied, .operation = Operation.pla, .cycles = 4 };

    map[0x28] = Instruction{ .opcode = .plp, .mode = .implied, .operation = Operation.plp, .cycles = 4 };

    map[0x2A] = Instruction{ .opcode = .rol, .mode = .accumulator, .operation = Operation.rol, .cycles = 2 };
    map[0x26] = Instruction{ .opcode = .rol, .mode = .zero_page, .operation = Operation.rol, .cycles = 5 };
    map[0x36] = Instruction{ .opcode = .rol, .mode = .zero_page_x, .operation = Operation.rol, .cycles = 6 };
    map[0x2E] = Instruction{ .opcode = .rol, .mode = .absolute, .operation = Operation.rol, .cycles = 6 };
    map[0x3E] = Instruction{ .opcode = .rol, .mode = .absolute_x, .operation = Operation.rol, .cycles = 7 };

    map[0x6A] = Instruction{ .opcode = .ror, .mode = .accumulator, .operation = Operation.ror, .cycles = 2 };
    map[0x66] = Instruction{ .opcode = .ror, .mode = .zero_page, .operation = Operation.ror, .cycles = 5 };
    map[0x76] = Instruction{ .opcode = .ror, .mode = .zero_page_x, .operation = Operation.ror, .cycles = 6 };
    map[0x6E] = Instruction{ .opcode = .ror, .mode = .absolute, .operation = Operation.ror, .cycles = 6 };
    map[0x7E] = Instruction{ .opcode = .ror, .mode = .absolute_x, .operation = Operation.ror, .cycles = 7 };

    map[0x40] = Instruction{ .opcode = .rti, .mode = .implied, .operation = Operation.rti, .cycles = 6 };

    map[0x60] = Instruction{ .opcode = .rts, .mode = .implied, .operation = Operation.rts, .cycles = 6 };

    map[0xE9] = Instruction{ .opcode = .sbc, .mode = .immediate, .operation = Operation.sbc, .cycles = 2 };
    map[0xE5] = Instruction{ .opcode = .sbc, .mode = .zero_page, .operation = Operation.sbc, .cycles = 3 };
    map[0xF5] = Instruction{ .opcode = .sbc, .mode = .zero_page_x, .operation = Operation.sbc, .cycles = 4 };
    map[0xED] = Instruction{ .opcode = .sbc, .mode = .absolute, .operation = Operation.sbc, .cycles = 4 };
    map[0xFD] = Instruction{ .opcode = .sbc, .mode = .absolute_x, .operation = Operation.sbc, .cycles = 4 };
    map[0xF9] = Instruction{ .opcode = .sbc, .mode = .absolute_y, .operation = Operation.sbc, .cycles = 4 };
    map[0xE1] = Instruction{ .opcode = .sbc, .mode = .indexed_indirect, .operation = Operation.sbc, .cycles = 6 };
    map[0xF1] = Instruction{ .opcode = .sbc, .mode = .indirect_indexed, .operation = Operation.sbc, .cycles = 5 };

    map[0x38] = Instruction{ .opcode = .sec, .mode = .implied, .operation = Operation.sec, .cycles = 2 };

    map[0xF8] = Instruction{ .opcode = .sed, .mode = .implied, .operation = Operation.sed, .cycles = 2 };

    map[0x78] = Instruction{ .opcode = .sei, .mode = .implied, .operation = Operation.sei, .cycles = 2 };

    map[0x85] = Instruction{ .opcode = .sta, .mode = .zero_page, .operation = Operation.sta, .cycles = 3 };
    map[0x95] = Instruction{ .opcode = .sta, .mode = .zero_page_x, .operation = Operation.sta, .cycles = 4 };
    map[0x8D] = Instruction{ .opcode = .sta, .mode = .absolute, .operation = Operation.sta, .cycles = 4 };
    map[0x9D] = Instruction{ .opcode = .sta, .mode = .absolute_x, .operation = Operation.sta, .cycles = 5 };
    map[0x99] = Instruction{ .opcode = .sta, .mode = .absolute_y, .operation = Operation.sta, .cycles = 5 };
    map[0x81] = Instruction{ .opcode = .sta, .mode = .indexed_indirect, .operation = Operation.sta, .cycles = 6 };
    map[0x91] = Instruction{ .opcode = .sta, .mode = .indirect_indexed, .operation = Operation.sta, .cycles = 6 };

    map[0x86] = Instruction{ .opcode = .stx, .mode = .zero_page, .operation = Operation.stx, .cycles = 3 };
    map[0x96] = Instruction{ .opcode = .stx, .mode = .zero_page_y, .operation = Operation.stx, .cycles = 4 };
    map[0x8E] = Instruction{ .opcode = .stx, .mode = .absolute, .operation = Operation.stx, .cycles = 4 };

    map[0x84] = Instruction{ .opcode = .sty, .mode = .zero_page, .operation = Operation.sty, .cycles = 3 };
    map[0x94] = Instruction{ .opcode = .sty, .mode = .zero_page_x, .operation = Operation.sty, .cycles = 4 };
    map[0x8C] = Instruction{ .opcode = .sty, .mode = .absolute, .operation = Operation.sty, .cycles = 4 };

    map[0xAA] = Instruction{ .opcode = .tax, .mode = .implied, .operation = Operation.tax, .cycles = 2 };

    map[0xA8] = Instruction{ .opcode = .tay, .mode = .implied, .operation = Operation.tay, .cycles = 2 };

    map[0xBA] = Instruction{ .opcode = .tsx, .mode = .implied, .operation = Operation.tsx, .cycles = 2 };

    map[0x8A] = Instruction{ .opcode = .txa, .mode = .implied, .operation = Operation.txa, .cycles = 2 };

    map[0x9A] = Instruction{ .opcode = .txs, .mode = .implied, .operation = Operation.txs, .cycles = 2 };

    map[0x98] = Instruction{ .opcode = .tya, .mode = .implied, .operation = Operation.tya, .cycles = 2 };

    return map;
}
