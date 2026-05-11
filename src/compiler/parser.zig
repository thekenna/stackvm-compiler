const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const TokenType = @import("lexer.zig").TokenType;
const Token = @import("lexer.zig").Token;

pub const ParserError = error{UnexpectedToken} || std.mem.Allocator.Error;

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

    pub fn consume(self: *Parser, expected_token_type: TokenType) !void {
        if (self.current_token.type == expected_token_type) {
            self.current_token = self.lexer.next();
        } else {
            std.debug.print("PARSE ERROR: Expected {s}, got {s}\n", .{ @tagName(expected_token_type), @tagName(self.current_token.type) });

            return error.UnexpectedToken;
        }
    }
};
