const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.createModule(.{
        .root_source_file = b.path("source/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    mod.addIncludePath(.{ .cwd_relative = "G:/libraries/godot/core/extension" });

    const lib = b.addLibrary(.{
        .name = "zigtest.windows.x86_64",
        .root_module = mod,
        .linkage = .dynamic,
    });

    // Install DLL into the project's binaries/ directory
    const install_dll = b.addInstallFileWithDir(
        lib.getEmittedBin(),
        .{ .custom = "../binaries" },
        "zigtest.windows.x86_64.dll",
    );
    b.getInstallStep().dependOn(&install_dll.step);

    // zig build run [-Dgodot=<path/to/godot.exe>]
    const godot_exe = b.option([]const u8, "godot", "Path to the Godot executable") orelse "godot";
    const run_godot = b.addSystemCommand(&.{ godot_exe, "--path", ".", "--editor" });
    run_godot.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Build the DLL then open the project in the Godot editor");
    run_step.dependOn(&run_godot.step);
}
