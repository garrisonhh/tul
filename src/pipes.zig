//! the plumbing of tul. globally used functions that tie together large parts
//! of the codebase

const builtin = @import("builtin");
const test_options = @import("test_options");
const std = @import("std");
const stderr = std.io.getStdErr().writer();
const gc = @import("gc.zig");
const parser = @import("parser.zig");
const lower = @import("lower.zig");
const vm = @import("vm.zig");
const Object = @import("object.zig").Object;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const ally = gpa.allocator();

pub fn init() error{}!void {
    // stub
}

pub fn deinit() void {
    gc.deinit();
    _ = gpa.deinit();

    // gpa may be reused in testing
    if (builtin.is_test) {
        gpa = .{};
    }
}

pub const EvalError = lower.Error || vm.PipelineError;
pub const ExecError = parser.Error || EvalError;

pub fn evalFunction(
    arglist: Object.Ref,
    code: Object.Ref,
) lower.Error!Object.Ref {
    // make args
    var args = lower.Args{};
    defer args.deinit(ally);

    const list = gc.get(arglist).list;
    for (list, 0..) |ref, i| {
        const id = gc.get(ref).tag;
        try args.put(ally, id, @intCast(i));
    }

    // lower
    const func = try lower.lower(&args, code);

    if (builtin.is_test and test_options.verbose) {
        stderr.print("[lowered function bytecode]\n", .{}) catch {};
        gc.get(func).@"fn".display(stderr) catch {};
    }

    return func;
}

pub fn eval(code: Object.Ref) EvalError!Object.Ref {
    const func = try lower.lower(null, code);
    defer gc.deacq(func);

    if (builtin.is_test and test_options.verbose) {
        stderr.print("[evaluating bytecode]\n", .{}) catch {};
        gc.get(func).@"fn".display(stderr) catch {};
    }

    return try vm.run(func);
}

/// evaluate a program starting from text
pub fn exec(program: []const u8) ExecError!Object.Ref {
    const code = try parser.parse(ally, program);
    defer gc.deacq(code);

    return try eval(code);
}
