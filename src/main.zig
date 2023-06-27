const std = @import("std");
const com = @import("common");
const vm = @import("vm.zig");
const bc = @import("bytecode.zig");
const Object = @import("object.zig").Object;
const parser = @import("parser.zig");

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
    // boilerplate
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const ally = gpa.allocator();

    _ = ally;

    try init();
    defer deinit();

    // behavior
    try parser.parse(
        \\ (this is some unicode (😊 1345))
        \\
    );
}
