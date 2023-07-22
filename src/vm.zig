const builtin = @import("builtin");
const test_options = @import("test_options");
const std = @import("std");
const Allocator = std.mem.Allocator;
const com = @import("common");
const Object = @import("object.zig").Object;
const bc = @import("bytecode.zig");
const in_debug = @import("builtin").mode == .Debug;

const CallStack = std.SinglyLinkedList(bc.Frame);

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const ally = gpa.allocator();

var mem = Object.RcMap{};
var call_stack = CallStack{};

pub fn deinit() void {
    mem.deinit(ally);

    _ = gpa.deinit();
}

/// displays memory to stderr for debugging purposes
pub fn inspectMemory() void {
    std.debug.assert(in_debug);

    std.debug.print("id\trc\tvalue\n", .{});

    var entries = mem.iterator();
    while (entries.nextEntry()) |entry| {
        std.debug.print("{%}\t{}\t{}\n", .{
            entry.ref,
            entry.ptr.count,
            entry.ptr.obj,
        });
    }
}

/// returns number of refs currently allocated
pub fn allocated() usize {
    var count: usize = 0;
    var iter = mem.iterator();
    while (iter.next()) |_| count += 1;

    return count;
}

/// without cloning, places an object into gc memory with 1 reference
pub fn put(obj: Object) Allocator.Error!Object.Ref {
    const rc = Object.Rc.init(obj);
    const ref = try mem.put(ally, rc);
    return ref;
}

/// clones the init object and places it in gc memory with 1 reference
pub fn new(init: Object) Allocator.Error!Object.Ref {
    return try put(try init.clone(ally));
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
fn sliceify(comptime func: fn (Object.Ref) void) fn ([]const Object.Ref) void {
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

/// get the count of an rc
pub fn refCount(ref: Object.Ref) usize {
    return mem.get(ref).count;
}

/// see acq
pub const acqAll = sliceify(acq);
/// see deacq
pub const deacqAll = sliceify(deacq);
/// see get
pub const getArray = arrayify(get).f;

/// code execution
const runtime = struct {
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

    const Error = Allocator.Error || bc.Inst.Iterator.Error;

    inline fn execInst(
        frame_p: **bc.Frame,
        inst: bc.Inst,
        consumed: u64,
    ) Error!void {
        const frame = frame_p.*;
        const func = frame.func;

        // execute
        switch (inst) {
            .nop => {},

            .load_const => {
                const ref = func.consts[consumed];
                acq(ref);
                frame.push(ref);
            },
            .inspect => {
                const obj = get(frame.peek());
                std.debug.print("[inspect] {}\n", .{obj});
            },

            // control flow
            .jump => {
                try frame.jump(consumed);
            },
            .branch => {
                const cond = cond: {
                    const ref = frame.pop();
                    defer deacq(ref);
                    break :cond get(ref).bool;
                };

                if (cond) try frame.jump(consumed);
            },

            // stack manipulation
            .swap => {
                var refs = frame.popArray(2);
                std.mem.swap(Object.Ref, &refs[0], &refs[1]);
                frame.pushAll(&refs);
            },
            .dup => {
                const top = frame.peek();
                acq(top);
                frame.push(top);
            },
            .over => {
                const under = frame.peekArray(2)[0];
                acq(under);
                frame.push(under);
            },
            .rot => {
                var refs = frame.popArray(3);
                const tmp = refs[0];
                refs[0] = refs[1];
                refs[1] = refs[2];
                refs[2] = tmp;
                frame.pushAll(&refs);
            },
            .drop => {
                deacq(frame.pop());
            },

            // math
            inline .add, .sub, .mul, .div, .mod => |tag| {
                const refs = frame.popArray(2);
                defer deacqAll(&refs);

                const lhs = get(refs[0]).int;
                const rhs = get(refs[1]).int;

                const val = switch (tag) {
                    .add => lhs + rhs,
                    .sub => lhs - rhs,
                    .mul => lhs * rhs,
                    .div => @divTrunc(lhs, rhs),
                    .mod => @mod(lhs, rhs),
                    else => unreachable,
                };

                frame.push(try new(.{ .int = val }));
            },

            // logic
            inline .land, .lor => |tag| {
                const refs = frame.popArray(2);
                defer deacqAll(&refs);

                const lhs = get(refs[0]).bool;
                const rhs = get(refs[1]).bool;

                const val = switch (tag) {
                    .land => lhs and rhs,
                    .lor => lhs or rhs,
                    else => unreachable,
                };

                frame.push(try new(.{ .bool = val }));
            },
            .lnot => {
                const ref = frame.pop();
                defer deacq(ref);

                const val = !get(ref).bool;
                frame.push(try new(.{ .bool = val }));
            },

            // comparison
            .eq => {
                const refs = frame.popArray(2);
                defer deacqAll(&refs);

                const res = Object.eql(refs[0], refs[1]);

                frame.push(try new(.{ .bool = res }));
            },

            // strings/lists
            .concat => {
                const refs = frame.popArray(2);
                defer deacqAll(&refs);

                const lhs_ref = get(refs[0]);
                const rhs_ref = get(refs[1]);

                if (lhs_ref.* == .string) {
                    const lhs = lhs_ref.string;
                    const rhs = rhs_ref.string;

                    const str = try std.mem.concat(ally, u8, &.{ lhs, rhs });

                    frame.push(try put(.{ .string = str }));
                } else if (lhs_ref.* == .list) {
                    const lhs = lhs_ref.list;
                    const rhs = rhs_ref.list;

                    const list = try std.mem.concat(
                        ally,
                        Object.Ref,
                        &.{ lhs, rhs },
                    );
                    acqAll(list);

                    frame.push(try put(.{ .list = list }));
                } else {
                    @panic("TODO runtime error; mismatched concat");
                }
            },
            .list => {
                // technically, this should deacq all refs when popping and then
                // reacq when placing on the list, but I think that is
                // unnecessary work
                const list = try frame.popSliceAlloc(ally, consumed);
                frame.push(try put(.{ .list = list }));
            },
        }
    }

    fn exec(main: *const bc.Function) Error!Object.Ref {
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

pub const RuntimeError = runtime.Error;

/// run a function on the vm
/// memory usage here is gc'd using the vm's internal allocator
pub fn run(main: bc.Function) RuntimeError!Object.Ref {
    return try runtime.exec(&main);
}
