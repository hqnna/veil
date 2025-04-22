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
        .file => if (try decryptFile(c, n, path)) |rename| switch (rename) {
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
        } else {
            try write(c.stderr.writer(), .Red, "error:");
            try write(c.stderr.writer(), .Default, " ");
            try c.stderr.writeAll("the file has not been encrypted\n");
            return 1;
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
fn decryptFile(c: *Command, n: Naming, path: []const u8) Command.Error!?sys.Rename {
    var id = try Identity.load(try c.keys.read(.secret));
    const file = try sys.File.load(c.allocator, path);
    defer file.unload(c.allocator);

    if (!std.mem.eql(u8, file.data[0..5], &sys.magic)) return null;

    const size = Base64.Encoder.calcSize(Ed25519.Signature.encoded_length);
    const data = try c.crypt.decrypt(&id, file.data[5 .. file.data.len - size], .b64);
    defer c.allocator.free(data);

    var iterator = std.mem.splitScalar(u8, data, 1);
    const old_name = try c.allocator.dupe(u8, file.meta.name);
    errdefer c.allocator.free(old_name);
    const file_name = iterator.next().?;
    const file_data = iterator.rest();

    try id.verify(file_data, file.data[file.data.len - size ..]);
    var dir = try std.fs.openDirAbsolute(file.meta.dir, .{});
    defer dir.close();

    if (!std.mem.eql(u8, old_name, file_name) and n == .change) {
        const new_name = try c.allocator.dupe(u8, file_name);
        errdefer c.allocator.free(new_name);

        try dir.writeFile(.{ .sub_path = new_name, .data = file_data });
        try dir.deleteFile(file.meta.path);

        return .{ .changed = .{
            .old = old_name,
            .new = new_name,
        } };
    }

    try dir.writeFile(.{ .sub_path = old_name, .data = file_data });
    return .{ .kept = old_name };
}

// Attempt to decrypt a directory at the given path
fn decryptDir(c: *Command, n: Naming, path: []const u8) Command.Error!sys.Rename {
    var id = try Identity.load(try c.keys.read(.secret));
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();

    var group = std.Thread.WaitGroup{};
    var iterator = Box(std.fs.Dir.Iterator).init(dir.iterate());

    if (c.threads.allowed == 1) {
        try worker(c, &dir, &group, &iterator, n);
    } else {
        c.mutex.lock();
        while (c.threads.used < c.threads.allowed) : (c.threads.used += 1) {
            _ = try std.Thread.spawn(.{}, worker, .{ c, &dir, &group, &iterator, n });
        }
        c.mutex.unlock();
    }

    group.wait();
    const rpath = try dir.realpathAlloc(c.allocator, ".");
    defer c.allocator.free(rpath);

    const name_buf = std.fs.path.basename(rpath);
    const old_name = try c.allocator.dupe(u8, name_buf);
    errdefer c.allocator.free(old_name);

    if (n == .change) {
        const new_name = c.crypt.decrypt(&id, old_name, .hex) catch {
            return .{ .kept = old_name };
        };

        errdefer c.allocator.free(new_name);
        const parent = std.fs.path.dirname(rpath);
        const npath = try std.fs.path.join(c.allocator, &.{ parent.?, new_name });
        defer c.allocator.free(npath);

        try std.fs.renameAbsolute(rpath, npath);

        return .{ .changed = .{
            .old = old_name,
            .new = new_name,
        } };
    }

    return .{ .kept = old_name };
}

fn worker(
    c: *Command,
    d: *std.fs.Dir,
    wg: *std.Thread.WaitGroup,
    it: *Box(std.fs.Dir.Iterator),
    n: Naming,
) Command.Error!void {
    wg.start();

    defer {
        wg.finish();
        if (c.threads.allowed > 1) {
            c.mutex.lock();
            c.threads.used -= 1;
            c.mutex.unlock();
        }
    }

    while (try it.get().next()) |entry| switch (entry.kind) {
        .file => {
            const sub_path = try d.realpathAlloc(c.allocator, entry.name);
            defer c.allocator.free(sub_path);
            if (try decryptFile(c, n, sub_path)) |r| switch (r) {
                .kept => |name| c.allocator.free(name),
                .changed => |meta| {
                    c.allocator.free(meta.old);
                    c.allocator.free(meta.new);
                },
            };
        },
        .directory => {
            const sub_path = try d.realpathAlloc(c.allocator, entry.name);
            defer c.allocator.free(sub_path);
            switch (try decryptDir(c, n, sub_path)) {
                .kept => |name| c.allocator.free(name),
                .changed => |meta| {
                    c.allocator.free(meta.old);
                    c.allocator.free(meta.new);
                },
            }
        },
        else => continue,
    };
}
