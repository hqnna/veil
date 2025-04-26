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

        /// Get the internal state
        pub fn get(self: *Self) *T {
            self.mutex.lock();
            defer self.mutex.unlock();
            return &self.state;
        }
    };
}

/// Basic thread queue implementation
pub const Queue = struct {
    mutex: std.Thread.Mutex,
    allocated: usize,
    running: usize,

    /// Initialize a queue with a worker count
    pub fn init(threads: usize) Queue {
        return Queue{
            .mutex = std.Thread.Mutex{},
            .allocated = threads,
            .running = 0,
        };
    }

    /// Spawn threads inside the queue with a group
    pub fn spawn(
        queue: *Queue,
        group: *std.Thread.WaitGroup,
        comptime func: anytype,
        args: anytype,
    ) !void {
        queue.mutex.lock();
        defer queue.mutex.unlock();
        if (queue.allocated == 1) return @call(.auto, func, args);
        while (queue.running < queue.allocated) : (queue.running += 1) {
            _ = try std.Thread.spawn(.{}, worker, .{ queue, group, func, args });
        }
    }

    /// The actual thread worker that does work
    fn worker(
        queue: *Queue,
        group: *std.Thread.WaitGroup,
        comptime func: anytype,
        args: anytype,
    ) !void {
        group.start();

        defer {
            group.finish();
            if (queue.running > 1) {
                queue.mutex.lock();
                queue.running -= 1;
                queue.mutex.unlock();
            }
        }

        return @call(.auto, func, args);
    }
};
