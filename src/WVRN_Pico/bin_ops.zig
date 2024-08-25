const std = @import("std");
const expect = std.testing.expect;

const flags_import = @import("flags.zig");
const Flags = flags_import.Flags;

pub inline fn addWithFlags(src_a: u8, src_b: u8, result: *u8, flags: *Flags, flag_update: u1) void {
    const src_a_9bit: u9 = @as(u9, src_a);
    const src_b_9bit: u9 = @as(u9, src_b);

    const result_7bit = (src_a_9bit & 0x7F) +% (src_b_9bit & 0x7F);
    const result_8bit = src_a +% src_b;
    const result_9bit = src_a_9bit +% src_b_9bit;

    const carry_8th: u1 = @truncate(result_9bit >> 8);
    const carry_7th: u1 = @truncate(result_7bit >> 7);

    const parity: u1 = @truncate(result_8bit);
    const sign: u1 = @truncate(result_8bit >> 7);

    if(flag_update == 1) {
        flags.*.flags.carry = carry_8th;
        flags.*.flags.overflow = carry_8th ^ carry_7th;
        flags.*.flags.parity = parity;
        flags.*.flags.sign = sign;
        flags.*.flags.not_zero = if(result_8bit == 0) 0 else 1;
    }

    result.* = result_8bit;
}

pub inline fn nandWithFlags(src_a: u8, src_b: u8, result: *u8, flags: *Flags, flag_update: u1) void {
    const result_8bit = ~(src_a & src_b);

    if(flag_update == 1) {
        const parity: u1 = @truncate(result_8bit);
        const sign: u1 = @truncate(result_8bit >> 7);

        flags.*.flags.carry = 0;
        flags.*.flags.overflow = 0;
        flags.*.flags.parity = parity;
        flags.*.flags.sign = sign;
        flags.*.flags.not_zero = if(result_8bit == 0) 0 else 1;
    }

    result.* = result_8bit;
}

pub inline fn rshWithFlags(src: u8, result: *u8, flags: *Flags, flag_update: u1) void {
    const result_8bit: u8 = src >> 1;

    if(flag_update == 1) {
        const overflow: u1 = @truncate(src);
        const parity: u1 = @truncate(result_8bit);
        const sign: u1 = @truncate(result_8bit >> 7);

        flags.*.flags.carry = 0;
        flags.*.flags.overflow = overflow;
        flags.*.flags.parity = parity;
        flags.*.flags.sign = sign;
        flags.*.flags.not_zero = if(result_8bit == 0) 0 else 1;
    }

    result.* = result_8bit;
}

pub inline fn signExtendu4u8(value: u4) u8 {
    return if(value & 0x08 == 0) @as(u8, value) else 0xF0 | @as(u8, value);
}

test "operations with flags" {
    var res: u8 = 0;
    var flg: Flags = Flags.init();

    addWithFlags(0, 0, &res, &flg, 1);
    try expect(res == 0);
    try expect(flg.flags.not_zero == 0);
    try expect(flg.flags.parity == 0);
    try expect(flg.flags.sign == 0);
    try expect(flg.flags.carry == 0);
    try expect(flg.flags.overflow == 0);

    addWithFlags(255, 1, &res, &flg, 1);
    try expect(res == 0);
    try expect(flg.flags.not_zero == 0);
    try expect(flg.flags.parity == 0);
    try expect(flg.flags.sign == 0);
    try expect(flg.flags.carry == 1);
    try expect(flg.flags.overflow == 0);

    std.debug.print("{b:0>8}", .{flg.byte});

    addWithFlags(2, 3, &res, &flg, 1);
    try expect(res == 5);
    try expect(flg.flags.not_zero == 1);
    try expect(flg.flags.parity == 1);
    try expect(flg.flags.sign == 0);
    try expect(flg.flags.carry == 0);
    try expect(flg.flags.overflow == 0);

    addWithFlags(127, 1, &res, &flg, 1);
    try expect(res == 128);
    try expect(flg.flags.not_zero == 1);
    try expect(flg.flags.parity == 0);
    try expect(flg.flags.sign == 1);
    try expect(flg.flags.carry == 0);
    try expect(flg.flags.overflow == 1);

    addWithFlags(128, 128, &res, &flg, 1);
    try expect(res == 0);
    try expect(flg.flags.not_zero == 0);
    try expect(flg.flags.parity == 0);
    try expect(flg.flags.sign == 0);
    try expect(flg.flags.carry == 1);
    try expect(flg.flags.overflow == 1);

    nandWithFlags(3, 5, &res, &flg, 1);
    try expect(res == 254);
    try expect(flg.flags.not_zero == 1);
    try expect(flg.flags.parity == 0);
    try expect(flg.flags.sign == 1);
    try expect(flg.flags.carry == 0);
    try expect(flg.flags.overflow == 0);

    rshWithFlags(9, &res, &flg, 1);
    try expect(res == 4);
    try expect(flg.flags.not_zero == 1);
    try expect(flg.flags.parity == 0);
    try expect(flg.flags.sign == 0);
    try expect(flg.flags.carry == 0);
    try expect(flg.flags.overflow == 1);
}