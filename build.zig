const std = @import("std");
const Build = std.Build;

/// Shouldn't be called from user code
pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    link(b, tests);

    const run_tests = b.addRunArtifact(tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}

/// Adds module to `step` and links STB library
pub fn link_module(b: *Build, step: *Build.Step.Compile) void {
    step.addModule("stb", module(b));
    link(b, step);
}

var _module: ?*Build.Module = null;
/// Get STB module
pub fn module(b: *Build) *Build.Module {
    if (_module) |m| return m;
    _module = b.createModule(.{
        .source_file = .{ .path = stbPath("/src/main.zig") },
    });
    return _module.?;
}

/// Link STB library to `step`
pub fn link(b: *Build, step: *Build.Step.Compile) void {
    const lib = build_library(b, step.optimize, step.target);
    step.linkLibrary(lib);
    step.addIncludePath(Build.LazyPath.relative("include/"));
    step.linkLibC();
}

fn build_library(b: *Build, optimize: std.builtin.OptimizeMode, target: std.zig.CrossTarget) *Build.Step.Compile {
    const lib = b.addStaticLibrary(Build.StaticLibraryOptions{
        .name = "stb_image",
        .target = target,
        .optimize = optimize,
    });

    lib.addIncludePath(Build.LazyPath.relative("include/"));
    lib.addCSourceFile(.{
        .file = Build.LazyPath.relative("src/c/stb_image.c"),
        .flags = &.{"-std=c99"},
    });
    lib.linkLibC();

    return lib;
}

fn stbPath(comptime suffix: []const u8) []const u8 {
    if (suffix[0] != '/') @compileError("suffix must be an absolute path");
    return comptime blk: {
        const root_dir = std.fs.path.dirname(@src().file) orelse ".";
        break :blk root_dir ++ suffix;
    };
}
