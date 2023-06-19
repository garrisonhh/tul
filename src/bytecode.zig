const std = @import("std");
const Allocator = std.mem.Allocator;
const vm = @import("vm.zig");

/// an atomic stack instruction
pub const Inst = enum(u8) {
    const Self = @This();

    const Meta = struct {
        inputs: comptime_int,
        outputs: comptime_int,

        fn of(in: comptime_int, out: comptime_int) Meta {
            return struct {
                .inputs = in,
                .outputs = out,
            };
        }

        pub fn diff(comptime m: Meta) comptime_int {
            return m.outputs - m.inputs;
        }
    };

    inspect,

    swap,
    dup,
    over,
    rot,
    drop,

    add,
    sub,
    mul,
    div,
    mod,

    /// comptime mapping of inst -> metadata
    pub fn meta(comptime self: Self) Meta {
        comptime {
            const m = Meta.of;
            return switch (self) {
                .inspect => m(1, 1),
                .swap => m(2, 2),
                .dup => m(1, 2),
                .over => m(2, 3),
                .rot => m(3, 3),
                .drop => m(1, 0),
                .add, .sub, .mul, .div, .mod => m(2, 1),
            };
        }
    }
};
