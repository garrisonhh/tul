//! the plumbing of tul. globally used functions that tie together large parts
//! of the codebase

const builtin = @import("builtin");
const std = @import("std");
const stderr = std.io.getStdErr().writer();
const tul = @import("tul.zig");
const Object = tul.Object;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const ally = gpa.allocator();

pub fn init() error{}!void {
    // stub
}

pub fn deinit() void {
    tul.registry.deinit();
    tul.gc.deinit();
    _ = gpa.deinit();

    // gpa may be reused in testing
    if (builtin.is_test) {
        gpa = .{};
    }
}

pub const EvalError = tul.lowering.Error || tul.vm.PipelineError;
pub const ExecError = tul.parsing.Error || EvalError;

pub fn evalFunction(
    arglist: Object.Ref,
    code: Object.Ref,
) tul.lowering.Error!Object.Ref {
    // make args
    var args = tul.lowering.Args{};
    defer args.deinit(ally);

    const list = tul.get(arglist).list;
    for (list, 0..) |ref, i| {
        const id = tul.get(ref).tag;
        try args.put(ally, id, @intCast(i));
    }

    return try tul.lowering.lower(&args, code);
}

pub fn eval(code: Object.Ref) EvalError!Object.Ref {
    const func = try tul.lowering.lower(null, code);
    defer tul.deacq(func);

    return try tul.vm.run(func);
}

/// evaluate a program starting from text
pub fn exec(name: []const u8, program: []const u8) ExecError!Object.Ref {
    const code = try tul.parsing.parse(ally, name, program);
    defer tul.deacq(code);

    return try eval(code);
}
