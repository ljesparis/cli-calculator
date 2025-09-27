const std = @import("std");
const tk = @import("token");
const lx = @import("lexer");
const errors = @import("errors");

pub const Node = struct {
    token: tk.Token,
    left_node: ?*Node,
    right_node: ?*Node,
};

pub fn freeAST(allocator: std.mem.Allocator, node: *Node) void {
    if (node.*.left_node) |ln| freeAST(allocator, ln);
    if (node.*.right_node) |rn| freeAST(allocator, rn);

    allocator.destroy(node);
}

fn postTokenChecker(current_token: tk.Token, next_token: tk.Token) errors.LanguageError!void {
    switch (current_token.type) {
        .PLUS, .MINUS, .MUL, .DIV => return postOperatorChecker(next_token),
        .NUMBER => return postNumberChecker(next_token),
        .LPAREN => return postLeftParenthesisChecker(next_token),
        .RPAREN => return postRightParenthesisChecker(next_token),
        else => return,
    }
}

fn postNumberChecker(next_token: tk.Token) errors.LanguageError!void {
    switch (next_token.type) {
        .LPAREN => return errors.LanguageError.SyntaxError,
        else => return,
    }
}

fn postLeftParenthesisChecker(next_token: tk.Token) errors.LanguageError!void {
    switch (next_token.type) {
        .PLUS, .MUL, .DIV, .EOF => return errors.LanguageError.SyntaxError,
        else => return,
    }
}

fn postRightParenthesisChecker(next_token: tk.Token) errors.LanguageError!void {
    switch (next_token.type) {
        .NUMBER => return errors.LanguageError.SyntaxError,
        else => return,
    }
}

fn postOperatorChecker(next_token: tk.Token) errors.LanguageError!void {
    switch (next_token.type) {
        .RPAREN, .EOF => return errors.LanguageError.SyntaxError,
        else => return,
    }
}

fn preTokenChecker(current_token: tk.Token, preToken: ?tk.Token) errors.LanguageError!void {
    switch (current_token.type) {
        .PLUS, .MINUS, .MUL, .DIV => return preOperatorChecker(preToken),
        .NUMBER => return preNumberChecker(preToken),
        .LPAREN => return preLeftParenthesisChecker(preToken),
        .RPAREN => return preRightParenthesisChecker(preToken),
        else => return,
    }
}

fn preNumberChecker(prev_token: ?tk.Token) errors.LanguageError!void {
    if (prev_token == null) {
        return;
    }
    switch (prev_token.?.type) {
        .RPAREN => return errors.LanguageError.SyntaxError,
        else => return,
    }
}

fn preLeftParenthesisChecker(prev_token: ?tk.Token) errors.LanguageError!void {
    if (prev_token == null) {
        return;
    }
    switch (prev_token.?.type) {
        .NUMBER, .RPAREN => return errors.LanguageError.SyntaxError,
        else => return,
    }
}

fn preRightParenthesisChecker(prev_token: ?tk.Token) errors.LanguageError!void {
    if (prev_token == null) return errors.LanguageError.SyntaxError;
    switch (prev_token.?.type) {
        .PLUS, .MINUS, .MUL, .DIV, .LPAREN => return errors.LanguageError.SyntaxError,
        else => return,
    }
}

fn preOperatorChecker(prev_token: ?tk.Token) errors.LanguageError!void {
    if (prev_token == null) return errors.LanguageError.SyntaxError;
    switch (prev_token.?.type) {
        .LPAREN, .PLUS, .MINUS, .MUL, .DIV => return errors.LanguageError.SyntaxError,
        else => return,
    }
}

pub const Parser = struct {
    allocator: std.mem.Allocator,
    lexer: lx.Lexer,
    operandsStack: std.ArrayList(*Node) = .{},
    operatorsStack: std.ArrayList(tk.Token) = .{},

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, input: []const u8) Self {
        return .{ .allocator = allocator, .lexer = lx.Lexer.init(input) };
    }

    pub fn deinit(self: *Self) void {
        for (self.operandsStack.items) |operand| {
            freeAST(self.allocator, operand);
        }

        self.operandsStack.deinit(self.allocator);
        self.operatorsStack.deinit(self.allocator);
    }

    pub fn parse(self: *Self) !*Node {
        var current_token = try self.lexer.nextToken();
        var next_token = try self.lexer.nextToken();
        var prev_token: ?tk.Token = null;

        while (current_token.type != tk.TokenType.EOF) {
            try preTokenChecker(current_token, prev_token);
            try postTokenChecker(current_token, next_token);

            switch (current_token.type) {
                .NUMBER => {
                    const node = try self.makeNode(current_token, null, null);
                    try self.operandsStack.append(self.allocator, node);
                },
                .LPAREN => {
                    try self.operatorsStack.append(self.allocator, current_token);
                },
                .RPAREN => {
                    var index: usize = self.getOperatorsStackLen() - 1;
                    while (self.operatorsStack.items[index].type != tk.TokenType.LPAREN) {
                        index -= 1;
                    }

                    _ = self.operatorsStack.orderedRemove(index);

                    try self.appendNode();
                },
                .DIV, .MUL, .PLUS, .MINUS => {
                    while (self.getOperatorsStackLen() > 0 and getTokenWeight(self.operatorsStack.getLast()) >= getTokenWeight(current_token)) {
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

        while (self.getOperatorsStackLen() > 0) {
            try self.appendNode();
        }

        return self.operandsStack.pop().?;
    }

    fn appendNode(self: *Self) !void {
        const op = self.operatorsStack.pop();
        const right_node = self.operandsStack.pop();
        const left_node = self.operandsStack.pop();

        const newNode = try self.makeNode(op.?, left_node, right_node);
        try self.operandsStack.append(self.allocator, newNode);
    }

    fn getOperatorsStackLen(self: *Self) usize {
        return self.operatorsStack.items.len;
    }

    fn makeNode(self: *Self, token: tk.Token, left_node: ?*Node, right_node: ?*Node) !*Node {
        const node = try self.allocator.create(Node);
        node.* = .{
            .token = token,
            .left_node = left_node,
            .right_node = right_node,
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
    const cases = [7][]const u8{
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

        try std.testing.expectError(errors.LanguageError.SyntaxError, parser.parse());
        parser.deinit();
        try std.testing.expect(gpa.deinit() == .ok);
    }
}
