const builtin = @import("builtin");
const test_options = @import("test_options");
const std = @import("std");
const stderr = std.io.getStdErr().writer();
const stdout = std.io.getStdOut().writer();
const com = @import("common");
const gc = @import("gc.zig");
const pipes = @import("pipes.zig");
const Object = @import("object.zig").Object;

pub fn main() !void {
    try pipes.init();
    defer pipes.deinit();

    const code =
        \\(eval (quote (+ 1 2 3 4)))
        \\
    ;

    const out = try pipes.exec(code);
    defer gc.deacq(out);

    try stdout.print("{}\n", .{gc.get(out)});
}

// testing =====================================================================

comptime {
    if (builtin.is_test) {
        std.testing.refAllDeclsRecursive(@This());
    }
}

const TestCaseError =
    pipes.ExecError ||
    @TypeOf(stderr).Error ||
    error{ TestFailure, UnreleasedMemory };

/// a test case; both inputs should match
fn runTest(expected: []const u8, actual: []const u8) TestCaseError!void {
    const exp = try pipes.exec(expected);
    defer gc.deacq(exp);
    const got = try pipes.exec(actual);
    defer gc.deacq(got);

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
            .{ actual, gc.get(got), expected, gc.get(exp) },
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
            .{ actual, gc.get(got) },
        );
    }
}

fn runTestSet(set: []const tests.Test) TestCaseError!void {
    for (set) |case| {
        runTest(case[0], case[1]) catch |e| {
            try stderr.print(
                \\test failed with: {[err]}
                \\[expected]
                \\{[expected]s}
                \\[actual]
                \\{[actual]s}
                \\
            ,
                .{
                    .err = e,
                    .expected = case[0],
                    .actual = case[1],
                },
            );

            return e;
        };

        if (gc.allocated() > 0) {
            try stderr.print("unreleased memory after test:\n", .{});
            gc.inspectMemory();

            return TestCaseError.UnreleasedMemory;
        }
    }
}

const tests = struct {
    const Test = [2][]const u8;

    fn selfEval(str: []const u8) Test {
        return .{ str, str };
    }

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
        .{ "true", "(== 3 3)" },
        .{ "false", "(== -123 4)" },
        .{ "false", "(== false 4)" },
        .{ "true", "(== true true)" },
        .{ "true", "(== false false)" },
        .{ "false", "(== true false)" },
        .{ "true", "(== (list 1 2) (list 1 2))" },
        .{ "true", "(== (list 1 (list 2 3)) (list 1 (list 2 3)))" },
        .{ "false", "(== (list 1 2) (list 420))" },
        .{
            \\"hello, world!"
            ,
            \\(++ "hello" ", " "world" "!")
        },
        selfEval("(list)"),
        selfEval("(list list)"),
        selfEval("(list 1 2 3)"),
        selfEval("(list (list (list 1) 2) 3)"),
        .{
            "(list 1 2 3 4 5 6)",
            "(++ (list 1 2 3) (list 4 5 6))",
        },
        .{ "1", "(if true 1 2)" },
        .{ "2", "(if false 1 2)" },
        .{ "(map)", "(map)" },
        .{ "(map 1 2)", "(map 1 2)" },
        .{ "2", "(get (map 1 2) 1)" },
        .{ "(list)", "(get (map 1 2) 3)" },
        .{
            \\"world"
            ,
            \\(get (put (map) "hello" "world") "hello")
        },
    };
};

test "tul" {
    try pipes.init();
    defer pipes.deinit();

    try runTestSet(&tests.literals);
    try runTestSet(&tests.operators);
}
