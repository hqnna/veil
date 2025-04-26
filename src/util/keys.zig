const Keys = @This();
const std = @import("std");
const xdg = @import("folders");
const Identity = @import("../crypto/identity.zig");

dir: []const u8,
allocator: std.mem.Allocator,

/// List of possible storage errors that could happen
pub const Error = xdg.Error ||
    std.fs.Dir.RealPathAllocError ||
    std.mem.Allocator.Error ||
    std.posix.MakeDirError ||
    std.fs.File.WriteError ||
    std.fs.File.ReadError ||
    std.fs.File.OpenError ||
    error{InvalidDirectory};

/// Initialize a new storage utility instance
pub fn init(allocator: std.mem.Allocator) Error!Keys {
    var env = try std.process.getEnvMap(allocator);
    defer env.deinit();

    var data_dir: []u8 = undefined;

    if (env.get("VEIL_HOME")) |custom_dir| {
        data_dir = try std.fs.cwd().realpathAlloc(allocator, custom_dir);
        errdefer allocator.free(data_dir);

        std.fs.accessAbsolute(data_dir, .{}) catch {
            try std.fs.makeDirAbsolute(data_dir);
        };
    } else {
        const xdg_dir = try xdg.getPath(allocator, .data);
        if (xdg_dir == null) return Error.InvalidDirectory;
        defer allocator.free(xdg_dir.?);

        data_dir = try std.fs.path.join(allocator, &.{ xdg_dir.?, "veil" });
        errdefer allocator.free(data_dir);

        std.fs.accessAbsolute(data_dir, .{}) catch {
            try std.fs.makeDirAbsolute(data_dir);
        };
    }

    return Keys{
        .allocator = allocator,
        .dir = data_dir,
    };
}

/// Write data to a specific type of key using a storage utility
pub fn write(s: Keys, comptime k: Identity.Key, d: []const u8) Error!void {
    const path = try switch (k) {
        .secret => std.fs.path.join(s.allocator, &.{ s.dir, "secret.key" }),
        .public => std.fs.path.join(s.allocator, &.{ s.dir, "public.key" }),
    };
    defer s.allocator.free(path);

    const handle = try std.fs.createFileAbsolute(path, .{ .truncate = true });
    defer handle.close();

    try handle.writeAll(d);
}

/// Read data from a specific type of key using a storage utility
pub fn read(s: Keys, comptime k: Identity.Key) Error![]const u8 {
    const path = try switch (k) {
        .secret => std.fs.path.join(s.allocator, &.{ s.dir, "secret.key" }),
        .public => std.fs.path.join(s.allocator, &.{ s.dir, "public.key" }),
    };
    defer s.allocator.free(path);

    const handle = try std.fs.openFileAbsolute(path, .{ .mode = .read_only });
    defer handle.close();

    return handle.readToEndAlloc(s.allocator, std.math.maxInt(usize));
}

/// Check if a keypair already exists
pub fn exists(s: Keys) Error!bool {
    const k1 = try std.fs.path.join(s.allocator, &.{ s.dir, "secret.key" });
    const k2 = try std.fs.path.join(s.allocator, &.{ s.dir, "public.key" });
    std.fs.accessAbsolute(k1, .{ .mode = .read_only }) catch return false;
    std.fs.accessAbsolute(k2, .{ .mode = .read_only }) catch return false;
    return true;
}

/// Destroy a storage utility
pub fn deinit(s: *Keys) void {
    s.allocator.free(s.dir);
}
