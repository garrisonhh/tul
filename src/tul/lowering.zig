const std = @import("std");
const Allocator = std.mem.Allocator;
const tul = @import("tul.zig");
const bc = tul.bc;
const Builder = bc.Builder;
const Object = tul.Object;

const LowerError = error{
    BadArity,

    // TODO eradicate these
    TodoVars,
    TodoLowerMap,
};

pub const Error = Allocator.Error || LowerError;

/// metadata about how to lower a builtin. there are many more builtins than
/// there are unique methods to lower builtins, this abstracts over that idea
const BuiltinMeta = union(enum) {
    const Pure = struct {
        inst: bc.Inst,
        params: usize,
    };

    const Quoted = struct {
        inst: bc.Inst,
        params: usize,
    };

    const Reduction = struct {
        inst: bc.Inst,
        min_arity: usize,
    };

    /// takes an exact number of parameters, outputs one value
    pure: Pure,
    /// pure but parameters are lowered as constants (quoted code)
    quoted: Quoted,
    /// reduce over some number of ops
    reduction: Reduction,

    list,
    map,
    @"if",
};

fn getBuiltinMetadata(b: Object.Builtin) BuiltinMeta {
    const mk = struct {
        fn pure(inst: bc.Inst, params: usize) BuiltinMeta {
            return .{ .pure = .{ .inst = inst, .params = params } };
        }

        fn quoted(inst: bc.Inst, params: usize) BuiltinMeta {
            return .{ .quoted = .{ .inst = inst, .params = params } };
        }

        fn reduction(inst: bc.Inst, min_arity: usize) BuiltinMeta {
            return .{ .reduction = .{ .inst = inst, .min_arity = min_arity } };
        }
    };

    return switch (b) {
        .inspect => mk.pure(.inspect, 1),
        .quote => mk.quoted(.nop, 1),
        .eval => mk.pure(.eval, 1),
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
        .map => .map,
        .concat => mk.reduction(.concat, 2),
        .put => mk.pure(.put, 3),
        .get => mk.pure(.get, 2),
        .@"if" => .@"if",
        .@"fn" => mk.quoted(.@"fn", 2),
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
        .quoted => |quo| {
            if (args.len != quo.params) return LowerError.BadArity;

            for (args) |arg| try bob.loadConst(arg);
            try bob.addInst(quo.inst);
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
        .map => {
            if (args.len % 2 != 0) return LowerError.BadArity;

            const empty_map = try tul.put(.{ .map = .{} });
            defer tul.deacq(empty_map);
            try bob.loadConst(empty_map);

            var i: usize = 0;
            while (i < args.len) : (i += 2) {
                try lowerValue(bob, args[i]);
                try lowerValue(bob, args[i + 1]);
                try bob.addInst(.put);
            }
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
    const applied = tul.get(refs[0]);
    const args = refs[1..];

    // builtins are a special case
    if (applied.* == .tag) {
        if (Object.Builtin.fromName(applied.tag)) |b| {
            try lowerAppliedBuiltin(bob, b, args);
            return;
        }
    }

    // evaluate applied and args as values and call
    try lowerValues(bob, refs);
    try bob.addInstC(.call, @as(u32, @intCast(refs.len)));
}

/// lower the evaluation of a tag as an identifier
fn lowerValueIdent(bob: *Builder, ident: []const u8) Error!void {
    if (Object.Builtin.fromName(ident)) |b| {
        // builtins read as values evaluate to themselves
        const ref = try tul.new(.{ .builtin = b });
        defer tul.deacq(ref);
        try bob.loadConst(ref);
    } else if (bob.hasArg(ident)) {
        // load an arg
        try bob.loadArg(ident);
    } else {
        // read an env variable
        return LowerError.TodoVars;
    }
}

fn lowerValues(bob: *Builder, refs: []const Object.Ref) Error!void {
    for (refs) |ref| try lowerValue(bob, ref);
}

/// lower a ref being read as a value
fn lowerValue(bob: *Builder, ref: Object.Ref) Error!void {
    switch (tul.get(ref).*) {
        .bool,
        .int,
        .string,
        .builtin,
        .@"fn",
        => try bob.loadConst(ref),
        .tag => |ident| try lowerValueIdent(bob, ident),
        .list => |refs| try lowerApplication(bob, ref, refs),
        .map => return Error.TodoLowerMap,
    }
}

pub const Args = Builder.Args;

/// lower some code to an executable function
pub fn lower(args: ?*const Args, code: Object.Ref) Error!Object.Ref {
    const args_or_default: *const Args = args orelse &.{};
    var bob = Builder.init(tul.gc.ally, args_or_default);
    errdefer bob.deinit();

    try lowerValue(&bob, code);

    const function = try bob.build();
    return tul.put(.{ .@"fn" = function });
}
