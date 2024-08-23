const std = @import("std");
const expect = std.testing.expect;

const flags_import = @import("flags.zig");
const Flags = flags_import.Flags;

pub inline fn addWithFlags(src_a: u8, src_b: u8, result: *u8, flags: *Flags) void {
    const src_a_9bit: u9 = @as(u9, src_a);
    const src_b_9bit: u9 = @as(u9, src_b);

    const result_7bit = (src_a_9bit & 0x7F) +% (src_b_9bit & 0x7F);
    const result_8bit = src_a +% src_b;
    const result_9bit = src_a_9bit +% src_b_9bit;

    const carry_8th: u1 = @truncate(result_9bit >> 8);
    const carry_7th: u1 = @truncate(result_7bit >> 7);

    const parity: u1 = @truncate(result_8bit);
    const sign: u1 = @truncate(result_8bit >> 7);

    flags.*.flags.carry = carry_8th;
    flags.*.flags.overflow = carry_8th ^ carry_7th;
    flags.*.flags.parity = parity;
    flags.*.flags.sign = sign;
    flags.*.flags.not_zero = if(result_8bit == 0) 0 else 1;

    result.* = result_8bit;
}

pub inline fn subWithFlags(src_a: u8, src_b: u8, result: *u8, flags: *Flags) void {
    addWithFlags(src_a, (~src_b) +% 1, result, flags);
}

pub inline fn andWithFlags(src_a: u8, src_b: u8, result: *u8, flags: *Flags) void {
    const result_8bit = src_a & src_b;

    const parity: u1 = @truncate(result_8bit);
    const sign: u1 = @truncate(result_8bit >> 7);

    flags.*.flags.carry = 0;
    flags.*.flags.overflow = 0;
    flags.*.flags.parity = parity;
    flags.*.flags.sign = sign;
    flags.*.flags.not_zero = if(result_8bit == 0) 0 else 1;

    result.* = result_8bit;
}

pub inline fn norWithFlags(src_a: u8, src_b: u8, result: *u8, flags: *Flags) void {
    const result_8bit = ~(src_a | src_b);

    const parity: u1 = @truncate(result_8bit);
    const sign: u1 = @truncate(result_8bit >> 7);

    flags.*.flags.carry = 0;
    flags.*.flags.overflow = 0;
    flags.*.flags.parity = parity;
    flags.*.flags.sign = sign;
    flags.*.flags.not_zero = if(result_8bit == 0) 0 else 1;

    result.* = result_8bit;
}

pub inline fn xorWithFlags(src_a: u8, src_b: u8, result: *u8, flags: *Flags) void {
    const result_8bit = src_a ^ src_b;

    const parity: u1 = @truncate(result_8bit);
    const sign: u1 = @truncate(result_8bit >> 7);

    flags.*.flags.carry = 0;
    flags.*.flags.overflow = 0;
    flags.*.flags.parity = parity;
    flags.*.flags.sign = sign;
    flags.*.flags.not_zero = if(result_8bit == 0) 0 else 1;

    result.* = result_8bit;
}

pub inline fn bshWithFlags(src: u8, amount: u4, result: *u8, flags: *Flags) void {
    const src_9bit: u9 = @as(u9, src);

    const result_9bit = switch(amount) {
        8...15 => src_9bit << @truncate(16 - @as(u5, amount)),
        0...7 => src_9bit >> amount
    };
    const result_8bit: u8 = @truncate(result_9bit);

    const carry: u1 = @truncate(result_9bit >> 8);
    const parity: u1 = @truncate(result_8bit);
    const sign: u1 = @truncate(result_8bit >> 7);

    flags.*.flags.carry = carry;
    flags.*.flags.overflow = carry;
    flags.*.flags.parity = parity;
    flags.*.flags.sign = sign;
    flags.*.flags.not_zero = if(result_8bit == 0) 0 else 1;

    result.* = result_8bit;
}

pub fn signExtendu4u8(value: u4) u8 {
    return if(value & 0x8 == 0) @as(u8, value) else 0xF0 | @as(u8, value);
}

pub fn signExtendu8u16(value: u8) u16 {
    return if(value & 0x80 == 0) @as(u16, value) else 0xFF00 | @as(u16, value);
}

test "operations with flags" {
    var res: u8 = 0;
    var flg: Flags = Flags.init();

    addWithFlags(0, 0, &res, &flg);
    try expect(res == 0);
    try expect(flg.flags.not_zero == 0);
    try expect(flg.flags.parity == 0);
    try expect(flg.flags.sign == 0);
    try expect(flg.flags.carry == 0);
    try expect(flg.flags.overflow == 0);

    addWithFlags(2, 3, &res, &flg);
    try expect(res == 5);
    try expect(flg.flags.not_zero == 1);
    try expect(flg.flags.parity == 1);
    try expect(flg.flags.sign == 0);
    try expect(flg.flags.carry == 0);
    try expect(flg.flags.overflow == 0);

    addWithFlags(127, 1, &res, &flg);
    try expect(res == 128);
    try expect(flg.flags.not_zero == 1);
    try expect(flg.flags.parity == 0);
    try expect(flg.flags.sign == 1);
    try expect(flg.flags.carry == 0);
    try expect(flg.flags.overflow == 1);

    addWithFlags(128, 128, &res, &flg);
    try expect(res == 0);
    try expect(flg.flags.not_zero == 0);
    try expect(flg.flags.parity == 0);
    try expect(flg.flags.sign == 0);
    try expect(flg.flags.carry == 1);
    try expect(flg.flags.overflow == 1);

    subWithFlags(100, 50, &res, &flg);
    try expect(res == 50);
    try expect(flg.flags.not_zero == 1);
    try expect(flg.flags.parity == 0);
    try expect(flg.flags.sign == 0);
    try expect(flg.flags.carry == 1);
    try expect(flg.flags.overflow == 0);

    subWithFlags(100, 101, &res, &flg);
    try expect(res == 255);
    try expect(flg.flags.not_zero == 1);
    try expect(flg.flags.parity == 1);
    try expect(flg.flags.sign == 1);
    try expect(flg.flags.carry == 0);
    try expect(flg.flags.overflow == 0);

    subWithFlags(1, 129, &res, &flg);
    try expect(res == 128);
    try expect(flg.flags.not_zero == 1);
    try expect(flg.flags.parity == 0);
    try expect(flg.flags.sign == 1);
    try expect(flg.flags.carry == 0);
    try expect(flg.flags.overflow == 1);

    andWithFlags(3, 5, &res, &flg);
    try expect(res == 1);
    try expect(flg.flags.not_zero == 1);
    try expect(flg.flags.parity == 1);
    try expect(flg.flags.sign == 0);
    try expect(flg.flags.carry == 0);
    try expect(flg.flags.overflow == 0);

    norWithFlags(3, 5, &res, &flg);
    try expect(res == 248);
    try expect(flg.flags.not_zero == 1);
    try expect(flg.flags.parity == 0);
    try expect(flg.flags.sign == 1);
    try expect(flg.flags.carry == 0);
    try expect(flg.flags.overflow == 0);

    xorWithFlags(3, 5, &res, &flg);
    try expect(res == 6);
    try expect(flg.flags.not_zero == 1);
    try expect(flg.flags.parity == 0);
    try expect(flg.flags.sign == 0);
    try expect(flg.flags.carry == 0);
    try expect(flg.flags.overflow == 0);

    bshWithFlags(8, 3, &res, &flg);
    try expect(res == 1);
    try expect(flg.flags.not_zero == 1);
    try expect(flg.flags.parity == 1);
    try expect(flg.flags.sign == 0);
    try expect(flg.flags.carry == 0);
    try expect(flg.flags.overflow == 0);

    bshWithFlags(8, 0b1100, &res, &flg);
    try expect(res == 128);
    try expect(flg.flags.not_zero == 1);
    try expect(flg.flags.parity == 0);
    try expect(flg.flags.sign == 1);
    try expect(flg.flags.carry == 0);
    try expect(flg.flags.overflow == 0);

    bshWithFlags(255, 0b1111, &res, &flg);
    try expect(res == 254);
    try expect(flg.flags.not_zero == 1);
    try expect(flg.flags.parity == 0);
    try expect(flg.flags.sign == 1);
    try expect(flg.flags.carry == 1);
    try expect(flg.flags.overflow == 1);

    bshWithFlags(255, 0, &res, &flg);
    try expect(res == 255);
    try expect(flg.flags.not_zero == 1);
    try expect(flg.flags.parity == 1);
    try expect(flg.flags.sign == 1);
    try expect(flg.flags.carry == 0);
    try expect(flg.flags.overflow == 0);
}