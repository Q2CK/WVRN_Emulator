pub const FlagsRepr = packed struct {
    unused: u1,
    a: u1,
    b: u1,
    overflow: u1,
    sign: u1,
    parity: u1,
    not_zero: u1,
    carry: u1
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
