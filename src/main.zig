const std = @import("std");
const stdout = std.io.getStdOut().writer();
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

    try init();
    defer deinit();

    // behavior
    const progs = [_][]const u8{
        "abc",
        "(abc def)",
        "((lists) (within) (lists))",
        "((((🔥 () 🔥))))",
        "((())",
    };

    for (progs) |prog| {
        try stdout.print("[program]\n{s}\n\n", .{prog});

        const start_time = com.time.now();
        const res = parser.parse(ally, prog); 
        const duration = com.time.now() - start_time;

        if (res) |ref| {
            defer vm.deacq(ref);

            const obj = vm.get(ref);
            try stdout.print("[success in {d:.6}s]\n{}\n", .{duration, obj});
        } else |err| {
            try stdout.print(
                "[failure in {d:.6}s]\nfailed with {}\n",
                .{duration, err},
            );
        }
        
        try stdout.writeAll("\n");
    }
}
