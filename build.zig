const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // const lib = b.addStaticLibrary(.{
    //     .name = "font",
    //     // In this case the main source file is merely a path, however, in more
    //     // complicated build scripts, this could be a generated file.
    //     .root_source_file = b.path("src/root.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    // b.installArtifact(lib);

    const font_mod = b.addModule(
        "font",
        .{ .root_source_file = b.path("src/root.zig") },
    );

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    const example_step = b.step("example", "Run an example");
    buildExample(b, "try_it", "examples/test.zig", .{
        .module = font_mod,
        .dependsOn = example_step,
        .target = target,
        .optimize = optimize,
    });
}

const Build = struct {
    module: *std.Build.Module,
    dependsOn: ?*std.Build.Step,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
};

fn buildExample(b: *std.Build, comptime name: []const u8, comptime root: []const u8, settings: Build) void {
    const exe = b.addExecutable(.{
        .name = name,
        .root_source_file = b.path(root),
        .target = settings.target,
        .optimize = settings.optimize,
    });

    exe.root_module.addImport("font", settings.module);

    const example_cmd = b.addRunArtifact(exe);
    example_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        example_cmd.addArgs(args);
    }

    const example_step = b.step(name, "Run the '" ++ name ++ "' example");
    example_step.dependOn(&example_cmd.step);

    if (settings.dependsOn) |d| {
        exe.step.dependOn(d);
    }
}
