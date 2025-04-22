const std = @import("std");
const args = @import("args");
const help = @import("help/help.zig");
const color = @import("util/color.zig");
const Commands = @import("util/cmds.zig");

/// Whether to change the names of encrypted files
pub const Naming = enum(u1) { change, keep };

/// The options / flags that the cli supports
pub const Schema = struct {
    pub const shorthands = .{ .h = "help", .t = "threads", .n = "naming" };
    naming: Naming = .change,
    threads: ?usize = null,
    version: bool = false,
    color: bool = true,
    help: bool = false,
};

pub fn main() !void {
    const stdout = std.io.getStdOut();
    const stderr = std.io.getStdErr();
    const allocator = std.heap.smp_allocator;

    var cli = try args.parseForCurrentProcess(Schema, allocator, .silent);
    defer cli.deinit();

    try color.checkCapability(allocator, stdout, cli.options.color);

    if (cli.options.help) try help.print(stdout, .full);
    if (cli.options.version) try help.print(stdout, .version);
    if (cli.positionals.len == 0) try help.print(stdout, .usage);
    var handler = try Commands.init(allocator, stdout, stderr, cli.options);
    defer handler.deinit();

    try handler.eval(cli.positionals);
}
