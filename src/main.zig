const std = @import("std");
const vm = @import("vm.zig");
const bc = @import("bytecode.zig");
const Object = @import("object.zig").Object;

comptime {
    std.testing.refAllDeclsRecursive(@This());
}

fn init() !void {
    // stub
}

fn deinit() void {
    vm.deinit();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const ally = gpa.allocator();

    try init();
    defer deinit();

    // make test function
    const consts = [_]Object{
        Object{ .string = "hello, world!" },
    };

    const code = [_]u8{
        // load_const 0
        @intFromEnum(bc.Inst.load_const), 0, 0, 0, 0,
        // nop
        @intFromEnum(bc.Inst.nop),
    };

    const owned_consts = try ally.alloc(Object, consts.len);
    for (consts, 0..) |obj, i| {
        owned_consts[i] = try obj.clone(ally);
    }

    const func = bc.Function{
        .consts = owned_consts,
        .code = try ally.dupe(u8, &code),
        .stack_size = 256,
    };
    defer func.deinit(ally);

    // run test function
    const obj = try vm.run(ally, func);
    defer obj.deinit(ally);

    std.debug.print("main returned:\n{}\n", .{obj});
}
