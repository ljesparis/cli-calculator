const std = @import("std");

// TODO: support decimals
// TODO: support left and right parentheses

const LanguageError = error {
    SyntaxError,
    IllegalCharacterError
};

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
    literal: []const u8,

    const Self = @This();

    pub fn print(self: *const Self) void {
        switch(self.type) {
            .NUMBER => std.debug.print("NUMBER({s})\n", .{self.literal}),

            .PLUS => std.debug.print("OPERATOR(+)\n", .{}),
            .MINUS  => std.debug.print("OPERATOR(-)\n", .{}),
            .SLASH  => std.debug.print("OPERATOR(/)\n", .{}),
            .ASTERISK  => std.debug.print("OPERATOR(*)\n", .{}),

            //.LPAREN => std.debug.print("LEFT PARENTHESIS\n", .{}),
            //.RPAREN  => std.debug.print("RIGHT PARENTHESIS\n", .{}),

            .EOF  => std.debug.print("{s}\n", .{self.literal}),
        }
    }
};

fn isWhitespace(c: u8) bool {
    return c == ' ' or c == '\n' or c == '\r' or c == '\t';
}

fn isOperator(c: u8) bool {
    return c == '-' or c == '+' or c == '*' or c == '/';
}

fn isNumber(c: u8) bool {
    return c >= '0' and c <= '9';
}

// LEXER
const Lexer = struct {
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

    pub fn nextToken(self: *Lexer) LanguageError!Token {
        self.skipWhitespace();
        return switch (self.currentChar) {
            '0' ... '9' => {
                const parsedToken = self.peakNumber();
                return Token {.type = TokenType.NUMBER, .literal = parsedToken  };
            },
            '-', '+', '*', '/' => {
                var tokenType: TokenType = undefined; var literal: []const u8 = undefined;
                if (self.currentChar == '-') {
                    tokenType = TokenType.MINUS; literal = "-";
                } else if (self.currentChar == '+') {
                    tokenType = TokenType.PLUS; literal = "+";
                } else if (self.currentChar == '/') {
                    tokenType = TokenType.SLASH; literal = "/";
                } else {
                    tokenType = TokenType.ASTERISK; literal = "*";
                }
                const token = Token {.type= tokenType, .literal = literal  };
                self.readChar();
                return token;
            },
            else => {
                if (self.currentChar == 0) {
                    return Token {.type = TokenType.EOF, .literal = "End Of Line" };
                }
                return LanguageError.IllegalCharacterError;
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

// PARSER
const Node = struct {
    token: Token,
    leftNode: ?*Node,
    rightNode: ?*Node,
};

fn freeAST(allocator: std.mem.Allocator, node: *Node) void {
    if (node.*.leftNode) |ln| freeAST(allocator, ln);
    if (node.*.rightNode) |rn| freeAST(allocator,rn);

    allocator.destroy(node);
}

const Parser = struct {
    allocator: std.mem.Allocator,
    lexer: Lexer,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, input: []const u8) Self {
        return .{
            .allocator = allocator,
            .lexer = Lexer.init(input)
        };
    }

    pub fn parse(self: *Self) !*Node {
        var operands: std.ArrayList(*Node) = .empty;
        defer operands.deinit(self.allocator);

        var operators: std.ArrayList(*Node) = .empty;
        defer operators.deinit(self.allocator);
        
        errdefer {
            for (operands.items) |operand| {
                freeAST(self.allocator, operand);
            }

            for (operators.items) |operator| {
                freeAST(self.allocator, operator);
            }
        }

        var currentToken = try self.lexer.nextToken();

        if (currentToken.type != TokenType.NUMBER ) return LanguageError.SyntaxError;

        var nextToken = try self.lexer.nextToken();

        while (currentToken.type != TokenType.EOF) {
            if (nextToken.type == currentToken.type or nextToken.type == TokenType.EOF and currentToken.type != TokenType.NUMBER) {
                return LanguageError.SyntaxError;
            }

            switch (currentToken.type) {
                TokenType.NUMBER => {
                    const node = try self.makeNode(currentToken);
                    try operands.append(self.allocator, node);
                },
                TokenType.SLASH, TokenType.ASTERISK, TokenType.PLUS, TokenType.MINUS => {
                    while(operators.items.len > 0 and getTokenWeight(operators.items[operators.items.len - 1].*.token)  >= getTokenWeight(currentToken)) {
                        const op = operators.pop();
                        const rightN = operands.pop();
                        const leftN = operands.pop();

                        op.?.*.rightNode = rightN;
                        op.?.*.leftNode = leftN;

                        try operands.append(self.allocator, op.?); 
                    }

                    const node = try self.makeNode(currentToken);
                    try operators.append(self.allocator, node);
                },
                else => {

                }
            }

            currentToken = nextToken;
            nextToken = try self.lexer.nextToken();

        }

        while (operators.items.len > 0 ) {
            const op = operators.pop();
            const rightN = operands.pop();
            const leftN = operands.pop();

            op.?.*.rightNode = rightN;
            op.?.*.leftNode = leftN;

            try operands.append(self.allocator, op.?); 
        }


        return operands.items[0];
    }

    fn makeNode(self: *Self, token: Token) !*Node {
        const node = try self.allocator.create(Node);
        node.* = .{
            .token = token,
            .leftNode = null,
            .rightNode = null,
        };
        return node;
    }

    inline fn getTokenWeight(token: Token) u8 {
        switch(token.type) {
            TokenType.SLASH, TokenType.ASTERISK => return 2,
            TokenType.MINUS, TokenType.PLUS => return 1,
            else => return 0,
        }
    }
};

pub fn parseToI32(s: []const u8) !i32 {
    return std.fmt.parseInt(i32, s, 10);
}

fn recursiveEval(allocator: std.mem.Allocator, ast:  * Node) !i32  {
    if (ast.*.leftNode == null and ast.*.rightNode == null and ast.*.token.type == TokenType.NUMBER) {
        return parseToI32(ast.token.literal);
    }

    const ln = try recursiveEval(allocator, ast.*.leftNode.?);
    const rn = try recursiveEval(allocator, ast.*.rightNode.?);
    const currentTokenType = ast.*.token.type;

    return switch (currentTokenType) {
        .ASTERISK => return ln * rn,
        .SLASH => return @divFloor(ln, rn),
        .PLUS => return ln + rn,
        .MINUS => return ln - rn,
        else => 0,
    };
}

fn eval(allocator: std.mem.Allocator, i: []const u8) !i32 {
    var parser = Parser.init(allocator, i);
    const ast = try parser.parse();

    defer freeAST(allocator, ast);

    return try recursiveEval(allocator, ast);
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    const result = eval(allocator, args[1]) catch |err| {
        switch(err) {
            LanguageError.SyntaxError => std.debug.print("Syntax error \n", .{}),
            LanguageError.IllegalCharacterError => std.debug.print("IllegalCharacter\n", .{}),
            else => std.debug.print("unknown error\n", .{}),
        }
        std.process.exit(1);
    };

    std.debug.print("{d}\n", .{result});
 }

// lexer tests
test "lexer should return an error when there's an illegal character" {
    var lexer = Lexer.init("a");
    try std.testing.expectError(LanguageError.IllegalCharacterError, lexer.nextToken());
}

test "lexer should tokenize all cases" {
    const cases = [3][]const u8 {
        "50 - 12 / 3 * 2 + 999999999",
        "100 / 5 + 60 - 8 * 3",
        "45*                 2- 120/6+                        9",
    };

    const expected_tokens_matrix: [3][9]Token = .{
        .{
            Token{.type=TokenType.NUMBER, .literal="50"},
            Token{.type=TokenType.MINUS, .literal= "-"},
            Token{.type=TokenType.NUMBER, .literal="12"},
            Token{.type=TokenType.SLASH, .literal = "/"},
            Token{.type=TokenType.NUMBER, .literal="3"},
            Token{.type=TokenType.ASTERISK, .literal = "*"},
            Token{.type=TokenType.NUMBER, .literal="2"},
            Token{.type=TokenType.PLUS, .literal = "+"},
            Token{.type=TokenType.NUMBER, .literal="999999999"},
        },
        .{
            Token{.type=TokenType.NUMBER, .literal="100"},
            Token{.type=TokenType.SLASH, .literal = "/"},
            Token{.type=TokenType.NUMBER, .literal="5"},
            Token{.type=TokenType.PLUS, .literal = "+"},
            Token{.type=TokenType.NUMBER, .literal="60"},
            Token{.type=TokenType.MINUS, .literal = "-"},
            Token{.type=TokenType.NUMBER, .literal="8"},
            Token{.type=TokenType.ASTERISK, .literal = "*"},
            Token{.type=TokenType.NUMBER, .literal="3"},
        },
        .{
            Token{.type=TokenType.NUMBER, .literal="45"},
            Token{.type=TokenType.ASTERISK, .literal = "*"},
            Token{.type=TokenType.NUMBER, .literal="2"},
            Token{.type=TokenType.MINUS, .literal = "-"},
            Token{.type=TokenType.NUMBER, .literal="120"},
            Token{.type=TokenType.SLASH, .literal = "/"},
            Token{.type=TokenType.NUMBER, .literal="6"},
            Token{.type=TokenType.PLUS, .literal = "+"},
            Token{.type=TokenType.NUMBER, .literal="9"},
        }
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

// PARSER
test "parser should fail due syntax errors" {
    const cases = [4][] const u8 {
        "1*2-3*1++2",
        "*1",
        "1-",
        "1+1+1+1+1+1+1+1+1+"
    };

    for (cases) |case| {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const allocator = gpa.allocator();
        var parser = Parser.init(allocator, case);

        try std.testing.expectError(LanguageError.SyntaxError,parser.parse());
        try std.testing.expect(gpa.deinit() == .ok);
    }
}

// EVAL
test "eval should be ok" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const cases = [8][]const u8 {
        "10*10",
        "10-10",
        "10+10",
        "10/10",
        "2*2+5*5-144/12",
        "2*2/2",
        "2/2*2-1",
        "10*1000"
    };
    const results = [8] i32 {
        100,
        0,
        20,
        1,
        17,
        2,
        1,
        10000
    };

    for(cases, results) |case, result| {
        const r = try eval(allocator, case);

        try std.testing.expect(result == r);
    }

    try std.testing.expect(gpa.deinit() == .ok);
}
