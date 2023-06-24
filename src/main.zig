const std = @import("std");
const com = @import("common");
const vm = @import("vm.zig");
const bc = @import("bytecode.zig");
const Object = @import("object.zig").Object;

comptime {
    std.testing.refAllDeclsRecursive(bc);
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
        Object{ .string = "hello" },
        Object{ .string = "world" },
    };

    const code = bc.ct_parse(
        \\ load_const 0
        \\ load_const 1
        \\ inspect
        \\ drop
        \\ inspect
    );

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
    const start_time = com.time.now();
    const obj = try vm.run(ally, func);
    defer obj.deinit(ally);
    const duration = com.time.now() - start_time;

    std.debug.print("in {d:.9}s main returned:\n{}\n", .{duration, obj});
}
