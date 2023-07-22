const std = @import("std");
const Allocator = std.mem.Allocator;
const com = @import("common");
const vm = @import("vm.zig");
const formatObject = @import("formatters.zig").formatObject;

/// canonical tul object
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

    /// builtin applicables
    pub const Builtin = enum {
        inspect,

        add,
        sub,
        mul,
        div,
        mod,

        @"and",
        @"or",
        not,

        eq,

        list,
        concat,

        @"if",

        // TODO eql, quote, unquote

        /// finds a builtin from its name
        pub fn fromName(s: []const u8) ?Builtin {
            return inline for (comptime std.enums.values(Builtin)) |b| {
                if (std.mem.eql(u8, s, b.name())) break b;
            } else null;
        }

        /// how this builtin is identified
        pub fn name(b: Builtin) []const u8 {
            return switch (b) {
                .add => "+",
                .sub => "-",
                .mul => "*",
                .div => "/",
                .mod => "%",
                .eq => "==",
                .concat => "++",

                inline .inspect,
                .@"and",
                .@"or",
                .not,
                .list,
                .@"if",
                => |tag| @tagName(tag),
            };
        }
    };

    bool: bool,
    int: i64,
    builtin: Builtin,
    /// owned string
    string: []const u8,
    /// owned string
    tag: []const u8,
    /// owned array of acq'd refs
    list: []const Ref,

    pub const format = formatObject;

    pub fn deinit(self: Self, ally: Allocator) void {
        switch (self) {
            .bool, .int, .builtin => {},
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
            .bool, .int, .builtin => {},
            // shallow dupe
            .string, .tag => |*str| {
                const Item = @typeInfo(@TypeOf(str.ptr)).Pointer.child;
                str.* = try ally.dupe(Item, str.*);
            },
            // deep dupe (shallow dupe + acq everything)
            .list => |*refs| {
                refs.* = try ally.dupe(Ref, refs.*);
                vm.acqAll(refs.*);
            },
        }

        return obj;
    }

    /// deep structural equality for two refs
    pub fn eql(ref: Ref, other: Ref) bool {
        const this = vm.get(ref);
        const that = vm.get(other);

        if (@as(Tag, this.*) != @as(Tag, that.*)) {
            return false;
        }

        return switch (this.*) {
            // direct comparison
            inline .bool,
            .int,
            .builtin,
            => |data, tag| data == @field(that, @tagName(tag)),

            // mem comparison
            inline .string, .tag => |slice, tag| mem: {
                const Item = @typeInfo(@TypeOf(slice)).Pointer.child;

                const other_slice = @field(that.*, @tagName(tag));
                break :mem std.mem.eql(Item, slice, other_slice);
            },

            // deep comparison
            .list => |xs| deep: {
                const os = that.list;
                if (xs.len != os.len) {
                    break :deep false;
                }

                for (xs, os) |x, o| {
                    if (!Object.eql(x, o)) {
                        break :deep false;
                    }
                }

                break :deep true;
            },
        };
    }
};
