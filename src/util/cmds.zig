const Commands = @This();
const std = @import("std");
const sys = @import("system.zig");
const Keys = @import("../util/keys.zig");
const write = @import("../util/color.zig").write;
const Identity = @import("../crypto/identity.zig");
const Crypt = @import("../crypto/crypt.zig");

// BEGIN COMMANDS --------------------------------------------------------------
const initCmd = @import("cmds/init.cmd.zig");
const lockCmd = @import("cmds/lock.cmd.zig");
const unlockCmd = @import("cmds/unlock.cmd.zig");
// END COMMANDS ----------------------------------------------------------------

keys: Keys,
crypt: Crypt,
stdout: std.fs.File,
stderr: std.fs.File,
allocator: std.mem.Allocator,

/// Combination of error unions used for commands
pub const Error = Identity.Error || Crypt.Error || Keys.Error || sys.Error ||
    error{RenameAcrossMountPoints};

/// Create a new command handler instance
pub fn init(
    allocator: std.mem.Allocator,
    stdout: std.fs.File,
    stderr: std.fs.File,
) Error!Commands {
    var keys = try Keys.init(allocator);
    errdefer keys.deinit();

    return Commands{
        .crypt = Crypt.init(allocator),
        .allocator = allocator,
        .stdout = stdout,
        .stderr = stderr,
        .keys = keys,
    };
}

/// Evaluate the arguments passed to the command line interface
pub fn eval(c: Commands, args: [][:0]const u8) Error!noreturn {
    if (std.mem.eql(u8, args[0], "init")) {
        std.process.exit(try initCmd.call(c));
    } else if (std.mem.eql(u8, args[0], "lock")) {
        std.process.exit(try lockCmd.call(c, args[1]));
    } else if (std.mem.eql(u8, args[0], "unlock")) {
        std.process.exit(try unlockCmd.call(c, args[1]));
    } else {
        try write(c.stderr.writer(), .Red, "error:");
        try write(c.stderr.writer(), .Default, " ");
        try c.stderr.writeAll("invalid or unknown command\n");
        std.process.exit(1);
    }
}

/// Destroy a command handler instance
pub fn deinit(c: *Commands) void {
    c.keys.deinit();
}
