const Commands = @This();
const std = @import("std");
const sys = @import("system.zig");
const Keys = @import("../util/keys.zig");
const color = @import("../util/color.zig");
const Identity = @import("../crypto/identity.zig");
const Crypt = @import("../crypto/crypt.zig");
const Ed25519 = std.crypto.sign.Ed25519;
const Base64 = std.base64.standard;

keys: Keys,
crypt: Crypt,
allocator: std.mem.Allocator,
stdout: std.fs.File,
stderr: std.fs.File,

/// Combination of error unions used for commands
pub const Error = sys.Error || Keys.Error || Identity.Error || Crypt.Error;

/// Create a new command handler instance
pub fn create(
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

// Attempt to initialize a new user identity
pub fn init(c: Commands) Error!noreturn {
    if (try c.keys.exists()) {
        try color.write(c.stderr.writer(), .Red, "error:");
        try color.write(c.stderr.writer(), .Default, " ");
        try c.stderr.writeAll("keys have already been initialized\n");
        std.process.exit(1);
    }

    const identity = Identity.create();
    const secret_key = try identity.encode(c.allocator, .secret);
    const public_key = try identity.encode(c.allocator, .public);
    try c.keys.write(.secret, secret_key);
    try c.keys.write(.public, public_key);

    try color.write(c.stdout.writer(), .Yellow, "public key: ");
    try color.write(c.stdout.writer(), .Default, public_key);
    try c.stdout.writeAll("\n");
    std.process.exit(0);
}

/// Attempt to encrypt a folder or file at a specified path
pub fn lock(c: Commands, path: []const u8) Error!noreturn {
    std.fs.cwd().access(path, .{}) catch {
        try color.write(c.stderr.writer(), .Red, "error:");
        try color.write(c.stderr.writer(), .Default, " ");
        try c.stderr.writeAll("the specified path doesn't exist");
        try c.stderr.writeAll("\n");
        std.process.exit(1);
    };

    const info = try std.fs.cwd().statFile(path);

    try switch (info.kind) {
        .file => c.encryptFile(path),
        else => {},
    };

    try color.write(c.stderr.writer(), .Red, "error:");
    try color.write(c.stderr.writer(), .Default, " ");
    try c.stderr.writeAll("the specified path is invalid");
    try c.stderr.writeAll("\n");
    std.process.exit(1);
}

/// Attempt to decrypt a folder or file at a specified path
pub fn unlock(c: Commands, path: []const u8) Error!noreturn {
    std.fs.cwd().access(path, .{}) catch {
        try color.write(c.stderr.writer(), .Red, "error:");
        try color.write(c.stderr.writer(), .Default, " ");
        try c.stderr.writeAll("the specified path doesn't exist");
        try c.stderr.writeAll("\n");
        std.process.exit(1);
    };

    const info = try std.fs.cwd().statFile(path);

    try switch (info.kind) {
        .file => c.decryptFile(path),
        else => {},
    };

    try color.write(c.stderr.writer(), .Red, "error:");
    try color.write(c.stderr.writer(), .Default, " ");
    try c.stderr.writeAll("the specified path is invalid");
    try c.stderr.writeAll("\n");
    std.process.exit(1);
}

/// Destroy a command handler instance
pub fn destroy(c: *Commands) void {
    c.keys.deinit();
}

// Attempt to encrypt a file at the given path
fn encryptFile(c: Commands, path: []const u8) Error!void {
    const id = try Identity.load(try c.keys.read(.secret));
    const file = try sys.File.load(c.allocator, path);
    defer file.unload(c.allocator);

    const hash = try c.crypt.hash(id, file.data);
    defer c.allocator.free(hash);

    const cdata = try std.mem.concat(c.allocator, u8, &.{ file.meta.name, &.{1}, file.data });
    defer c.allocator.free(cdata);

    const data = try c.crypt.encrypt(id, cdata);
    defer c.allocator.free(data);

    const sig = try id.sign(c.allocator, file.data);
    defer c.allocator.free(sig);

    const sdata = try std.mem.concat(c.allocator, u8, &.{ data, sig });
    defer c.allocator.free(sdata);

    var dir = try std.fs.openDirAbsolute(file.meta.dir, .{});
    defer dir.close();

    try dir.writeFile(.{ .sub_path = hash, .data = sdata });
    try dir.deleteFile(file.meta.path);

    try color.write(c.stdout.writer(), .Green, "successfully ");
    try color.write(c.stdout.writer(), .Default, "encrypted ");
    try color.write(c.stdout.writer(), .Yellow, file.meta.name);
    try color.write(c.stdout.writer(), .Default, " as ");
    try color.write(c.stdout.writer(), .Yellow, hash);
    try color.write(c.stdout.writer(), .Default, "\n");
    std.process.exit(0);
}

// Attempt to decrypt a file at the given path
fn decryptFile(c: Commands, path: []const u8) Error!void {
    const id = try Identity.load(try c.keys.read(.secret));
    const file = try sys.File.load(c.allocator, path);
    defer file.unload(c.allocator);

    const size = Base64.Encoder.calcSize(Ed25519.Signature.encoded_length);
    const data = try c.crypt.decrypt(id, file.data[0 .. file.data.len - size]);
    defer c.allocator.free(data);

    var iterator = std.mem.splitScalar(u8, data, 1);
    const file_name = iterator.next();
    const file_data = iterator.rest();

    try id.verify(file_data, file.data[file.data.len - size ..]);
    var dir = try std.fs.openDirAbsolute(file.meta.dir, .{});
    defer dir.close();

    try dir.writeFile(.{ .sub_path = file_name.?, .data = file_data });
    try dir.deleteFile(file.meta.path);

    try color.write(c.stdout.writer(), .Green, "successfully ");
    try color.write(c.stdout.writer(), .Default, "decrypted ");
    try color.write(c.stdout.writer(), .Yellow, file.meta.name);
    try color.write(c.stdout.writer(), .Default, " as ");
    try color.write(c.stdout.writer(), .Yellow, file_name.?);
    try color.write(c.stdout.writer(), .Default, "\n");
    std.process.exit(0);
}
