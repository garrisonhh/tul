const std = @import("std");
const Allocator = std.mem.Allocator;
const vm = @import("vm.zig");
const bc = @import("bytecode.zig");
const Object = @import("object.zig").Object;

const LowerError = error{
    BadArity,

    // TODO eradicate these
    TodoVars,
    TodoCallee,
};

pub const Error = Allocator.Error || LowerError;

fn reqArgs(comptime req: comptime_int, nargs: usize) Error!void {
    if (nargs < req) return Error.BadArity;
}

/// lower a ref being called as a function
fn lowerCallee(bob: *bc.Builder, ref: Object.Ref, arity: usize) Error!void {
    switch (vm.get(ref).*) {
        .tag => |ident| {
            // these operators act like a reduction with pure function with two
            // arguments
            const bin_reduce_ops = comptime std.ComptimeStringMap(bc.Inst, .{
                .{ "+", .add },
                .{ "-", .sub },
                .{ "*", .mul },
                .{ "/", .div },
                .{ "%", .mod },
            });

            if (bin_reduce_ops.get(ident)) |inst| {
                try reqArgs(1, arity);
                for (0..arity - 1) |_| try bob.addInst(inst);
            } else {
                return Error.TodoCallee;
            }
        },
        else => return Error.TodoCallee,
    }
}

/// lower a ref being read as a value
fn lowerValue(bob: *bc.Builder, ref: Object.Ref) Error!void {
    switch (vm.get(ref).*) {
        .tag => return Error.TodoVars,
        .int, .string => try bob.loadConst(ref),
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
            try lowerCallee(bob, refs[0], arity);
        },
    }
}

/// lower some code to bytecode for execution
///
/// TODO this will very soon need to return a representation of an entire
/// program rather than a single function (unless I can have function nesting
/// or something? lambda-ness would be cool)
pub fn lower(ally: Allocator, code: Object.Ref) Error!bc.Function {
    var bob = bc.Builder.init(ally);
    try lowerValue(&bob, code);

    return bob.build();
}
