const std = @import("std");

const app = @import("app.zig");

pub fn main() !void {
    try app.run();
}

