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
        const node: *CallStack.Node = call_stack.popFirst().?;
        node.data.deinit(ally);
        ally.destroy(node);
    }

    inline fn execInst(frame_p: **bc.Frame, inst: bc.Inst, consumed: u64) !void {
        const frame = frame_p.*;
        const func = frame.func;

        switch (inst) {
            .nop => {},
            .load_const => {
                const const_obj = func.consts[consumed];
                const ref = try new(const_obj);
                frame.push(ref);
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
