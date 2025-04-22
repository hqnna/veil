const Commands = @This();
const std = @import("std");
const sys = @import("system.zig");
const Keys = @import("../util/keys.zig");
const write = @import("../util/color.zig").write;
const Identity = @import("../crypto/identity.zig");
const Crypt = @import("../crypto/crypt.zig");
const Schema = @import("root").Schema;

// BEGIN COMMANDS --------------------------------------------------------------
const initCmd = @import("cmds/init.cmd.zig");
const lockCmd = @import("cmds/lock.cmd.zig");
const unlockCmd = @import("cmds/unlock.cmd.zig");
// END COMMANDS ----------------------------------------------------------------

keys: Keys,
crypt: Crypt,
options: Schema,
stdout: std.fs.File,
stderr: std.fs.File,
allocator: std.mem.Allocator,
mutex: std.Thread.Mutex,
threads: struct {
    allowed: usize,
    used: usize,
},

/// Combination of error unions used for commands
pub const Error = error{RenameAcrossMountPoints} ||
    std.Thread.CpuCountError ||
    std.Thread.SpawnError ||
    Identity.Error ||
    Crypt.Error ||
    Keys.Error ||
    sys.Error;

/// Create a new command handler instance
pub fn init(
    allocator: std.mem.Allocator,
    stdout: std.fs.File,
    stderr: std.fs.File,
    options: Schema,
) Error!Commands {
    var keys = try Keys.init(allocator);
    errdefer keys.deinit();

    return Commands{
        .crypt = Crypt.init(allocator),
        .mutex = std.Thread.Mutex{},
        .allocator = allocator,
        .options = options,
        .stdout = stdout,
        .stderr = stderr,
        .keys = keys,
        .threads = .{
            .allowed = value: {
                if (options.threads) |v| if (v >= 1) break :value v;
                break :value try std.Thread.getCpuCount();
            },
            .used = 0,
        },
    };
}

/// Evaluate the arguments passed to the command line interface
pub fn eval(c: *Commands, args: [][:0]const u8) Error!noreturn {
    if (std.mem.eql(u8, args[0], "init")) {
        std.process.exit(try initCmd.call(c));
    } else if (std.mem.eql(u8, args[0], "lock")) {
        std.process.exit(try lockCmd.call(c, c.options.naming, args[1]));
    } else if (std.mem.eql(u8, args[0], "unlock")) {
        std.process.exit(try unlockCmd.call(c, c.options.naming, args[1]));
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
