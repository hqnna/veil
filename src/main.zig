const std = @import("std");
const args = @import("args");
const help = @import("help/help.zig");
const color = @import("util/color.zig");
const Commands = @import("util/cmds.zig");

pub fn main() !void {
    const stdout = std.io.getStdOut();
    const stderr = std.io.getStdErr();
    const allocator = std.heap.smp_allocator;

    var cli = try args.parseForCurrentProcess(struct {
        pub const shorthands = .{ .h = "help" };
        version: bool = false,
        color: bool = true,
        help: bool = false,
    }, allocator, .silent);
    defer cli.deinit();

    try color.checkCapability(allocator, stdout, cli.options.color);

    if (cli.options.help) try help.print(stdout, .full);
    if (cli.options.version) try help.print(stdout, .version);
    if (cli.positionals.len == 0) try help.print(stdout, .usage);
    var cmds = try Commands.create(allocator, stdout, stderr);
    defer cmds.destroy();

    if (std.mem.eql(u8, cli.positionals[0], "init")) try cmds.init();
    if (std.mem.eql(u8, cli.positionals[0], "lock")) try cmds.lock(cli.positionals[1]);

    try color.write(stderr.writer(), .Red, "error:");
    try color.write(stderr.writer(), .Default, " ");
    try stderr.writeAll("invalid or unknown command\n");
    std.process.exit(1);
}
