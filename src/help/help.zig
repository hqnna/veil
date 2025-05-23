const std = @import("std");
const write = @import("../util/color.zig").write;
const ver_str = @import("zon").version;
const data = @embedFile("help.txt");

/// The type of help information that we want to show
pub const HelpType = enum(u2) { usage, version, full };

/// Print the requested type of help information to the terminal and exit
pub fn print(stream: std.fs.File, kind: HelpType) !void {
    var buffer = std.io.bufferedWriter(stream.writer());

    try switch (kind) {
        .full => full(buffer.writer()),
        .version => version(buffer.writer()),
        .usage => usage(buffer.writer()),
    };

    try buffer.flush();
    std.process.exit(0);
}

// Print the version string to a stream
fn version(stream: anytype) !void {
    try write(stream, .Green, "veil");
    try write(stream, .Default, " version ");
    try write(stream, .Green, ver_str);
    try write(stream, .Default, "\n");
}

// Print the usage string to a stream
fn usage(stream: anytype) !void {
    try write(stream, .Green, data[88..95]);
    try write(stream, .Default, data[95..99]);
    try write(stream, .{ .Grey = 128 }, data[99..110]);
    try write(stream, .Default, data[110..120]);
}

// Print the full message string to a stream
fn full(stream: anytype) !void {
    try write(stream, .Default, data[0..88]);
    try write(stream, .Green, data[88..95]);
    try write(stream, .Default, data[95..99]);
    try write(stream, .{ .Grey = 128 }, data[99..110]);
    try write(stream, .Default, data[110..121]);

    try write(stream, .Blue, "Commands\n");
    var cmds = std.mem.splitAny(u8, data[121..], "\n");
    while (cmds.next()) |flag| if (flag.len == 0) break else {
        try write(stream, .Green, flag[0..22]);
        try write(stream, .Default, flag[22..]);
        try write(stream, .Default, "\n");
    };

    try write(stream, .Default, "\n");

    try write(stream, .Blue, "Options\n");
    var flags = std.mem.splitAny(u8, cmds.rest(), "\n");
    while (flags.next()) |flag| if (flag.len == 0) break else {
        try write(stream, .Green, flag[0..22]);
        try write(stream, .Default, flag[22..]);
        try write(stream, .Default, "\n");
    };

    try write(stream, .Default, "\n");
    try write(stream, .Blue, "Notes\n");
    try write(stream, .{ .Grey = 128 }, flags.rest());
}
