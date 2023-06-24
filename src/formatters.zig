const std = @import("std");
const fmt = std.fmt;
const Object = @import("object.zig").Object;

pub fn formatObject(
    obj: *const Object,
    comptime _: []const u8,
    _: fmt.FormatOptions,
    writer: anytype,
) @TypeOf(writer).Error!void {
    switch (obj.*) {
        .unit => try writer.writeAll("()"),
        .int => |n| try writer.print("{}", .{n}),
        .string => |s| try writer.print("\"{}\"", .{std.zig.fmtEscapes(s)}),
    }
}
