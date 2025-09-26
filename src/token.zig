pub const TokenType = enum {
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

pub const Token = struct {
    type: TokenType,
    literal: []const u8,
};
