pub const Opcode = enum(u4) {
    EXT, // Extended opcodes
    STA, // REG <= ACC
    LDA, // ACC <= REG
    ADD, // ACC <= ACC + REG
    SUB, // ACC <= REG - ACC
    ADC, // ACC <= ACC + REG + CARRY
    AND, // ACC <= ACC & REG
    NOR, // ACC <= ~(ACC | REG)
    XOR, // ACC <= ACC ^ REG
    BSH, // ACC << (sign extended)IMM (negative = left)
    LIM, // ACC <= (sign exgended)IMM
    AIM, // ACC <= ACC + (sign extended)IMM
    MLD, // ACC <= MEM[{SEG, REG} + (sign extended)IMM]
    MST, // MEM[{SEG, REG} + (sign extended)IMM] <= ACC
    BRC, // PC <= PC + (sign extended)IMM
    JAL  // {SEG, ACC} <= PC + 2, PC <= {SEG, REG} + (sign extended)IMM
};

pub const Instruction = packed struct {
    const Self = @This();

    operand4bit: u4,
    opcode: Opcode,
    operand8bit: u8,
};