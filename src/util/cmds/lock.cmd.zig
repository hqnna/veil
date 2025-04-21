const std = @import("std");
const sys = @import("../system.zig");
const Command = @import("../cmds.zig");
const write = @import("../color.zig").write;
const Identity = @import("../../crypto/identity.zig");
const Box = @import("../sync.zig").Box;

/// Attempt to encrypt a folder or file at a specified path
pub fn call(c: *Command, path: []const u8) Command.Error!u8 {
    std.fs.cwd().access(path, .{}) catch {
        try write(c.stderr.writer(), .Red, "error:");
        try write(c.stderr.writer(), .Default, " ");
        try c.stderr.writeAll("the specified path doesn't exist\n");
        return 1;
    };

    const info = try std.fs.cwd().statFile(path);

    switch (info.kind) {
        .file => if (try encryptFile(c, path)) |meta| {
            try write(c.stdout.writer(), .Green, "successfully ");
            try write(c.stdout.writer(), .Default, "encrypted ");
            try write(c.stdout.writer(), .Green, meta.old);
            try write(c.stdout.writer(), .Default, " as ");
            try write(c.stdout.writer(), .Green, meta.new);
            try write(c.stdout.writer(), .Default, "\n");
            return 0;
        } else {
            try write(c.stderr.writer(), .Red, "error:");
            try write(c.stderr.writer(), .Default, " ");
            try c.stderr.writeAll("the file is already encrypted\n");
            return 1;
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
fn encryptFile(c: *Command, path: []const u8) Command.Error!?sys.Rename {
    const id = try Identity.load(try c.keys.read(.secret));
    const file = try sys.File.load(c.allocator, path);
    defer file.unload(c.allocator);

    if (std.mem.eql(u8, file.data[0..5], &sys.magic)) return null;

    const name = try c.allocator.dupe(u8, file.meta.name);
    errdefer c.allocator.free(name);

    const hash = try c.crypt.hash(id, file.data);
    errdefer c.allocator.free(hash);

    const cdata = try std.mem.concat(c.allocator, u8, &.{ name, &.{1}, file.data });
    defer c.allocator.free(cdata);

    const data = try c.crypt.encrypt(id, cdata, .b64);
    defer c.allocator.free(data);

    const sig = try id.sign(c.allocator, file.data);
    defer c.allocator.free(sig);

    const sdata = try std.mem.concat(c.allocator, u8, &.{ &sys.magic, data, sig });
    defer c.allocator.free(sdata);

    var dir = try std.fs.openDirAbsolute(file.meta.dir, .{});
    defer dir.close();

    try dir.writeFile(.{ .sub_path = hash, .data = sdata });
    try dir.deleteFile(file.meta.path);

    return sys.Rename{
        .old = name,
        .new = hash,
    };
}

// Attempt to encrypt a directory at the given path
fn encryptDir(c: *Command, path: []const u8) Command.Error!sys.Rename {
    const id = try Identity.load(try c.keys.read(.secret));
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();

    var group = std.Thread.WaitGroup{};
    var iterator = Box(std.fs.Dir.Iterator).init(dir.iterate());

    c.mutex.lock();
    while (c.threads.used < c.threads.allowed) : (c.threads.used += 1) {
        _ = try std.Thread.spawn(.{}, worker, .{ c, &dir, &group, &iterator });
    }
    c.mutex.unlock();
    group.wait();

    const rpath = try dir.realpathAlloc(c.allocator, ".");
    defer c.allocator.free(rpath);

    const name_buf = std.fs.path.basename(rpath);
    const old_name = try c.allocator.dupe(u8, name_buf);
    errdefer c.allocator.free(old_name);

    const parent = std.fs.path.dirname(rpath);
    const new_name = try c.crypt.encrypt(id, old_name, .hex);
    errdefer c.allocator.free(new_name);

    const npath = try std.fs.path.join(c.allocator, &.{ parent.?, new_name });
    defer c.allocator.free(npath);

    try std.fs.renameAbsolute(rpath, npath);

    return sys.Rename{
        .old = old_name,
        .new = new_name,
    };
}

fn worker(
    c: *Command,
    d: *std.fs.Dir,
    wg: *std.Thread.WaitGroup,
    it: *Box(std.fs.Dir.Iterator),
) Command.Error!void {
    wg.start();

    defer {
        c.mutex.lock();
        c.threads.used -= 1;
        c.mutex.unlock();
        wg.finish();
    }

    while (try it.get().next()) |entry| switch (entry.kind) {
        .directory => {
            const sub_path = try d.realpathAlloc(c.allocator, entry.name);
            defer c.allocator.free(sub_path);
            const meta = try encryptDir(c, sub_path);
            c.allocator.free(meta.old);
            c.allocator.free(meta.new);
        },
        .file => {
            const sub_path = try d.realpathAlloc(c.allocator, entry.name);
            defer c.allocator.free(sub_path);
            const meta = try encryptFile(c, sub_path);
            if (meta) |m| c.allocator.free(m.old);
            if (meta) |m| c.allocator.free(m.new);
        },
        else => continue,
    };
}
