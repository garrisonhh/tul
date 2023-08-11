//! the plumbing of tul. globally used functions that tie together large parts
//! of the codebase

const builtin = @import("builtin");
const std = @import("std");
const stderr = std.io.getStdErr().writer();
const gc = @import("gc.zig");
const registry = @import("registry.zig");
const Object = @import("object.zig").Object;
const parsing = @import("parser.zig");
const lowering = @import("lower.zig");
const vm = @import("vm.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const ally = gpa.allocator();

pub fn init() error{}!void {
    // stub
}

pub fn deinit() void {
    registry.deinit();
    gc.deinit();
    _ = gpa.deinit();

    // gpa may be reused in testing
    if (builtin.is_test) {
        gpa = .{};
    }
}

pub const EvalError = lowering.Error || vm.PipelineError;
pub const ExecError = parsing.Error || EvalError;

pub fn evalFunction(
    arglist: Object.Ref,
    code: Object.Ref,
) lowering.Error!Object.Ref {
    // make args
    var args = lowering.Args{};
    defer args.deinit(ally);

    const list = gc.get(arglist).list;
    for (list, 0..) |ref, i| {
        const id = gc.get(ref).tag;
        try args.put(ally, id, @intCast(i));
    }

    // lower
    return try lowering.lower(&args, code);
}

pub fn eval(code: Object.Ref) EvalError!Object.Ref {
    const func = try lowering.lower(null, code);
    defer gc.deacq(func);

    return try vm.run(func);
}

/// evaluate a program starting from text
pub fn exec(name: []const u8, program: []const u8) ExecError!Object.Ref {
    const code = try parsing.parse(ally, name, program);
    defer gc.deacq(code);

    return try eval(code);
}
