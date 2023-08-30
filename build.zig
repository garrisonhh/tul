const std = @import("std");
const stderr = std.io.getStdErr().writer();
const builtin = @import("builtin");

const VersionError = error{WrongVersion};

fn ensureVersion() (@TypeOf(stderr).Error || VersionError)!void {
    const req_version = std.SemanticVersion{
        .major = 0,
        .minor = 11,
        .patch = 0,
    };

    // ensure version matches req_version
    if (builtin.zig_version.order(req_version).compare(.neq)) {
        try stderr.print(
            "error: expected version {}, found {}\n",
            .{ req_version, builtin.zig_version },
        );
        return VersionError.WrongVersion;
    }
}

const BuildError = std.mem.Allocator.Error || @TypeOf(stderr).Error || VersionError;

pub fn build(b: *std.Build) BuildError!void {
    ensureVersion() catch |e| {
        if (e == VersionError.WrongVersion) return;
        return e;
    };

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // libs
    const common = b.dependency("zighh", .{}).module("common");
    const blox = b.dependency("blox", .{}).module("blox");

    const tulInternal = b.createModule(.{
        .source_file = .{ .path = "src/tul/tul.zig" },
        .dependencies = &.{
            .{ .name = "common", .module = common },
            .{ .name = "blox", .module = blox },
        },
    });
    try tulInternal.dependencies.put("tul", tulInternal);

    const tulExternal = b.addModule("tul", .{
        .source_file = .{ .path = "src/tul.zig" },
        .dependencies = &.{
            .{ .name = "common", .module = common },
            .{ .name = "blox", .module = blox },
            .{ .name = "tul", .module = tulInternal },
        },
    });

    // repl
    const repl = b.addExecutable(.{
        .name = "tul",
        .root_source_file = .{ .path = "src/repl.zig" },
        .target = target,
        .optimize = optimize,
    });

    repl.addModule("tul", tulInternal);
    b.installArtifact(repl);

    // run cmd
    const run_cmd = b.addRunArtifact(repl);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "run the app");
    run_step.dependOn(&run_cmd.step);

    // testing
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/tests.zig" },
        .target = target,
        .optimize = optimize,
    });

    unit_tests.addModule("tul", tulExternal);

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    // autodoc
    const docs = b.addInstallDirectory(.{
        .source_dir = repl.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "doc",
    });

    const install_docs = b.step("docs", "build and install autodocs");
    install_docs.dependOn(&docs.step);
}
