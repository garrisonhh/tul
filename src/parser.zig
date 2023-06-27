const std = @import("std");
const Tokenizer = @import("tokenizer.zig");

pub fn parse(text: []const u8) !void {
    var tokens = Tokenizer.init(text);
    while (try tokens.next()) |token| {
        const slice = text[token.index .. token.index + token.len];
        std.debug.print("[{s}] `{s}`\n", .{ @tagName(token.type), slice });
    }
}
