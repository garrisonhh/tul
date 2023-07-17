const std = @import("std");
const Allocator = std.mem.Allocator;
const com = @import("common");
const vm = @import("vm.zig");
const Object = @import("object.zig").Object;
const in_debug = @import("builtin").mode == .Debug;

/// an atomic stack instruction
pub const Inst = enum(u8) {
    const Self = @This();

    const Meta = struct {
        /// tag of the meta type fields
        const FieldTag = t: {
            const fields = @typeInfo(Meta).Struct.fields;
            var tag_fields: [fields.len]std.builtin.Type.EnumField = undefined;

            for (fields, &tag_fields, 0..) |st_field, *e_field, i| {
                e_field.* = .{
                    .name = st_field.name,
                    .value = i,
                };
            }

            break :t @Type(.{
                .Enum = .{
                    .tag_type = u8,
                    .fields = &tag_fields,
                    .decls = &.{},
                    .is_exhaustive = true,
                },
            });
        };

        /// number of refs popped
        inputs: comptime_int,
        /// number of refs pushed
        outputs: comptime_int,
        /// number of extra bytes consumed in interpretation
        consumes: comptime_int,

        fn of(
            comptime inputs: comptime_int,
            comptime outputs: comptime_int,
            comptime consumes: comptime_int,
        ) Meta {
            return .{
                .inputs = inputs,
                .outputs = outputs,
                .consumes = consumes,
            };
        }
    };

    nop = 0,

    load_const,
    inspect,

    jump,

    swap, // x y - y x
    dup, // x - x x
    over, // x y - x y x
    rot, // x y z - y z x
    drop, // x y - x

    // math
    add,
    sub,
    mul,
    div,
    mod,

    // logic
    land,
    lor,
    lnot,

    /// comptime mapping of inst -> metadata
    fn meta(comptime self: Self) Meta {
        comptime {
            const m = Meta.of;
            return switch (self) {
                .nop => m(0, 0, 0),
                .load_const => m(0, 1, 4),
                .jump => m(0, 0, 4),
                .swap => m(2, 2, 0),
                .dup => m(1, 2, 0),
                .over => m(2, 3, 0),
                .rot => m(3, 3, 0),
                .drop => m(1, 0, 0),

                .inspect,
                .lnot,
                => m(1, 1, 0),
                .add,
                .sub,
                .mul,
                .div,
                .mod,
                .land,
                .lor,
                => m(2, 1, 0),
            };
        }
    }

    /// get metadata about this instruction
    pub fn getMeta(self: Self, comptime field: Meta.FieldTag) usize {
        return switch (self) {
            inline else => |inst| @field(inst.meta(), @tagName(field)),
        };
    }

    /// canonical way to read bytecode
    pub fn iterator(code: []const u8) Iterator {
        return Iterator.init(code);
    }

    pub const Iterator = struct {
        pub const Error = error{
            InvalidInst,
            InvalidJump,
            UnexpectedEndOfCode,
        };

        start: []const u8,
        cur: []const u8,

        fn init(code: []const u8) Iterator {
            return Iterator{
                .start = code,
                .cur = code,
            };
        }

        fn nextByte(iter: *Iterator) ?u8 {
            if (iter.cur.len == 0) return null;

            defer iter.cur = iter.cur[1..];
            return iter.cur[0];
        }

        /// set state to an absolute index
        fn jump(iter: *Iterator, index: usize) Error!void {
            if (index >= iter.start.len) {
                return Error.InvalidJump;
            }

            iter.cur = iter.start[index..];
        }

        /// iterates to next instruction, writing any consumed bytes to the
        /// provided address
        pub fn next(iter: *Iterator, consumed: *u64) Error!?Inst {
            // get instruction
            const inst_byte = iter.nextByte() orelse {
                return null;
            };

            const inst = std.meta.intToEnum(Inst, inst_byte) catch {
                return Error.InvalidInst;
            };

            // read any consumed bytes
            const consume_bytes: usize = inst.getMeta(.consumes);

            if (consume_bytes > 0) {
                var n: usize = 0;
                for (0..consume_bytes) |_| {
                    const byte = iter.nextByte() orelse {
                        return Error.UnexpectedEndOfCode;
                    };
                    n = (n << 8) | byte;
                }

                consumed.* = n;
            } else {
                consumed.* = undefined;
            }

            return inst;
        }
    };
};

const comptime_parsing = struct {
    /// iterate lines with ';' comment support
    const LineIterator = struct {
        const Self = @This();

        iter: std.mem.TokenIterator(u8, .scalar),

        fn init(str: []const u8) Self {
            return .{ .iter = std.mem.tokenizeScalar(u8, str, '\n') };
        }

        fn next(self: *Self) ?[]const u8 {
            const line = self.iter.next() orelse {
                return null;
            };

            // remove comments
            if (std.mem.indexOf(u8, line, ";")) |index| {
                return line[0..index];
            }

            return line;
        }
    };

    fn tokenize(str: []const u8) std.mem.TokenIterator(u8, .any) {
        const ws = "\t\n\r ";
        return std.mem.tokenizeAny(u8, str, ws);
    }

    fn splitLines(str: []const u8) LineIterator {
        return LineIterator.init(str);
    }

    /// bytes generated by line
    fn LineBytes(comptime str: []const u8) comptime_int {
        comptime {
            var tokens = tokenize(str);
            const fst = tokens.next() orelse {
                return 0;
            };
            const inst = parseInst(fst);
            return 1 + inst.meta().consumes;
        }
    }

    /// bytes generated by program
    fn BytecodeBytes(comptime str: []const u8) comptime_int {
        comptime {
            var n = 0;
            var lines = splitLines(str);
            while (lines.next()) |line| {
                n += LineBytes(line);
            }

            return n;
        }
    }

    fn parseInst(comptime name: []const u8) Inst {
        comptime {
            // TODO use std.meta.stringToEnum when it works
            for (std.meta.fields(Inst)) |tag| {
                if (std.mem.eql(u8, tag.name, name)) {
                    return @field(Inst, name);
                }
            } else {
                std.debug.panic("`{s}` is not a valid instruction", .{name});
            }
        }
    }

    /// parses non-negative decimal to a comptime_int
    fn parseUInt(comptime text: []const u8) comptime_int {
        comptime {
            var n = 0;
            for (text) |digit| {
                switch (digit) {
                    '0'...'9' => {},
                    else => std.debug.panic(
                        "non-digits found in number `{s}`",
                        .{text},
                    ),
                }

                n = n * 10 + @as(comptime_int, digit - '0');
            }

            return n;
        }
    }

    /// parse line into [_]u8 bytecode at comptime
    fn parseLine(comptime str: []const u8) [LineBytes(str)]u8 {
        return comptime ct: {
            var bytes = std.BoundedArray(u8, LineBytes(str)){};
            var tokens = tokenize(str);

            // inst byte
            const inst_tok = tokens.next() orelse {
                return bytes.buffer;
            };
            const inst = parseInst(inst_tok);
            bytes.appendAssumeCapacity(@intFromEnum(inst));

            // any other bytes
            const consumes = inst.meta().consumes;
            if (consumes > 0) {
                // parse number into bytes
                const num_tok = tokens.next() orelse {
                    std.debug.panic("{} expects a number", .{inst});
                };
                var num = parseUInt(num_tok);

                // to big-endian repr
                var be_bytes: [consumes]u8 = undefined;
                var i = consumes;
                while (i > 0) {
                    i -= 1;
                    be_bytes[i] = num % 256;
                    num >>= 8;
                }

                bytes.appendSliceAssumeCapacity(&be_bytes);
            }

            std.debug.assert(bytes.len == bytes.capacity());
            break :ct bytes.buffer;
        };
    }

    /// parse full bytecode program
    /// supports asm-style comments with ';'
    fn parseBytecode(comptime str: []const u8) [BytecodeBytes(str)]u8 {
        return comptime ct: {
            var bytes = std.BoundedArray(u8, BytecodeBytes(str)){};
            var lines = splitLines(str);

            while (lines.next()) |line| {
                const line_bytes = parseLine(line);
                bytes.appendSliceAssumeCapacity(&line_bytes);
            }

            std.debug.assert(bytes.len == bytes.capacity());
            break :ct bytes.buffer;
        };
    }
};

pub const ct_parse = comptime_parsing.parseBytecode;

fn expectParse(bytes: []const u8, comptime str: []const u8) !void {
    var parsed = comptime ct_parse(str);
    try std.testing.expectEqualSlices(u8, bytes, &parsed);
}

test "line parsing" {
    try expectParse(&.{ 0, 1, 0, 0, 1, 0 },
        \\ nop
        \\ ; this is a comment
        \\ load_const 256 ; this is another comment
        \\
    );
}

pub const Function = struct {
    const Self = @This();

    /// gc tracked values
    consts: []const Object.Ref,
    /// bytecode
    code: []const u8,
    /// max refs required for stack vm
    stack_size: usize,

    pub fn deinit(self: Self, ally: Allocator) void {
        vm.deacqAll(self.consts);
        ally.free(self.consts);
        ally.free(self.code);
    }

    pub fn numOps(self: Self) Inst.Iterator.Error!usize {
        var n: usize = 0;
        var consumed: u64 = undefined;
        var insts = Inst.iterator(self.code);
        while (try insts.next(&consumed)) |_| {
            n += 1;
        }

        return n;
    }

    /// print this function's code
    pub fn display(
        self: Self,
        writer: anytype,
    ) (Inst.Iterator.Error || @TypeOf(writer).Error)!void {
        var insts = Inst.iterator(self.code);
        var consumed: u64 = undefined;
        while (try insts.next(&consumed)) |inst| {
            try writer.print("{s} ", .{@tagName(inst)});

            if (inst == .load_const) {
                const ref = self.consts[consumed];
                try writer.print("{}", .{vm.get(ref)});
            } else if (inst.getMeta(.consumes) > 0) {
                try writer.print("{d}", .{consumed});
            }

            try writer.writeByte('\n');
        }
    }
};

/// a tool for easily creating bytecode functions
///
/// builders are not reusable, you instantiate them, build(), and then store the
/// function for whatever purpose
pub const Builder = struct {
    const Self = @This();

    ally: Allocator,
    consts: std.ArrayListUnmanaged(Object.Ref) = .{},
    code: std.ArrayListUnmanaged(u8) = .{},

    pub fn init(ally: Allocator) Self {
        return .{ .ally = ally };
    }

    pub fn deinit(self: *Self) void {
        vm.deacqAll(self.consts.items);
        self.consts.deinit(self.ally);
        self.code.deinit(self.ally);
    }

    /// frees all builder memory, you can safely ignore deinit if you call this
    pub fn build(self: *Self) Allocator.Error!Function {
        return Function{
            .consts = try self.consts.toOwnedSlice(self.ally),
            .code = try self.code.toOwnedSlice(self.ally),
            // TODO am I statically analyzing this? making the consumer of this
            // builder track it?
            .stack_size = 256,
        };
    }

    /// stores and acqs a ref to the builder, returns const index
    fn addConst(self: *Self, ref: Object.Ref) Allocator.Error!u32 {
        vm.acq(ref);
        const index = @intCast(u32, self.consts.items.len);
        try self.consts.append(self.ally, ref);
        return index;
    }

    /// store and acq a ref; add a load instruction
    pub fn loadConst(self: *Self, ref: Object.Ref) Allocator.Error!void {
        const ld = try self.addConst(ref);
        try self.addInstC(.load_const, ld);
    }

    fn Consumed(comptime inst: Inst) type {
        return std.meta.Int(.unsigned, 8 * inst.getMeta(.consumes));
    }

    /// add an instruction with consumed data. for instructions with no data,
    /// this type will be `u0`.
    pub fn addInstC(
        self: *Self,
        comptime inst: Inst,
        c: Consumed(inst),
    ) Allocator.Error!void {
        try self.addInst(inst);
        const consumed = com.bytes.bytesFromInt(Consumed(inst), c, .Big);
        try self.code.appendSlice(self.ally, &consumed);
    }

    /// add an instruction with no consumed data
    pub fn addInst(self: *Self, inst: Inst) Allocator.Error!void {
        try self.code.append(self.ally, @intFromEnum(inst));
    }
};

/// context for function execution
pub const Frame = struct {
    const Self = @This();
    const Stack = std.ArrayListUnmanaged(Object.Ref);

    func: *const Function,
    stack: Stack,
    iter: Inst.Iterator,

    pub fn init(ally: Allocator, func: *const Function) Allocator.Error!Self {
        return Self{
            .func = func,
            .stack = try Stack.initCapacity(ally, func.stack_size),
            .iter = Inst.iterator(func.code),
        };
    }

    pub fn deinit(self: *Self, ally: Allocator) void {
        std.debug.assert(self.stack.items.len == 0);
        self.stack.deinit(ally);
    }

    /// use code iterator through this
    pub fn nextInst(self: *Self, consumed: *u64) Inst.Iterator.Error!?Inst {
        return self.iter.next(consumed);
    }

    pub fn push(self: *Self, ref: Object.Ref) void {
        self.stack.appendAssumeCapacity(ref);
    }

    pub fn pushAll(self: *Self, refs: []const Object.Ref) void {
        for (refs) |ref| self.push(ref);
    }

    fn assertStack(self: Self, num_items: usize) void {
        if (in_debug and self.stack.items.len < num_items) {
            @panic("stack frame underflow :(");
        }
    }

    pub fn pop(self: *Self) Object.Ref {
        self.assertStack(1);
        return self.stack.pop();
    }

    pub fn popArray(self: *Self, comptime N: comptime_int) [N]Object.Ref {
        const arr = self.peekArray(N);
        self.stack.shrinkRetainingCapacity(self.stack.items.len - N);
        return arr;
    }

    pub fn peek(self: Self) Object.Ref {
        self.assertStack(1);
        return self.stack.getLast();
    }

    pub fn peekArray(self: Self, comptime N: comptime_int) [N]Object.Ref {
        self.assertStack(N);
        var arr: [N]Object.Ref = undefined;
        @memcpy(&arr, self.stack.items[self.stack.items.len - N ..]);
        return arr;
    }

    /// jump to an instruction address
    pub fn jump(self: *Self, index: usize) Inst.Iterator.Error!void {
        try self.iter.jump(index);
    }
};
