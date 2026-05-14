const std = @import("std");
const Lexer = @import("compiler/lexer.zig").Lexer;
const Parser = @import("compiler/parser.zig").Parser;
const Node = @import("compiler/ast.zig").Node;

fn printPadding(padding: usize) void {
    var i: usize = 0;
    while (i < padding) : (i += 1) {
        std.debug.print("  ", .{});
    }
}

fn printAST(node: *Node, padding: usize) void {
    printPadding(padding);

    switch (node.*) {
        .number => |n| std.debug.print("Number: {d}\n", .{n}),
        .variable => |v| std.debug.print("Variable: {s}\n", .{v}),
        .assignment => |a| {
            std.debug.print("Assignment: let {s} =\n", .{a.name});
            printAST(a.value, padding + 1);
        },
        .binary_op => |b| {
            std.debug.print("BinaryOp: {s}\n", .{@tagName(b.op)});
            printAST(b.l, padding + 1);
            printAST(b.r, padding + 1);
        },
    }
}

pub fn main() !void {
    const source = "let x = 10 + 5 + 3 + 5 + 6 +3 +9;";
    std.debug.print("SOURCE CODE:\n{s}\n\n", .{source});

    var lexer = Lexer{ .source = source };

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = Parser.init(&lexer, allocator);

    const ast_tree = parser.parseStatement() catch |err| {
        std.debug.print("Failed to parse: {any}\n", .{err});
        return;
    };

    std.debug.print("ABSTRACT SYNTAX TREE:\n", .{});
    printAST(ast_tree, 0);
}

