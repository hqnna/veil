const std = @import("std");

/// Thread safe container for values
pub fn Box(comptime T: type) type {
    return struct {
        const Self = @This();

        state: T,
        mutex: std.Thread.Mutex,

        /// Create a thread safe value
        pub fn init(value: T) Self {
            return Self{
                .mutex = std.Thread.Mutex{},
                .state = value,
            };
        }
    };
}
