const std = @import("std");
const tk = @import("token");
const pr = @import("parser");
const errors = @import("errors");

const Parser = pr.Parser;
const TokenType = tk.TokenType;
const Token = tk.Token;

// TODO: refactor parser code. Try to find zig best practices
// TODO: support decimals
// TODO: add more tests

fn eval(allocator: std.mem.Allocator, i: []const u8) !i32 {
    var parser = Parser.init(allocator, i);
    defer parser.deinit();
    const ast = try parser.parse();
    defer pr.freeAST(allocator, ast);
    return try recursiveEval(allocator, ast);
}

fn recursiveEval(allocator: std.mem.Allocator, ast:  * pr.Node) !i32  {
    if (ast.*.left_node == null and ast.*.right_node == null and ast.*.token.type == TokenType.NUMBER) {
        return parseToI32(ast.token.literal);
    }

    const ln = try recursiveEval(allocator, ast.*.left_node.?);
    const rn = try recursiveEval(allocator, ast.*.right_node.?);
    const current_token_type = ast.*.token.type;

    return switch (current_token_type) {
        .MUL => return ln * rn,
        .PLUS => return ln + rn,
        .MINUS => return ln - rn,
        else => {
            if (rn == 0) return errors.LanguageError.ZeroDivisionError;
            return @divFloor(ln, rn);
        },
    };
}

pub fn parseToI32(s: []const u8) !i32 {
    return std.fmt.parseInt(i32, s, 10);
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    const result = eval(allocator, args[1]) catch |err| {
        switch(err) {
            errors.LanguageError.SyntaxError => std.debug.print("SyntaxError \n", .{}),
            errors.LanguageError.IllegalCharacterError => std.debug.print("IllegalCharacter\n", .{}),
            errors.LanguageError.ZeroDivisionError => std.debug.print("ZeroDivisionError\n", .{}),
            else => std.debug.print("Unknown error\n", .{}),
        }
        std.process.exit(1);
    };

    std.debug.print("{d}\n", .{result});
 }

test "eval should be ok" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const cases = [16][]const u8 {
       "10*10",
       "10-10",
       "10+10",
       "10/10",
       "2*2+5*5-144/12",
       "2*2/2",
       "2/2*2-1",
       "10*1000",
       "(10+10) * 2",
       "(10+10) * (1-1)",
       "(2*10-10) * (2*4+2)",
       "(5*5+10) * (2*4+2)",
       "(2*(10-10)) * (2*(4+2))",
       "((2*10) * (8/4)) + ((12/2) * (2*5))",
       "(((2*2) - 2) * 3)",
        "((((2*2)-2)-2)+3)"
    };
    const results = [16] i32 {
       100,
       0,
       20,
       1,
       17,
       2,
       1,
       10000,
       40,
       0,
       100,
       350,
       0,
       100,
       6,
        3
    };

    for(cases, results) |case, result| {
        const r = try eval(allocator, case);
        try std.testing.expect(result == r);
    }

    try std.testing.expect(gpa.deinit() == .ok);
}

