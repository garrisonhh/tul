const std = @import("std");
const fmt = std.fmt;
const tul = @import("tul");

pub fn formatObject(
    obj: *const tul.Object,
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
                try writer.print("{}", .{tul.get(ref)});
            }
            try writer.writeAll(")");
        },
        .map => |map| {
            try writer.writeAll("{");

            var entries = map.iterator();
            var i: usize = 0;
            while (entries.next()) |entry| : (i += 1) {
                if (i > 0) try writer.writeAll(", ");
                try writer.print("{}: {}", .{
                    tul.get(entry.key_ptr.*),
                    tul.get(entry.value_ptr.*),
                });
            }

            try writer.writeAll("}");
        },
        .@"fn" => |f| {
            try writer.print("<fn (takes {d})>", .{f.param_count});
        },
    }
}
