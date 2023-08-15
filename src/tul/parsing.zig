const std = @import("std");
const Allocator = std.mem.Allocator;
const com = @import("common");
const tul = @import("tul");
const registry = tul.registry;
const Object = tul.Object;
const Tokenizer = @import("parsing/tokenizer.zig");
const Token = Tokenizer.Token;

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
    file: registry.FileRef,
    tokens: Tokenizer,
    cache: ?Token = null,

    fn init(ally: Allocator, file: registry.FileRef) Self {
        return Self{
            .ally = ally,
            .file = file,
            .tokens = Tokenizer.init(registry.get(file).text),
        };
    }

    fn deinit(self: *Self, ally: Allocator) void {
        _ = self;
        _ = ally;

        // stub
    }

    fn getText(self: *const Self) []const u8 {
        return registry.get(self.file).text;
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

    fn locFromToken(self: *const Self, tok: Token) registry.Loc {
        return registry.Loc{
            .file = self.file,
            .start = @intCast(tok.index),
            .stop = @intCast(tok.index + tok.len - 1),
        };
    }

    /// adds an object to the tul and uses the token to mark its location
    fn newAtom(
        self: *const Self,
        tok: Token,
        init_obj: Object,
    ) Allocator.Error!Object.Ref {
        const ref = try tul.new(init_obj);
        try registry.mark(ref, self.locFromToken(tok));
        return ref;
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
        tul.deacqAll(list.items);
        list.deinit();
    }

    const lparen = try ctx.expect(.lparen);
    const rparen = while (true) {
        const tok = try ctx.mustPeek();
        if (tok.type == .rparen) {
            ctx.accept();
            break tok;
        }

        try list.append(try parseAtom(ctx));
    };

    const loc = ctx.locFromToken(lparen).to(ctx.locFromToken(rparen));
    const ref = try tul.new(.{ .list = list.items });
    try registry.mark(ref, loc);

    return ref;
}

/// atom ::= ident | number | string | list
fn parseAtom(ctx: *Context) Error!Object.Ref {
    const tok = try ctx.mustPeek();
    return switch (tok.type) {
        .ident => t: {
            ctx.accept();
            const ident = tok.slice(ctx.getText());

            if (std.mem.eql(u8, ident, "true")) {
                break :t try ctx.newAtom(tok, .{ .bool = true });
            } else if (std.mem.eql(u8, ident, "false")) {
                break :t try ctx.newAtom(tok, .{ .bool = false });
            }

            break :t try ctx.newAtom(tok, .{ .tag = ident });
        },
        .tag => t: {
            ctx.accept();
            const slice = tok.slice(ctx.getText());

            // remove @ symbol
            const tag = try tul.new(.{ .tag = slice[1..] });
            defer tul.deacq(tag);

            // quote the tag
            const quote = try tul.new(.{ .tag = "quote" });
            defer tul.deacq(quote);

            break :t try ctx.newAtom(tok, .{ .list = &.{ quote, tag } });
        },
        .number => t: {
            ctx.accept();
            const num_str = tok.slice(ctx.getText());
            const num = std.fmt.parseInt(i64, num_str, 10) catch {
                return Error.InvalidNumber;
            };

            break :t try ctx.newAtom(tok, .{ .int = num });
        },
        .string => t: {
            ctx.accept();
            const slice = tok.slice(ctx.getText());

            const parsed = try parseString(ctx.ally, slice);
            defer ctx.ally.free(parsed);

            break :t try ctx.newAtom(tok, .{ .string = parsed });
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
pub fn parse(
    ally: Allocator,
    filename: []const u8,
    text: []const u8,
) Error!Object.Ref {
    const file = try registry.register(filename, text);
    var ctx = Context.init(ally, file);
    defer ctx.deinit(ally);

    return try parseAtom(&ctx);
}
