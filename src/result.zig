const std = @import("std");

pub const Result = union(enum) {
    Ok: void,
    Err: []const u8,

    const Self = @This();

    pub fn ok() Self {
        return Self{ .Ok = {} };
    }

    pub fn err(alloc: std.mem.Allocator, format_string: []const u8, args: anytype) Self {
        const error_string = std.fmt.allocPrint(alloc, format_string, args) catch "Out of memory";

        return Self{ .Err = error_string };
    }

    pub fn errStatic(string: []const u8) Self {
        return Self{ .Err = string };
    }

    pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
        if(self == .Err) |msg| {
            alloc.free(msg);
        }
    }
};