const std = @import("std");
const vstr = @import("zon").version;
const data = @embedFile("help.txt");

/// The type of help information that we want to show
pub const HelpType = enum(u2) { usage, version, full };

/// Print the requested type of help information to the terminal and exit
pub fn print(stream: std.fs.File, kind: HelpType) std.fs.File.WriteError!void {
    var buffer = std.io.bufferedWriter(stream.writer());
    const version = "veil version " ++ vstr ++ "\n";

    try switch (kind) {
        .full => buffer.writer().writeAll(data),
        .usage => buffer.writer().writeAll(data[88..120]),
        .version => buffer.writer().writeAll(version),
    };

    try buffer.flush();
    std.process.exit(0);
}
