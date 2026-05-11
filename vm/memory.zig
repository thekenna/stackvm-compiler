const std = @import("std");

pub const MemoryError = error{OutOfBounds};

pub const Memory = struct {
    data: [1024]i64 = .{0} ** 1024,

    pub fn read(self: *Memory, index: usize) MemoryError!i64 {
        try checkSegment(index);

        // std.debug.print(" -> LOAD {d} from {d}\n", .{value, memory_idx});
        return self.data[index];
        
    }

    pub fn write(self: *Memory, index: usize, value: i64) MemoryError!void {
        try checkSegment(index);

        self.data[index] = value;
        std.debug.print(" -> STORE {d} at {d}\n", .{ value, index });
    }

    fn checkSegment(index: usize) MemoryError!void {
        if (index > 1024) {
            std.debug.print(" -> STORE SEGFAULT!: Address {d} out of bounds!\n", .{index});
            return MemoryError.OutOfBounds;
        }
    }
};
