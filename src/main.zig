const std = @import("std");
const tk = @import("token");
const lx = @import("lexer");
const pr = @import("parser");
const errors = @import("errors");

// TODO: support decimals
// TODO: support left and right parentheses
fn eval(allocator: std.mem.Allocator, i: []const u8) !i32 {
    var parser = pr.Parser.init(allocator, i);
    const ast = try parser.parse();

    defer pr.freeAST(allocator, ast);

    return try recursiveEval(allocator, ast);
}

fn recursiveEval(allocator: std.mem.Allocator, ast:  * pr.Node) !i32  {
    if (ast.*.leftNode == null and ast.*.rightNode == null and ast.*.token.type == tk.TokenType.NUMBER) {
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
            errors.LanguageError.SyntaxError => std.debug.print("Syntax error \n", .{}),
            errors.LanguageError.IllegalCharacterError => std.debug.print("IllegalCharacter\n", .{}),
            else => std.debug.print("Unknown error\n", .{}),
        }
        std.process.exit(1);
    };

    std.debug.print("{d}\n", .{result});
 }



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

