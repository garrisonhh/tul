const std = @import("std");
const Allocator = std.mem.Allocator;
const com = @import("common");
const Object = @import("object.zig").Object;
const Ref = Object.Ref;
const Rc = Object.Rc;
const in_debug = @import("builtin").Mode == .Debug;

var gpa = std.heap.GeneralPurposeAllocator(.{}){}; 
const ally = gpa.allocator();

var mem = Object.RcMap{};
var stk = std.ArrayListUnmanaged(Ref){};

pub fn deinit() void {
    deleteAllObjects();
    mem.deinit(ally);
    stk.deinit(ally);

    _ = gpa.deinit();
}

/// delete all objects in memory
fn deleteAllObjects() void {
    var rc_iter = mem.iterator();
    while (rc_iter.next()) |rc| rc.obj.deinit(ally);
}

/// return runtime to a clean condition 
pub fn reset() void {
    deleteAllObjects();
    stk.shrinkRetainingCapacity(0);
}

/// clones the init object and places it in gc memory with 1 reference
pub fn new(init: Object) Allocator.Error!Object.Ref {
    const obj = try init.clone(ally);
    const rc = Rc.init(obj);
    return try mem.put(ally, rc);
}

/// declare ownership; increase object reference count
pub fn acq(ref: Object.Ref) void {
    mem.get(ref).count += 1;
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
