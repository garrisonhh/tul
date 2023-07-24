const std = @import("std");
const Allocator = std.mem.Allocator;
const com = @import("common");
const gc = @import("gc.zig");
const Object = @import("object.zig").Object;
const in_debug = @import("builtin").mode == .Debug;

/// type for storing branch addresses
pub const AddressInt = u32;

/// an atomic stack instruction
pub const Inst = enum(u8) {
    const Self = @This();

    const Meta = struct {
        const FieldTag = std.meta.FieldEnum(@This());

        const Input = union(enum) {
            /// takes some number of values
            pops: usize,
            /// takes `consumed` values
            consumed,
        };

        /// number of refs popped
        inputs: Input,
        /// number of refs pushed
        outputs: usize,
        /// number of extra bytes consumed in interpretation
        consumes: usize,

        fn of(inputs: Input, outputs: usize, consumes: usize) Meta {
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

    jump, // jump to addr
    branch, // if cond, jump to addr

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

    // comparison
    eq,

    // strings/lists
    concat,
    list,

    /// get metadata for how this instruction is parsed and affects the stack
    pub fn meta(self: Self) Meta {
        const m = Meta.of;
        const pops = struct {
            fn f(comptime n: comptime_int) Meta.Input {
                return .{ .pops = n };
            }
        }.f;

        return switch (self) {
            .nop => m(pops(0), 0, 0),
            .load_const => m(pops(0), 1, 4),
            .jump => m(pops(0), 0, @sizeOf(AddressInt)),
            .branch => m(pops(1), 0, @sizeOf(AddressInt)),
            .swap => m(pops(2), 2, 0),
            .dup => m(pops(1), 2, 0),
            .over => m(pops(2), 3, 0),
            .rot => m(pops(3), 3, 0),
            .drop => m(pops(1), 0, 0),
            .list => m(.consumed, 1, 4),

            .inspect,
            .lnot,
            => m(pops(1), 1, 0),

            .add,
            .sub,
            .mul,
            .div,
            .mod,
            .land,
            .lor,
            .eq,
            .concat,
            => m(pops(2), 1, 0),
        };
    }
};

pub const Function = struct {
    const Self = @This();

    /// gc tracked values
    /// TODO store these more globally, intern them with Object.HashMap
    consts: []const Object.Ref,
    /// bytecode
    code: []const u8,
    /// max refs required for stack vm
    stack_size: usize,

    pub fn deinit(self: Self, ally: Allocator) void {
        gc.deacqAll(self.consts);
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
    ) (Iterator.Error || @TypeOf(writer).Error)!void {
        var insts = iterator(self.code);
        var consumed: u64 = undefined;
        while (true) {
            const addr = insts.index;
            const inst = try insts.next(&consumed) orelse break;

            try writer.print("{d:>4} {s} ", .{ addr, @tagName(inst) });

            if (inst == .load_const) {
                const ref = self.consts[consumed];
                try writer.print("{}", .{gc.get(ref)});
            } else if (inst.meta().consumes > 0) {
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

    const BackRefMeta = struct {
        index: usize,
        nailed: bool,
    };

    pub const BackRef = com.Ref(.backref, 4);
    const BackRefMap = com.RefMap(BackRef, BackRefMeta);

    ally: Allocator,
    consts: std.ArrayListUnmanaged(Object.Ref) = .{},
    code: std.ArrayListUnmanaged(u8) = .{},
    backrefs: BackRefMap = .{},

    pub fn init(ally: Allocator) Self {
        return .{ .ally = ally };
    }

    pub fn deinit(self: *Self) void {
        gc.deacqAll(self.consts.items);
        self.consts.deinit(self.ally);
        self.code.deinit(self.ally);
        self.backrefs.deinit(self.ally);
    }

    /// sanity check for debugging backref code
    fn fullyNailed(self: *const Self) bool {
        var nailed = true;

        var nails = self.backrefs.iterator();
        while (nails.nextEntry()) |entry| {
            const backref = entry.ref;
            const meta = entry.ptr;

            if (!meta.nailed) {
                std.debug.print("[unnailed] {p}\n", .{backref});
                nailed = false;
            }
        }

        return nailed;
    }

    /// frees all builder memory, you can safely ignore deinit if you call this
    pub fn build(self: *Self) Allocator.Error!Function {
        std.debug.assert(self.fullyNailed());
        self.backrefs.deinit(self.ally);

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
        gc.acq(ref);
        const index: u32 = @intCast(self.consts.items.len);
        try self.consts.append(self.ally, ref);
        return index;
    }

    /// store and acq a ref; add a load instruction
    pub fn loadConst(self: *Self, ref: Object.Ref) Allocator.Error!void {
        const ld = try self.addConst(ref);
        try self.addInstC(.load_const, ld);
    }

    /// add an instruction with no consumed data
    pub fn addInst(self: *Self, inst: Inst) Allocator.Error!void {
        try self.code.append(self.ally, @intFromEnum(inst));
    }

    fn Consumed(comptime inst: Inst) type {
        return std.meta.Int(.unsigned, 8 * inst.meta().consumes);
    }

    /// add an instruction with consumed data. for instructions with no data,
    /// this type will be `u0`.
    pub fn addInstC(
        self: *Self,
        comptime inst: Inst,
        c: Consumed(inst),
    ) Allocator.Error!void {
        try self.addInst(inst);
        const consumed = com.bytes.bytesFromInt(Consumed(inst), c);
        try self.code.appendSlice(self.ally, &consumed);
    }

    /// add a control flow instruction with a backreferenced address as its
    /// consumed value
    pub fn addInstBackRef(self: *Self, inst: Inst) Allocator.Error!BackRef {
        // verify for debug
        std.debug.assert(switch (inst) {
            .jump, .branch => true,
            else => false,
        });

        // add inst with dummy value
        try self.addInst(inst);
        const index = self.code.items.len;
        try self.code.appendNTimes(self.ally, undefined, @sizeOf(AddressInt));

        return try self.backrefs.put(self.ally, .{
            .index = index,
            .nailed = false,
        });
    }

    /// writes current instruction address to the backref
    pub fn nail(self: *Self, back: BackRef) Allocator.Error!void {
        const meta = self.backrefs.get(back);
        std.debug.assert(!meta.nailed);

        // get consumed int slice
        const start = meta.index;
        const stop = meta.index + @sizeOf(AddressInt);
        const slice = self.code.items[start..stop];

        // get slice for address
        const addr: AddressInt = @intCast(self.code.items.len);
        const bytes = com.bytes.bytesFromInt(AddressInt, addr);
        @memcpy(slice, &bytes);

        // check boxes
        meta.nailed = true;
    }
};

/// flexible iterator for code
pub const Iterator = struct {
    const Self = @This();

    pub const Error = error{
        InvalidInst,
        UnexpectedEndOfCode,
    };

    code: []const u8,
    index: usize = 0,

    fn nextByte(self: *Self) ?u8 {
        if (self.index == self.code.len) {
            return null;
        }

        defer self.index += 1;
        return self.code[self.index];
    }

    /// set state to an absolute index
    pub fn jump(self: *Self, index: usize) void {
        std.debug.assert(index <= self.code.len);
        self.index = index;
    }

    /// iterates to next instruction, writing any consumed bytes to the
    /// provided address
    pub fn next(self: *Self, consumed: *u64) Error!?Inst {
        // get instruction
        const inst_byte = self.nextByte() orelse {
            return null;
        };

        const inst = std.meta.intToEnum(Inst, inst_byte) catch {
            return Error.InvalidInst;
        };

        // read any consumed bytes
        const eat = inst.meta().consumes;
        if (eat > 0) {
            if (self.index + eat > self.code.len) {
                return Error.InvalidInst;
            }

            const chomp = self.code[self.index .. self.index + eat];
            self.index += eat;
            consumed.* = com.bytes.intFromBytes(u64, chomp);
        } else {
            consumed.* = undefined;
        }

        return inst;
    }
};

/// canonical iteration for bytecode
pub fn iterator(code: []const u8) Iterator {
    return .{ .code = code };
}
