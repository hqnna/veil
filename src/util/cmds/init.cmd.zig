const Command = @import("../cmds.zig");
const write = @import("../color.zig").write;
const Identity = @import("../../crypto/identity.zig");

// Attempt to initialize a new user identity
pub fn call(c: *Command) Command.Error!u8 {
    if (try c.keys.exists()) {
        try write(c.stderr.writer(), .Red, "error:");
        try write(c.stderr.writer(), .Default, " ");
        try c.stderr.writeAll("keys have already been initialized\n");
        return 1;
    }

    const identity = Identity.create();
    const secret_key = try identity.encode(c.allocator, .secret);
    const public_key = try identity.encode(c.allocator, .public);
    try c.keys.write(.secret, secret_key);
    try c.keys.write(.public, public_key);

    try write(c.stdout.writer(), .Green, "public key: ");
    try write(c.stdout.writer(), .Default, public_key);
    try c.stdout.writeAll("\n");
    return 0;
}
