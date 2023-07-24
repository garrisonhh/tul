const std = @import("std");
const Allocator = std.mem.Allocator;
const gc = @import("../gc.zig");
const Object = @import("../object.zig").Object;
const bc = @import("../bytecode.zig");
const Inst = bc.Inst;

const Self = @This();

/// gc tracked values
/// TODO store these more globally, intern them with Object.HashMap
consts: []const Object.Ref,
/// bytecode
code: []const u8,
/// max refs required for stack vm
stack_size: usize,

pub fn deinit(self: Self, ally: Allocator) void {
    gc.deacqAll(self.consts);
    ally.free(self.consts);
    ally.free(self.code);
}

/// print this function's code
pub fn display(
    self: Self,
    writer: anytype,
) (bc.Iterator.Error || @TypeOf(writer).Error)!void {
    var insts = bc.iterator(self.code);
    var consumed: u64 = undefined;
    while (true) {
        const addr = insts.index;
        const inst = try insts.next(&consumed) orelse break;

        try writer.print("{d:>4} {s} ", .{ addr, @tagName(inst) });

        if (inst == .load_const) {
            const ref = self.consts[consumed];
            try writer.print("{}", .{gc.get(ref)});
        } else if (inst.meta().consumes > 0) {
            try writer.print("{d}", .{consumed});
        }

        try writer.writeByte('\n');
    }
}
