//! contains entry point for tul

const builtin = @import("builtin");
const std = @import("std");
const stderr = std.io.getStdErr().writer();
const stdout = std.io.getStdOut().writer();
const tul = @import("tul");

pub fn main() !void {
    try tul.init();
    defer tul.deinit();

    const code =
        \\((fn (a) a) 1)
        \\
    ;

    const out = try tul.exec("main", code);
    defer tul.deacq(out);

    try stdout.print("{}\n", .{tul.get(out)});
}
