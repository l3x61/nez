// TODO: consider cycles
// https://www.nesdev.org/wiki/CPU
const Cpu = @This();

const std = @import("std");
const mem = std.mem;

const Nes = @import("Nes.zig");

const gui = @import("zgui");

regs: Registers = undefined,
nes: *Nes = undefined,
window_name: [:0]const u8 = "CPU"[0.. :0],

// https://www.nesdev.org/wiki/CPU_registers
const Registers = struct {
    A: u8, // accumulator
    X: u8, // x register
    Y: u8, // y register
    PC: u16, // program counter (in reality two registers PCH and PCL)
    S: u8, // stack pointer
    P: StatusRegister,
    IR: u8, // instruction register

    // https://www.nesdev.org/wiki/CPU_power_up_state
    fn powerUp(self: *@This()) void {
        self.A = 0;
        self.X = 0;
        self.Y = 0;
        self.PC = 0xFFFC;
        self.S = 0xFD;
        self.P.powerUp();
    }

    fn reset(self: *@This()) void {
        self.PC = 0xFFFC;
        self.S -%= 3;
        self.P.reset();
    }
};
// https://www.nesdev.org/wiki/Status_flags
const StatusRegister = packed struct {
    C: u1, // carry
    Z: u1, // zero
    I: u1, // interrupt disable
    D: u1, // decimal (no supported on NES)
    B: u1, // break (not a real flag)
    _: u1, // unused - always 1
    V: u1, // overflow
    N: u1, // negative

    // https://www.nesdev.org/wiki/CPU_power_up_state
    fn powerUp(self: *@This()) void {
        self.C = 0;
        self.Z = 0;
        self.I = 1;
        self.D = 0;
        self.B = 1; // according to http://visual6502.org/JSSim/
        self._ = 1; // always 1
        self.V = 0;
        self.N = 0;
    }

    fn reset(self: *@This()) void {
        self.I = 1;
        self.B = 1; // according to http://visual6502.org/JSSim/
        self._ = 1; // always 1
    }

    pub fn format(self: @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("{s}{s}{s}{s}{s}{s}{s}{s}", .{
            if (self.N == 1) "N" else ".",
            if (self.V == 1) "V" else ".",
            if (self._ == 1) "-" else ".",
            if (self.B == 1) "B" else ".",
            if (self.D == 1) "D" else ".",
            if (self.I == 1) "I" else ".",
            if (self.Z == 1) "Z" else ".",
            if (self.C == 1) "C" else ".",
        });
    }
};

pub fn init(nes: *Nes) Cpu {
    var self = Cpu{};
    self.regs.powerUp();
    std.crypto.random.bytes(mem.asBytes(&self.regs));
    self.nes = nes;
    return self;
}

pub fn write(self: @This(), address: u16, data: u8) void {
    self.nes.write(address, data);
}

pub fn read(self: @This(), address: u16) u8 {
    return self.nes.read(address);
}

pub fn powerUp(self: *@This()) void {
    self.regs.powerUp();
}

pub fn interrupt_request(self: *@This()) void {
    _ = self;
}

pub fn non_maskable_interrupt(self: *@This()) void {
    _ = self;
}

pub fn reset(self: *@This()) void {
    self.regs.reset();
}

pub fn update(self: *@This()) void {
    self.fetch();
}

pub fn draw(self: @This()) void {
    _ = gui.begin(self.window_name, .{});
    gui.text("A:  {x:0<2}", .{self.regs.A});
    gui.text("X:  {x:0<2}", .{self.regs.X});
    gui.text("Y:  {x:0<2}", .{self.regs.Y});
    gui.text("PC: {x:0<4}", .{self.regs.PC});
    gui.text("S:  {x:0<2}", .{self.regs.S});
    gui.text("P:  {s}", .{self.regs.P});
    gui.end();
}

pub fn fetch(self: *@This()) void {
    self.regs.IR = self.read(self.regs.PC);
    self.regs.PC += 1;
}
