const std = @import("std");
const VM = @import("vm.zig").VM;
const Stack = @import("stack.zig").Stack;
const instructions = @import("instructions.zig");
// const Lexer = @import("src/compiler/lexer.zig").Lexer;

pub fn main() !void {
    var vm = VM.init();

    // const program = [_]u8{
    //     1, 1,
    //     1, 1,
    //     3,
    //     5, 0,
    // };

    // const program = [_]u8{
    //     6, 3, // 0, 1: CALL 4
    //     0, // 2: HALT
    //     1, 10, // 4, 5: PUSH 10
    //     7, // 6: RET
    // };

    const program =[_]u8{ 
        1, 5, 1, 5, 2,         // 0-4:  PUSH 5, PUSH 5, ADD (Стек: [10])
        1, 10, 1, 20, 1, 30, 1, 40, // 5-12: PUSH 10, 20, 30, 40
        6, 17,                 // 13, 14: CALL 17
        2,                     // 15: ADD (10 + 100)
        0,                     // 16: HALT
        
        // --- Функция sum4 (с индекса 17) ---
        11, 252,               // 17, 18: LOAD -4 (10)
        11, 253,               // 19, 20: LOAD -3 (20)
        2,                     // 21: ADD
        11, 254,               // 22, 23: LOAD -2 (30)
        2,                     // 24: ADD
        11, 255,               // 25, 26: LOAD -1 (40)
        2,                     // 27: ADD
        7                      // 28: RET
    };

    vm.run(&program);

    // std.debug.print("Result memory[0]: {d}\n", .{vm.mem.data[0]});

    // const source = " let x = 10; let y = 20; if (x) y + 5;";
    // var lexer = Lexer{ .source = source };

    // std.debug.print("--- START LEXING ---\n", .{});

    // while (true) {
    //     const token = lexer.next();
    //     std.debug.print("Token: [Type: {s: <10}] | Value: '{s}'\n", .{ @tagName(token.type), token.value });

    //     if (token.type == .eof) break;
    // }

    // std.debug.print("--- END LEXING ---\n", .{});
}
