const std = @import("std");
const tk = @import("token");
const lx = @import("lexer");
const errors = @import("errors");

pub  const Node = struct {
    token: tk.Token,
    leftNode: ?*Node,
    rightNode: ?*Node,
};

pub fn freeAST(allocator: std.mem.Allocator, node: *Node) void {
    if (node.*.leftNode) |ln| freeAST(allocator, ln);
    if (node.*.rightNode) |rn| freeAST(allocator,rn);

    allocator.destroy(node);
}

pub const Parser = struct {
    allocator: std.mem.Allocator,
    lexer: lx.Lexer,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, input: []const u8) Self {
        return .{
            .allocator = allocator,
            .lexer = lx.Lexer.init(input)
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

        if (currentToken.type != tk.TokenType.NUMBER ) return errors.LanguageError.SyntaxError;

        var nextToken = try self.lexer.nextToken();

        while (currentToken.type != tk.TokenType.EOF) {
            if (nextToken.type == currentToken.type or nextToken.type == tk.TokenType.EOF and currentToken.type != tk.TokenType.NUMBER) {
                return errors.LanguageError.SyntaxError;
            }

            switch (currentToken.type) {
                .NUMBER => {
                    const node = try self.makeNode(currentToken);
                    try operands.append(self.allocator, node);
                },
                .SLASH, .ASTERISK, .PLUS, .MINUS => {
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
        switch(token.type) {
            .SLASH, .ASTERISK => return 2,
            .MINUS, .PLUS => return 1,
            else => return 0,
        }
    }
};


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

        try std.testing.expectError(errors.LanguageError.SyntaxError,parser.parse());
        try std.testing.expect(gpa.deinit() == .ok);
    }
}
