const std = @import("std");
const color = @import("../util/color.zig");
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
    try color.write(stream, .Yellow, "veil");
    try color.write(stream, .Default, " version ");
    try color.write(stream, .Yellow, ver_str);
    try color.write(stream, .Default, "\n");
}

// Print the usage string to a stream
fn usage(stream: anytype) !void {
    try color.write(stream, .Yellow, data[88..95]);
    try color.write(stream, .Default, data[95..99]);
    try color.write(stream, .{ .Grey = 128 }, data[99..110]);
    try color.write(stream, .Default, data[110..120]);
}

// Print the full message string to a stream
fn full(stream: anytype) !void {
    try color.write(stream, .Default, data[0..88]);
    try color.write(stream, .Yellow, data[88..95]);
    try color.write(stream, .Default, data[95..99]);
    try color.write(stream, .{ .Grey = 128 }, data[99..110]);
    try color.write(stream, .Default, data[110..121]);

    var flags = std.mem.splitAny(u8, data[121..], "\n");
    while (flags.next()) |flag| if (flag.len == 0) break else {
        try color.write(stream, .Yellow, flag[0..22]);
        try color.write(stream, .Default, flag[22..]);
        try color.write(stream, .Default, "\n");
    };

    try color.write(stream, .Default, "\n");
    try color.write(stream, .{ .Grey = 128 }, flags.rest());
}
