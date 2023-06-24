const std = @import("std");
const Allocator = std.mem.Allocator;
const vm = @import("vm.zig");
const Object = @import("object.zig").Object;
const in_debug = @import("builtin").mode == .Debug;

/// an atomic stack instruction
pub const Inst = enum(u8) {
    const Self = @This();

    const Meta = struct {
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

    swap, // x y - y x
    dup, // x - x x
    over, // x y - x y x
    rot, // x y z - y z x
    drop, // x y - x

    add,
    sub,
    mul,
    div,
    mod,

    /// comptime mapping of inst -> metadata
    pub fn meta(comptime self: Self) Meta {
        comptime {
            const m = Meta.of;
            return switch (self) {
                .nop => m(0, 0, 0),
                .load_const => m(0, 1, 4),
                .inspect => m(1, 1, 0),
                .swap => m(2, 2, 0),
                .dup => m(1, 2, 0),
                .over => m(2, 3, 0),
                .rot => m(3, 3, 0),
                .drop => m(1, 0, 0),
                .add, .sub, .mul, .div, .mod => m(2, 1, 0),
            };
        }
    }

    /// canonical way to read bytecode
    pub fn iterator(code: []const u8) Iterator {
        return Iterator.init(code);
    }

    const Iterator = struct {
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

        /// set state to an index
        pub fn jump(iter: *Iterator, index: usize) Error!void {
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
            const consume_bytes: usize = switch (inst) {
                inline else => |tag| tag.meta().consumes,
            };

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

pub const Function = struct {
    const Self = @This();

    pub const Diff = struct {
        inputs: usize,
        outputs: usize,
    };

    /// owned by function
    consts: []Object,
    /// bytecode
    code: []const u8,
    /// max refs required for stack vm
    stack_size: usize,

    pub fn deinit(self: *const Self, ally: Allocator) void {
        for (self.consts) |obj| obj.deinit(ally);
        ally.free(self.consts);
        ally.free(self.code);
    }

    pub fn numOps(self: Self) Inst.Iterator.Error!usize {
        var n: usize = 0;
        var insts = Inst.iterator(self.code);
        while (try insts.next()) |_| {
            n += 1;
        }

        return n;
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

    pub fn pop(self: *Self) Object.Ref {
        if (in_debug and self.stack.items.len == 0) {
            @panic("stack frame underflow :(");
        }

        return self.stack.pop();
    }
};
