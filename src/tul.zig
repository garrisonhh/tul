//! external module for tul. all the stuff you need to access from an embedding
//! perspective.

const tul = @import("tul");

pub const pipes = tul.pipes;
pub usingnamespace pipes;
pub const registry = tul.registry;
pub const Object = tul.Object;
pub const gc = tul.gc;

// gc primitives
pub const new = tul.new;
pub const put = tul.put;
pub const get = tul.get;
pub const acq = tul.acq;
pub const deacq = tul.deacq;
pub const acqAll = tul.acqAll;
pub const deacqAll = tul.deacqAll;
