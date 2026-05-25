pub const Stack = struct {
    data: [1024]i64 = undefined,
    sp: usize = 0,

    pub fn push(self: *Stack, value: i64) void {
        self.data[self.sp] = value;
        self.sp += 1;
    }

    pub fn pop(self: *Stack) i64 {
        self.sp -= 1;

        return self.data[self.sp];
    }

    pub fn getSP(self: *const Stack) usize {
        return self.sp;
    }

    pub fn setSP(self: *Stack, index: usize) !void {
        self.sp = index;
    }
};
