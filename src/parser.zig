const std = @import("std");
const Allocator = std.mem.Allocator;
const com = @import("common");
const vm = @import("vm.zig");
const Tokenizer = @import("tokenizer.zig");
const Token = Tokenizer.Token;
const Object = @import("object.zig").Object;

const ParseError = error{
    UnexpectedEof,
    InvalidSyntax,
    InvalidNumber,
    InvalidStringEscapeSequence,
};

pub const Error = Allocator.Error || Tokenizer.Error || ParseError;

/// provides context and helpers for parsing
const Context = struct {
    const Self = @This();

    ally: Allocator,
    text: []const u8,
    tokens: Tokenizer,
    cache: ?Token = null,

    fn init(ally: Allocator, text: []const u8) Self {
        return Self{
            .ally = ally,
            .text = text,
            .tokens = Tokenizer.init(text),
        };
    }

    fn deinit(self: *Self, ally: Allocator) void {
        _ = self;
        _ = ally;

        // stub
    }

    fn next(self: *Self) Tokenizer.Error!?Token {
        if (self.cache) |tok| {
            self.cache = null;
            return tok;
        }

        return try self.tokens.next();
    }

    /// look at the next token without iterating past it
    fn peek(self: *Self) Tokenizer.Error!?Token {
        if (self.cache) |tok| {
            return tok;
        }

        self.cache = try self.tokens.next();
        return self.cache;
    }

    /// iterate past a peeked token
    fn accept(self: *Self) void {
        std.debug.assert(self.cache != null);
        self.cache = null;
    }

    /// when peek must succeed
    fn mustPeek(self: *Self) Error!Token {
        return (try self.peek()) orelse Error.UnexpectedEof;
    }

    /// when you expect a token to exist
    fn mustNext(self: *Self) Error!Token {
        return (try self.next()) orelse Error.UnexpectedEof;
    }

    /// when you expect a specific token to exist, accept it
    fn expect(self: *Self, expects: Token.Type) Error!Token {
        const token = try self.mustNext();
        if (token.type != expects) return Error.InvalidSyntax;
        return token;
    }
};

/// validates string; parses string escapes; returns owned string
fn parseString(ally: Allocator, unescaped_str: []const u8) Error![]const u8 {
    const str = unescaped_str[1 .. unescaped_str.len - 1];

    // str.len is used since the parsed string should always be shorter than the
    // unparsed string
    var parsed = try std.ArrayListUnmanaged(u8).initCapacity(ally, str.len);
    defer parsed.deinit(ally);

    var is_escaped = false;
    var iter = com.utf8.Codepoint.parse(str);
    while (try iter.next()) |c| {
        // handle escape state
        if (!is_escaped and c.c == '\\') {
            is_escaped = true;
            continue;
        }
        defer is_escaped = false;

        // escape and write
        const ct = com.utf8.Codepoint.ct;
        const escaped = if (!is_escaped) c else switch (c.c) {
            'n' => ct("\n"),
            'r' => ct("\r"),
            '\\' => ct("\\"),
            '"' => ct("\""),
            '\'' => ct("\'"),
            else => return Error.InvalidStringEscapeSequence,
        };

        var buf: [4]u8 = undefined;
        const bytes = escaped.toBytes(&buf);
        parsed.appendSliceAssumeCapacity(bytes);
    }

    return try parsed.toOwnedSlice(ally);
}

/// list ::= lparen atom* rparen
fn parseList(ctx: *Context) Error!Object.Ref {
    var list = std.ArrayList(Object.Ref).init(ctx.ally);
    defer {
        vm.deacqAll(list.items);
        list.deinit();
    }

    _ = try ctx.expect(.lparen);

    while (true) {
        const tok = try ctx.mustPeek();
        if (tok.type == .rparen) {
            ctx.accept();
            break;
        }

        try list.append(try parseAtom(ctx));
    }

    return try vm.new(.{ .list = list.items });
}

/// atom ::= ident | number | string | list
fn parseAtom(ctx: *Context) Error!Object.Ref {
    const tok = try ctx.mustPeek();
    return switch (tok.type) {
        .ident => t: {
            ctx.accept();
            const ident = tok.slice(ctx.text);

            // since booleans are first-class values, I think it's most
            // appropriate to treat them as first-class syntax and live in
            // the parser (as opposed to being globally bound constants)
            if (std.mem.eql(u8, ident, "true")) {
                break :t try vm.new(.{ .bool = true });
            } else if (std.mem.eql(u8, ident, "false")) {
                break :t try vm.new(.{ .bool = false });
            }

            break :t try vm.new(.{ .tag = ident });
        },
        .number => t: {
            ctx.accept();
            const num_str = tok.slice(ctx.text);
            const num = std.fmt.parseInt(i64, num_str, 10) catch {
                return Error.InvalidNumber;
            };

            break :t try vm.new(.{ .int = num });
        },
        .string => t: {
            ctx.accept();
            const slice = tok.slice(ctx.text);

            const parsed = try parseString(ctx.ally, slice);
            defer ctx.ally.free(parsed);

            break :t try vm.new(.{ .string = parsed });
        },
        .lparen => try parseList(ctx),
        .rparen => Error.InvalidSyntax,
    };
}

/// parse a program into an object representing executable code
///
/// TODO I probably want to capture tokenization and parsing errors and
/// print error messages with the current context state, instead of
/// propagating them to the caller.
///
/// some ideas:
/// - return either an error with data attached or an object ref
/// - return an object ref, which might represent an error (this would be
///   very cool for its homoiconic properties)
/// - store errors/warnings as they are generated in a cache inside context,
///   the caller would then be responsible for checking this
pub fn parse(ally: Allocator, text: []const u8) Error!Object.Ref {
    var ctx = Context.init(ally, text);
    defer ctx.deinit(ally);

    return try parseAtom(&ctx);
}
