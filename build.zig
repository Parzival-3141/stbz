const std = @import("std");
const Build = std.Build;

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
        .source_file = .{ .path = stbPath("/src/stb.zig") },
    });
    return _module.?;
}

/// Link STB library to `step`
pub fn link(b: *Build, step: *Build.Step.Compile) void {
    const lib = build_library(b, step.optimize, step.target);
    step.linkLibrary(lib);
    add_includes(step);
    step.linkLibC();
}

fn build_library(b: *Build, optimize: std.builtin.OptimizeMode, target: std.zig.CrossTarget) *Build.Step.Compile {
    const lib = b.addStaticLibrary(Build.StaticLibraryOptions{
        .name = "stb_image",
        .target = target,
        .optimize = optimize,
    });

    add_includes(lib);
    lib.addCSourceFile(stbPath("/src/stb_image.c"), &[_][]const u8{"-std=c99"});
    lib.linkLibC();

    return lib;
}

fn add_includes(step: *Build.Step.Compile) void {
    step.addIncludePath(stbPath("/include/"));
}

fn stbPath(comptime suffix: []const u8) []const u8 {
    if (suffix[0] != '/') @compileError("suffix must be an absolute path");
    return comptime blk: {
        const root_dir = std.fs.path.dirname(@src().file) orelse ".";
        break :blk root_dir ++ suffix;
    };
}
