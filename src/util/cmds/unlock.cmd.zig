const std = @import("std");
const sys = @import("../system.zig");
const Command = @import("../cmds.zig");
const write = @import("../color.zig").write;
const Identity = @import("../../crypto/identity.zig");
const Ed25519 = std.crypto.sign.Ed25519;
const Box = @import("../sync.zig").Box;
const Naming = @import("root").Naming;
const Base64 = std.base64.standard;

/// Attempt to decrypt a folder or file at a specified path
pub fn call(c: *Command, n: Naming, path: []const u8) Command.Error!u8 {
    std.fs.cwd().access(path, .{}) catch {
        try write(c.stderr.writer(), .Red, "error:");
        try write(c.stderr.writer(), .Default, " ");
        try c.stderr.writeAll("the specified path doesn't exist\n");
        return 1;
    };

    const info = try std.fs.cwd().statFile(path);

    switch (info.kind) {
        .file => switch (try decryptFile(c, n, path)) {
            .changed => |meta| {
                try write(c.stdout.writer(), .Green, "successfully ");
                try write(c.stdout.writer(), .Default, "decrypted ");
                try write(c.stdout.writer(), .Green, meta.old);
                try write(c.stdout.writer(), .Default, " as ");
                try write(c.stdout.writer(), .Green, meta.new);
                try write(c.stdout.writer(), .Default, "\n");
                return 0;
            },
            .kept => |file_name| {
                try write(c.stdout.writer(), .Green, "successfully ");
                try write(c.stdout.writer(), .Default, "decrypted ");
                try write(c.stdout.writer(), .Green, file_name);
                try write(c.stdout.writer(), .Default, "\n");
                return 0;
            },
            .none => {
                try write(c.stderr.writer(), .Red, "error:");
                try write(c.stderr.writer(), .Default, " ");
                try c.stderr.writeAll("the file has not been encrypted\n");
                return 1;
            },
        },
        .directory => {
            switch (try decryptDir(c, n, path)) {
                .changed => |meta| {
                    try write(c.stdout.writer(), .Green, "successfully ");
                    try write(c.stdout.writer(), .Default, "decrypted ");
                    try write(c.stdout.writer(), .Green, meta.old);
                    try write(c.stdout.writer(), .Default, " as ");
                    try write(c.stdout.writer(), .Green, meta.new);
                    try write(c.stdout.writer(), .Default, "\n");
                    return 0;
                },
                .kept => |dir_name| {
                    try write(c.stdout.writer(), .Green, "successfully ");
                    try write(c.stdout.writer(), .Default, "decrypted ");
                    try write(c.stdout.writer(), .Green, dir_name);
                    try write(c.stdout.writer(), .Default, "\n");
                    return 0;
                },
                .none => unreachable,
            }
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
fn decryptFile(c: *Command, n: Naming, path: []const u8) Command.Error!sys.Rename {
    var id = try Identity.load(try c.keys.read(.secret));
    const file = try sys.File.load(c.allocator, path);
    defer file.unload(c.allocator);

    if (!std.mem.eql(u8, file.data[0..5], &sys.magic)) return .none;

    const size = Base64.Encoder.calcSize(Ed25519.Signature.encoded_length);
    const data = try c.crypt.decrypt(&id, file.data[5 .. file.data.len - size], .b64);
    defer c.allocator.free(data);

    var iterator = std.mem.splitScalar(u8, data, 1);
    const file_name = iterator.next().?;
    const file_data = iterator.rest();

    try id.verify(file_data, file.data[file.data.len - size ..]);
    var dir = try std.fs.openDirAbsolute(file.meta.dir, .{});
    defer dir.close();

    if (!std.mem.eql(u8, file.meta.name, file_name) and n == .change) {
        try dir.writeFile(.{ .sub_path = file_name, .data = file_data });
        try dir.deleteFile(file.meta.path);

        return try sys.Rename.init(c.allocator, .{ .changed = .{
            .old = file.meta.name,
            .new = file_name,
        } });
    }

    try dir.writeFile(.{ .sub_path = file.meta.name, .data = file_data });
    return try sys.Rename.init(c.allocator, .{ .kept = file.meta.name });
}

// Attempt to decrypt a directory at the given path
fn decryptDir(c: *Command, n: Naming, path: []const u8) Command.Error!sys.Rename {
    var id = try Identity.load(try c.keys.read(.secret));
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();

    var group = std.Thread.WaitGroup{};
    var iterator = Box(std.fs.Dir.Iterator).init(dir.iterate());
    try c.queue.spawn(&group, worker, .{ c, &dir, &iterator, n });
    group.wait();

    const rpath = try dir.realpathAlloc(c.allocator, ".");
    defer c.allocator.free(rpath);

    const old_name = std.fs.path.basename(rpath);

    if (n == .change) {
        const new_name = c.crypt.decrypt(&id, old_name, .hex) catch {
            return sys.Rename.init(c.allocator, .{ .kept = old_name });
        };

        defer c.allocator.free(new_name);
        const parent = std.fs.path.dirname(rpath);
        const npath = try std.fs.path.join(c.allocator, &.{ parent.?, new_name });
        defer c.allocator.free(npath);

        try std.fs.renameAbsolute(rpath, npath);

        return sys.Rename.init(c.allocator, .{ .changed = .{
            .old = old_name,
            .new = new_name,
        } });
    }

    return sys.Rename.init(c.allocator, .{ .kept = old_name });
}

fn worker(
    c: *Command,
    d: *std.fs.Dir,
    it: *Box(std.fs.Dir.Iterator),
    n: Naming,
) Command.Error!void {
    while (try it.get().next()) |entry| switch (entry.kind) {
        .directory => {
            const sub_path = try d.realpathAlloc(c.allocator, entry.name);
            defer c.allocator.free(sub_path);
            const result = try decryptDir(c, n, sub_path);
            defer if (result != .none) result.deinit(c.allocator);
        },
        .file => {
            const sub_path = try d.realpathAlloc(c.allocator, entry.name);
            defer c.allocator.free(sub_path);
            const result = try decryptFile(c, n, sub_path);
            defer if (result != .none) result.deinit(c.allocator);
        },
        else => continue,
    };
}
