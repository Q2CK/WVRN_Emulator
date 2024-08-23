const std = @import("std");

const registers = @import("registers.zig");
const Registers = registers.Registers;
const memory = @import("memory.zig");
const Memory = memory.Memory;
const instruction = @import("instruction.zig");
const Instruction = instruction.Instruction;

const Result = @import("../result.zig").Result;
const Status = @import("../cpu_status.zig").Status;

const bin_ops = @import("bin_ops.zig");

pub const CPU = struct {
    const Self = @This();

    status: Status,

    program_counter: u16,
    registers: Registers,
    memory: Memory,

    pub fn init() Self {
        return Self {
            .status = .Halt,
            .program_counter = 0,
            .registers = Registers.init(),
            .memory = Memory.init()
        };
    }

    pub fn reset(self: *Self) void {
        self.status = .Halt;
        self.program_counter = 0;
        self.registers.reset();
    }

    pub fn tick(self: *Self) void {
        const instr_byte = self.memory.get(self.program_counter);

        const instr: Instruction = @bitCast(instr_byte);

        switch(instr.opcode) {
            .EXT  => self.instrExt(instr.operand5bit),
            .SWA  => self.instrSwa(instr.operand5bit),
            .ADD  => self.instrAdd(instr.operand5bit),
            .ADDI => self.instrAddi(instr.operand5bit),
            .NAND => self.instrNand(instr.operand5bit),
            .LD   => self.instrLd(instr.operand5bit),
            .ST   => self.instrSt(instr.operand5bit),
            .B    => self.instrB(instr.operand5bit),
        }
    }

    pub fn nTicks(self: *Self, n: usize) void {
        for(0..n) |_| {
            self.tick();
        }
    }

    pub fn setQuery(self: *Self, query: []const u8, value: usize) Result {
        _ = self;
        _ = query;
        _ = value;
    }

    pub fn getQuery(self: *Self, query: []const u8, buffer: *std.ArrayList(u8)) Result {
        _ = self;
        _ = query;
        _ = buffer;
    }

    fn instrExt(self: *Self, operand: u5) void {
        if(operand == 1) {
            self.status = .Pause;
            self.program_counter += 1;
        } else {
            self.status = .Halt;
        }
    }

    fn instrSwa(self: *Self, operand: u5) void {
        const temp = self.registers.get(operand);
        self.registers.set(operand, self.registers.accumulator);
        self.registers.accumulator = temp;

        self.registers.flags.flags.parity = @truncate(self.registers.accumulator);
        self.registers.flags.flags.not_zero = if(self.registers.accumulator == 0) 0 else 1;
        self.registers.flags.flags.sign = @truncate(self.registers.accumulator >> 7);
        self.registers.flags.flags.carry = 0;
        self.registers.flags.flags.overflow = 0;

        self.program_counter += 1;
    }

    fn instrAdd(self: *Self, operand: u5) void {
        bin_ops.addWithFlags(
            self.registers.accumulator,
            self.registers.get(operand),
            &self.registers.accumulator, 
            &self.registers.flags
        );

        self.program_counter += 1;
    }

    fn instrAddi(self: *Self, operand: u5) void {
        bin_ops.addWithFlags(
            self.registers.accumulator,
            bin_ops.signExtendu5u8(operand),
            &self.registers.accumulator, 
            &self.registers.flags
        );

        self.program_counter += 1;
    }

    fn instrNand(self: *Self, operand: u5) void {
        const carry = self.registers.flags.flags.carry;
        bin_ops.nandWithFlags(
            self.registers.accumulator + @as(u8, carry),
            self.registers.get(operand),
            &self.registers.accumulator, 
            &self.registers.flags
        );

        self.program_counter += 1;
    }


    fn instrLd(self: *Self, operand: u5) void {
        const address = ((@as(u16, self.registers.segment) << 8) | @as(u16, self.registers.get(operand)));

        const mem_value = self.memory.get(address);
        
        self.registers.flags.flags.carry = 0;
        self.registers.flags.flags.overflow = 0;
        self.registers.flags.flags.not_zero = if(mem_value == 0) 0 else 1;
        self.registers.flags.flags.parity = @truncate(mem_value);
        self.registers.flags.flags.sign = @truncate(mem_value >> 7);

        self.program_counter += 2;
    }

    fn instrSt(self: *Self, operand: u5) void {
        const address = ((@as(u16, self.registers.segment) << 8) | @as(u16, self.registers.get(operand)));

        self.memory.set(address, self.registers.accumulator);

        self.program_counter += 2;
    }

    fn instrB(self: *Self, operand: u5) void {
        const flags = self.registers.flags.flags;

        const condition_met: bool = switch(operand) {
            0b00000 => false,
            0b00001 => true,
            0b00010 => flags.a == 0,
            0b00011 => flags.a == 1,
            0b00100 => flags.b == 0,
            0b00101 => flags.b == 1,
            0b00110 => flags.parity == 0,
            0b00111 => flags.parity == 1,
            0b01000 => flags.not_zero == 0,
            0b01001 => flags.not_zero == 1,
            0b01010 => flags.sign == 0,
            0b01011 => flags.sign == 1,
            0b01100 => flags.carry == 0,
            0b01101 => flags.carry == 1,
            0b01110 => flags.overflow == 0,
            0b01111 => flags.overflow == 1,
            else => false
        };

        if(condition_met) {
             self.program_counter = ((@as(u16, self.registers.segment) << 8) | (@as(u16, self.registers.get(operand))));
        } else {
            self.program_counter += 1;
        }
    }
};