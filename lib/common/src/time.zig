const std = @import("std");

/// get timestamp since epoch in seconds, with nanosecond precision
pub fn now() f64 {
    return @floatFromInt(f64, std.time.nanoTimestamp()) * 1e-9;
}
