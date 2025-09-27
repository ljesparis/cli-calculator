const std = @import("std");
const tk = @import("token");
const errors = @import("errors");

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
    currentPosition: usize,
    nextPosition: usize,
    currentChar: u8,
    
    const Self = @This();

    pub fn init(input: []const u8) Self {
        var lexer: Lexer = .{
            .input =  input,
            .currentPosition = 0,
            .nextPosition = 0,
            .currentChar = 0,
        };
        lexer.readChar();
        return lexer;
    }

    pub fn nextToken(self: *Lexer) errors.LanguageError!tk.Token {
        self.skipWhitespace();
        return switch (self.currentChar) {
            '0' ... '9' => {
                const parsedToken = self.peakNumber();
                return tk.Token {.type = tk.TokenType.NUMBER, .literal = parsedToken  };
            },
            '-', '+', '*', '/', '(', ')' => {
                var tokenType: tk.TokenType = undefined; var literal: []const u8 = undefined;
                if (self.currentChar == '-') {
                    tokenType = tk.TokenType.MINUS; literal = "-";
                } else if (self.currentChar == '+') {
                    tokenType = tk.TokenType.PLUS; literal = "+";
                } else if (self.currentChar == '/') {
                    tokenType = tk.TokenType.DIV; literal = "/";
                } else if (self.currentChar == '*')  {
                    tokenType = tk.TokenType.MUL; literal = "*";
                } else if(self.currentChar == '(') {
                    tokenType = tk.TokenType.LPAREN; literal = "(";
                } else if (self.currentChar == ')') {
                    tokenType = tk.TokenType.RPAREN; literal = ")";
                }

                const token = tk.Token {.type= tokenType, .literal = literal  };
                self.readChar();
                return token;
            },
            else => {
                if (self.currentChar == 0) {
                    return tk.Token {.type = tk.TokenType.EOF, .literal = "End Of Line" };
                }
                return errors.LanguageError.IllegalCharacterError;
            }
        };
    }

    fn peakNumber(self: *Lexer) []const u8 {
        const start = self.currentPosition;
        while (isNumber(self.currentChar)) {
            self.readChar();
        }
        return self.input[start..self.currentPosition];
    }

    fn skipWhitespace(self: *Lexer) void {
        while (isWhitespace(self.currentChar)) {
            self.readChar();
        }
    }

    fn readChar(self: * Lexer) void {
        if (self.nextPosition >= self.input.len) {
            self.currentChar = 0;
        } else  {
            self.currentChar = self.input[self.nextPosition];
        }

        self.currentPosition = self.nextPosition;
        self.nextPosition += 1;
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

    const expected_tokens_matrix: [4][9]tk.Token = .{
        .{
            tk.Token{.type=tk.TokenType.NUMBER, .literal="50"},
            tk.Token{.type=tk.TokenType.MINUS, .literal= "-"},
            tk.Token{.type=tk.TokenType.NUMBER, .literal="12"},
            tk.Token{.type=tk.TokenType.DIV, .literal = "/"},
            tk.Token{.type=tk.TokenType.NUMBER, .literal="3"},
            tk.Token{.type=tk.TokenType.MUL, .literal = "*"},
            tk.Token{.type=tk.TokenType.NUMBER, .literal="2"},
            tk.Token{.type=tk.TokenType.PLUS, .literal = "+"},
            tk.Token{.type=tk.TokenType.NUMBER, .literal="999999999"},
        },
        .{
            tk.Token{.type=tk.TokenType.NUMBER, .literal="100"},
            tk.Token{.type=tk.TokenType.DIV, .literal = "/"},
            tk.Token{.type=tk.TokenType.NUMBER, .literal="5"},
            tk.Token{.type=tk.TokenType.PLUS, .literal = "+"},
            tk.Token{.type=tk.TokenType.NUMBER, .literal="60"},
            tk.Token{.type=tk.TokenType.MINUS, .literal = "-"},
            tk.Token{.type=tk.TokenType.NUMBER, .literal="8"},
            tk.Token{.type=tk.TokenType.MUL, .literal = "*"},
            tk.Token{.type=tk.TokenType.NUMBER, .literal="3"},
        },
        .{
            tk.Token{.type=tk.TokenType.NUMBER, .literal="45"},
            tk.Token{.type=tk.TokenType.MUL, .literal = "*"},
            tk.Token{.type=tk.TokenType.NUMBER, .literal="2"},
            tk.Token{.type=tk.TokenType.MINUS, .literal = "-"},
            tk.Token{.type=tk.TokenType.NUMBER, .literal="120"},
            tk.Token{.type=tk.TokenType.DIV, .literal = "/"},
            tk.Token{.type=tk.TokenType.NUMBER, .literal="6"},
            tk.Token{.type=tk.TokenType.PLUS, .literal = "+"},
            tk.Token{.type=tk.TokenType.NUMBER, .literal="9"},
        },
        .{
            tk.Token{.type=tk.TokenType.LPAREN, .literal="("},
            tk.Token{.type=tk.TokenType.NUMBER, .literal = "10"},
            tk.Token{.type=tk.TokenType.PLUS, .literal="+"},
            tk.Token{.type=tk.TokenType.NUMBER, .literal = "2"},
            tk.Token{.type=tk.TokenType.RPAREN, .literal=")"},
            tk.Token{.type=tk.TokenType.MINUS, .literal = "-"},
            tk.Token{.type=tk.TokenType.LPAREN, .literal="("},
            tk.Token{.type=tk.TokenType.NUMBER, .literal = "1"},
            tk.Token{.type=tk.TokenType.RPAREN, .literal=")"},
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
