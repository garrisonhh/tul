//! source registry for error reporting

const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const com = @import("common");
const tul = @import("tul.zig");
const Object = tul.Object;
const formatters = @import("formatters.zig");

pub const Loc = struct {
    file: FileRef,
    /// char index
    start: u32,
    /// char index
    stop: u32,

    /// merge two locs (like `begin.to(end)`)
    pub fn to(begin: Loc, end: Loc) Loc {
        std.debug.assert(begin.file.index == end.file.index);
        std.debug.assert(end.stop >= begin.start);
        return Loc{
            .file = begin.file,
            .start = begin.start,
            .stop = end.stop,
        };
    }

    pub const format = @compileError("use Loc.fmt() to print a location");

    /// since calculating line + char numbers for the expected output is kinda
    /// expensive, wrapping this in a function to be explicit about when this
    /// computation is happening is important
    pub fn fmt(loc: Loc) Formattable {
        return Formattable.init(loc);
    }

    pub const Formattable = struct {
        const Indices = struct {
            lineno: usize,
            charno: usize,

            fn ofIndex(text: []const u8, charno: usize) Indices {
                var lineno: usize = 1;
                var last_start: usize = 0;

                for (text[0..charno], 0..) |ch, i| {
                    if (ch == '\n') {
                        lineno += 1;
                        last_start = i;
                    }
                }

                return Indices{
                    .lineno = lineno,
                    .charno = charno - last_start,
                };
            }
        };

        filename: []const u8,
        start: Indices,
        stop: Indices,

        pub fn init(loc: Loc) Formattable {
            const file = get(loc.file);
            return Formattable{
                .filename = file.name,
                .start = Indices.ofIndex(file.text, loc.start),
                .stop = Indices.ofIndex(file.text, loc.stop),
            };
        }

        pub fn format(
            self: Formattable,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) @TypeOf(writer).Error!void {
            try writer.print("{s}:", .{self.filename});

            if (self.start.lineno == self.stop.lineno) {
                try writer.print(
                    "{d}:{d}",
                    .{ self.start.lineno, self.start.charno },
                );

                if (self.start.charno != self.stop.charno) {
                    try writer.print("-{d}", .{self.stop.charno});
                }
            } else {
                try writer.print("{d}:{d}-{d}:{d}", .{
                    self.start.lineno,
                    self.start.charno,
                    self.stop.lineno,
                    self.stop.charno,
                });
            }
        }
    };
};

const File = struct {
    name: []const u8,
    text: []const u8,
};

pub const FileRef = com.Ref(.file, 32);
const FileMap = com.RefMap(FileRef, File);

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const ally = gpa.allocator();

var files = FileMap{};
var locs = std.AutoHashMapUnmanaged(Object.Ref, Loc){};

/// must be called before tul.deinit()
pub fn deinit() void {
    var refs = locs.keyIterator();
    while (refs.next()) |ref| tul.deacq(ref.*);

    var file_iter = files.iterator();
    while (file_iter.next()) |file| {
        ally.free(file.name);
        ally.free(file.text);
    }

    files.deinit(ally);
    locs.deinit(ally);
    _ = gpa.deinit();

    if (builtin.is_test) {
        files = .{};
        locs = .{};
        gpa = .{};
    }
}

/// add a file to the registry
pub fn register(name: []const u8, text: []const u8) Allocator.Error!FileRef {
    return try files.put(ally, File{
        .name = try ally.dupe(u8, name),
        .text = try ally.dupe(u8, text),
    });
}

/// retrieve a file
pub fn get(fr: FileRef) *const File {
    return files.get(fr);
}

/// add an object's source location to the registry
pub fn mark(ref: Object.Ref, loc: Loc) Allocator.Error!void {
    try locs.putNoClobber(ally, ref, loc);
    tul.acq(ref);
}

/// attempt to retrieve a source location for an object
pub fn find(ref: Object.Ref) ?Loc {
    return locs.get(ref);
}

/// displays all locations to stderr for debugging purposes
pub fn inspectLocations() void {
    var iter = locs.iterator();
    while (iter.next()) |entry| {
        std.debug.print(
            "[{}]\n{}\n",
            .{ entry.value_ptr.fmt(), tul.get(entry.key_ptr.*) },
        );
    }
}
