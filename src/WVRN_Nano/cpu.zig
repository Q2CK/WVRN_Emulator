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
        const instr_byte1 = self.memory.get(self.program_counter);
        const instr_byte2 = self.memory.get(self.program_counter +% 1);

        const instr: Instruction = @bitCast([_]u8{instr_byte1, instr_byte2});

        switch(instr.opcode) {
            .EXT => self.instrExt(instr.operand4bit),
            .STA => self.instrSta(instr.operand4bit),
            .LDA => self.instrLda(instr.operand4bit),
            .ADD => self.instrAdd(instr.operand4bit),
            .SUB => self.instrSub(instr.operand4bit),
            .ADC => self.instrAdc(instr.operand4bit),
            .AND => self.instrAnd(instr.operand4bit),
            .NOR => self.instrNor(instr.operand4bit),
            .XOR => self.instrXor(instr.operand4bit),
            .BSH => self.instrBsh(instr.operand4bit),
            .LIM => self.instrLim(instr.operand4bit),
            .AIM => self.instrAim(instr.operand4bit),
            .MLD => self.instrMld(instr.operand4bit, instr.operand8bit),
            .MST => self.instrMst(instr.operand4bit, instr.operand8bit),
            .BRC => self.instrBrc(instr.operand4bit, instr.operand8bit),
            .JAL => self.instrJal(instr.operand4bit, instr.operand8bit)
        }
    }

    pub fn nTicks(self: *Self, n: usize) void {
        for(0..n) |_| {
            self.tick();
        }
    }

    pub fn getNextInstruction(self: Self, buffer: *std.ArrayList(u8)) Result {
        _ = self;
        _ = buffer;

        return Result.ok();
    }

    pub fn setQuery(self: *Self, query: []const[]const u8) Result {
        _ = self;
        _ = query;

        return Result.ok();
    }

    pub fn getQuery(self: *Self, query: []const[]const u8, buffer: *std.ArrayList(u8)) Result {
        _ = self;
        _ = query;
        _ = buffer;

        return Result.ok();
    }

    fn instrExt(self: *Self, operand: u4) void {
        if(operand == 1) {
            self.status = .Pause;
            self.program_counter += 1;
        } else {
            self.status = .Halt;
        }
    }

    fn instrSta(self: *Self, operand: u4) void {
        self.registers.set(operand, self.registers.accumulator);

        self.program_counter += 1;
    }

    fn instrLda(self: *Self, operand: u4) void {
        self.registers.accumulator = self.registers.get(operand);

        self.program_counter += 1;
    }

    fn instrAdd(self: *Self, operand: u4) void {
        bin_ops.addWithFlags(
            self.registers.accumulator,
            self.registers.get(operand),
            &self.registers.accumulator, 
            &self.registers.flags
        );

        self.program_counter += 1;
    }

    fn instrSub(self: *Self, operand: u4) void {
        bin_ops.subWithFlags(
            self.registers.accumulator,
            self.registers.get(operand),
            &self.registers.accumulator, 
            &self.registers.flags
        );

        self.program_counter += 1;
    }

    fn instrAdc(self: *Self, operand: u4) void {
        const carry = self.registers.flags.flags.carry;
        bin_ops.addWithFlags(
            self.registers.accumulator + @as(u8, carry),
            self.registers.get(operand),
            &self.registers.accumulator, 
            &self.registers.flags
        );

        self.program_counter += 1;
    }

    fn instrAnd(self: *Self, operand: u4) void {
        bin_ops.andWithFlags(
            self.registers.accumulator,
            self.registers.get(operand),
            &self.registers.accumulator, 
            &self.registers.flags
        );

        self.program_counter += 1;
    }

    fn instrNor(self: *Self, operand: u4) void {
        bin_ops.norWithFlags(
            self.registers.accumulator,
            self.registers.get(operand),
            &self.registers.accumulator, 
            &self.registers.flags
        );

        self.program_counter += 1;
    }

    fn instrXor(self: *Self, operand: u4) void {
        bin_ops.xorWithFlags(
            self.registers.accumulator,
            self.registers.get(operand),
            &self.registers.accumulator, 
            &self.registers.flags
        );

        self.program_counter += 1;
    }

    fn instrBsh(self: *Self, operand: u4) void {
        bin_ops.bshWithFlags(
            self.registers.accumulator,
            operand,
            &self.registers.accumulator, 
            &self.registers.flags
        );

        self.program_counter += 1;
    }

    fn instrLim(self: *Self, operand: u4) void {
        self.registers.accumulator = bin_ops.signExtendu4u8(operand);

        self.program_counter += 1;
    }

    fn instrAim(self: *Self, operand: u4) void {
        bin_ops.addWithFlags(
            self.registers.accumulator,
            bin_ops.signExtendu4u8(operand),
            &self.registers.accumulator,
            &self.registers.flags
        );

        self.program_counter += 1;
    }

    fn instrMld(self: *Self, operand4bit: u4, operand8bit: u8) void {
        const address = ((@as(u16, self.registers.segment) << 8) | @as(u16, self.registers.get(operand4bit))) +% bin_ops.signExtendu8u16(operand8bit);

        const mem_value = self.memory.get(address);
        
        self.registers.flags.flags.carry = 0;
        self.registers.flags.flags.overflow = 0;
        self.registers.flags.flags.not_zero = if(mem_value == 0) 0 else 1;
        self.registers.flags.flags.parity = @truncate(mem_value);
        self.registers.flags.flags.sign = @truncate(mem_value >> 7);

        self.program_counter += 2;
    }

    fn instrMst(self: *Self, operand4bit: u4, operand8bit: u8) void {
        const address = ((@as(u16, self.registers.segment) << 8) | @as(u16, self.registers.get(operand4bit))) +% bin_ops.signExtendu8u16(operand8bit);

        self.memory.set(address, self.registers.accumulator);

        self.program_counter += 2;
    }

    fn instrBrc(self: *Self, operand4bit: u4, operand8bit: u8) void {
        const flags = self.registers.flags.flags;

        const condition_met: bool = switch(operand4bit) {
            0b0000 => false,
            0b0001 => true,
            0b0010 => flags.a == 0,
            0b0011 => flags.a == 1,
            0b0100 => flags.b == 0,
            0b0101 => flags.b == 1,
            0b0110 => flags.parity == 0,
            0b0111 => flags.parity == 1,
            0b1000 => flags.not_zero == 0,
            0b1001 => flags.not_zero == 1,
            0b1010 => flags.sign == 0,
            0b1011 => flags.sign == 1,
            0b1100 => flags.carry == 0,
            0b1101 => flags.carry == 1,
            0b1110 => flags.overflow == 0,
            0b1111 => flags.overflow == 1
        };

        if(condition_met) {
            const new_address = self.program_counter +% bin_ops.signExtendu8u16(operand8bit);
            self.program_counter = new_address;
        } else {
            self.program_counter += 2;
        }
    }

    fn instrJal(self: *Self, operand4bit: u4, operand8bit: u8) void {
        const next_program_counter = self.program_counter +% 2;
        
        self.program_counter = ((@as(u16, self.registers.segment) << 8) | (@as(u16, self.registers.get(operand4bit)))) +% bin_ops.signExtendu8u16(operand8bit);
        self.registers.segment = @truncate(next_program_counter >> 8);
        self.registers.accumulator = @truncate(next_program_counter);
    }
};