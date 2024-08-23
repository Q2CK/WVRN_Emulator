const flags = @import("flags.zig");
const Flags = flags.Flags;

pub usingnamespace flags;

pub const Registers = struct {
    const Self = @This();

    general_purpose: [28]u8,
    flags: Flags,
    segment: u8,
    accumulator: u8,

    pub fn init() Self {
        return Self {
            .general_purpose = [_]u8{0} ** 28,
            .flags = Flags.init(),
            .segment = 0,
            .accumulator = 0
        };
    }

    pub fn reset(self: *Self) void {
        self.general_purpose = [_]u8{0} ** 28;
        self.flags.reset();
        self.segment = 0;
        self.accumulator = 0;
    }

    pub fn get(self: Self, idx: u5) u8 {
        return switch(idx) {
            0 => 0,
            1 => self.accumulator,
            2 => self.flags.byte,
            3 => self.segment,
            4...31 => self.general_purpose[idx - 4]
        };
    }

    pub fn set(self: *Self, idx: u5, value: u8) void {
        switch(idx) {
            0 => {},
            1 => self.accumulator = value,
            2 => self.flags.byte = value,
            3 => self.segment = value,
            4...31 => self.general_purpose[idx - 4] = value
        }
    }
};