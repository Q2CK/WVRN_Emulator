const std = @import("std");

const app = @import("app.zig");

pub fn main() !void {
    // var cpu = CPU.init();
    
    // const program = [_]u8 {
    //     0b1010_0001, // LIM 1
    //     0b0001_0001, // STA r1
    //     0b0010_0000, // LDA r0,
    //     0b0011_0001, // ADD r1,
    //     0b1110_0001,
    //     0b1111_1111  // BRC true -1
    // };

    // @memcpy(cpu.memory.bytes[0..program.len], program[0..program.len]);

    // cpu.status = .Run;

    // while(cpu.status == .Run) {
    //     std.debug.print("Acc: {d}\nPc: {}\n\n", .{cpu.registers.accumulator, cpu.program_counter});
    //     std.time.sleep(100000000);
    //     cpu.tick();
    // }

    try app.run();
}

