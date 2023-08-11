//! internal root module.

pub usingnamespace @import("pipes.zig");
pub const registry = @import("registry.zig");
pub const Object = @import("object.zig").Object;
pub const gc = @import("gc.zig");
pub const parsing = @import("parsing.zig");
pub const lowering = @import("lowering.zig");
pub const bc = @import("bytecode.zig");
pub const vm = @import("vm.zig");

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
