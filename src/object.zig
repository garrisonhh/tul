const std = @import("std");
const Allocator = std.mem.Allocator;
const com = @import("common");
const vm = @import("vm.zig");
const formatObject = @import("formatters.zig").formatObject;

pub const Object = union(enum) {
    const Self = @This();
    pub const Tag = std.meta.Tag(Self);
    pub const Ref = com.Ref(.object, @bitSizeOf(usize));
    pub const RcMap = com.RefMap(Ref, Rc);

    pub const Rc = struct {
        count: usize,
        obj: Self,

        /// create an rc with 1 reference
        pub fn init(obj: Object) Rc {
            return Rc{
                .count = 1,
                .obj = obj,
            };
        }
    };

    unit,
    int: i64,
    /// owned string
    string: []const u8,
    /// owned string
    tag: []const u8,
    /// owned array of acq'd refs
    list: []const Ref,

    pub const format = formatObject;

    pub fn deinit(self: Self, ally: Allocator) void {
        switch (self) {
            .unit, .int => {},
            .string, .tag => |str| ally.free(str),
            .list => |refs| {
                vm.deacqAll(refs);
                ally.free(refs);
            },
        }
    }

    pub fn clone(self: *const Self, ally: Allocator) Allocator.Error!Self {
        var obj = self.*;
        switch (obj) {
            .unit, .int => {},
            // direct dupe
            .string, .tag => |*str| {
                const Item = @typeInfo(@TypeOf(str.ptr)).Pointer.child;
                str.* = try ally.dupe(Item, str.*);
            },
            // deep dupe
            .list => |*refs| {
                refs.* = try ally.dupe(Ref, refs.*);
                vm.acqAll(refs.*);
            },
        }

        return obj;
    }
};
