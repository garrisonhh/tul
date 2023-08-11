/// type for storing branch addresses
pub const AddressInt = u32;

pub const Inst = @import("bytecode/inst.zig").Inst;
pub const Function = @import("bytecode/function.zig");
pub const Builder = @import("bytecode/builder.zig");
pub const Iterator = @import("bytecode/iterator.zig");

/// canonical iteration for bytecode
pub fn iterator(code: []const u8) Iterator {
    return .{ .code = code };
}
