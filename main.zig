const std = @import("std");
const Lexer = @import("compiler/lexer.zig").Lexer;
const Parser = @import("compiler/parser.zig").Parser;
const Compiler = @import("compiler/generator.zig").Compiler;
const VM = @import("vm/vm.zig").VM;
const OpCode = @import("vm/instructions.zig").OpCode;
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
        .return_stmt => {

        },
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
        .function_decl => |f| {
             std.debug.print("Function Declaration: {s}\n", .{f.name});
            printPadding(padding + 1);
            
           
            std.debug.print("Params: (", .{});
            for (f.params, 0..) |param, i| {
                if (i > 0) std.debug.print(", ", .{});
                std.debug.print("{s}", .{param});
            }
            std.debug.print(")\n", .{});
          

            for (f.body) |stmt| {
                printAST(stmt, padding + 1);
            }
        },
        .call_expr => |c| {
            std.debug.print("Call Expression: {s}()\n", .{c.name});
            for (c.args) |arg| {
                printAST(arg, padding + 1);
            }
        },
        else => {}
    }
}


pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;
    const arena_allocator = init.arena.allocator();

    const args = try init.minimal.args.toSlice(arena_allocator);

    if (args.len < 2) {
        std.debug.print("Usage: custom_vm <file_path>\n", .{});
        std.process.exit(1);
    }

    const file_path = args[1];

    const max_file_size = 10 * 1024 * 1024; 
    const source = std.Io.Dir.cwd().readFileAlloc(io, file_path, arena_allocator, .limited(max_file_size)) catch |err| {
        std.debug.print("ERROR: Could not read file '{s}': {s}\n", .{file_path, @errorName(err)});
        std.process.exit(1);
    };

    var lexer = Lexer{ .source = source };
    var parser = Parser.init(&lexer, arena_allocator);

    var statements = try std.ArrayList(*Node).initCapacity(arena_allocator, 0);

    while (parser.current_token.type != .eof) {
        const stmt = parser.parseStatement() catch |err| {
            std.debug.print("PARSE ERROR: {s} at token '{s}'\n", .{@errorName(err), parser.current_token.value});
            std.process.exit(1);
        };
        try statements.append(arena_allocator, stmt);
    }

    std.debug.print("=== 2. ABSTRACT SYNTAX TREE ===\n", .{});
    for (statements.items) |stmt| {
        printAST(stmt, 0);
        std.debug.print("\n", .{});
    }

    var compiler = Compiler.init(gpa);
    defer compiler.deinit();

    for (statements.items) |stmt| {
        compiler.genNode(stmt) catch |err| {
            std.debug.print("COMPILER ERROR: {s}\n", .{@errorName(err)});
            std.process.exit(1);
        };
    }

    try compiler.bytecode.append(compiler.allocator, @intFromEnum(OpCode.halt));

    const program = compiler.bytecode.items;

    std.debug.print("=== STARTING VM ===\n", .{});
    var vm = VM{};
    vm.run(program);

    std.debug.print("\n=== EXECUTION FINISHED ===\n", .{});

    vm.mem.printDump(4);
}