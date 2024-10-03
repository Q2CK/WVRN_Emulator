pub const FlagsRepr = packed struct {
    overflow: u1,
    carry: u1,
    sign: u1,
    not_zero: u1,
    parity: u1,
    b: u1,
    a: u1,
    always_true: u1 = 1,
};

pub const Flags = packed union {
    const Self = @This();

    flags: FlagsRepr,
    byte: u8,

    pub fn init() Self {
        return Self {
            .byte = 0b10000000
        };
    }

    pub fn reset(self: *Self) void {
        self.byte = 0b10000000;
    }
};
