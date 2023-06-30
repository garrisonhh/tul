const std = @import("std");
const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();
const com = @import("common");
const vm = @import("vm.zig");
const bc = @import("bytecode.zig");
const Object = @import("object.zig").Object;
const parser = @import("parser.zig");
const lower = @import("lower.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const ally = gpa.allocator();

fn init() !void {
    // stub
}

fn deinit() void {
    vm.deinit();
    _ = gpa.deinit();
}

/// one execution cycle
fn exec(program: []const u8) !Object.Ref {
    const code = try parser.parse(ally, program);
    const func = try lower.lower(ally, code);
    vm.deacq(code);

    const res = try vm.run(func);
    func.deinit(ally);

    return res;
}

pub fn main() !void {
    try init();
    defer deinit();

    @panic("TODO");
}

// testing =====================================================================

/// a test case; both inputs should match
fn tulTestCase(expected: []const u8, actual: []const u8) !void {
    const exp = try exec(expected);
    defer vm.deacq(exp);
    const got = try exec(actual);
    defer vm.deacq(got);

    // check for equality
    if (!Object.eql(exp, got)) {
        try stderr.print(
            \\[expected input]
            \\{s}
            \\[actual input]
            \\{s}
            \\
            \\[expected output]
            \\{}
            \\[actual output]
            \\{}
            \\
        ,
            .{ expected, actual, vm.get(exp), vm.get(got) },
        );

        return error.TestFailure;
    }
}

const tul_test_cases = [_][2][]const u8{
    .{ "true", "(and (not false) true)" },
    .{ "4", "(+ 2 2)" },
    .{ "6", " (/ (* 3 4) 2)" },
};

test "tul-test-cases" {
    try init();
    defer deinit();

    for (tul_test_cases) |case| {
        tulTestCase(case[0], case[1]) catch |e| {
            try stderr.print("test failed with: {}\n", .{e});
        };

        if (vm.allocated() > 0) {
            try stderr.print("unreleased memory after test:\n", .{});
            vm.inspectMemory();

            return error.UnreleasedMemory;
        }
    }
}
