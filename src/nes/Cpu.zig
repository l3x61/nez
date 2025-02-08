// https://www.nesdev.org/wiki/CPU
const Cpu = @This();

const std = @import("std");
const mem = std.mem;

const Nes = @import("Nes.zig");

const gui = @import("zgui");

registers: Registers = undefined,
nes: *Nes = undefined,
window_name: [:0]const u8 = "CPU"[0.. :0],

// https://www.nesdev.org/wiki/CPU_registers
const Registers = struct {
    A: u8,
    X: u8,
    Y: u8,
    PC: u16,
    S: u8,
    P: StatusRegister,

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
    C: u1,
    Z: u1,
    I: u1,
    D: u1,
    B: u1,
    _: u1, // always 1
    V: u1,
    N: u1,

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
};

pub fn init(nes: *Nes) Cpu {
    var self = Cpu{};
    self.registers.powerUp();
    std.crypto.random.bytes(mem.asBytes(&self.registers));
    self.nes = nes;
    return self;
}

pub fn write(self: @This(), address: u16, data: u8) void {
    self.nes.write(address, data);
}

pub fn read(self: @This(), address: u16) u8 {
    return self.nes.read(address);
}

pub fn draw(self: @This()) void {
    _ = gui.begin(self.window_name, .{});
    gui.text("A:  {x:0<2}", .{self.registers.A});
    gui.text("X:  {x:0<2}", .{self.registers.X});
    gui.text("Y:  {x:0<2}", .{self.registers.Y});
    gui.text("PC: {x:0<4}", .{self.registers.PC});
    gui.text("S:  {x:0<2}", .{self.registers.S});
    gui.end();
}

pub fn powerUp(self: *@This()) void {
    self.registers.powerUp();
}

pub fn reset(self: *@This()) void {
    self.registers.reset();
}
