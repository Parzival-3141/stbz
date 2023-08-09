//! To use, include `stbz` in your `build.zig` like so:
//!```zig
//!pub fn build(b: *Build) void {
//!    // ...
//!    // if using .zon dependency:
//!    const stb_dep = b.dependency("stbz", .{ .target = target, .optimize = optimize });
//!    // else if vendoring:
//!    const stb_dep = b.anonymousDependency(
//!        "your_deps/stbz/",
//!        @import("your_deps/stbz/build.zig"),
//!        .{ .target = target, .optimize = optimize },
//!    );
//!    // then add module and link library
//!    exe.addModule("stb", stb_dep.module("stbz"));
//!    exe.linkLibrary(stb_dep.artifact("stbz"));
//!}
//!```

const Self = @This();
const std = @import("std");
const Build = std.Build;
const LazyPath = Build.LazyPath;

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("stbz", .{ .source_file = LazyPath.relative("src/main.zig") });

    const lib = b.addStaticLibrary(.{
        .name = "stbz",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    link_C_library(b, lib);
    b.installArtifact(lib);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    link_C_library(b, tests);

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}

/// Link stb C libs to `step`
fn link_C_library(b: *Build, step: *Build.Step.Compile) void {
    const c_lib = build_C_library(b, step.optimize, step.target);
    step.linkLibrary(c_lib);
    step.addIncludePath(LazyPath.relative("include/"));
    step.linkLibC();
}

/// Build stb C libs
fn build_C_library(b: *Build, optimize: std.builtin.OptimizeMode, target: std.zig.CrossTarget) *Build.Step.Compile {
    const lib = b.addStaticLibrary(Build.StaticLibraryOptions{
        .name = "stb_c",
        .target = target,
        .optimize = optimize,
    });

    lib.addIncludePath(LazyPath.relative("include/"));
    lib.addCSourceFile(.{
        .file = LazyPath.relative("src/c/stb_image.c"),
        .flags = &.{"-std=c99"},
    });
    lib.linkLibC();

    return lib;
}
