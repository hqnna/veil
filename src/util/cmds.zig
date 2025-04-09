const Commands = @This();
const std = @import("std");
const Keys = @import("../util/keys.zig");
const color = @import("../util/color.zig");
const Identity = @import("../crypto/identity.zig");

keys: Keys,
allocator: std.mem.Allocator,
stdout: std.fs.File,
stderr: std.fs.File,

/// Combination of error unions used for commands
pub const Error = Keys.Error || Identity.Error;

/// Create a new command handler instance
pub fn create(
    allocator: std.mem.Allocator,
    stdout: std.fs.File,
    stderr: std.fs.File,
) Error!Commands {
    var keys = try Keys.init(allocator);
    errdefer keys.deinit();

    return Commands{
        .allocator = allocator,
        .stdout = stdout,
        .stderr = stderr,
        .keys = keys,
    };
}

// Attempt to initialize a new user identity
pub fn init(cmds: Commands) Error!void {
    if (try cmds.keys.exists()) {
        try color.write(cmds.stderr.writer(), .Red, "error:");
        try color.write(cmds.stderr.writer(), .Default, " ");
        try cmds.stderr.writeAll("keys have already been initialized\n");
        std.process.exit(1);
    }

    var identity = Identity.generate(cmds.allocator);
    const secret_key = try identity.encode(.secret);
    const public_key = try identity.encode(.public);
    try cmds.keys.write(.secret, secret_key);
    try cmds.keys.write(.public, public_key);

    try color.write(cmds.stdout.writer(), .Yellow, "public key: ");
    try color.write(cmds.stdout.writer(), .Default, public_key);
    try cmds.stdout.writeAll("\n");
    std.process.exit(0);
}

/// Destroy a command handler instance
pub fn destroy(cmds: *Commands) void {
    cmds.keys.deinit();
}
