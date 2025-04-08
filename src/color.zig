const std = @import("std");
const ansi = @import("ansi");

// Whether or not color is enabled
var use_color: bool = undefined;

/// Check terminal capability for the use of ansi color codes
pub fn checkCapability(
    allocator: std.mem.Allocator,
    terminal: std.fs.File,
    cli_flag: bool,
) std.process.GetEnvMapError!void {
    var env = try std.process.getEnvMap(allocator);
    defer env.deinit();

    use_color = value: {
        if (!cli_flag) break :value cli_flag;
        if (env.get("NO_COLOR")) |_| break :value false;
        if (env.get("HYPER_COLOR")) |v| break :value std.mem.eql(u8, v, "true");
        if (env.get("TERM")) |v| break :value !std.mem.eql(u8, v, "dumb");
        break :value std.posix.isatty(terminal.handle);
    };
}

/// Set the color for a message and write it to the specified stream
pub fn write(stream: anytype, color: ansi.style.Color, msg: []const u8) !void {
    const style = ansi.style.Style{ .foreground = color };
    if (use_color) try ansi.format.updateStyle(stream, style, null);
    try stream.writeAll(msg);
}
