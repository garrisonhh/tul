const test_options = @import("test_options");
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

fn init() error{}!void {
    // stub
}

fn deinit() void {
    vm.deinit();
    _ = gpa.deinit();
}

const ExecError = parser.Error || lower.Error || vm.RuntimeError;

/// one execution cycle
fn exec(program: []const u8) ExecError!Object.Ref {
    const code = try parser.parse(ally, program);
    defer vm.deacq(code);
    const func = try lower.lower(ally, code);
    defer func.deinit(ally);

    return try vm.run(func);
}

pub fn main() !void {
    try init();
    defer deinit();

    @panic("TODO");
}

// testing =====================================================================

const TestCaseError =
    ExecError ||
    @TypeOf(stderr).Error ||
    error{TestFailure};

/// a test case; both inputs should match
fn tulTestCase(expected: []const u8, actual: []const u8) TestCaseError!void {
    const exp = try exec(expected);
    defer vm.deacq(exp);
    const got = try exec(actual);
    defer vm.deacq(got);

    // check for equality
    if (!Object.eql(exp, got)) {
        try stderr.print(
            \\[actual input]
            \\{s}
            \\[actual output]
            \\{}
            \\
            \\[expected input]
            \\{s}
            \\[expected output]
            \\{}
            \\
        ,
            .{ actual, vm.get(got), expected, vm.get(exp) },
        );

        return error.TestFailure;
    } else if (test_options.verbose) {
        try stderr.print(
            \\[input]
            \\{s}
            \\[output]
            \\{s}
            \\
            \\
        ,
            .{ actual, vm.get(got) },
        );
    }
}

/// a test case that evaluates to itself
fn selfEval(case: []const u8) [2][]const u8 {
    return .{ case, case };
}

const tul_test_cases = [_][2][]const u8{
    .{ "true", "(and (not false) true)" },
    .{ "4", "(+ 2 2)" },
    .{ "6", " (/ (* 3 4) 2)" },
    selfEval(
        \\"a string to be parsed"
    ),
    selfEval(
        \\"escape sequences: \r\n\"\'"
    ),
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
