
const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const errors_mod = b.createModule(.{
        .root_source_file = b.path("src/errors.zig"),
    });
    const token_mod = b.createModule(.{
        .root_source_file = b.path("src/token.zig"),
    });
    const lexer_mod = b.createModule(.{
        .root_source_file = b.path("src/lexer.zig"),
        .imports = &.{
            .{ .name = "errors", .module = errors_mod },
            .{ .name = "token", .module = token_mod },
        },
    });
    const parser_mod = b.createModule(.{
        .root_source_file = b.path("src/parser.zig"),
        .imports = &.{
            .{ .name = "errors", .module = errors_mod },
            .{ .name = "token", .module = token_mod },
            .{ .name = "lexer", .module = lexer_mod },
        },
    });

    const exe = b.addExecutable(.{
        .name = "cli_calculator",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "errors", .module = errors_mod },
                .{ .name = "token", .module = token_mod },
                .{ .name = "lexer", .module = lexer_mod },
                .{ .name = "parser", .module = parser_mod },
            },
        }),
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const main_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "errors", .module = errors_mod },
                .{ .name = "token", .module = token_mod },
                .{ .name = "lexer", .module = lexer_mod },
                .{ .name = "parser", .module = parser_mod },
            },
        }),
    });
    main_tests.root_module.addImport("errors", errors_mod);
    main_tests.root_module.addImport("token", token_mod);
    main_tests.root_module.addImport("lexer", lexer_mod);
    main_tests.root_module.addImport("parser", parser_mod);
    const run_main_tests = b.addRunArtifact(main_tests);

    const lexer_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/lexer.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "errors", .module = errors_mod },
                .{ .name = "token", .module = token_mod },
                .{ .name = "lexer", .module = lexer_mod },
            },
        }),
    });
    lexer_tests.root_module.addImport("errors", errors_mod);
    lexer_tests.root_module.addImport("token", token_mod);
    lexer_tests.root_module.addImport("lexer", lexer_mod);
    const run_lexer_tests = b.addRunArtifact(lexer_tests);

    const parser_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/parser.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "errors", .module = errors_mod },
                .{ .name = "token", .module = token_mod },
                .{ .name = "lexer", .module = lexer_mod },
                .{ .name = "parser", .module = parser_mod },
            },
        }),
    });
    parser_tests.root_module.addImport("errors", errors_mod);
    parser_tests.root_module.addImport("token", token_mod);
    parser_tests.root_module.addImport("lexer", lexer_mod);
    parser_tests.root_module.addImport("parser", parser_mod);
    const run_parser_tests = b.addRunArtifact(parser_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_main_tests.step);
    test_step.dependOn(&run_lexer_tests.step);
    test_step.dependOn(&run_parser_tests.step);
}

