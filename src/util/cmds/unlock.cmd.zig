const std = @import("std");
const sys = @import("../system.zig");
const Command = @import("../cmds.zig");
const write = @import("../color.zig").write;
const Identity = @import("../../crypto/identity.zig");
const Ed25519 = std.crypto.sign.Ed25519;
const Base64 = std.base64.standard;

// Encryption metadata such as the original name and the resulting hash
const Rename = struct { old: []const u8, new: []const u8 };

/// Attempt to decrypt a folder or file at a specified path
pub fn call(c: Command, path: []const u8) Command.Error!u8 {
    std.fs.cwd().access(path, .{}) catch {
        try write(c.stderr.writer(), .Red, "error:");
        try write(c.stderr.writer(), .Default, " ");
        try c.stderr.writeAll("the specified path doesn't exist\n");
        return 1;
    };

    const info = try std.fs.cwd().statFile(path);

    switch (info.kind) {
        .file => {
            const meta = try decryptFile(c, path);
            try write(c.stdout.writer(), .Green, "successfully ");
            try write(c.stdout.writer(), .Default, "decrypted ");
            try write(c.stdout.writer(), .Green, meta.old);
            try write(c.stdout.writer(), .Default, " as ");
            try write(c.stdout.writer(), .Green, meta.new);
            try write(c.stdout.writer(), .Default, "\n");
            return 0;
        },
        .directory => {
            const meta = try decryptDir(c, path);
            try write(c.stdout.writer(), .Green, "successfully ");
            try write(c.stdout.writer(), .Default, "decrypted ");
            try write(c.stdout.writer(), .Green, meta.old);
            try write(c.stdout.writer(), .Default, " as ");
            try write(c.stdout.writer(), .Green, meta.new);
            try write(c.stdout.writer(), .Default, "\n");
            return 0;
        },
        else => {
            try write(c.stderr.writer(), .Red, "error:");
            try write(c.stderr.writer(), .Default, " ");
            try c.stderr.writeAll("the specified path is invalid\n");
            return 1;
        },
    }
}

// Attempt to decrypt a file at the given path
fn decryptFile(c: Command, path: []const u8) Command.Error!Rename {
    const id = try Identity.load(try c.keys.read(.secret));
    const file = try sys.File.load(c.allocator, path);
    defer file.unload(c.allocator);

    const size = Base64.Encoder.calcSize(Ed25519.Signature.encoded_length);
    const data = try c.crypt.decrypt(id, file.data[0 .. file.data.len - size], .b64);
    errdefer c.allocator.free(data);

    var iterator = std.mem.splitScalar(u8, data, 1);
    const file_name = iterator.next();
    const file_data = iterator.rest();

    try id.verify(file_data, file.data[file.data.len - size ..]);
    var dir = try std.fs.openDirAbsolute(file.meta.dir, .{});
    defer dir.close();

    try dir.writeFile(.{ .sub_path = file_name.?, .data = file_data });
    try dir.deleteFile(file.meta.path);

    return Rename{ .old = path, .new = file_name.? };
}

// Attempt to decrypt a directory at the given path
fn decryptDir(c: Command, path: []const u8) Command.Error!Rename {
    const id = try Identity.load(try c.keys.read(.secret));
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();

    var iterator = dir.iterate();
    while (try iterator.next()) |entry| switch (entry.kind) {
        .directory => {
            const sub_path = try dir.realpathAlloc(c.allocator, entry.name);
            errdefer c.allocator.free(sub_path);
            _ = try decryptDir(c, sub_path);
        },
        .file => {
            const sub_path = try dir.realpathAlloc(c.allocator, entry.name);
            errdefer c.allocator.free(sub_path);
            _ = try decryptFile(c, sub_path);
        },
        else => continue,
    };

    const rpath = try dir.realpathAlloc(c.allocator, ".");
    errdefer c.allocator.free(rpath);

    const name = std.fs.path.basename(rpath);
    const parent = std.fs.path.dirname(rpath);
    const ename = try c.crypt.decrypt(id, name, .hex);
    errdefer c.allocator.free(ename);

    const npath = try std.fs.path.join(c.allocator, &.{ parent.?, ename });
    errdefer c.allocator.free(npath);

    try std.fs.renameAbsolute(rpath, npath);
    return Rename{ .old = name, .new = ename };
}
