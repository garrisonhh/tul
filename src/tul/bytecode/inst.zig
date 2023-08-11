const std = @import("std");
const bc = @import("../tul.zig").bc;
const AddressInt = bc.AddressInt;

/// an atomic stack instruction
pub const Inst = enum(u8) {
    const Self = @This();

    const Meta = struct {
        const FieldTag = std.meta.FieldEnum(@This());

        const Input = union(enum) {
            /// takes some number of values
            pops: usize,
            /// takes `consumed` values
            consumed,
        };

        /// number of refs popped
        inputs: Input,
        /// number of refs pushed
        outputs: usize,
        /// number of extra bytes consumed in interpretation
        consumes: usize,

        fn of(inputs: Input, outputs: usize, consumes: usize) Meta {
            return .{
                .inputs = inputs,
                .outputs = outputs,
                .consumes = consumes,
            };
        }
    };

    nop = 0,

    load_const,
    load_abs, // dupe absolute stack index
    inspect,
    eval,
    @"fn",

    call,
    jump, // jump to addr
    branch, // if cond, jump to addr

    swap, // x y - y x
    dup, // x - x x
    over, // x y - x y x
    rot, // x y z - y z x
    drop, // x y - x

    // math
    add,
    sub,
    mul,
    div,
    mod,

    // logic
    land,
    lor,
    lnot,

    // comparison
    eq,

    // collections
    concat,
    list,
    put, // map k v - map
    get, // map k - v

    /// get metadata for how this instruction is parsed and affects the stack
    pub fn meta(self: Self) Meta {
        const m = Meta.of;
        const pops = struct {
            fn f(comptime n: comptime_int) Meta.Input {
                return .{ .pops = n };
            }
        }.f;

        return switch (self) {
            .nop => m(pops(0), 0, 0),
            .jump => m(pops(0), 0, @sizeOf(AddressInt)),
            .drop => m(pops(1), 0, 0),
            .branch => m(pops(1), 0, @sizeOf(AddressInt)),
            .swap => m(pops(2), 2, 0),
            .dup => m(pops(1), 2, 0),
            .over => m(pops(2), 3, 0),
            .rot => m(pops(3), 3, 0),

            .list,
            .call,
            => m(.consumed, 1, 4),

            .load_const,
            .load_abs,
            => m(pops(0), 1, 4),

            .inspect,
            .eval,
            .lnot,
            => m(pops(1), 1, 0),

            .@"fn",
            .add,
            .sub,
            .mul,
            .div,
            .mod,
            .land,
            .lor,
            .eq,
            .concat,
            .get,
            => m(pops(2), 1, 0),

            .put => m(pops(3), 1, 0),
        };
    }

    pub fn isBranching(self: Self) bool {
        return switch (self) {
            .jump, .branch => true,
            else => false,
        };
    }
};
