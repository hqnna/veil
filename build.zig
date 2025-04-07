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

    const args = b.dependency("args", .{});
    exe.root_module.addImport("args", args.module("args"));
    b.installArtifact(exe);
}
