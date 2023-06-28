const std = @import("std");

/// extrude an int into an array
pub fn bytesFromInt(
    comptime T: type,
    value: T,
    endian: std.builtin.Endian,
) [@sizeOf(T)]u8 {
    var arr: [@sizeOf(T)]u8 = undefined;
    std.mem.writeIntSlice(T, &arr, value, endian);
    return arr;
}