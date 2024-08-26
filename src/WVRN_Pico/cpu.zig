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

    pub inline fn tick(self: *Self) void {
        const instr_byte = self.memory.get(self.program_counter);

        const instr: Instruction = @bitCast(instr_byte);

        switch(instr.opcode) {
            .EXT  => self.instrExt(instr.operand),
            .SWA  => self.instrSwa(instr.operand, instr.flag_update),
            .ADD  => self.instrAdd(instr.operand, instr.flag_update),
            .ADDI => self.instrAddi(instr.operand, instr.flag_update),
            .NAND => self.instrNand(instr.operand, instr.flag_update),
            .LD   => self.instrLd(instr.operand, instr.flag_update),
            .ST   => self.instrSt(instr.operand),
            .B    => self.instrB(instr.operand),
        }
    }

    pub fn nTicks(self: *Self, n: usize) void {
        for(0..n) |_| {
            self.tick();
        }
    }

    pub fn getNextInstruction(self: Self, buffer: *std.ArrayList(u8)) Result {
        const instr_byte = self.memory.get(self.program_counter);
        const instr: Instruction = @bitCast(instr_byte);

        var writer = buffer.writer();

        switch(instr.opcode) {
            .EXT  => writer.print("ext {d} {d}", .{instr.flag_update, instr.operand}) catch return Result.errStatic("Failed to allocate buffer"),
            .SWA  => writer.print("swa{s} r{d}", .{if(instr.flag_update == 1) ".f" else "", instr.operand}) catch return Result.errStatic("Failed to allocate buffer"),
            .ADD  => writer.print("add{s} r{d}", .{if(instr.flag_update == 1) ".f" else "", instr.operand}) catch return Result.errStatic("Failed to allocate buffer"),
            .ADDI => writer.print("addi{s} {d}", .{if(instr.flag_update == 1) ".f" else "", instr.operand}) catch return Result.errStatic("Failed to allocate buffer"),
            .NAND => writer.print("nand{s} r{d}", .{if(instr.flag_update == 1) ".f" else "", instr.operand}) catch return Result.errStatic("Failed to allocate buffer"),
            .LD   => writer.print("ld{s} r{d}", .{if(instr.flag_update == 1) ".f" else "", instr.operand}) catch return Result.errStatic("Failed to allocate buffer"),
            .ST   => writer.print("st r{d}", .{instr.operand}) catch return Result.errStatic("Failed to allocate buffer"),
            .B    => writer.print("b {s}", .{switch(instr.operand) {
                0b0000 => "false",
                0b0001 => "true",
                0b0010 => "!a",
                0b0011 => "a",
                0b0100 => "!b",
                0b0101 => "b",
                0b0110 => "!overflow",
                0b0111 => "overflow",
                0b1000 => "!sign",
                0b1001 => "sign",
                0b1010 => "even",
                0b1011 => "odd",
                0b1100 => "zero",
                0b1101 => "!zero",
                0b1110 => "!carry",
                0b1111 => "carry",
            }}) catch return Result.errStatic("Failed to allocate buffer"),
        }

        return Result.ok();
    }

    pub fn setQuery(self: *Self, query: []const[]const u8) Result {
        if(query.len < 1) {
            return Result.errStatic("Empty query");
        }

        const n_args = query.len - 1;

        const device = query[0];
        const params = query[1..];

        if(std.mem.eql(u8, device, "reg")) {
            if(n_args == 2) {
                const reg_name = params[0];
                const value_string = params[1];
                const value = std.fmt.parseInt(u8, value_string, 0) catch return Result.errStatic("Failed to parse numeric value");
                if(std.mem.startsWith(u8, reg_name, "r")) {
                    const reg_number = std.fmt.parseInt(u4, reg_name[1..], 0) catch return Result.errStatic("Failed to parse register name");
                    self.registers.set(reg_number, value);
                    return Result.ok();
                } else if(std.mem.eql(u8, reg_name, "zero")) {
                    return Result.ok();
                } else if(std.mem.eql(u8, reg_name, "acc")) {
                    self.registers.set(1, value);
                    return Result.ok();
                } else if(std.mem.eql(u8, reg_name, "flg")) {
                    self.registers.set(2, value);
                    return Result.ok();
                } else if(std.mem.eql(u8, reg_name, "seg")) {
                    self.registers.set(3, value);
                    return Result.ok();
                } else if(std.mem.eql(u8, reg_name, "tr1")) {
                    self.registers.set(4, value);
                    return Result.ok();
                } else if(std.mem.eql(u8, reg_name, "tr2")) {
                    self.registers.set(5, @truncate(value));
                    return Result.ok();
                } else {
                    return Result.errStatic("Failed to parse register name");
                }
            } else {
                return Result.errStatic("'reg' query expects 1 register index parameter and 1 value");
            }
        } else if(std.mem.eql(u8, device, "mem")) {
            if(n_args == 2) {
                const address_string = params[0];
                const value_string = params[1];
                const address = std.fmt.parseInt(u16, address_string, 0) catch return Result.errStatic("Failed to parse register name");
                const value = std.fmt.parseInt(u8, value_string, 0) catch return Result.errStatic("Failed to parse numeric value");
                self.memory.set(address, value);
                return Result.ok();
            } else if(n_args == 3) {
                const start_address_string = params[0];
                const end_address_string = params[1];
                const value_string = params[2];
                const start_address = std.fmt.parseInt(usize, start_address_string, 0) catch return Result.errStatic("Failed to parse address");
                const end_addres = std.fmt.parseInt(usize, end_address_string, 0) catch return Result.errStatic("Failed to parse address");
                const value = std.fmt.parseInt(u8, value_string, 0) catch return Result.errStatic("Failed to parse numeric value");
                if(start_address > 65535 or end_addres > 65535) {
                    return Result.errStatic("Address out of range: <0; 65535>");
                }
                if(end_addres < start_address) {
                    return Result.errStatic("Start address is larger than end address");
                }
                var address: usize = start_address;
                while(address <= end_addres) {
                    self.memory.set(@truncate(address), value);
                    address +%= 1;
                }
                return Result.ok();
            } else {
                return Result.errStatic("'mem' query expects 1 memory address parameter and 1 value, or a memory range and a value");
            }
        } else if(std.mem.eql(u8, device, "pc")) {
            if(n_args == 1) {
                const value_string = params[0];
                const value = std.fmt.parseInt(u16, value_string, 0) catch return Result.errStatic("Failed to parse numeric value");
                self.program_counter = value;
                return Result.ok();
            } else {
                return Result.errStatic("'pc' query expects no parameters");
            }
        } else {
            return Result.errStatic("No such CPU component");
        }
    }

    pub fn getQuery(self: *Self, query: []const[]const u8, buffer: *std.ArrayList(u8)) Result {
        var writer = buffer.*.writer();

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
                    const reg_number = std.fmt.parseInt(u4, reg_name[1..], 0) catch return Result.errStatic("Failed to parse register name");
                    const reg_value = self.registers.get(reg_number);
                    writer.print("r{d} = \x1b[96m{d}\x1b[0m", .{reg_number, reg_value}) catch return Result.errStatic("Failed to allocate buffer");
                    return Result.ok();
                } else if(std.mem.eql(u8, reg_name, "zero")) {
                    writer.print("zero= \x1b[96m0\x1b[0m", .{}) catch return Result.errStatic("Failed to allocate buffer");
                    return Result.ok();
                } else if(std.mem.eql(u8, reg_name, "acc")) {
                    const reg_value = self.registers.get(1);
                    writer.print("acc = \x1b[96m{d}\x1b[0m", .{reg_value}) catch return Result.errStatic("Failed to allocate buffer");
                    return Result.ok();
                } else if(std.mem.eql(u8, reg_name, "flg")) {
                    const reg_value = self.registers.get(2);
                    writer.print("flg= \x1b[96m{b:0>8}\x1b[0m", .{reg_value}) catch return Result.errStatic("Failed to allocate buffer");
                    return Result.ok();
                } else if(std.mem.eql(u8, reg_name, "seg")) {
                    const reg_value = self.registers.get(3);
                    writer.print("seg = \x1b[96m{d}\x1b[0m", .{reg_value}) catch return Result.errStatic("Failed to allocate buffer");
                    return Result.ok();
                } else if(std.mem.eql(u8, reg_name, "tr1")) {
                    const reg_value = self.registers.get(4);
                    writer.print("tr1 = \x1b[96m{d}\x1b[0m", .{reg_value}) catch return Result.errStatic("Failed to allocate buffer");
                    return Result.ok();
                } else if(std.mem.eql(u8, reg_name, "tr2")) {
                    const reg_value = self.registers.get(5);
                    writer.print("tr1 = \x1b[96m{d}\x1b[0m", .{reg_value}) catch return Result.errStatic("Failed to allocate buffer");
                    return Result.ok();
                } else {
                    return Result.errStatic("Failed to parse register name");
                }
            } else {
                return Result.errStatic("'reg' query expects 1 register index parameter");
            }
        } else if(std.mem.eql(u8, device, "regs")) {
            if(n_args == 0) {
                writer.print("\x1b[0m\n", .{}) catch return Result.errStatic("Failed to allocate buffer");
                writer.print("\x1b[0mr0/zero = \x1b[96m0\n", .{}) catch return Result.errStatic("Failed to allocate buffer");
                writer.print("\x1b[0mr1/acc  = \x1b[96m{d}\n", .{self.registers.accumulator}) catch return Result.errStatic("Failed to allocate buffer");
                writer.print("\x1b[0mr2/flg  = \x1b[96m{b:0>8}\n", .{self.registers.flags.byte}) catch return Result.errStatic("Failed to allocate buffer");
                writer.print("\x1b[0mr3/seg  = \x1b[96m{d}\n", .{self.registers.segment}) catch return Result.errStatic("Failed to allocate buffer");

                for(4..16) |i| {
                    writer.print("\x1b[0mr{d: <2} = \x1b[96m{d: <3}", .{i, self.registers.get(@intCast(i))}) catch return Result.errStatic("Failed to allocate buffer");

                    if(i % 4 == 3) {
                        writer.print("\n", .{}) catch return Result.errStatic("Failed to allocate buffer");
                    } else {
                        writer.print(" ", .{}) catch return Result.errStatic("Failed to allocate buffer");
                    }
                }

                return Result.ok();
            } else {
                return Result.errStatic("'regs' query expects no parameters");
            }
        } else if(std.mem.eql(u8, device, "mem")) {
            if(n_args == 1) {
                const address_string = params[0];
                const address = std.fmt.parseInt(usize, address_string, 0) catch return Result.errStatic("Failed to parse address");
                if(address > 65535) {
                    return Result.errStatic("Address out of range: <0; 65535>");
                }
                const mem_value = self.memory.get(@truncate(address));
                writer.print("mem[{d}] = \x1b[96m{d}\x1b[0m", .{address, mem_value}) catch return Result.errStatic("Failed to allocate buffer");
                return Result.ok();
            } if(n_args == 2) {
                const start_address_string = params[0];
                const end_address_string = params[1];
                const start_address = std.fmt.parseInt(usize, start_address_string, 0) catch return Result.errStatic("Failed to parse address");
                const end_addres = std.fmt.parseInt(usize, end_address_string, 0) catch return Result.errStatic("Failed to parse address");
                if(start_address > 65535 or end_addres > 65535) {
                    return Result.errStatic("Address out of range: <0; 65535>");
                }
                if(end_addres < start_address) {
                    return Result.errStatic("Start address is larger than end address");
                }
                var address: usize = start_address;
                while(address <= end_addres) {
                    const mem_value = self.memory.get(@truncate(address));
                    writer.print("\nmem[{d}] = \x1b[96m{d}\x1b[0m", .{address, mem_value}) catch return Result.errStatic("Failed to allocate buffer");

                    address +%= 1;
                }
                return Result.ok();
            } else {
                return Result.errStatic("'mem' query expects 1 or 2 memory address parameters");
            }
        } else if(std.mem.eql(u8, device, "pc")) {
            if(n_args == 0) {
                const pc_value = self.program_counter;
                writer.print("pc = \x1b[96m{d}\x1b[0m", .{pc_value}) catch return Result.errStatic("Failed to allocate buffer");
                return Result.ok();
            } else {
                return Result.errStatic("'pc' query expects no parameters");
            }
        } else {
            return Result.errStatic("No such CPU component");
        }
    }

    inline fn instrExt(self: *Self, operand: u4) void {
        if(operand == 1) {
            self.status = .Pause;
            self.program_counter += 1;
        } else {
            self.status = .Halt;
        }
    }

    inline fn instrSwa(self: *Self, operand: u4, flag_update: u1) void {
        const temp = self.registers.get(operand);
        self.registers.set(operand, self.registers.accumulator);
        self.registers.accumulator = temp;

        if(flag_update == 1) {
            self.registers.flags.flags.carry = 0;
            self.registers.flags.flags.overflow = 0;
            self.registers.flags.flags.not_zero = if(self.registers.accumulator == 0) 0 else 1;
            self.registers.flags.flags.parity = @truncate(self.registers.accumulator);
            self.registers.flags.flags.sign = @truncate(self.registers.accumulator >> 7);
        }

        self.program_counter += 1;
    }

    inline fn instrAdd(self: *Self, operand: u4, flag_update: u1) void {
        bin_ops.addWithFlags(
            self.registers.accumulator,
            self.registers.get(operand),
            &self.registers.accumulator, 
            &self.registers.flags,
            flag_update
        );

        self.program_counter += 1;
    }

    inline fn instrAddi(self: *Self, operand: u4, flag_update: u1) void {
        bin_ops.addWithFlags(
            self.registers.accumulator,
            bin_ops.signExtendu4u8(operand),
            &self.registers.accumulator, 
            &self.registers.flags,
            flag_update
        );

        self.program_counter += 1;
    }

    inline fn instrNand(self: *Self, operand: u4, flag_update: u1) void {
        bin_ops.nandWithFlags(
            self.registers.accumulator,
            self.registers.get(operand),
            &self.registers.accumulator, 
            &self.registers.flags,
            flag_update
        );

        self.program_counter += 1;
    }


    inline fn instrLd(self: *Self, operand: u4, flag_update: u1) void {
        const address = ((@as(u16, self.registers.segment) << 8) | @as(u16, self.registers.get(operand)));

        const mem_value = self.memory.get(address);
        self.registers.accumulator = mem_value;
        
        if(flag_update == 1) {
            self.registers.flags.flags.carry = 0;
            self.registers.flags.flags.overflow = 0;
            self.registers.flags.flags.not_zero = if(mem_value == 0) 0 else 1;
            self.registers.flags.flags.parity = @truncate(mem_value);
            self.registers.flags.flags.sign = @truncate(mem_value >> 7);
        }

        self.program_counter += 1;
    }

    inline fn instrSt(self: *Self, operand: u4) void {
        const address = ((@as(u16, self.registers.segment) << 8) | @as(u16, self.registers.get(operand)));
        self.memory.set(address, self.registers.accumulator);

        self.program_counter += 1;
    }

    inline fn instrB(self: *Self, operand: u4) void {
        const flags = self.registers.flags.flags;

        const condition_met: bool = switch(operand) {
            0b0000 => false,
            0b0001 => true,
            0b0010 => flags.a == 0,
            0b0011 => flags.a == 1,
            0b0100 => flags.b == 0,
            0b0101 => flags.b == 1,
            0b0110 => flags.overflow == 0,
            0b0111 => flags.overflow == 1,
            0b1000 => flags.sign == 0,
            0b1001 => flags.sign == 1,
            0b1010 => flags.parity == 0,
            0b1011 => flags.parity == 1,
            0b1100 => flags.not_zero == 0,
            0b1101 => flags.not_zero == 1,
            0b1110 => flags.carry == 0,
            0b1111 => flags.carry == 1,
        };

        if(condition_met) {
            self.program_counter = ((@as(u16, self.registers.segment) << 8) | (@as(u16, self.registers.accumulator)));
        } else {
            self.program_counter += 1;
        }
    }
};