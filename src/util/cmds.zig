const Commands = @This();
const std = @import("std");
const sys = @import("system.zig");
const Keys = @import("../util/keys.zig");
const write = @import("../util/color.zig").write;
const Identity = @import("../crypto/identity.zig");
const Crypt = @import("../crypto/crypt.zig");
const Queue = @import("sync.zig").Queue;
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
params: [][:0]const u8,
queue: Queue,

/// Combination of error unions used for commands
pub const Error = error{RenameAcrossMountPoints} ||
    std.Thread.CpuCountError ||
    std.Thread.SpawnError ||
    Identity.Error ||
    Crypt.Error ||
    Keys.Error ||
    sys.Error;

pub const HandlerOptions = struct {
    env: std.process.EnvMap,
    params: [][:0]const u8,
    stdout: std.fs.File,
    stderr: std.fs.File,
    flags: Schema,
};

/// Create a new command handler instance
pub fn init(
    allocator: std.mem.Allocator,
    options: HandlerOptions,
) Error!Commands {
    var keys = try Keys.init(allocator, options.env);
    errdefer keys.deinit();

    return Commands{
        .keys = keys,
        .params = options.params,
        .stderr = options.stderr,
        .stdout = options.stdout,
        .options = options.flags,
        .allocator = allocator,
        .crypt = Crypt.init(allocator),
        .queue = Queue.init(value: {
            if (options.flags.threads) |v| if (v >= 1) break :value v;
            break :value try std.Thread.getCpuCount();
        }),
    };
}

/// Evaluate the arguments passed to the command line interface
pub fn run(c: *Commands) Error!noreturn {
    if (std.mem.eql(u8, c.params[0], "init")) {
        std.process.exit(try initCmd.call(c));
    } else if (std.mem.eql(u8, c.params[0], "lock")) {
        std.process.exit(try lockCmd.call(c, c.options.naming, c.params[1]));
    } else if (std.mem.eql(u8, c.params[0], "unlock")) {
        std.process.exit(try unlockCmd.call(c, c.options.naming, c.params[1]));
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
