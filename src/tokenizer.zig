const std = @import("std");
const com = @import("common");
const Codepoint = com.utf8.Codepoint;

pub const Error = Codepoint.ParseError || error{
    UnterminatedString,
    DisallowedCharacter,
};

pub const Token = struct {
    pub const Type = enum {
        lparen,
        rparen,
        ident,
        tag,
        number,
        string,
    };

    index: usize,
    len: usize,
    type: Type,

    pub fn slice(self: Token, text: []const u8) []const u8 {
        return text[self.index .. self.index + self.len];
    }
};

/// type for metaprogramming symbol tokens
const Symbol = struct {
    const list = [_]Symbol{
        ct("(", .lparen),
        ct(")", .rparen),
    };

    c: Codepoint,
    type: Token.Type,

    fn ct(comptime str: []const u8, ty: Token.Type) Symbol {
        return Symbol{
            .c = Codepoint.ct(str),
            .type = ty,
        };
    }

    /// check for a matching symbol
    fn get(c: Codepoint) ?Token.Type {
        return for (list) |sym| {
            if (sym.c.eql(c)) {
                break sym.type;
            }
        } else null;
    }
};

/// valid codepoints for the beginning of an identifier
/// TODO extend this using js or c++ spec as examples
fn isIdentStart(c: Codepoint) bool {
    return switch (c.getUnicodeBlock()) {
        .BasicLatin,
        .Latin1Supplement,
        .Emoticons,
        .MiscellaneousSymbolsAndPictographs,
        => b: {
            // banned chars
            const ct = Codepoint.ct;
            const banned = [_]Codepoint{
                ct("@"),
            };

            for (banned) |bc| {
                if (bc.eql(c)) break :b false;
            }

            // banned char classes
            const is_space = c.isSpace();
            const is_digit = c.isDigit(10);
            const is_sym = Symbol.get(c) != null;

            break :b !is_space and !is_sym and !is_digit;
        },
        else => false,
    };
}

/// valid codepoints for the tail of an identifier
/// TODO extend this using js or c++ spec as examples
fn isIdentInner(c: Codepoint) bool {
    return switch (c.getUnicodeBlock()) {
        .BasicLatin,
        .Latin1Supplement,
        .Emoticons,
        .MiscellaneousSymbolsAndPictographs,
        => b: {
            const is_space = c.isSpace();
            const is_sym = Symbol.get(c) != null;

            break :b !is_space and !is_sym;
        },
        else => false,
    };
}

const Self = @This();

iter: Codepoint.Iterator,

pub fn init(text: []const u8) Self {
    return Self{ .iter = Codepoint.parse(text) };
}

/// accept codepoints while they match a predicate
fn acceptWhile(
    self: *Self,
    comptime pred: fn (Codepoint) bool,
) Codepoint.ParseError!void {
    while (true) {
        const c = try self.iter.peek() orelse break;
        if (pred(c)) {
            self.iter.accept(c);
        } else {
            break;
        }
    }
}

/// accept codepoints while they match a digit predicate
fn acceptDigits(
    self: *Self,
    comptime base: comptime_int,
) Codepoint.ParseError!void {
    while (true) {
        const c = try self.iter.peek() orelse break;
        if (c.isDigit(base)) {
            self.iter.accept(c);
        } else {
            break;
        }
    }
}

/// accept codepoints until the end of a string
fn acceptString(self: *Self) Error!void {
    var is_escaped = false;
    while (true) {
        const c = try self.iter.next() orelse {
            return Error.UnterminatedString;
        };

        if (!is_escaped and c.c == '"') break;

        is_escaped = c.c == '\\' and !is_escaped;
    }
}

fn skipSpaces(self: *Self) Codepoint.ParseError!void {
    try self.acceptWhile(Codepoint.isSpace);
}

pub fn next(self: *Self) Error!?Token {
    try self.skipSpaces();

    const index = self.iter.byte_index;
    const c = try self.iter.next() orelse {
        return null;
    };

    const ty: Token.Type = t: {
        if (Symbol.get(c)) |t| {
            break :t t;
        } else if (c.isDigit(10)) {
            try self.acceptDigits(10);
            break :t .number;
        } else if (c.c == '"') {
            try self.acceptString();
            break :t .string;
        } else if (c.c == '+' or c.c == '-') {
            const pk = try self.iter.peek();
            const is_number = if (pk) |got| got.isDigit(10) else false;

            if (is_number) {
                try self.acceptDigits(10);
                break :t .number;
            } else {
                try self.acceptWhile(isIdentInner);
                break :t .ident;
            }
        } else if (isIdentStart(c)) {
            try self.acceptWhile(isIdentInner);
            break :t .ident;
        } else if (c.eql(Codepoint.ct("@"))) {
            try self.acceptWhile(isIdentInner);
            break :t .tag;
        } else {
            std.debug.print("disallowed character: `{}`\n", .{c});
            std.debug.print("in unicode block: {}\n", .{c.getUnicodeBlock()});
            return Error.DisallowedCharacter;
        }
    };

    const len = self.iter.byte_index - index;

    return Token{
        .index = index,
        .len = len,
        .type = ty,
    };
}
