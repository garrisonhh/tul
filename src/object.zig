const std = @import("std");
const Allocator = std.mem.Allocator;
const com = @import("common");
const formatObject = @import("formatters.zig").formatObject;

pub const Object = union(enum) {
    const Self = @This();
    pub const Tag = std.meta.Tag(Self);
    pub const Ref = com.Ref(.object, @sizeOf(usize));
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

    int: i64,
    string: []const u8,
    
    pub const format = formatObject;

    pub fn deinit(self: *Self, ally: Allocator) void {
        switch (self.*) {
            .int => {},
            .string => |str| ally.free(str),
        }
    }

    pub fn clone(self: *const Self, ally: Allocator) Allocator.Error!Self {
        var obj = self.*;
        switch (obj) {
            .int => {},
            .string => |*str| str.* = try ally.dupe(u8, str.*),
        }
 
        return obj;
    }
};