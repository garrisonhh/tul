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
    error{ TestFailure, UnreleasedMemory };

/// a test case; both inputs should match
fn runTest(expected: []const u8, actual: []const u8) TestCaseError!void {
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

        return TestCaseError.TestFailure;
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

fn runTestSet(set: []const tests.Test) TestCaseError!void {
    for (set) |case| {
        runTest(case[0], case[1]) catch |e| {
            try stderr.print("test failed with: {}\n", .{e});
        };

        if (vm.allocated() > 0) {
            try stderr.print("unreleased memory after test:\n", .{});
            vm.inspectMemory();

            return TestCaseError.UnreleasedMemory;
        }
    }
}

const tests = struct {
    const Test = [2][]const u8;

    fn selfEvalSet(comptime set: []const []const u8) [set.len]Test {
        comptime {
            var arr: [set.len]Test = undefined;
            for (set, 0..) |str, i| {
                arr[i] = .{ str, str };
            }

            return arr;
        }
    }

    const literals = selfEvalSet(&.{
        // bool
        "true",
        "false",

        // int
        "0",
        std.fmt.comptimePrint("{d}", .{std.math.minInt(i64)}),
        std.fmt.comptimePrint("{d}", .{std.math.maxInt(i64)}),

        // string
        \\"a string to be parsed"
        ,
        \\"escape sequences: \r\n\"'"
        ,
    }) ++ selfEvalSet(&b: {
        // builtins
        const values = std.enums.values(Object.Builtin);

        var arr: [values.len][]const u8 = undefined;
        for (values, 0..) |b, i| {
            arr[i] = b.name();
        }

        break :b arr;
    });

    const operators = [_]Test{
        .{ "true", "(and (not false) true)" },
        .{ "4", "(+ 2 2)" },
        .{ "6", "(/ (* 3 4) 2)" },
        .{
            \\"hello, world!"
            ,
            \\(++ "hello" ", " "world" "!")
        },
    };
};

test "tul-tests" {
    try init();
    defer deinit();

    try runTestSet(&tests.literals);
    try runTestSet(&tests.operators);
}
