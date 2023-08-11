const std = @import("std");
const com = @import("common");
const bc = @import("../tul.zig").bc;
const Inst = bc.Inst;

const Self = @This();

pub const Error = error{
    InvalidInst,
    UnexpectedEndOfCode,
};

code: []const u8,
index: usize = 0,

fn nextByte(self: *Self) ?u8 {
    if (self.index >= self.code.len) {
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
