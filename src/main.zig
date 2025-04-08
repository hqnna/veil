const std = @import("std");
const args = @import("args");
const help = @import("help/help.zig");
const color = @import("color.zig");

pub fn main() !void {
    const stdout = std.io.getStdOut();
    const allocator = std.heap.smp_allocator;

    var cli = try args.parseForCurrentProcess(struct {
        pub const shorthands = .{ .h = "help" };
        version: bool = false,
        color: bool = false,
        help: bool = false,
    }, allocator, .silent);
    defer cli.deinit();

    try color.checkCapability(allocator, stdout, cli.options.color);
    if (cli.options.help) try help.print(stdout, .full);
    if (cli.options.version) try help.print(stdout, .version);
    if (cli.positionals.len == 0) try help.print(stdout, .usage);
}
