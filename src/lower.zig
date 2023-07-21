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
        .add => mk.reduction(.add, 2),
        .sub => mk.reduction(.sub, 2),
        .mul => mk.reduction(.mul, 2),
        .div => mk.reduction(.div, 2),
        .mod => mk.reduction(.mod, 2),
        .@"and" => mk.reduction(.land, 2),
        .@"or" => mk.reduction(.lor, 2),
        .not => mk.unary(.lnot),
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

/// lower a ref being read as a value
fn lowerValue(bob: *Builder, ref: Object.Ref) Error!void {
    switch (vm.get(ref).*) {
        .tag => return Error.TodoVars,
        .bool, .int, .string => try bob.loadConst(ref),
        .builtin => @panic("TODO lower builtins"),
        .list => |refs| {
            // unit evaluates to unit
            if (refs.len == 0) {
                try bob.loadConst(ref);
                return;
            }

            // function call
            for (refs[1..]) |arg| {
                try lowerValue(bob, arg);
            }

            const arity = refs.len - 1;
            try lowerApplied(bob, refs[0], arity);
        },
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
