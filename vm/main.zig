const std = @import("std");
const VM = @import("vm.zig").VM;
const Stack = @import("stack.zig").Stack;
const instructions = @import("instructions.zig");
const Lexer = @import("src/compiler/lexer.zig").Lexer;

pub fn main() !void {
    // var vm = VM.init();

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

    // const program = [_]u8{
    //     1, 42,
    //     8, 0,
    //     6, 8,
    //     0,
    //     0, 
    //     9,
    //     0,
    //     1,
    //     5,
    //     2,
    //     8,
    //     0,
    //     7,
    // };

    // vm.run(&program);
    
    // std.debug.print("Result memory[0]: {d}\n", .{vm.mem.data[0]});


    const source = " let x = 10; let y = 20; if (x) y + 5;";
    var lexer = Lexer{ .source = source };

    std.debug.print("--- START LEXING ---\n", .{});

    while (true) {
        const token = lexer.next();
        std.debug.print("Token: [Type: {s: <10}] | Value: '{s}'\n", .{ @tagName(token.type), token.value });
        
        if (token.type == .eof) break;
    }

    std.debug.print("--- END LEXING ---\n", .{});
}
