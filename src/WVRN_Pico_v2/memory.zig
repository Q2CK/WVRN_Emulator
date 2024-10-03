pub const Memory = struct {
    const Self = @This();

    bytes: [65536]u8,

    pub fn get(self: Self, address: u16) u8 {
        return self.bytes[address];
    }

    pub fn set(self: *Self, address: u16, value: u8) void {
        self.bytes[address] = value;
    }

    pub fn init() Self {
        return Self {
            .bytes = [_]u8{0} ** 65536
        };
    }
};