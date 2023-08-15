//! internal root module.

// high level stuff
pub const pipes = @import("pipes.zig");
pub usingnamespace pipes;
pub const registry = @import("registry.zig");
pub const Object = @import("object.zig").Object;

// low level stuff
pub const gc = @import("gc.zig");
pub const parsing = @import("parsing.zig");
pub const lowering = @import("lowering.zig");
pub const bc = @import("bytecode.zig");
pub const vm = @import("vm.zig");

// implementation details
pub const fmt = @import("formatters.zig");

// gc primitives for convenience
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
