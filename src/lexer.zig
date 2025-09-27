const std = @import("std");
const tk = @import("token");
const errors = @import("errors");

const Token = tk.Token;
const TokenType = tk.TokenType;

fn isWhitespace(c: u8) bool {
    return c == ' ' or c == '\n' or c == '\r' or c == '\t';
}

fn isOperator(c: u8) bool {
    return c == '-' or c == '+' or c == '*' or c == '/';
}

fn isNumber(c: u8) bool {
    return c >= '0' and c <= '9';
}

pub const Lexer = struct {
    input: []const u8,
    current_position: usize,
    next_position: usize,
    current_char: u8,
    
    const Self = @This();

    pub fn init(input: []const u8) Self {
        var lexer: Lexer = .{
            .input =  input,
            .current_position = 0,
            .next_position = 0,
            .current_char = 0,
        };
        lexer.readChar();
        return lexer;
    }

    pub fn nextToken(self: *Lexer) errors.LanguageError!Token {
        self.skipWhitespace();
        return switch (self.current_char) {
            '0' ... '9' => {
                const parsedToken = self.peakNumber();
                return Token {.type = TokenType.NUMBER, .literal = parsedToken  };
            },
            '-', '+', '*', '/', '(', ')' => {
                var tokenType: TokenType = undefined; var literal: []const u8 = undefined;
                if (self.current_char == '-') {
                    tokenType = TokenType.MINUS; literal = "-";
                } else if (self.current_char == '+') {
                    tokenType = TokenType.PLUS; literal = "+";
                } else if (self.current_char == '/') {
                    tokenType = TokenType.DIV; literal = "/";
                } else if (self.current_char == '*')  {
                    tokenType = TokenType.MUL; literal = "*";
                } else if(self.current_char == '(') {
                    tokenType = TokenType.LPAREN; literal = "(";
                } else if (self.current_char == ')') {
                    tokenType = TokenType.RPAREN; literal = ")";
                }

                const token = Token {.type= tokenType, .literal = literal  };
                self.readChar();
                return token;
            },
            else => {
                if (self.current_char == 0) {
                    return Token {.type = TokenType.EOF, .literal = "End Of Line" };
                }
                return errors.LanguageError.IllegalCharacterError;
            }
        };
    }

    fn peakNumber(self: *Lexer) []const u8 {
        const start = self.current_position;
        while (isNumber(self.current_char)) {
            self.readChar();
        }
        return self.input[start..self.current_position];
    }

    fn skipWhitespace(self: *Lexer) void {
        while (isWhitespace(self.current_char)) {
            self.readChar();
        }
    }

    fn readChar(self: * Lexer) void {
        if (self.next_position >= self.input.len) {
            self.current_char = 0;
        } else  {
            self.current_char = self.input[self.next_position];
        }

        self.current_position = self.next_position;
        self.next_position += 1;
    }
};

test "lexer should return an error when there's an illegal character" {
    var lexer = Lexer.init("a");
    try std.testing.expectError(errors.LanguageError.IllegalCharacterError, lexer.nextToken());
}

test "lexer should tokenize all cases" {
    const cases = [4][]const u8 {
        "50 - 12 / 3 * 2 + 999999999",
        "100 / 5 + 60 - 8 * 3",
        "45*                 2- 120/6+                        9",
        "(10   +2) - (1)"
    };

    const expected_tokens_matrix: [4][9]Token = .{
        .{
            Token{.type=TokenType.NUMBER, .literal="50"},
            Token{.type=TokenType.MINUS, .literal= "-"},
            Token{.type=TokenType.NUMBER, .literal="12"},
            Token{.type=TokenType.DIV, .literal = "/"},
            Token{.type=TokenType.NUMBER, .literal="3"},
            Token{.type=TokenType.MUL, .literal = "*"},
            Token{.type=TokenType.NUMBER, .literal="2"},
            Token{.type=TokenType.PLUS, .literal = "+"},
            Token{.type=TokenType.NUMBER, .literal="999999999"},
        },
        .{
            Token{.type=TokenType.NUMBER, .literal="100"},
            Token{.type=TokenType.DIV, .literal = "/"},
            Token{.type=TokenType.NUMBER, .literal="5"},
            Token{.type=TokenType.PLUS, .literal = "+"},
            Token{.type=TokenType.NUMBER, .literal="60"},
            Token{.type=TokenType.MINUS, .literal = "-"},
            Token{.type=TokenType.NUMBER, .literal="8"},
            Token{.type=TokenType.MUL, .literal = "*"},
            Token{.type=TokenType.NUMBER, .literal="3"},
        },
        .{
            Token{.type=TokenType.NUMBER, .literal="45"},
            Token{.type=TokenType.MUL, .literal = "*"},
            Token{.type=TokenType.NUMBER, .literal="2"},
            Token{.type=TokenType.MINUS, .literal = "-"},
            Token{.type=TokenType.NUMBER, .literal="120"},
            Token{.type=TokenType.DIV, .literal = "/"},
            Token{.type=TokenType.NUMBER, .literal="6"},
            Token{.type=TokenType.PLUS, .literal = "+"},
            Token{.type=TokenType.NUMBER, .literal="9"},
        },
        .{
            Token{.type=TokenType.LPAREN, .literal="("},
            Token{.type=TokenType.NUMBER, .literal = "10"},
            Token{.type=TokenType.PLUS, .literal="+"},
            Token{.type=TokenType.NUMBER, .literal = "2"},
            Token{.type=TokenType.RPAREN, .literal=")"},
            Token{.type=TokenType.MINUS, .literal = "-"},
            Token{.type=TokenType.LPAREN, .literal="("},
            Token{.type=TokenType.NUMBER, .literal = "1"},
            Token{.type=TokenType.RPAREN, .literal=")"},
        },
    };

    for (cases, expected_tokens_matrix) |case, expected_tokens| {
        var lexer = Lexer.init(case);
        var token = try lexer.nextToken();

        for (expected_tokens) |expected_token| {
            try std.testing.expect(expected_token.type == token.type);
            try std.testing.expectEqualSlices(u8, expected_token.literal, token.literal);
            token = try lexer.nextToken();
        }
    }
}
