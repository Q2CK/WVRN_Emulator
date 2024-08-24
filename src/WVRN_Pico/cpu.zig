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
        var tokens_iterator = std.mem.tokenizeAny(u8, query, " \n\t");

        var tokens_list = std.ArrayList([]const u8).init();
        defer tokens_list.deinit();

        while(tokens_iterator.next()) |token| {
            tokens_list.append(token);
        }

        if(tokens_list.items.len < 1) {
            return Result.errStatic("Empty query");
        }

        const n_args = tokens_list.items.len - 1;

        const device = tokens_list.items[0];
        const params = tokens_list.items[1..];

        if(std.mem.eql(u8, device, "reg")) {
            if(n_args == 1) {
                const reg_name = params[0];
                if(std.mem.startsWith(u8, reg_name, 'r')) {
                    const reg_number = std.fmt.parseInt(u5, reg_name[1..], 0) catch return Result.errStatic("Failed to parse register name");
                    self.registers.set(reg_number, value);
                } else if(std.mem.eql(u8, reg_name, "zero")) {
                    
                } else if(std.mem.eql(u8, reg_name, "acc")) {
                    self.registers.set(1, value);
                } else if(std.mem.eql(u8, reg_name, "flg")) {
                    self.registers.set(2, value);
                } else if(std.mem.eql(u8, reg_name, "seg")) {
                    self.registers.set(3, value);
                } else if(std.mem.eql(u8, reg_name, "tr1")) {
                    self.registers.set(4, value);
                } else if(std.mem.eql(u8, reg_name, "tr2")) {
                    self.registers.set(5, @truncate(value));
                }
            } else {
                return Result.errStatic("'reg' query expects 1 register index parameter");
            }
        } else if(std.mem.eql(u8, device, "mem")) {
            if(n_args == 1) {
                const address_string = params[0];
                const address = std.fmt.parseInt(u16, address_string, 0) catch return Result.errStatic("Failed to parse register name");
                self.memory.set(address, @truncate(value));
            } else {
                return Result.errStatic("'mem' query expects 1 memory address parameter");
            }
        } else if(std.mem.eql(u8, device, "pc")) {
            if(n_args == 0) {
                self.program_counter = @truncate(value);
            } else {
                return Result.errStatic("'pc' query expects no parameters");
            }
        } else {
            return Result.errStatic("No such CPU component");
        }
    }

    pub fn getQuery(self: *Self, alloc: std.mem.Allocator, query: []const[]const u8, buffer: *[]u8) Result {
        if(query.len < 1) {
            return Result.errStatic("Empty query");
        }

        const n_args = query.len - 1;

        const device = query[0];
        const params = query[1..];

        if(std.mem.eql(u8, device, "reg")) {
            if(n_args == 1) {
                const reg_name = std.mem.trim(u8, params[0], " \n\t\r");
                if(std.mem.startsWith(u8, reg_name, "r")) {
                    const reg_number = std.fmt.parseInt(u5, reg_name[1..], 0) catch return Result.errStatic("Failed to parse register name");
                    const reg_value = self.registers.get(@truncate(reg_number));
                    buffer.* = std.fmt.allocPrint(alloc, "r{d} = \x1b[96m{d}\x1b[0m", .{reg_number, reg_value}) catch return Result.errStatic("Failed to allocate buffer");
                    return Result.ok();
                } else if(std.mem.eql(u8, reg_name, "zero")) {
                    buffer.* = std.fmt.allocPrint(alloc, "zero= \x1b[96m0\x1b[0m", .{}) catch return Result.errStatic("Failed to allocate buffer");
                    return Result.ok();
                } else if(std.mem.eql(u8, reg_name, "acc")) {
                    const reg_value = self.registers.get(1);
                    buffer.* = std.fmt.allocPrint(alloc, "acc = \x1b[96m{d}\x1b[0m", .{reg_value}) catch return Result.errStatic("Failed to allocate buffer");
                    return Result.ok();
                } else if(std.mem.eql(u8, reg_name, "flg")) {
                    const reg_value = self.registers.get(2);
                    buffer.* = std.fmt.allocPrint(alloc, "flg= \x1b[96m{d}\x1b[0m", .{reg_value}) catch return Result.errStatic("Failed to allocate buffer");
                    return Result.ok();
                } else if(std.mem.eql(u8, reg_name, "seg")) {
                    const reg_value = self.registers.get(3);
                    buffer.* = std.fmt.allocPrint(alloc, "seg = \x1b[96m{d}\x1b[0m", .{reg_value}) catch return Result.errStatic("Failed to allocate buffer");
                    return Result.ok();
                } else if(std.mem.eql(u8, reg_name, "tr1")) {
                    const reg_value = self.registers.get(4);
                    buffer.* = std.fmt.allocPrint(alloc, "tr1 = \x1b[96m{d}\x1b[0m", .{reg_value}) catch return Result.errStatic("Failed to allocate buffer");
                    return Result.ok();
                } else if(std.mem.eql(u8, reg_name, "tr2")) {
                    const reg_value = self.registers.get(5);
                    buffer.* = std.fmt.allocPrint(alloc, "tr1 = \x1b[96m{d}\x1b[0m", .{reg_value}) catch return Result.errStatic("Failed to allocate buffer");
                    return Result.ok();
                } else {
                    return Result.errStatic("Failed to parse register name");
                }
            } else {
                return Result.errStatic("'reg' query expects 1 register index parameter");
            }
        } else if(std.mem.eql(u8, device, "mem")) {
            if(n_args == 1) {
                const address_string = params[0];
                const address = std.fmt.parseInt(u16, address_string, 0) catch return Result.errStatic("Failed to parse register name");
                const mem_value = self.memory.get(address);
                buffer.* = std.fmt.allocPrint(alloc, "mem[{d}] = \x1b[96m{d}\x1b[0m", .{address, mem_value}) catch return Result.errStatic("Failed to allocate buffer");
                return Result.ok();
            } else {
                return Result.errStatic("'mem' query expects 1 memory address parameter");
            }
        } else if(std.mem.eql(u8, device, "pc")) {
            if(n_args == 0) {
                const pc_value = self.program_counter;
                buffer.* = std.fmt.allocPrint(alloc, "pc = \x1b[96m{d}\x1b[0m", .{pc_value}) catch return Result.errStatic("Failed to allocate buffer");
                return Result.ok();
            } else {
                return Result.errStatic("'pc' query expects no parameters");
            }
        } else {
            return Result.errStatic("No such CPU component");
        }
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