const std = @import("std");
const fmt = std.fmt;
const Object = @import("object.zig").Object;
const gc = @import("gc.zig");

pub fn formatObject(
    obj: *const Object,
    comptime _: []const u8,
    _: fmt.FormatOptions,
    writer: anytype,
) @TypeOf(writer).Error!void {
    switch (obj.*) {
        .bool => |b| try writer.print("{}", .{b}),
        .int => |n| try writer.print("{}", .{n}),
        .builtin => |b| try writer.print("<builtin>{s}", .{b.name()}),
        .string => |s| try writer.print("\"{}\"", .{std.zig.fmtEscapes(s)}),
        .tag => |t| try writer.print("@{s}", .{t}),
        .list => |refs| {
            try writer.writeAll("(");
            for (refs, 0..) |ref, i| {
                if (i > 0) try writer.writeAll(" ");
                try writer.print("{}", .{gc.get(ref)});
            }
            try writer.writeAll(")");
        },
    }
}
