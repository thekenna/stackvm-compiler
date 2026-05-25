const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const TokenType = @import("lexer.zig").TokenType;
const Token = @import("lexer.zig").Token;
const ast = @import("ast.zig");
const Node = ast.Node;

pub const ParserError = error{ UnexpectedToken, InvalidNumber } || std.mem.Allocator.Error;

pub const Parser = struct {
    lexer: *Lexer,
    current_token: Token,
    next_token: Token,
    allocator: std.mem.Allocator,

    pub fn init(lexer: *Lexer, allocator: std.mem.Allocator) Parser {
        const first_token = lexer.next();
        const second_token = lexer.next();

        return Parser{
            .lexer = lexer,
            .current_token = first_token,
            .next_token = second_token,
            .allocator = allocator,
        };
    }

    pub fn parseExpression(self: *Parser) !*Node {
        // 5 .plus 3 .plus 2
        var left = try self.parse(); // 5
        // eat 5 and assign to left -> next token to current (.plus)

        while (self.current_token.type == .plus) {
            const op_token = self.current_token;

            self.eatToken(); // eat +(.plus)

            const op: ast.Op = switch (op_token.type) {
                .plus => .add,
                else => unreachable,
            };

            const right = try self.parse(); // current 3

            const node_ptr = try self.allocator.create(Node);

            node_ptr.* = Node{ .binary_op = .{
                .l = left,
                .op = op,
                .r = right,
            } };

            left = node_ptr; // value = (5 .plus 3) to left [for next iteration]
        }

        return left; // result three
    }

    pub fn parseStatement(self: *Parser) !*Node {
        if (self.current_token.type == .let) {
            self.eatToken(); // move right

            // if next token is variable name - ok
            const name_token = self.current_token;
            try self.consume(.identifier);

            // if next token is assign (=) - ok
            try self.consume(.assign);

            // get expression node
            const value_node = try self.parseExpression();

            // if next tokein is ";" - ok
            try self.consume(.semicolon);

            const assign_node = try self.allocator.create(Node);

            assign_node.* = Node{ .assignment = .{
                .name = name_token.value,
                .value = value_node,
            } };

            return assign_node;
        }

        // if its not let -> then its expression
        const expression_node = try self.parseExpression();
        try self.consume(.semicolon);

        return expression_node;
    }

    pub fn parse(self: *Parser) !*Node {
        const node_ptr = try self.allocator.create(Node);

        switch (self.current_token.type) {
            .identifier => {
                if (self.next_token.type == .lpar) {
                    return try self.parseCallExpression();
                } else {
                    node_ptr.* = Node{ .variable = self.current_token.value };
                    self.eatToken();
                    return node_ptr;
                }
            },
            .number => {
                const value = std.fmt.parseInt(i64, self.current_token.value, 10) catch {
                    std.debug.print("PARSE ERROR: Invalid number format: {s}\n", .{self.current_token.value});
                    return error.InvalidNumber;
                };
                self.eatToken();
                node_ptr.* = Node{ .number = value };
                return node_ptr;
            },
            .function => {
                return try self.parseFunction();
            },
            else => {
                std.debug.print("PARSE ERROR: Unexpected token for primary expression: {s}\n", .{self.current_token.value});
                return error.UnexpectedToken;
            },
        }
    }

    fn parseFunction(self: *Parser) !*Node {
        try self.consume(.function); // [function]

        const func_name = self.current_token.value;
        try self.consume(.identifier); // function [doSomething]

        try self.consume(.lpar); // function doSomething [ ( ]

        var params = try std.ArrayList([]const u8).initCapacity(self.allocator, 0);
        defer params.deinit(self.allocator);

        while (self.current_token.type != .rpar) {
            const arg_name = self.current_token.value;
            try self.consume(.identifier); // function doSomething ( [ a ]

            try params.append(self.allocator, arg_name);

            if (self.current_token.type == .comma) {
                try self.consume(.comma); // function doSomething (a[ , ]
            }
        }

        try self.consume(.rpar); // function doSomething (a, b[ ) ]
        try self.consume(.lbrace); // function doSomething (a, b) [ { ]

        var body = try std.ArrayList(*Node).initCapacity(self.allocator, 0);
        defer body.deinit(self.allocator);

        // parse function body function doSomething (a, b) {[...]
        while (self.current_token.type != .rbrace) {
            const node = try self.parseStatement();
            try body.append(self.allocator, node);
        }

        try self.consume(.rbrace); // function body function doSomething (a, b) {...[ } ]

        const node = try self.allocator.create(Node);

        node.* = Node{ .function_decl = .{
            .name = func_name,
            .params = try params.toOwnedSlice(self.allocator),
            .body = try body.toOwnedSlice(self.allocator),
        } };

        return node;
    }

    fn parseCallExpression(self: *Parser) !*Node {
        const func_name = self.current_token.value;

        try self.consume(.lpar);

        var args = try std.ArrayList(*Node).initCapacity(self.allocator, 0);
        defer args.deinit(self.allocator);

        while (self.current_token.type != .rpar) {
            const arg = try self.parseExpression();

            try args.append(self.allocator, arg);

            if (self.current_token.type == .comma) {
                try self.consume(.comma);
            }
        }

        try self.consume(.rpar);

        const node = try self.allocator.create(Node);

        node.* = Node{ .call_expr = .{
            .name = func_name,
            .args = args.toOwnedSlice(self.allocator),
        } };

        return node;
    }

    fn eatToken(self: *Parser) void {
        self.current_token = self.next_token;
        self.next_token = self.lexer.next();
    }

    fn consume(self: *Parser, expected_token_type: TokenType) !void {
        // try std.fmt.parseInt(i64, self.current_token.value, 10);
        if (self.current_token.type == expected_token_type) {
            self.eatToken();
        } else {
            std.debug.print("PARSE ERROR: Expected {s}, got {s}\n", .{ @tagName(expected_token_type), @tagName(self.current_token.type) });

            return error.UnexpectedToken;
        }
    }
};
