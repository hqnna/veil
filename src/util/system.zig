const std = @import("std");

/// Magic bytes put at the beginning of encrypted files
pub const magic = [5]u8{ 'v', 'e', 'i', 'l', 1 };

/// Possible filesystem related errors for utils
pub const Error = std.mem.Allocator.Error ||
    std.fs.Dir.RealPathError ||
    std.fs.File.SeekError ||
    std.fs.File.OpenError ||
    std.fs.File.ReadError ||
    error{NotFile};

/// Utility struct for files
pub const File = struct {
    data: []const u8,
    meta: struct {
        path: []const u8,
        name: []const u8,
        dir: []const u8,
    },

    /// Attempt to fetch a file from the filesystem and return info about it
    pub fn load(allocator: std.mem.Allocator, path: []const u8) Error!File {
        const r_path = try std.fs.cwd().realpathAlloc(allocator, path);
        errdefer allocator.free(r_path);

        const info = try std.fs.cwd().statFile(path);
        if (info.kind != .file) return Error.NotFile;

        const data = try std.fs.cwd().readFileAlloc(allocator, r_path, info.size);
        errdefer allocator.free(data);

        return File{
            .data = data,
            .meta = .{
                .name = std.fs.path.basename(r_path),
                .dir = std.fs.path.dirname(r_path).?,
                .path = r_path,
            },
        };
    }

    /// Destroy the allocated path buffer for the file and other things
    pub fn unload(file: File, allocator: std.mem.Allocator) void {
        allocator.free(file.meta.path);
        allocator.free(file.data);
    }
};

// Encryption metadata such as the original name and the resulting hash
pub const Rename = union(enum(u2)) {
    changed: struct { old: []const u8, new: []const u8 },
    kept: []const u8,
    none: void,

    /// Initialize a new instance of the rename information struct
    pub fn init(allocator: std.mem.Allocator, data: Rename) Error!Rename {
        return switch (data) {
            .none => unreachable,
            .kept => |name| .{ .kept = try allocator.dupe(u8, name) },
            .changed => |meta| .{ .changed = .{
                .old = try allocator.dupe(u8, meta.old),
                .new = try allocator.dupe(u8, meta.new),
            } },
        };
    }

    /// Free allocated resources relating to rename changes
    pub fn deinit(r: Rename, allocator: std.mem.Allocator) void {
        switch (r) {
            .none => return,
            .kept => |name| allocator.free(name),
            .changed => |data| {
                allocator.free(data.old);
                allocator.free(data.new);
            },
        }
    }
};
