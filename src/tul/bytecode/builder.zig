//! a tool for easily creating bytecode functions
//!
//! builders are not reusable, you instantiate them, build(), and then store the
//! function for whatever purpose

const std = @import("std");
const Allocator = std.mem.Allocator;
const com = @import("common");
const Object = @import("../object.zig").Object;
const gc = @import("../gc.zig");
const bc = @import("../bytecode.zig");
const Inst = bc.Inst;
const Function = bc.Function;
const AddressInt = bc.AddressInt;

const Self = @This();

/// should map parameter identifiers to absolute stack indices 0..k
pub const Args = std.StringHashMapUnmanaged(u32);

const BackRefMeta = struct {
    index: usize,
    nailed: bool,
};

pub const BackRef = com.Ref(.backref, 4);
const BackRefMap = com.RefMap(BackRef, BackRefMeta);

ally: Allocator,
args: *const Args,
consts: std.ArrayListUnmanaged(Object.Ref) = .{},
code: std.ArrayListUnmanaged(u8) = .{},
backrefs: BackRefMap = .{},

pub fn init(ally: Allocator, args: *const Args) Self {
    return Self{
        .ally = ally,
        .args = args,
    };
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

/// all memory is freed or moved to Function, you can safely ignore deinit if
/// you call this
pub fn build(self: *Self) Allocator.Error!Function {
    std.debug.assert(self.fullyNailed());
    self.backrefs.deinit(self.ally);

    return Function{
        .consts = try self.consts.toOwnedSlice(self.ally),
        .code = try self.code.toOwnedSlice(self.ally),
        .param_count = self.args.count(),
        // TODO am I statically analyzing this? making the consumer of this
        // builder track it?
        .stack_size = 256,
    };
}

pub fn hasArg(self: *const Self, ident: []const u8) bool {
    return self.args.contains(ident);
}

pub fn loadArg(self: *Self, ident: []const u8) Allocator.Error!void {
    const index = self.args.get(ident).?;
    try self.addInstC(.load_abs, index);
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
    std.debug.assert(inst.isBranching());

    // add inst with buffer space for the address
    try self.addInst(inst);
    const index = self.code.items.len;
    try self.code.appendNTimes(self.ally, undefined, @sizeOf(AddressInt));

    // store location of address for future nailage
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
