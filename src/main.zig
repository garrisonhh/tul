const std = @import("std");
const stdout = std.io.getStdOut().writer();
const com = @import("common");
const vm = @import("vm.zig");
const bc = @import("bytecode.zig");
const Object = @import("object.zig").Object;
const parser = @import("parser.zig");
const lower = @import("lower.zig");

comptime {
    std.testing.refAllDeclsRecursive(bc);
}

fn init() !void {
    // stub
}

fn deinit() void {
    vm.deinit();
}

pub fn main() !void {
    // boilerplate
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const ally = gpa.allocator();

    try init();
    defer deinit();

    // behavior
    const progs = [_][]const u8{
        "(and (not false true) true)",
        "(+ 2 2)",
        "(/ (* 3 4) 2)",
    };

    for (progs) |prog| {
        // execution
        const start_time = com.time.now();

        const code = try parser.parse(ally, prog);
        defer vm.deacq(code);

        const parse_time = com.time.now();

        const func = try lower.lower(ally, code);
        defer func.deinit(ally);

        const lower_time = com.time.now();

        const res = try vm.run(func);
        defer vm.deacq(res);

        const exec_time = com.time.now();

        // output
        try stdout.print("[program]\n{s}\n\n", .{prog});
        try stdout.print("[code]\n{}\n\n", .{vm.get(code)});
        try stdout.print("[bytecode]\n", .{});
        try func.display(stdout);
        try stdout.print("\n", .{});
        try stdout.print("[result]\n{}\n\n", .{vm.get(res)});

        try stdout.print(
            \\[timing]
            \\total     {[total]d:.6}s
            \\parsing   {[parse]d:.6}s
            \\lowering  {[lower]d:.6}s
            \\execution {[exec]d:.6}s
            \\ 
            \\
        ,
            .{
                .total = exec_time - start_time,
                .parse = parse_time - start_time,
                .lower = lower_time - parse_time,
                .exec = exec_time - lower_time,
            },
        );
    }
}
