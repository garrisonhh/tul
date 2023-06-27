const std = @import("std");
const Allocator = std.mem.Allocator;
const vm = @import("vm.zig");
const Tokenizer = @import("tokenizer.zig");
const Token = Tokenizer.Token;
const Object = @import("object.zig").Object;

const ParseError = error {
    UnexpectedEof,
    InvalidSyntax,

    /// TODO remove eventually
    Unimplemented,
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

/// this can also produce unit `()` if the list is empty
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

    if (list.items.len == 0) {
        return try vm.new(Object.unit);
    }
    return try vm.new(.{ .list = list.items });
}

fn parseAtom(ctx: *Context) Error!Object.Ref {
    const tok = try ctx.mustPeek();
    return switch (tok.type) {
        .ident => t: {
            ctx.accept();
            const ident = tok.slice(ctx.text);
            break :t try vm.new(.{ .tag = ident });
        },
        .lparen => try parseList(ctx),
        .rparen => Error.InvalidSyntax,
        else => Error.Unimplemented,
    };
}

pub fn parse(ally: Allocator, text: []const u8) Error!Object.Ref {
    var ctx = Context.init(ally, text);

    // TODO I probably want to capture tokenization and parsing errors and
    // print error messages with the current context state, instead of
    // propagating them to the caller. or return either an object and some
    // error struct to the caller.
    const root = try parseAtom(&ctx);

    return root;
}
