const std = @import("std");
const Stack = @import("stack.zig").Stack;
const OpCode = @import("instructions.zig").OpCode;
const Memory = @import("memory.zig").Memory;

pub const VM = struct {
    ip: usize = 0,

    stack: Stack = Stack{},

    call_stack: [1024]usize = undefined,
    csp: usize = 0,

    mem: Memory = Memory{},

    pub fn init() VM {
        return VM{};
    }

    pub fn run(self: *VM, program: []const u8) void {
        while (self.ip < program.len) {
            const opcode_raw = program[self.ip];
            const opcode = std.enums.fromInt(OpCode, opcode_raw) orelse {
                std.debug.print("ERROR: Unknown opcode\n", .{});
                return;
            };

            std.debug.print("OPCODE:{}, IP:{d}\n", .{ opcode, self.ip });

            switch (opcode) {
                .push => {
                    self.ip += 1;

                    const value = program[self.ip];
                    self.stack.push(value);

                    std.debug.print(" -> Push {d}\n", .{value});
                },
                .add => {
                    const a = self.stack.pop();
                    const b = self.stack.pop();

                    self.stack.push(a + b);

                    std.debug.print(" -> ADD ({d} + {d} ) = {d}\n", .{ a, b, (b + a) });
                },
                .sub => {
                    const a = self.stack.pop();
                    const b = self.stack.pop();

                    self.stack.push(b - a);
                    std.debug.print(" -> SUB ({d} - {d} )\n", .{ b, a });
                },
                .halt => {
                    std.debug.print(" Exit Exec Loop\n", .{});
                    break;
                },
                .jump => {
                    self.ip += 1;
                    const jump_to_idx = program[self.ip];

                    self.ip = jump_to_idx;
                    continue; // skip ip += 1 after switch
                },
                .jump_if_zero => {
                    self.ip += 1;
                    const jump_to_idx = program[self.ip];

                    const value = self.stack.pop();

                    if (value == 0) {
                        self.ip = jump_to_idx;
                        continue; // skip ip inc after switch (ip += 1)
                    }
                },
                .call => {
                    // current ip 3[.call], call [10],
                    self.ip += 1;
                    // current .call cammand index
                    const jump_to_idx = program[self.ip];

                    // save back instruction index after .call code index
                    self.call_stack[self.csp] = self.ip + 1;
                    self.csp += 1;

                    std.debug.print(" -> SAVE TO CALLSTACK ({d}), CALLSTACK LENGTH IS {d}\n", .{ self.call_stack[self.csp - 1], self.csp });
                    std.debug.print(" -> JUMP TO ({d})\n", .{jump_to_idx});
                    self.ip = jump_to_idx;

                    continue;
                },
                .ret => {
                    if (self.csp <= 0) {
                        std.debug.print(" -> RET PANIC: call stack pointer <= 0 EXIT", .{});
                        return;
                    }

                    self.csp -= 1;
                    const ret_index = self.call_stack[self.csp];

                    std.debug.print(" -> RET TO ({d})\n", .{ret_index});

                    self.ip = ret_index;
                    continue;
                },
                .store => {
                    // stack -> memory
                    self.ip += 1;
                    const memory_idx = program[self.ip];

                    const value = self.stack.pop();

                    self.mem.write(memory_idx, value) catch |err| {
                        switch (err) {
                            error.OutOfBounds => {
                                std.debug.print(" -> STORE error.OutOfBounds", .{});
                                return;
                            },
                            // else => {
                            //     std.debug.print(" -> STORE error.Else", .{});
                            //     return;
                            // },
                        }
                    };
                },
                .load => {
                    // memory -> stack
                    self.ip += 1;
                    const memory_idx = program[self.ip];

                    const value = self.mem.read(memory_idx) catch |err| {
                        switch (err) {
                            error.OutOfBounds => {
                                std.debug.print(" -> LOAD error.OutOfBounds", .{});
                                return;
                            },
                            // else => {
                            //     std.debug.print(" -> LOAD error.Else", .{});
                            //     return;
                            // },
                        }
                    };
                    self.stack.push(value);

                    std.debug.print(" -> LOAD {d} from {d}\n", .{ value, memory_idx });
                },
            }

            self.ip += 1;
        }
    }
};
