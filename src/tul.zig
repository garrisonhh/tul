//! root module for tul. all the stuff you need to access from an embedding
//! perspective.

pub usingnamespace @import("tul/pipes.zig");
pub const registry = @import("tul/registry.zig");
pub const Object = @import("tul/object.zig").Object;
pub const gc = @import("tul/gc.zig");

// gc primitives
pub const new = gc.new;
pub const put = gc.put;
pub const get = gc.get;
pub const acq = gc.acq;
pub const deacq = gc.deacq;
pub const acqAll = gc.acqAll;
pub const deacqAll = gc.deacqAll;

comptime {
    @import("std").testing.refAllDecls(@This());
}
