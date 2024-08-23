pub const Opcode = enum(u3) {
    EXT, // Extended opcodes
    SWA,
    ADD,
    ADDI,
    NAND,
    LD,
    ST,
    B,
};

pub const Instruction = packed struct {
    const Self = @This();

    opcode: Opcode,
    operand5bit: u5,
};