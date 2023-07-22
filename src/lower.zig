const std = @import("std");
const Allocator = std.mem.Allocator;
const vm = @import("vm.zig");
const bc = @import("bytecode.zig");
const Builder = bc.Builder;
const Object = @import("object.zig").Object;

const LowerError = error{
    BadArity,

    // TODO eradicate these
    TodoVars,
    TodoApplied,
};

pub const Error = Allocator.Error || LowerError;

/// metadata about how to lower a builtin
const BuiltinMeta = union(enum) {
    const Reduction = struct {
        inst: bc.Inst,
        min_arity: usize,
    };

    unary: bc.Inst,
    reduction: Reduction,

    list,
};

fn getBuiltinMetadata(b: Object.Builtin) BuiltinMeta {
    const mk = struct {
        fn unary(inst: bc.Inst) BuiltinMeta {
            return .{ .unary = inst };
        }

        fn reduction(inst: bc.Inst, min_arity: usize) BuiltinMeta {
            return .{ .reduction = .{ .inst = inst, .min_arity = min_arity } };
        }
    };

    return switch (b) {
        .inspect => mk.unary(.inspect),
        .add => mk.reduction(.add, 2),
        .sub => mk.reduction(.sub, 2),
        .mul => mk.reduction(.mul, 2),
        .div => mk.reduction(.div, 2),
        .mod => mk.reduction(.mod, 2),
        .@"and" => mk.reduction(.land, 2),
        .@"or" => mk.reduction(.lor, 2),
        .not => mk.unary(.lnot),
        .list => .list,
        .concat => mk.reduction(.concat, 2),
    };
}

fn lowerAppliedBuiltin(
    bob: *Builder,
    b: Object.Builtin,
    arity: usize,
) Error!void {
    switch (getBuiltinMetadata(b)) {
        .unary => |inst| {
            if (arity != 1) return LowerError.BadArity;
            try bob.addInst(inst);
        },
        .reduction => |red| {
            if (arity < red.min_arity) return LowerError.BadArity;
            for (0..arity - 1) |_| {
                try bob.addInst(red.inst);
            }
        },
        .list => {
            try bob.addInstC(.list, @as(u32, @intCast(arity)));
        },
    }
}

/// lower a ref being called as a function
fn lowerApplied(bob: *Builder, ref: Object.Ref, arity: usize) Error!void {
    switch (vm.get(ref).*) {
        .tag => |ident| {
            if (Object.Builtin.fromName(ident)) |b| {
                try lowerAppliedBuiltin(bob, b, arity);
            } else {
                return Error.TodoApplied;
            }
        },
        else => return Error.TodoApplied,
    }
}

fn lowerApplication(
    bob: *Builder,
    expr: Object.Ref,
    refs: []const Object.Ref,
) Error!void {
    // unit evaluates to unit
    if (refs.len == 0) {
        try bob.loadConst(expr);
        return;
    }

    // function call
    for (refs[1..]) |arg| {
        try lowerValue(bob, arg);
    }

    const arity = refs.len - 1;
    try lowerApplied(bob, refs[0], arity);
}

/// lower the evaluation of a tag as an identifier
fn lowerValueIdent(bob: *Builder, ident: []const u8) Error!void {
    if (Object.Builtin.fromName(ident)) |b| {
        // builtins read as values evaluate to themselves
        const ref = try vm.new(.{ .builtin = b });
        defer vm.deacq(ref);
        try bob.loadConst(ref);
    } else {
        // read a var
        return LowerError.TodoVars;
    }
}

/// lower a ref being read as a value
fn lowerValue(bob: *Builder, ref: Object.Ref) Error!void {
    switch (vm.get(ref).*) {
        .bool, .int, .string, .builtin => try bob.loadConst(ref),
        .tag => |ident| try lowerValueIdent(bob, ident),
        .list => |refs| try lowerApplication(bob, ref, refs),
    }
}

/// lower some code to bytecode for execution
///
/// TODO this will very soon need to return a representation of an entire
/// program rather than a single function (unless I can have function nesting
/// or something? lambda-ness would be cool)
pub fn lower(ally: Allocator, code: Object.Ref) Error!bc.Function {
    var bob = Builder.init(ally);
    errdefer bob.deinit();
    try lowerValue(&bob, code);

    return bob.build();
}
