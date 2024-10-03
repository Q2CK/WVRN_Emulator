const std = @import("std");

const result = @import("result.zig");
const Result = result.Result;

const Status = @import("cpu_status.zig").Status;

const wvrn_nano = @import("WVRN_Nano/cpu.zig");
const wvrn_pico = @import("WVRN_Pico/cpu.zig");
const wvrn_pico_v2 = @import("WVRN_Pico_v2/cpu.zig");

const CPUType = enum {
    WVRN_Nano,
    WVRN_Pico,
    WVRN_Pico_v2
};

const CPU = union(CPUType) {
    const Self = @This();

    WVRN_Nano: wvrn_nano.CPU,
    WVRN_Pico: wvrn_pico.CPU,
    WVRN_Pico_v2: wvrn_pico_v2.CPU,

    pub fn init(cpu_type: CPUType) Self {
        return switch(cpu_type) {
            .WVRN_Nano => Self{ .WVRN_Nano = wvrn_nano.CPU.init() },
            .WVRN_Pico => Self{ .WVRN_Pico = wvrn_pico.CPU.init() },
            .WVRN_Pico_v2 => Self{ .WVRN_Pico_v2 = wvrn_pico_v2.CPU.init() }
        };
    }

    pub fn reset(self: *Self) void {
        switch(self.*) {
            .WVRN_Nano => |*cpu| cpu.reset(),
            .WVRN_Pico => |*cpu| cpu.reset(),
            .WVRN_Pico_v2 => |*cpu| cpu.reset()
        }
    }

    pub fn tick(self: *Self) void {
        switch(self.*) {
            .WVRN_Nano => |*cpu| cpu.tick(),
            .WVRN_Pico => |*cpu| cpu.tick(),
            .WVRN_Pico_v2 => |*cpu| cpu.tick(),
        }
    }

    pub fn nTicks(self: *Self, n: usize) void {
        switch(self.*) {
            .WVRN_Nano => |*cpu| cpu.nTicks(n),
            .WVRN_Pico => |*cpu| cpu.nTicks(n),
            .WVRN_Pico_v2 => |*cpu| cpu.nTicks(n)
        }
    }

    pub fn setMemory(self: *Self, image: []const u8) void {
        switch(self.*) {
            .WVRN_Nano => |*cpu| @memcpy(cpu.memory[0..image.len], image),
            .WVRN_Pico => |*cpu| @memcpy(cpu.memory[0..image.len], image),
            .WVRN_Pico_v2 => |*cpu| @memcpy(cpu.memory[0..image.len], image),
        }
    }

    pub fn dumpMemory(self: Self) []const u8 {
        switch(self) {
            .WVRN_Nano => |cpu| cpu.memory.bytes,
            .WVRN_Pico => |cpu| cpu.memory.bytes,
            .WVRN_Pico_v2 => |cpu| cpu.memory.bytes,
        }
    }

    pub fn getNextInstruction(self: *Self, buffer: *std.ArrayList(u8)) Result {
        return switch(self.*) {
            .WVRN_Nano => |*cpu| return cpu.getNextInstruction(buffer),
            .WVRN_Pico => |*cpu| return cpu.getNextInstruction(buffer),
            .WVRN_Pico_v2 => |*cpu| return cpu.getNextInstruction(buffer)
        };
    }

    pub fn setQuery(self: *Self, query: []const[]const u8) Result {
        return switch(self.*) {
            .WVRN_Nano => |*cpu| cpu.setQuery(query),
            .WVRN_Pico => |*cpu| cpu.setQuery(query),
            .WVRN_Pico_v2 => |*cpu| cpu.setQuery(query)
        };
    }

    pub fn getQuery(self: *Self, query: []const[]const u8, buffer: *std.ArrayList(u8)) Result {
        return switch(self.*) {
            .WVRN_Nano => |*cpu| cpu.getQuery(query, buffer),
            .WVRN_Pico => |*cpu| cpu.getQuery(query, buffer),
            .WVRN_Pico_v2 => |*cpu| cpu.getQuery(query, buffer)
        };
    }

    pub fn setStatus(self: *Self, status: Status) void {
        switch(self.*) {
            .WVRN_Nano => |*cpu| cpu.status = status,
            .WVRN_Pico => |*cpu| cpu.status = status,
            .WVRN_Pico_v2 => |*cpu| cpu.status = status
        }
    }

    pub fn getStatus(self: Self) Status {
        return switch(self) {
            .WVRN_Nano => |cpu| cpu.status,
            .WVRN_Pico => |cpu| cpu.status,
            .WVRN_Pico_v2 => |cpu| cpu.status
        };
    }

    pub fn loadProgram(self: *Self, program: []const u8) void {
        switch(self.*) {
            .WVRN_Nano => |*cpu| {
                const copy_len = @min(cpu.memory.bytes.len, program.len);
                @memcpy(cpu.memory.bytes[0..copy_len], program[0..copy_len]);
            },
            .WVRN_Pico => |*cpu| {
                const copy_len = @min(cpu.memory.bytes.len, program.len);
                @memcpy(cpu.memory.bytes[0..copy_len], program[0..copy_len]);
            },
            .WVRN_Pico_v2 => |*cpu| {
                const copy_len = @min(cpu.memory.bytes.len, program.len);
                @memcpy(cpu.memory.bytes[0..copy_len], program[0..copy_len]);
            }
        }
    }
};

const AppContext = struct {
    program_file_path: ?[]const u8,
    program_file: ?std.fs.File,

    cpu: CPU,

    pub fn loadProgramFile(self: *AppContext, path: []const u8, alloc: std.mem.Allocator) Result {
        const file = std.fs.cwd().openFile(std.mem.trim(u8, path, "\n\t \r"), .{
            .mode = .read_only
        }) catch return Result.errStatic("Failed to open program file");

        self.program_file_path = path;
        self.program_file = file;

        const program = file.readToEndAlloc(alloc, 65536) catch return Result.errStatic("Failed to read file contents");

        self.cpu.loadProgram(program);

        return Result.ok();
    }

    pub fn reloadProgramFile(self: *AppContext, alloc: std.mem.Allocator) Result {
        if(self.program_file_path) |unwrapped_path| {
            return self.loadProgramFile(unwrapped_path, alloc);
        } else {
            return Result.errStatic("No program file selected");
        }
    }
};

const ReportType = enum {
    Success,
    Error,
    Info
};

fn printReport(writer: anytype, report_type: ReportType, comptime format_string: []const u8, args: anytype) !void {
    switch(report_type) {
        .Success => try writer.print("[\x1b[92m OK \x1b[0m] " ++ format_string ++ "\n", args),
        .Error   => try writer.print("[\x1b[95mFAIL\x1b[0m] "   ++ format_string ++ "\n", args),
        .Info    => try writer.print("[\x1b[96mINFO\x1b[0m] "    ++ format_string ++ "\n", args),
    }
}

pub fn run() !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    var args = try std.process.argsWithAllocator(alloc);
    defer args.deinit();

    var args_list = std.ArrayList([]const u8).init(alloc);
    defer args_list.deinit();

    while(args.next()) |arg| {
        try args_list.append(arg);
    }

    errdefer stdout.print("\x1b[0m", .{}) catch unreachable;
    defer stdout.print("\x1b[0m", .{}) catch unreachable;

    const cwd_path = try std.fs.realpathAlloc(alloc, ".");

    var app_context = AppContext{
        .program_file_path = null,
        .program_file = null,
        .cpu = CPU.init(.WVRN_Pico)
    };

    try stdout.print("\n\x1b[0m\x1b[96mWVRN Emulator\x1b[0m | Q2CK\n\n", .{});

    try printReport(stdout, .Info, "Current working directory: '\x1b[96m{s}\x1b[0m'", .{cwd_path});
    try printReport(stdout, .Info, "Default CPU set to '\x1b[96m{s}\x1b[0m'", .{@tagName(app_context.cpu)});
    try printReport(stdout, .Info, "Use '\x1b[96mhelp\x1b[0m' to print available commands", .{});

    const number_of_args = args_list.items.len;
    switch(number_of_args) {
        0 => {
            try printReport(stdout, .Error, "Couldn't obtain current working directory path\n", .{});
            return;
        },
        1 => {     
            try printReport(stdout, .Info, "Use '\x1b[96mload <relative_path>\x1b[0m' to load a program file", .{});
        },
        2 => {
            switch(app_context.loadProgramFile(args_list.items[1], alloc)) {
                .Ok => {
                    try printReport(stdout, .Success, "Loaded '\x1b[96m{s}\x1b[0m'", .{args_list.items[1]});
                },
                .Err => |msg| {
                    try printReport(stdout, .Error, "{s}", .{msg});
                }
            }
        },
        else => {
            try printReport(stdout, .Error, "Expected 0 or 1 command line parameters, got {d}", .{number_of_args - 1});
        }
    }

    try stdout.print("\x1b[0m\n", .{});

    main_loop: while(true) {
        try stdout.print("\x1b[0m> ", .{});
        const command_raw = try stdin.readUntilDelimiterAlloc(alloc, '\n', 65536);
        const command_stripped = std.mem.trim(u8, command_raw, "\n\t\r ");

        var tokens_iterator = std.mem.tokenizeAny(u8, command_stripped, " \t\n");
        var tokens_list = std.ArrayList([]const u8).init(alloc);
        defer tokens_list.deinit();

        while(tokens_iterator.next()) |token| {
            try tokens_list.append(token);
        }

        if(tokens_list.items.len < 1) {
            try printReport(stdout, .Error, "Failed to parse command", .{});
            continue :main_loop;
        }

        const command = tokens_list.items[0];
        const params = tokens_list.items[1..];

        if(std.mem.eql(u8, tokens_list.items[0], "quit")) {
            return;
        } else if(std.mem.eql(u8, command, "help")) {
            const help_string: []const[]const u8 = &.{
                "\x1b[0mAvailable commands:",
                "",
                "    \x1b[96mhelp \x1b[0m- print available commands",
                "    \x1b[96mquit \x1b[0m- exit the application",
                "",
                "    \x1b[96mcpu \x1b[0m[name]   - select the CPU type or print available CPUs if [name] is omitted",
                "",
                "    \x1b[96mload \x1b[0m<path>  - load a program file (path is relative to the current working directory)",
                "    \x1b[96mstep \x1b[0m[steps] - step the emulator n times or perform a single step if [step] is omitted",
                "    \x1b[96mrun \x1b[0m         - run the emulator continuously until nearest breakpoint or halt instruction",
                "    \x1b[96mreset \x1b[0m       - reset the entire state of the emulator",
                "",
                "    \x1b[96mset \x1b[0m<query>  - manually set the state of a CPU component",
                "    \x1b[96mget \x1b[0m<query>  - read the state of a CPU component",
                "",
                "<param> - obligatory parameter, [param] - optional parameter",
                ""
            };

            for(help_string) |line| {
                try stdout.print("{s}\n", .{line});
            }
        } else if(std.mem.eql(u8, command, "load")) {
            if(params.len != 1) {
                try printReport(stdout, .Error, "Expected 1 parameter, got {d}", .{params.len});
                continue :main_loop;
            }

            switch(app_context.loadProgramFile(params[0], alloc)) {
                .Ok => {
                    try printReport(stdout, .Success, "Loaded '\x1b[96m{s}\x1b[0m'", .{params[0]});
                },
                .Err => |msg| {
                    try printReport(stdout, .Error, "{s}", .{msg});
                    continue :main_loop;
                }
            }
        } else if(std.mem.eql(u8, command, "cpu")) {
            if(params.len == 0) {
                try stdout.print("\x1b[0mAvailable cpus:\n\n", .{});
                inline for(@typeInfo(CPUType).Enum.fields) |field| {
                    try stdout.print("    {s}\n", .{field.name});
                }
                try stdout.print("\n", .{});
            } else if(params.len == 1) {
                const cpu_type: CPUType = cpu_types: inline for(@typeInfo(CPUType).Enum.fields) |field| {
                    if(std.mem.eql(u8, field.name, params[0])) {
                        break :cpu_types @enumFromInt(field.value);
                    }
                } else {
                    try printReport(stdout, .Error, "No CPU type named '\x1b[96m{s}\x1b[0m'", .{params[0]});
                    continue :main_loop;
                };

                app_context.cpu = CPU.init(cpu_type);
                try printReport(stdout, .Success, "CPU type set to '\x1b[96m{s}\x1b[0m'", .{params[0]});
            } else {
                try printReport(stdout, .Error, "Expected 0 or 1 parameter(s), got {d}", .{params.len});
                continue :main_loop;
            }
        } else if(std.mem.eql(u8, command, "step")) {
            if(params.len == 0) {
                if(app_context.program_file) |_| {
                    app_context.cpu.tick();
                    try printReport(stdout, .Success, "Executed \x1b[96m1\x1b[0m clock cycle", .{});

                    var buffer = std.ArrayList(u8).init(alloc);
                    defer buffer.deinit();
                    switch(app_context.cpu.getNextInstruction(&buffer)) {
                        .Ok => try printReport(stdout, .Info, "Next instruction: {s}", .{buffer.items}),
                        .Err => try printReport(stdout, .Error, "Failed to read next instruction", .{})
                    }
                } else {
                    try printReport(stdout, .Error, "No program file loaded", .{});
                }
            } else if(params.len == 1) {
                if(app_context.program_file) |_| {
                    const parsed_int = std.fmt.parseInt(usize, params[0], 0) catch {
                        try printReport(stdout, .Error, "Failed to parse the provided number of ticks", .{});
                        continue :main_loop;
                    };
                    app_context.cpu.nTicks(parsed_int);
                    try printReport(stdout, .Success, "Executed \x1b[96m{d}\x1b[0m clock cycle(s)", .{parsed_int});
                } else {
                    try printReport(stdout, .Error, "No program file loaded", .{});
                }
            } else {
                try printReport(stdout, .Error, "Expected 0 or 1 parameter(s), got {d}", .{params.len});
                continue :main_loop;
            }
        } else if(std.mem.eql(u8, command, "run")) {
            var cycle_counter: usize = 0;
            if(params.len == 0) {
                if(app_context.program_file) |_| {
                    app_context.cpu.setStatus(.Run);
                    while(app_context.cpu.getStatus() == .Run) {
                        app_context.cpu.tick();
                        cycle_counter += 1;
                    }
                    try printReport(stdout, .Success, "Executed \x1b[96m{}\x1b[0m clock cycle(s)", .{cycle_counter});
                } else {
                    try printReport(stdout, .Error, "No program file loaded", .{});
                } 
            } else {
                try printReport(stdout, .Error, "Expected 0 parameters, got {d}", .{params.len});
                continue :main_loop;
            }
        } else if(std.mem.eql(u8, command, "reset")) {
            if(params.len == 0) {
                app_context.cpu.reset();
                try printReport(stdout, .Success, "CPU reset to initial state", .{});
                switch(app_context.reloadProgramFile(alloc)) {
                    .Ok => {
                        try printReport(stdout, .Success, "Reloaded '\x1b[96m{s}\x1b[0m'", .{app_context.program_file_path orelse "?"});
                    },
                    .Err => |msg| {
                        try printReport(stdout, .Error, "{s}", .{msg});
                        continue :main_loop;
                    }
                }
            } else {
                try printReport(stdout, .Error, "Expected 0 parameters, got {d}", .{params.len});
                continue :main_loop;
            }
        } else if(std.mem.eql(u8, command, "get")) {
            if(params.len > 0) {
                var buffer = std.ArrayList(u8).init(alloc);
                defer buffer.deinit();
                switch(app_context.cpu.getQuery(params,&buffer)) {
                    .Ok => {
                        try printReport(stdout, .Success, "{s}", .{buffer.items});
                    },
                    .Err => |msg| {
                        try printReport(stdout, .Error, "{s}", .{msg});
                    }
                }
            } else {
                try printReport(stdout, .Error, "Expected more than 0 parameters, got {d}", .{params.len});
                continue :main_loop;
            }
        } else if(std.mem.eql(u8, command, "set")) {
            if(params.len > 0) {
                switch(app_context.cpu.setQuery(params)) {
                    .Ok => {
                        try printReport(stdout, .Success, "Changed component state", .{});
                    },
                    .Err => |msg| {
                        try printReport(stdout, .Error, "{s}", .{msg});
                    }
                }
            } else {
                try printReport(stdout, .Error, "Expected more than 0 parameters, got {d}", .{params.len});
                continue :main_loop;
            }
        } else {
            try printReport(stdout, .Error, "Command not recognised", .{});
        }
    }
}