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
        if (env.get("NO_COLOR")) |_| break :value false;
        if (env.get("HYPER_COLOR")) |_| break :value true;
        if (env.get("TERM")) |v| break :value !std.mem.eql(u8, v, "dumb");
        break :value cli_flag or std.posix.isatty(terminal.handle);
    };
}
