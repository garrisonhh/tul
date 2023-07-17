const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // libs
    const common = b.createModule(.{
        .source_file = .{ .path = "lib/common/common.zig" },
    });

    // exe
    const exe = b.addExecutable(.{
        .name = "tul",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.addModule("common", common);
    b.installArtifact(exe);

    // run cmd
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "run the app");
    run_step.dependOn(&run_cmd.step);

    // testing
    const verbose_tests = b.option(
        bool,
        "verbose-tests",
        "make tul tests always generate output",
    ) orelse false;

    const test_options = b.addOptions();
    test_options.addOption(bool, "verbose", verbose_tests);

    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    unit_tests.addModule("common", common);
    unit_tests.addOptions("test_options", test_options);

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
