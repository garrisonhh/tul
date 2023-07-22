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

/// metadata about how to lower a builtin. there are many more builtins than
/// there are unique methods to lower builtins, this abstracts over that idea
const BuiltinMeta = union(enum) {
    const Pure = struct {
        inst: bc.Inst,
        params: usize,
    };

    const Reduction = struct {
        inst: bc.Inst,
        min_arity: usize,
    };

    /// takes an exact number of parameters, outputs one value
    pure: Pure,
    /// reduce over some number of ops
    reduction: Reduction,

    list,
    @"if",
};

fn getBuiltinMetadata(b: Object.Builtin) BuiltinMeta {
    const mk = struct {
        fn pure(inst: bc.Inst, params: usize) BuiltinMeta {
            return .{ .pure = .{ .inst = inst, .params = params } };
        }

        fn reduction(inst: bc.Inst, min_arity: usize) BuiltinMeta {
            return .{ .reduction = .{ .inst = inst, .min_arity = min_arity } };
        }
    };

    return switch (b) {
        .inspect => mk.pure(.inspect, 1),
        .add => mk.reduction(.add, 2),
        .sub => mk.reduction(.sub, 2),
        .mul => mk.reduction(.mul, 2),
        .div => mk.reduction(.div, 2),
        .mod => mk.reduction(.mod, 2),
        .@"and" => mk.reduction(.land, 2),
        .@"or" => mk.reduction(.lor, 2),
        .not => mk.pure(.lnot, 1),
        .eq => mk.pure(.eq, 2),
        .list => .list,
        .concat => mk.reduction(.concat, 2),
        .@"if" => .@"if",
    };
}

fn lowerAppliedBuiltin(
    bob: *Builder,
    b: Object.Builtin,
    args: []const Object.Ref,
) Error!void {
    switch (getBuiltinMetadata(b)) {
        .pure => |pure| {
            if (args.len != pure.params) return LowerError.BadArity;
            try lowerValues(bob, args);
            try bob.addInst(pure.inst);
        },
        .reduction => |red| {
            if (args.len < red.min_arity) return LowerError.BadArity;

            try lowerValue(bob, args[0]);
            for (1..args.len) |i| {
                try lowerValue(bob, args[i]);
                try bob.addInst(red.inst);
            }
        },
        .list => {
            try lowerValues(bob, args);
            // TODO in future zig, this explicit `@as` should be unnecessary
            try bob.addInstC(.list, @as(u32, @intCast(args.len)));
        },
        .@"if" => {
            if (args.len != 3) return LowerError.BadArity;

            const cond = args[0];
            const if_true = args[1];
            const if_false = args[2];

            try lowerValue(bob, cond);
            const if_true_back = try bob.addInstBackRef(.branch);
            try lowerValue(bob, if_false);
            const end_back = try bob.addInstBackRef(.jump);
            try bob.nail(if_true_back);
            try lowerValue(bob, if_true);
            try bob.nail(end_back);
        },
    }
}

/// lower the evaluation of an application
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
    const applied = vm.get(refs[0]);
    const args = refs[1..];

    // builtins are a special case
    if (applied.* == .tag) {
        if (Object.Builtin.fromName(applied.tag)) |b| {
            try lowerAppliedBuiltin(bob, b, args);
            return;
        }
    }

    // evaluate applied as a value and call it
    return Error.TodoApplied;
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

fn lowerValues(bob: *Builder, refs: []const Object.Ref) Error!void {
    for (refs) |ref| try lowerValue(bob, ref);
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
