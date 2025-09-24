const std = @import("std");

// TOKEN & TOKENTYPE
const TokenType = enum {
    PLUS,
    MINUS,
    SLASH,
    ASTERISK,

    // LPAREN,
    // RPAREN,

    NUMBER,

    ILLEGAL,
    EOF,
};

const Token = struct {
    type: TokenType,
    literal: ?i32,

    const Self = @This();

    pub fn print(self: *Self) void {
        switch(self.type) {
            .NUMBER => std.debug.print("NUMBER({s})\n", .{self.literal}),

            .PLUS => std.debug.print("OPERATOR(+)\n", .{}),
            .MINUS  => std.debug.print("OPERATOR(-)\n", .{}),
            .SLASH  => std.debug.print("OPERATOR(/)\n", .{}),
            .ASTERISK  => std.debug.print("OPERATOR(*)\n", .{}),

            .LPAREN => std.debug.print("LEFT PARENTHESIS\n", .{}),
            .RPAREN  => std.debug.print("RIGHT PARENTHESIS\n", .{}),

            .ILLEGAL => std.debug.print("ILLEGAL\n", .{}),
            .EOF  => std.debug.print("END OF LINE\n", .{}),
        }
    }
};

// LEXER
const Lexer = struct {
    input: []const u8,
    currentPosition: usize,
    nextPosition: usize,
    currentChar: u8,
    allocator: std.mem.Allocator,
    
    const Self = @This();

    pub fn init(input: []const u8, allocator: std.mem.Allocator) Self {
        var lexer: Lexer = .{
            .input =  input,
            .currentPosition = 0,
            .nextPosition = 0,
            .currentChar = 0,
            .allocator = allocator,
        };

        // reading first character
        lexer.readChar();

        return lexer;
    }

    pub fn nextToken(self: *Lexer) Token {
        self.skipWhitespace();

        return switch (self.currentChar) {
            '0' ... '9' => {
                const parsedToken = self.peakNumber() catch {
                    std.process.exit(1);
                };
                return Token {.type = TokenType.NUMBER, .literal = parsedToken  };
            },
            '-', '+', '*', '/' => {
                var tokenType: TokenType = undefined;
                if (self.currentChar == '-') {
                    tokenType = TokenType.MINUS;
                } else if (self.currentChar == '+') {
                    tokenType = TokenType.PLUS;
                } else if (self.currentChar == '/') {
                    tokenType = TokenType.SLASH;
                } else {
                    tokenType = TokenType.ASTERISK;
                }
                const token = Token {.type= tokenType, .literal = null };
                self.readChar();
                return token;
            },
            else => {
                if (self.currentChar == 0) {
                    return Token {.type = TokenType.EOF, .literal = null };
                }
                return Token {.type = TokenType.ILLEGAL, .literal = null};
            }
        };
    }

    pub fn peakNumber(self: *Lexer) !i32 {
        var list: std.ArrayList(u8) = .empty;
        defer list.deinit(self.allocator);

        while (self.currentChar >= '0' and self.currentChar <= '9') {
            try list.append(self.allocator, self.currentChar);
            self.readChar();
        }

        const parsed = try std.fmt.parseInt(i32, list.items, 10);
        return parsed;
    }

    pub fn skipWhitespace(self: *Lexer) void {
        while (self.currentChar == ' ' or self.currentChar == '\t' or self.currentChar == '\n' or self.currentChar == '\r') {
            self.readChar();
        }
    }

    pub fn readChar(self: * Lexer) void {
        // is it the end of the array ?
        if (self.nextPosition >= self.input.len) {
            // yes
            self.currentChar = 0;
        } else  {
            // no and get the char of the next position
            self.currentChar = self.input[self.nextPosition];
        }

        // update current position
        self.currentPosition = self.nextPosition;
        // go to next position
        self.nextPosition += 1;
    }
};

// PARSER


pub fn main() !void {
    std.debug.print("hello world\n", .{});
}

// lexer tests
test "lexer should tokenize all cases" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const cases = [3][]const u8 {
        "50 - 12 / 3 * 2 + 999999999",
        "100 / 5 + 60 - 8 * 3",
        "45*                 2-120/6+                        9",
    };

    const expected: [3][9]Token = .{
        .{
            Token{.type=TokenType.NUMBER, .literal=50},
            Token{.type=TokenType.MINUS, .literal= null},
            Token{.type=TokenType.NUMBER, .literal=12},
            Token{.type=TokenType.SLASH, .literal = null},
            Token{.type=TokenType.NUMBER, .literal=3},
            Token{.type=TokenType.ASTERISK, .literal = null},
            Token{.type=TokenType.NUMBER, .literal=2},
            Token{.type=TokenType.PLUS, .literal = null},
            Token{.type=TokenType.NUMBER, .literal=999999999},
        },
        .{
            Token{.type=TokenType.NUMBER, .literal=100},
            Token{.type=TokenType.SLASH, .literal = null},
            Token{.type=TokenType.NUMBER, .literal=5},
            Token{.type=TokenType.PLUS, .literal = null},
            Token{.type=TokenType.NUMBER, .literal=60},
            Token{.type=TokenType.MINUS, .literal = null},
            Token{.type=TokenType.NUMBER, .literal=8},
            Token{.type=TokenType.ASTERISK, .literal = null},
            Token{.type=TokenType.NUMBER, .literal=3},
        },
        .{
            Token{.type=TokenType.NUMBER, .literal=45},
            Token{.type=TokenType.ASTERISK, .literal = null},
            Token{.type=TokenType.NUMBER, .literal=2},
            Token{.type=TokenType.MINUS, .literal = null},
            Token{.type=TokenType.NUMBER, .literal=120},
            Token{.type=TokenType.SLASH, .literal = null},
            Token{.type=TokenType.NUMBER, .literal=6},
            Token{.type=TokenType.PLUS, .literal = null},
            Token{.type=TokenType.NUMBER, .literal=9},
        }
    };

    for (cases, expected) |case, tks| {
        var lexer = Lexer.init(case, allocator);
        var token = lexer.nextToken();
        for (tks) |expected_tk| {
            try std.testing.expect(expected_tk.type == token.type);
            try std.testing.expect(expected_tk.literal == token.literal);
            token = lexer.nextToken();
        }
    }

    const leaked = gpa.deinit();
    try std.testing.expect(leaked == .ok);
}
