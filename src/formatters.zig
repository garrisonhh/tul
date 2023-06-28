const std = @import("std");
const fmt = std.fmt;
const Object = @import("object.zig").Object;
const vm = @import("vm.zig");

pub fn formatObject(
    obj: *const Object,
    comptime _: []const u8,
    _: fmt.FormatOptions,
    writer: anytype,
) @TypeOf(writer).Error!void {
    switch (obj.*) {
        .int => |n| try writer.print("{}", .{n}),
        .string => |s| try writer.print("\"{}\"", .{std.zig.fmtEscapes(s)}),
        .tag => |t| try writer.print("@{s}", .{t}),
        .list => |refs| {
            try writer.writeAll("(");
            for (refs, 0..) |ref, i| {
                if (i > 0) try writer.writeAll(" ");
                try writer.print("{}", .{vm.get(ref)});
            }
            try writer.writeAll(")");
        },
    }
}
