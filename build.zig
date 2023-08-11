const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // libs
    const common = b.createModule(.{
        .source_file = .{ .path = "lib/common/common.zig" },
    });
    const tul = b.addModule("tul", .{
        .source_file = .{ .path = "src/tul.zig" },
        .dependencies = &.{
            .{ .name = "common", .module = common },
        },
    });

    // repl
    const repl = b.addExecutable(.{
        .name = "tul",
        .root_source_file = .{ .path = "src/repl.zig" },
        .target = target,
        .optimize = optimize,
    });

    repl.addModule("tul", tul);
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

    unit_tests.addModule("tul", tul);

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
