const std = @import("std");
const vm = @import("vm.zig");
const Object = @import("object.zig").Object;

fn init() !void {
    // stub
}

fn deinit() void {
    vm.deinit();
}

pub fn main() !void {
    try init();
    defer deinit();

    const ref = try vm.new(.{ .string = "hello, world!" });
    defer vm.deacq(ref);

    std.debug.print("created object: {}\n", .{vm.get(ref)});
}
