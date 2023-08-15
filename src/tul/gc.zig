const builtin = @import("builtin");
const std = @import("std");
const Allocator = std.mem.Allocator;
const com = @import("common");
const tul = @import("tul");
const Object = tul.Object;
const bc = tul.bc;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
/// use this responsibly (only for memory getting directly put on gc)
pub const ally = gpa.allocator();

var mem = Object.RcMap{};

pub fn deinit() void {
    mem.deinit(ally);
    _ = gpa.deinit();

    // in testing, gc may be reinitialized
    if (builtin.is_test) {
        mem = .{};
        gpa = .{};
    }
}

/// displays memory to stderr for debugging purposes
pub fn inspectMemory() void {
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

fn arrayify_lower(comptime func: anytype) type {
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

/// turn `fn(Object.Ref) T` into a version that operates on and returns an array
fn arrayify(comptime func: anytype) @TypeOf(arrayify_lower(func).f) {
    return arrayify_lower(func).f;
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
    return getMut(ref);
}

/// get mutable object pointer (use with caution)
pub fn getMut(ref: Object.Ref) *Object {
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
pub const getArray = arrayify(get);
