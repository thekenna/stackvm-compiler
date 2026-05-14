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
    allocator: std.mem.Allocator,

    pub fn init(lexer: *Lexer, allocator: std.mem.Allocator) Parser {
        return Parser{
            .lexer = lexer,
            .current_token = lexer.next(), // load first token
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

            node_ptr.* = Node{
                .binary_op = .{
                    .l = left,
                    .op = op,
                    .r = right,
                }
            };

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

            assign_node.* = Node{
                .assignment = .{
                    .name = name_token.value,
                    .value = value_node,
                }
            };
            
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
                node_ptr.* = Node{ .variable = self.current_token.value };
                self.eatToken();
                return node_ptr;
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
            else => {
                std.debug.print("PARSE ERROR: Unexpected token for primary expression: {s}\n", .{self.current_token.value});
                return error.UnexpectedToken;
            },
        }
    }

    pub fn eatToken(self: *Parser) void {
        self.current_token = self.lexer.next();
    }

    pub fn consume(self: *Parser, expected_token_type: TokenType) !void {
        // try std.fmt.parseInt(i64, self.current_token.value, 10);
        if (self.current_token.type == expected_token_type) {
            self.eatToken();
        } else {
            std.debug.print("PARSE ERROR: Expected {s}, got {s}\n", .{ @tagName(expected_token_type), @tagName(self.current_token.type) });

            return error.UnexpectedToken;
        }
    }
};
