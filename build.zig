const std = @import("std");
const t = @import("builtin").target;

pub fn build(b: *std.Build) anyerror!void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{ .default_target = .{
        .abi = if (t.os.tag == .linux) .musl else null,
    } });

    const exe = b.addExecutable(.{
        .root_source_file = b.path("src/main.zig"),
        .optimize = optimize,
        .target = target,
        .name = "veil",
    });

    const zon = b.createModule(.{
        .root_source_file = b.path("build.zig.zon"),
        .optimize = optimize,
        .target = target,
    });

    const args = b.dependency("args", .{});
    const ansi = b.dependency("ansi_term", .{});
    const folders = b.dependency("known_folders", .{});
    exe.root_module.addImport("args", args.module("args"));
    exe.root_module.addImport("ansi", ansi.module("ansi_term"));
    exe.root_module.addImport("folders", folders.module("known-folders"));
    exe.root_module.addImport("zon", zon);
    b.installArtifact(exe);
}
