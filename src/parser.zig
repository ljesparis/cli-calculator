const std = @import("std");
const tk = @import("token");
const lx = @import("lexer");
const errors = @import("errors");

pub const Node = struct {
    token: tk.Token,
    leftNode: ?*Node,
    rightNode: ?*Node,
};

pub fn freeAST(allocator: std.mem.Allocator, node: *Node) void {
    if (node.*.leftNode) |ln| freeAST(allocator, ln);
    if (node.*.rightNode) |rn| freeAST(allocator, rn);

    allocator.destroy(node);
}

fn postTokenChecker(currentToken: tk.Token, nextToken: tk.Token) errors.LanguageError!void {
    switch(currentToken.type) {
        .PLUS, .MINUS, .MUL, .DIV => return postOperatorChecker(nextToken),
        .NUMBER => return postNumberChecker(nextToken),
        .LPAREN => return postLeftParenthesisChecker(nextToken),
        .RPAREN => return postRightParenthesisChecker(nextToken),
        else => return,
    }
}

fn postNumberChecker(nextToken: tk.Token) errors.LanguageError!void {
    switch (nextToken.type) {
        .LPAREN => return errors.LanguageError.SyntaxError,
        else => return,
    }
}

fn postLeftParenthesisChecker(nextToken: tk.Token) errors.LanguageError!void {
    switch (nextToken.type) {
        .PLUS, .MUL, .DIV, .EOF => return errors.LanguageError.SyntaxError,
        else => return,
    }
}

fn postRightParenthesisChecker(nextToken: tk.Token) errors.LanguageError!void {
    switch (nextToken.type) {
        .NUMBER => return errors.LanguageError.SyntaxError,
        else => return,
    }
}

fn postOperatorChecker(nextToken: tk.Token) errors.LanguageError!void {
    switch (nextToken.type) {
        .RPAREN, .EOF => return errors.LanguageError.SyntaxError,
        else => return,
    }
}

fn preTokenChecker(currentToken: tk.Token, preToken: ?tk.Token) errors.LanguageError!void {
    switch(currentToken.type) {
        .PLUS, .MINUS, .MUL, .DIV => return preOperatorChecker(preToken),
        .NUMBER => return preNumberChecker(preToken),
        .LPAREN => return preLeftParenthesisChecker(preToken),
        .RPAREN => return preRightParenthesisChecker(preToken),
        else => return,
    }
}

fn preNumberChecker(prevToken: ?tk.Token) errors.LanguageError!void {
    if (prevToken == null) {
        return;
    }
    switch (prevToken.?.type) {
        .RPAREN => return errors.LanguageError.SyntaxError,
        else => return,
    }
}

fn preLeftParenthesisChecker(prevToken: ?tk.Token) errors.LanguageError!void {
    if (prevToken == null) {
        return;
    }
    switch (prevToken.?.type) {
        .NUMBER, .RPAREN => return errors.LanguageError.SyntaxError,
        else => return,
    }
}

fn preRightParenthesisChecker(prevToken: ?tk.Token) errors.LanguageError!void {
    if (prevToken == null) return errors.LanguageError.SyntaxError;
    switch (prevToken.?.type) {
        .PLUS, .MINUS, .MUL, .DIV, .LPAREN => return errors.LanguageError.SyntaxError,
        else => return,
    }
}

fn preOperatorChecker(prevToken: ?tk.Token) errors.LanguageError!void {
    if (prevToken == null) return errors.LanguageError.SyntaxError;
    switch (prevToken.?.type) {
        .LPAREN, .PLUS, .MINUS, .MUL, .DIV => return errors.LanguageError.SyntaxError,
        else => return,
    }
}

pub const Parser = struct {
    allocator: std.mem.Allocator,
    lexer: lx.Lexer,
    operands: std.ArrayList(*Node),
    operators: std.ArrayList(*Node),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, input: []const u8) Self {
        return .{ .allocator = allocator, .lexer = lx.Lexer.init(input), .operands = .empty, .operators = .empty };
    }

    pub fn deinit(self: *Self) void {
        for (self.operands.items) |operand| {
            freeAST(self.allocator, operand);
        }

        for (self.operators.items) |operator| {
            freeAST(self.allocator, operator);
        }
        self.operands.deinit(self.allocator);
        self.operators.deinit(self.allocator);
    }

    pub fn parse(self: *Self) !*Node {
        var currentToken = try self.lexer.nextToken();
        var nextToken = try self.lexer.nextToken();
        var prevToken: ?tk.Token  = null;

        while (currentToken.type != tk.TokenType.EOF) {
            try preTokenChecker(currentToken, prevToken);
            try postTokenChecker(currentToken, nextToken);
            
            switch (currentToken.type) {
                .NUMBER => {
                    const node = try self.makeNode(currentToken);
                    try self.operands.append(self.allocator, node);
                },
                .LPAREN => {
                    const node = try self.makeNode(currentToken);
                    try self.operators.append(self.allocator, node);
                },
                .RPAREN => {
                    var index: usize = self.operators.items.len - 1;
                    while (self.operators.items[index].*.token.type != tk.TokenType.LPAREN) {
                        index -= 1;
                    }

                    freeAST(self.allocator, self.operators.orderedRemove(index));

                    const op = self.operators.pop();
                    const rightN = self.operands.pop();
                    const leftN = self.operands.pop();

                    op.?.*.rightNode = rightN;
                    op.?.*.leftNode = leftN;

                    try self.operands.append(self.allocator, op.?);
                },
                .DIV, .MUL, .PLUS, .MINUS => {
                    while (self.operators.items.len > 0 and getTokenWeight(self.operators.items[self.operators.items.len - 1].*.token) >= getTokenWeight(currentToken)) {
                        const op = self.operators.pop();
                        const rightN = self.operands.pop();
                        const leftN = self.operands.pop();

                        op.?.*.rightNode = rightN;
                        op.?.*.leftNode = leftN;

                        try self.operands.append(self.allocator, op.?);
                    }

                    const node = try self.makeNode(currentToken);
                    try self.operators.append(self.allocator, node);
                },
                else => {},
            }

            prevToken = currentToken;
            currentToken = nextToken;
            nextToken = try self.lexer.nextToken();
        }

        while (self.operators.items.len > 0) {
            const op = self.operators.pop();
            const rightN = self.operands.pop();
            const leftN = self.operands.pop();

            op.?.*.rightNode = rightN;
            op.?.*.leftNode = leftN;

            try self.operands.append(self.allocator, op.?);
        }

        return self.operands.items[0];
    }

    fn makeNode(self: *Self, token: tk.Token) !*Node {
        const node = try self.allocator.create(Node);
        node.* = .{
            .token = token,
            .leftNode = null,
            .rightNode = null,
        };
        return node;
    }

    inline fn getTokenWeight(token: tk.Token) u8 {
        switch (token.type) {
            .DIV, .MUL => return 2,
            .MINUS, .PLUS => return 1,
            else => return 0,
        }
    }
};

test "parser should fail due syntax errors" {
    const cases = [7][] const u8 {
        "1*2-3*1++2",
        "*1",
        "1-",
        "1+1+1+1+1+1+1+1+1+",
        ")1",
        "(+)",
        "(1+1)-(",
    };

    for (cases) |case| {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const allocator = gpa.allocator();
        var parser = Parser.init(allocator, case);

        try std.testing.expectError(errors.LanguageError.SyntaxError,parser.parse());
        parser.deinit();
        try std.testing.expect(gpa.deinit() == .ok);
    }
}
