const std = @import("std");
const sys = @import("../system.zig");
const Command = @import("../cmds.zig");
const write = @import("../color.zig").write;
const Identity = @import("../../crypto/identity.zig");

// Encryption metadata such as the original name and the resulting hash
const Rename = struct { old: []const u8, new: []const u8 };

/// Attempt to encrypt a folder or file at a specified path
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
            const meta = try encryptFile(c, path);
            try write(c.stdout.writer(), .Green, "successfully ");
            try write(c.stdout.writer(), .Default, "encrypted ");
            try write(c.stdout.writer(), .Green, meta.old);
            try write(c.stdout.writer(), .Default, " as ");
            try write(c.stdout.writer(), .Green, meta.new);
            try write(c.stdout.writer(), .Default, "\n");
            return 0;
        },
        .directory => {
            const meta = try encryptDir(c, path);
            try write(c.stdout.writer(), .Green, "successfully ");
            try write(c.stdout.writer(), .Default, "encrypted ");
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

// Attempt to encrypt a file at the given path
fn encryptFile(c: Command, path: []const u8) Command.Error!Rename {
    const id = try Identity.load(try c.keys.read(.secret));
    const file = try sys.File.load(c.allocator, path);
    errdefer file.unload(c.allocator);

    const hash = try c.crypt.hash(id, file.data);
    errdefer c.allocator.free(hash);

    const cdata = try std.mem.concat(c.allocator, u8, &.{ file.meta.name, &.{1}, file.data });
    defer c.allocator.free(cdata);

    const data = try c.crypt.encrypt(id, cdata, .b64);
    defer c.allocator.free(data);

    const sig = try id.sign(c.allocator, file.data);
    defer c.allocator.free(sig);

    const sdata = try std.mem.concat(c.allocator, u8, &.{ data, sig });
    defer c.allocator.free(sdata);

    var dir = try std.fs.openDirAbsolute(file.meta.dir, .{});
    defer dir.close();

    try dir.writeFile(.{ .sub_path = hash, .data = sdata });
    try dir.deleteFile(file.meta.path);

    return Rename{ .old = file.meta.name, .new = hash };
}

// Attempt to encrypt a directory at the given path
fn encryptDir(c: Command, path: []const u8) Command.Error!Rename {
    const id = try Identity.load(try c.keys.read(.secret));
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();

    var iterator = dir.iterate();
    while (try iterator.next()) |entry| switch (entry.kind) {
        .directory => {
            const sub_path = try dir.realpathAlloc(c.allocator, entry.name);
            errdefer c.allocator.free(sub_path);
            _ = try encryptDir(c, sub_path);
        },
        .file => {
            const sub_path = try dir.realpathAlloc(c.allocator, entry.name);
            errdefer c.allocator.free(sub_path);
            _ = try encryptFile(c, sub_path);
        },
        else => continue,
    };

    const rpath = try dir.realpathAlloc(c.allocator, ".");
    errdefer c.allocator.free(rpath);

    const name = std.fs.path.basename(rpath);
    const parent = std.fs.path.dirname(rpath);
    const ename = try c.crypt.encrypt(id, name, .hex);
    errdefer c.allocator.free(ename);

    const npath = try std.fs.path.join(c.allocator, &.{ parent.?, ename });
    errdefer c.allocator.free(npath);

    try std.fs.renameAbsolute(rpath, npath);
    return Rename{ .old = name, .new = ename };
}
