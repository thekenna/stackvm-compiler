const std = @import("std");

pub const TokenType = enum {
    let,
    @"var", // std.meta.stringToEnum(TokenType, value)
    @"if",
    @"else",
    identifier,
    assign, //  "="
    number,
    plus, // +
    semicolon, // ;
    lpar, // (
    rpar, // )
    eof,
};

pub const Token = struct {
    type: TokenType,
    value: []const u8,
};

pub const Lexer = struct {
    source: []const u8 = undefined,
    pos: usize = 0,

    pub fn next(self: *Lexer) Token {
        self.skipWhitespace();

        if (self.pos >= self.source.len) {
            return Token{
                .type = TokenType.eof,
                .value = "",
            };
        }

        const start = self.pos; // Запоминаем начало ДО сдвига
        const curChar = self.source[self.pos];

        return switch (curChar) {
            'a'...'z', 'A'...'Z' => self.lexWord(start),
            '0'...'9' => self.lexNumber(start),
            '=' => self.consume(TokenType.assign, start, self.pos + 1),
            '+' => self.consume(TokenType.plus, start, self.pos + 1),
            ';' => self.consume(TokenType.semicolon, start, self.pos + 1),
            '(' => self.consume(TokenType.lpar, start, self.pos + 1),
            ')' => self.consume(TokenType.rpar, start, self.pos + 1),
            else => {
                std.debug.print("Unknown character: {c}\n", .{curChar});
                self.pos += 1;
                return self.next();
            },
        };
    }

    pub fn lexWord(self: *Lexer, start: usize) Token {
        // const start = self.pos;

        // [l, e, t, ' ' -> break, ] start = 0 self.pos = 2
        while ((self.pos < self.source.len) and std.ascii.isAlphanumeric(self.source[self.pos])) {
            self.pos += 1;
        }

        // const symLen = self.pos - start;

        return self.createToken(null, start, self.pos);
    }

    pub fn lexNumber(self: *Lexer, start: usize) Token {
        // const start = self.pos;

        while ((self.pos < self.source.len) and std.ascii.isDigit(self.source[self.pos])) {
            self.pos += 1;
        }

        // const symLen = self.pos - start;

        return self.createToken(TokenType.number, start, self.pos);
    }

    fn createToken(self: *Lexer, tokenType: ?TokenType, start: usize, end: usize) Token {
        const value = self.source[start..end];

        const _tokenType =
            tokenType orelse
            (std.meta.stringToEnum(TokenType, value) orelse TokenType.identifier);

        return Token{
            .type = _tokenType,
            .value = value,
        };
    }

    fn consume(self: *Lexer, tokenType: ?TokenType, start: usize, end: usize) Token {
        self.pos += end - start;

        return self.createToken(tokenType, start, end);
    }

    fn skipWhitespace(self: *Lexer) void {
        while ((self.pos < self.source.len) and std.ascii.isWhitespace(self.source[self.pos])) {
            self.pos += 1;
        }
    }
};
