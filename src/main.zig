const std = @import("std");
const args = @import("args");
const help = @import("help/help.zig");
const Keys = @import("util/keys.zig");
const color = @import("util/color.zig");
const Identity = @import("crypto/identity.zig");

pub fn main() !void {
    const stdout = std.io.getStdOut();
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

    var keys = try Keys.init(allocator);
    defer keys.deinit();

    if (std.mem.eql(u8, cli.positionals[0], "init")) {
        if (try keys.exists()) {
            try color.write(stdout.writer(), .Red, "error:");
            try color.write(stdout.writer(), .Default, " ");
            try stdout.writeAll("keys have already been initialized\n");
            std.process.exit(1);
        }

        var keypair = Identity.generate(allocator);
        const secret_data = try keypair.encode(.secret);
        const public_data = try keypair.encode(.public);
        try keys.write(.secret, secret_data);
        try keys.write(.public, public_data);

        try color.write(stdout.writer(), .Yellow, "public key: ");
        try color.write(stdout.writer(), .Default, public_data);
        try color.write(stdout.writer(), .Default, "\n");
    }
}
