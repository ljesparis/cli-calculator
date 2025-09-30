const std = @import("std");
const tk = @import("token");
const lx = @import("lexer");
const errors = @import("errors");

const testing = std.testing;
const Token = tk.Token;
const TokenType = tk.TokenType;
const Lexer = lx.Lexer;
const LanguageError = errors.LanguageError;


pub const Node = struct {
    token: Token,
    left_node: ?*Node,
    right_node: ?*Node,
    
    const Self = @This();

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        if (self.*.left_node) |ln| ln.deinit(allocator);
        if (self.*.right_node) |rn| rn.deinit(allocator);
        allocator.destroy(self);
    }
};

fn isOperator(token: Token) bool {
    return switch(token.type) {
        .PLUS, .MINUS, .MUL, .DIV => true,
        else => false,
    };
}

fn tokenChecker(current_token: Token, next_token: Token, prev_token: ?Token) LanguageError!void {
    switch(current_token.type) {
        .NUMBER => return numberTokenChecker(next_token, prev_token),
        .PLUS, .MINUS, .MUL, .DIV => return operatorTokenChecker(next_token, prev_token),
        .LPAREN => return leftParenthesisTokenChecker(next_token, prev_token),
        .RPAREN => return rightParenthesisTokenChecker(next_token, prev_token),
        else => return,

    }
}

fn numberTokenChecker(next_token: Token, prev_token: ?Token) LanguageError!void {
    if (prev_token) |ptoken| {
        if (ptoken.type == TokenType.RPAREN and next_token.type == TokenType.LPAREN) {
            return LanguageError.SyntaxError;
        }
        if (ptoken.type == TokenType.LPAREN and next_token.type == TokenType.EOF) {
            return LanguageError.SyntaxError;
        }
        if (ptoken.type == TokenType.RPAREN and next_token.type == TokenType.EOF) {
            return LanguageError.SyntaxError;
        }
    } else {
        if (next_token.type == TokenType.RPAREN or next_token.type == TokenType.LPAREN) {
            return LanguageError.SyntaxError;
        }
    }
}

fn operatorTokenChecker(next_token: Token, prev_token: ?Token) LanguageError!void {
    if (prev_token) |ptoken| {
        if (next_token.type == TokenType.EOF) {
            return LanguageError.SyntaxError;
        }
        if (ptoken.type == TokenType.LPAREN) {
            return LanguageError.SyntaxError;
        }
        if (isOperator(next_token)) {
            return LanguageError.SyntaxError;
        }
        if (next_token.type == TokenType.RPAREN) {
            return LanguageError.SyntaxError;
        }
    } else {
        return LanguageError.SyntaxError;
    }
}

fn leftParenthesisTokenChecker(next_token: Token, prev_token: ?Token) LanguageError!void {
    if (prev_token) |ptoken| {
        if (ptoken.type == TokenType.RPAREN or next_token.type == TokenType.RPAREN) {
            return LanguageError.SyntaxError;
        }
        if(next_token.type == TokenType.EOF) {
            return LanguageError.SyntaxError;
        }
        if (ptoken.type == TokenType.NUMBER) {
            return LanguageError.SyntaxError;
        }
        if (isOperator(next_token)) {
            return LanguageError.SyntaxError;
        }
    } else {
        if (isOperator(next_token)) {
            return LanguageError.SyntaxError;
        }
        if (next_token.type == TokenType.RPAREN) {
            return LanguageError.SyntaxError;
        }
    }
}

fn rightParenthesisTokenChecker(next_token: Token, prev_token: ?Token) LanguageError!void {
    if (prev_token) |ptoken| {
        if (ptoken.type == TokenType.LPAREN or next_token.type == TokenType.LPAREN) {
            return LanguageError.SyntaxError;
        }
        if (next_token.type == TokenType.NUMBER) {
            return LanguageError.SyntaxError;
        }
        if (isOperator(ptoken)) {
            return LanguageError.SyntaxError;
        }
    } else {
        return LanguageError.SyntaxError;
    }
}

pub const Parser = struct {
    allocator: std.mem.Allocator,
    lexer: Lexer,
    operandsStack: std.ArrayList(*Node) = .empty,
    operatorsStack: std.ArrayList(Token) = .empty,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, input: []const u8) Self {
        return .{
            .allocator = allocator,
            .lexer = Lexer.init(input),
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.operandsStack.items) |operand| {
            operand.deinit(self.allocator);
        }

        self.operandsStack.deinit(self.allocator);
        self.operatorsStack.deinit(self.allocator);
    }

    pub fn parse(self: *Self) !*Node {
        var current_token = try self.lexer.nextToken();
        var next_token = try self.lexer.nextToken();
        var prev_token: ?Token = null;

        while (current_token.type != TokenType.EOF) {
            try tokenChecker(current_token, next_token, prev_token);
            switch (current_token.type) {
                .NUMBER => {
                    const node = try self.makeNode(current_token, null, null);
                    try self.operandsStack.append(self.allocator, node);
                },
                .LPAREN => {
                    try self.operatorsStack.append(self.allocator, current_token);
                },
                .RPAREN => {
                    if (self.operatorsLen() == 0) {
                        return LanguageError.SyntaxError;
                    }
                    var index: usize = self.operatorsLen() - 1;
                    while (self.operatorsStack.items[index].type != TokenType.LPAREN and index > 0) {
                        index -= 1;
                    }

                    if (index == 0 and self.operatorsStack.items[index].type != TokenType.LPAREN) {
                        return LanguageError.SyntaxError;
                    }

                    _ = self.operatorsStack.orderedRemove(index);
                    if (self.operatorsLen() > 0) {
                        try self.appendNode();
                    }
                },
                .DIV, .MUL, .PLUS, .MINUS => {
                    while (self.operatorsLen() > 0 and getTokenWeight(self.operatorsStack.getLast()) >= getTokenWeight(current_token)) {
                        try self.appendNode();
                    }

                    try self.operatorsStack.append(self.allocator, current_token);
                },
                else => {},
            }

            prev_token = current_token;
            current_token = next_token;
            next_token = try self.lexer.nextToken();
        }

        while (self.operatorsLen() > 0) {
            try self.appendNode();
        }

        return self.operandsStack.pop().?;
    }

    fn appendNode(self: *Self) !void {
        const op = self.operatorsStack.pop();
        if (op.?.type == TokenType.LPAREN) {
            return LanguageError.SyntaxError;
        }

        const right_node = self.operandsStack.pop();
        const left_node = self.operandsStack.pop();

        const newNode = try self.makeNode(op.?, left_node, right_node);
        try self.operandsStack.append(self.allocator, newNode);
    }

    fn operatorsLen(self: *Self) usize {
        return self.operatorsStack.items.len;
    }

    fn makeNode(self: *Self, token: Token, left_node: ?*Node, right_node: ?*Node) !*Node {
        const node = try self.allocator.create(Node);
        node.* = .{
            .token = token,
            .left_node = left_node,
            .right_node = right_node,
        };
        return node;
    }

    fn getTokenWeight(token: Token) u8 {
        switch (token.type) {
            .DIV, .MUL => return 2,
            .MINUS, .PLUS => return 1,
            else => return 0,
        }
    }
};

test "parser should fail due syntax error" {
    const cases = [29][]const u8{
       "1*2-3*1++2",
       "*1",
       "1-",
       "1+1+1+1+1+1+1+1+1+",
       "(1",
       "(+)",
       "(1+1)-(",
       "1)",
       "1(",
       ")1(",
       "+)",
       "+(",
       "+2",
       "++",
       "2+)",
       "2+/",
       "(+2",
       "(+",
       "()",
       "((+",
       "(()",
       "2(2",
       ")+",
       ")2",
       "))",
       ")(",
       "2)2",
       "))(",
       "())",
    };

    for (cases) |case| {
        var parser = Parser.init(testing.allocator, case);
        defer parser.deinit();

        try testing.expectError(LanguageError.SyntaxError, parser.parse());
    }
}
