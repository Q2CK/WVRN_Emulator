pub const Opcode = enum(u4) {
    EXT    = 0b1000,
    STA    = 0b0000,
    LDA    = 0b0001,
    LDA_f  = 0b1001,
    ADD    = 0b0010,
    ADD_f  = 0b1010,
    ADDI   = 0b0011,
    ADDI_f = 0b1011,
    NAND   = 0b0100,
    NAND_f = 0b1100,
    LD     = 0b0101,
    LD_f   = 0b1101,
    ST     = 0b1110,
    B      = 0b0111,
    B_h    = 0b1111
};

pub const Instruction = packed struct {
    const Self = @This();

    opcode: Opcode,
    operand: u4,
};