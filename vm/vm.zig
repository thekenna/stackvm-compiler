const std = @import("std");
const Stack = @import("stack.zig").Stack;
const OpCode = @import("instructions.zig").OpCode;
const Memory = @import("memory.zig").Memory;

pub const StackFrame = struct {
    return_pc: usize,
    saved_fp: usize,
};

pub const VM = struct {
    pc: usize = 0,
    fp: usize = 0, // frame pointer

    stack: Stack = Stack{},

    call_stack: [1024]StackFrame = undefined,
    csp: usize = 0,

    mem: Memory = Memory{},

    pub fn init() VM {
        return VM{};
    }

    pub fn run(self: *VM, program: []const u8) void {
        while (self.pc < program.len) {
            const opcode_raw = program[self.pc];
            const opcode = std.enums.fromInt(OpCode, opcode_raw) orelse {
                std.debug.print("ERROR: Unknown opcode\n", .{});
                return;
            };

            std.debug.print("OPCODE:{}, IP:{d}\n", .{ opcode, self.pc });

            switch (opcode) {
                .push => {
                    self.pc += 1;

                    const value = program[self.pc];
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
                    self.pc += 1;
                    const jump_to_idx = program[self.pc];

                    self.pc = jump_to_idx;
                    continue; // skip ip += 1 after switch
                },
                .jump_if_zero => {
                    self.pc += 1;
                    const jump_to_idx = program[self.pc];

                    const value = self.stack.pop();

                    if (value == 0) {
                        self.pc = jump_to_idx;
                        continue; // skip ip inc after switch (ip += 1)
                    }
                },
                .call => {
                    // current ip 3[.call], call [10],
                    self.pc += 1;
                    // current .call cammand index
                    const jump_to_idx = program[self.pc];

                    self.call_stack[self.csp] = StackFrame{
                        .return_pc = self.pc + 1,
                        .saved_fp = self.fp,
                    };

                    self.csp += 1;

                    self.fp = self.stack.getSP();

                    self.pc = jump_to_idx;
                    std.debug.print(" -> JUMP TO ({d})\n", .{jump_to_idx});
                    continue;

                    // // save back instruction index after .call code index
                    // self.call_stack[self.csp] = self.pc + 1;
                    // self.csp += 1;

                    // std.debug.print(" -> SAVE TO CALLSTACK ({d}), CALLSTACK LENGTH IS {d}\n", .{ self.call_stack[self.csp - 1], self.csp });
                    // std.debug.print(" -> JUMP TO ({d})\n", .{jump_to_idx});
                    // self.pc = jump_to_idx;

                    // continue;
                },
                .ret => {
                    if (self.csp <= 0) {
                        std.debug.print(" -> RET PANIC: call stack pointer <= 0 EXIT", .{});
                        return;
                    }
                    const result = self.stack.data[self.stack.getSP() - 1];

                    self.csp -= 1;
                    const frame = self.call_stack[self.csp];

                    self.stack.setSP(self.fp) catch |err| {
                        std.debug.print(" -> RET PANIC: {s}", .{err});
                    };

                    self.stack.push(result);

                    self.fp = frame.saved_fp;

                    self.pc = frame.return_pc;
                    continue;

                    // self.csp -= 1;
                    // const ret_index = self.call_stack[self.csp];

                    // std.debug.print(" -> RET TO ({d})\n", .{ret_index});

                    // self.pc = ret_index;
                    // continue;
                },
                .store => {
                    // stack -> memory
                    self.pc += 1;
                    const memory_idx = program[self.pc];

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
                    self.pc += 1;
                    const memory_idx = program[self.pc];

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
                .store_local => {
                    self.pc += 1;
                    const raw_byte = program[self.pc];
                    const offset = @as(isize, @as(i8, @bitCast(raw_byte)));

                    const val = self.stack.pop(); 

                    const addr = @as(usize, @intCast(@as(isize, @intCast(self.fp)) + offset)); // FP + offset args(-1, -2)

                    self.stack.data[addr] = val;
                    std.debug.print(" -> STORE_LOCAL val {d} at FP + {d} (index {d})\n", .{ val, offset, addr });
                },

                .load_local => {
                    self.pc += 1;
                   
                    const raw_byte = program[self.pc];
                    const offset = @as(isize, @as(i8, @bitCast(raw_byte)));

                   
                    const addr = @as(usize, @intCast(@as(isize, @intCast(self.fp)) + offset));

                    const val = self.stack.data[addr];
                    self.stack.push(val);
                    std.debug.print(" -> LOAD_LOCAL val {d} from FP + {d} (index {d})\n", .{ val, offset, addr });
                },
            }

            self.pc += 1;
        }
    }
};
