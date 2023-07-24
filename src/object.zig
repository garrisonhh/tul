const std = @import("std");
const Allocator = std.mem.Allocator;
const com = @import("common");
const gc = @import("gc.zig");
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
                gc.deacqAll(refs);
                ally.free(refs);
            },
        }
    }

    /// deepcopy
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
                gc.acqAll(refs.*);
            },
        }

        return obj;
    }

    /// deep structural equality for two refs
    pub fn eql(ref: Ref, other: Ref) bool {
        const this = gc.get(ref);
        const that = gc.get(other);

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

    /// type for hashing objects
    pub const Hasher = std.hash.Wyhash;
    /// type for holding a hash
    pub const Hash = @typeInfo(@TypeOf(Hasher.hash)).Fn.return_type.?;

    const HashMapContext = struct {
        const seed = 0xBEEF_FA75;

        pub fn hash(_: HashMapContext, key: Ref) Hash {
            var hasher = Hasher.init(seed);
            Object.hash(&hasher, key);
            return hasher.final();
        }

        pub fn eql(_: HashMapContext, a: Ref, b: Ref) bool {
            return Object.eql(a, b);
        }
    };

    /// a zig stdlib hashmap which can use refs as keys
    pub fn HashMapUnmanaged(comptime T: type) type {
        const load_percentage = std.hash_map.default_max_load_percentage;
        return std.HashMapUnmanaged(Ref, T, HashMapContext, load_percentage);
    }

    /// a zig stdlib hashmap which can use refs as keys
    pub fn HashMap(comptime T: type) type {
        return HashMapUnmanaged(T).Managed;
    }

    /// hash any ref
    pub fn hash(hasher: *Hasher, ref: Ref) void {
        const b = std.mem.asBytes;
        const obj = gc.get(ref);

        hasher.update(b(&@as(Tag, obj.*)));

        switch (obj.*) {
            // convert to bytes and hash
            inline .bool, .int, .builtin => |v| hasher.update(b(&v)),
            // hash bytes directly
            .string, .tag => |s| hasher.update(s),
            // recurse
            .list => |children| {
                for (children) |child| {
                    hash(hasher, child);
                }
            },
        }
    }

    test "hashmap" {
        // TODO make main.init, main.deinit accessible from outside of main
        // for testing purposes? right now this could break if I add code to
        // those functions
        defer gc.deinit();

        var map = HashMap(usize).init(std.testing.allocator);
        defer map.deinit();

        const inits = [_]Self{
            .{ .bool = true },
            .{ .bool = false },
            .{ .int = 0 },
            .{ .int = -1 },
            .{ .int = std.math.maxInt(i64) },
            .{ .string = "hello, world!" },
        };

        // put objects in mem and into hashmap
        var refs: [inits.len]Ref = undefined;
        for (inits, 0..) |obj, i| {
            const ref = try gc.new(obj);

            refs[i] = ref;
            try map.put(ref, i);
        }
        defer gc.deacqAll(&refs);

        // check they are retrievable with the same ref
        for (refs, 0..) |ref, index| {
            const got = map.get(ref) orelse {
                return error.TestFailure;
            };

            try std.testing.expectEqual(index, got);
        }

        // attempt to retrieve each value using different refs
        for (inits, 0..) |obj, i| {
            const t = try gc.new(obj);
            defer gc.deacq(t);

            const got = map.get(t) orelse {
                return error.TestFailure;
            };

            try std.testing.expectEqual(i, got);
        }
    }
};
