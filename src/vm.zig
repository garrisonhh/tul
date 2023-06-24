const std = @import("std");
const Allocator = std.mem.Allocator;
const com = @import("common");
const Object = @import("object.zig").Object;
const bc = @import("bytecode.zig");
const in_debug = @import("builtin").Mode == .Debug;

const CallStack = std.SinglyLinkedList(bc.Frame);

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const ally = gpa.allocator();

var mem = Object.RcMap{};
var call_stack = CallStack{};

pub fn deinit() void {
    deleteAllObjects();
    mem.deinit(ally);

    _ = gpa.deinit();
}

/// delete all objects in memory
fn deleteAllObjects() void {
    var rc_iter = mem.iterator();
    while (rc_iter.nextEntry()) |entry| {
        const rc = entry.ptr;
        const ref = entry.ref;

        rc.obj.deinit(ally);
        mem.del(ref);
    }
}

/// return runtime to a clean condition
pub fn reset() void {
    deleteAllObjects();
}

/// clones the init object and places it in gc memory with 1 reference
pub fn new(init: Object) Allocator.Error!Object.Ref {
    const obj = try init.clone(ally);
    const rc = Object.Rc.init(obj);
    return try mem.put(ally, rc);
}

fn ReturnType(comptime func: anytype) type {
    return @typeInfo(@TypeOf(func)).Fn.return_type.?;
}

/// turn `fn(Object.Ref) T` into a version that operates on and returns an array
/// 
/// get output with '.f' since returning parametrized function types isn't
/// currently supported afaik
fn arrayify(comptime func: anytype) type {
    return struct {
        fn f(
            comptime N: comptime_int,
            inputs: [N]Object.Ref,
        ) t: {
            const R = ReturnType(func);
            break :t if (R == void) void else [N]R;
        } {
            const R = ReturnType(func);
            if (R == void) {
                for (inputs) |ref| func(ref);
                return;
            } else {
                var arr: [N]ReturnType(func) = undefined;
                for (inputs, &arr) |ref, *slot| {
                    slot.* = func(ref);
                }

                return arr;
            }
        }
    };
}

/// turn `fn(Object.Ref) void` into a version that operates on a slice
fn sliceify(comptime func: fn(Object.Ref) void) fn([]const Object.Ref) void {
    return struct {
        fn f(refs: []const Object.Ref) void {
            for (refs) |ref| func(ref);
        }
    }.f;
}

/// declare ownership; increase object reference count
pub fn acq(ref: Object.Ref) void {
    const rc = mem.get(ref);
    rc.count += 1;
}

/// revoke ownership; decrease object reference count
pub fn deacq(ref: Object.Ref) void {
    const rc = mem.get(ref);
    rc.count -= 1;

    if (rc.count == 0) {
        rc.obj.deinit(ally);
        mem.del(ref);
    }
}

/// read from an object thru its ref & rc
pub fn get(ref: Object.Ref) *const Object {
    return &mem.get(ref).obj;
}

/// see acq
pub const acqAll = sliceify(acq);
/// see deacq
pub const deacqAll = sliceify(deacq);
/// see get
pub const getArray = arrayify(get).f;

/// code execution
const runtime = struct {
    fn assertClean() void {
        const assert = std.debug.assert;
        assert(mem.count() == 0);
        // assert(call_stack.len() == 0);
    }

    /// adds a frame to the call stack
    fn pushFrame(func: *const bc.Function) Allocator.Error!*bc.Frame {
        const frame = try bc.Frame.init(ally, func);
        const node = try ally.create(CallStack.Node);
        node.* = .{ .data = frame };

        call_stack.prepend(node);

        return &node.data;
    }

    /// removes a frame from the call stack
    fn popFrame() void {
        const node = call_stack.popFirst().?;
        node.data.deinit(ally);
        ally.destroy(node);
    }

    inline fn execInst(
        frame_p: **bc.Frame,
        inst: bc.Inst,
        consumed: u64,
    ) !void {
        const frame = frame_p.*;
        const func = frame.func;

        // execute
        switch (inst) {
            .nop => {},
            .load_const => {
                const const_obj = func.consts[consumed];
                const ref = try new(const_obj);
                frame.push(ref);
            },
            .swap => {
                var refs = frame.popArray(2);
                std.mem.swap(Object.Ref, &refs[0], &refs[1]);
                frame.pushAll(&refs);
            },
            .dup => frame.push(frame.peek()),
            inline .add, .sub, .mul, .div, .mod => |tag| {
                const refs = frame.popArray(2);
                defer deacqAll(&refs);

                const lhs = get(refs[0]).int;
                const rhs = get(refs[1]).int;

                const n = switch (tag) {
                    .add => lhs + rhs,
                    .sub => lhs - rhs,
                    .mul => lhs * rhs,
                    .div => @divTrunc(lhs, rhs),
                    .mod => @mod(lhs, rhs),
                    else => unreachable,
                };

                const result = try new(Object{ .int = n });
                frame.push(result);
            },
            else => unreachable,
        }
    }

    fn exec(main: *const bc.Function) !Object.Ref {
        assertClean();

        var frame = try pushFrame(main);
        defer popFrame();

        // main vm loop
        var consumed: u64 = undefined;
        while (try frame.iter.next(&consumed)) |inst| {
            try execInst(&frame, inst, consumed);
        }

        // main should return one value
        return frame.pop();
    }
};

/// run a function on the vm
///
/// vm uses its internal allocator for memory management, but the final value is
/// cloned onto the allocator passed to this function
pub fn run(caller_ally: Allocator, main: bc.Function) !Object {
    defer reset();

    const final = try runtime.exec(&main);
    defer deacq(final);

    return try get(final).clone(caller_ally);
}
