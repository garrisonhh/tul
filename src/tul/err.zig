//! tul error messaging

const std = @import("std");
const Allocator = std.mem.Allocator;
const safe = std.debug.runtime_safety;
const blox = @import("blox");
const tul = @import("tul");
const registry = tul.registry;
const FileRef = registry.FileRef;
const Loc = registry.Loc;

pub const Level = enum {
    const Self = @This();

    debug,
    warn,
    err,

    pub fn color(self: Self) blox.Color {
        const c = blox.Color.init;
        return switch (self) {
            .debug => c(.normal, .green),
            .warn => c(.bright, .magenta),
            .err => c(.bright, .red),
        };
    }

    /// renders the label for the level
    const render = tul.formatters.renderErrorLevel;
};

pub const Message = struct {
    const Self = @This();

    level: Level,
    loc: ?Loc,
    text: []const u8,

    const render = tul.formatters.renderErrorMessage;

    pub fn warn(loc: ?Loc, text: []const u8) Self {
        return Self{
            .level = .warn,
            .loc = loc,
            .text = text,
        };
    }

    pub fn err(loc: ?Loc, text: []const u8) Self {
        return Self{
            .level = .err,
            .loc = loc,
            .text = text,
        };
    }
};

pub const Messenger = struct {
    const Self = @This();

    messages: std.MultiArrayList(Message) = .{},

    pub fn deinit(self: *Self) void {
        // you have to use the queued messages before you're done with it
        if (safe and self.messages.len > 0) {
            @panic("failed to use queue messages");
        }
    }

    pub fn write(
        self: *const Self,
        ally: Allocator,
        writer: anytype,
    ) (blox.Error || @TypeOf(writer).Error)!void {
        var mason = blox.Mason.init(ally);
        defer mason.deinit();

        // stack messages
        var msgDivs = std.ArrayList(Message).init(ally);
        defer msgDivs.deinit();

        for (self.messages.items) |msg| {
            try msgDivs.append(try msg.render(&mason));
        }

        const messages = try mason.newBox(msgDivs.items, .{});

        // write to writer
        try mason.write(messages, writer, .{});
    }

    pub fn add(
        self: *Self,
        ally: Allocator,
        message: Message,
    ) Allocator.Error!void {
        try self.messages.append(ally, message);
    }
};
