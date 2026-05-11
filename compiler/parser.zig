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

    pub fn parse(self: *Parser) !*Node {
        const node_ptr = try self.allocator.create(Node);

        switch (self.current_token.type) {
            .identifier => {
                node_ptr.* = Node{ .variable = self.current_token.value };
            },
            .number => {
                const value = std.fmt.parseInt(i64, self.current_token.value, 10) catch {
                    std.debug.print("PARSE ERROR: Invalid number format: {s}\n", .{self.current_token.value});
                    return error.InvalidNumber;
                };
                node_ptr.* = Node{ .number = value };
            },
            else => {
                std.debug.print("PARSE ERROR: Unexpected token for primary expression: {s}\n", .{self.current_token.value});
                return error.UnexpectedToken;
            },
        }

        self.nextToken();

        return node_ptr;
    }

    pub fn nextToken(self: *Parser) void {
        self.current_token = self.lexer.next();
    }

    pub fn consume(self: *Parser, expected_token_type: TokenType) !void {
        std.fmt.parseInt(i64, self.current_token.value, 10);
        if (self.current_token.type == expected_token_type) {
            self.nextToken();
        } else {
            std.debug.print("PARSE ERROR: Expected {s}, got {s}\n", .{ @tagName(expected_token_type), @tagName(self.current_token.type) });

            return error.UnexpectedToken;
        }
    }
};
