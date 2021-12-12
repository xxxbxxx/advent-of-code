const std = @import("std");
const tools = @import("tools");

const with_trace = false;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}
const assert = std.debug.assert;

pub const main = tools.defaultMain("2021/day10.txt", run);

pub fn run(input: []const u8, gpa: std.mem.Allocator) tools.RunError![2][]const u8 {
    const ans12 = ans: {
        var score_syntax: u64 = 0;
        var scores_complete: [100]u64 = undefined;
        var scores_complete_len: usize = 0;

        var it = std.mem.tokenize(u8, input, "\n");
        var stack: [128]u8 = undefined;
        stack[0] = 'X'; // canary
        var sp: u32 = 0;
        while (it.next()) |line| {
            sp = 0;
            const wrong_char = err: for (line) |c| {
                switch (c) {
                    // push fermeture attendue
                    '(', '[', '{', '<' => {
                        sp += 1;
                        stack[sp] = switch (c) {
                            '(' => ')',
                            '[' => ']',
                            '{' => '}',
                            '<' => '>',
                            else => unreachable,
                        };
                    },

                    // pop + check fermeture
                    ')', ']', '}', '>' => {
                        const expected = stack[sp];
                        assert(expected != 'X'); // manifestement, jamais de stack underflow? triste.
                        sp -= 1;
                        if (expected != c) break :err c;
                    },

                    else => continue,
                }
            } else null;

            if (wrong_char) |c| {
                score_syntax += switch (c) {
                    ')' => @as(u32, 3),
                    ']' => @as(u32, 57),
                    '}' => @as(u32, 1197),
                    '>' => @as(u32, 25137),
                    else => unreachable,
                };
                trace("syntax error '{s}', found error: '{c}'. {} points\n", .{ line, wrong_char, score_syntax });
            } else {
                var pts: u64 = 0;
                while (sp > 0) : (sp -= 1) {
                    pts = pts * 5 +
                        switch (stack[sp]) {
                        ')' => @as(u32, 1),
                        ']' => @as(u32, 2),
                        '}' => @as(u32, 3),
                        '>' => @as(u32, 4),
                        else => unreachable,
                    };
                }
                scores_complete[scores_complete_len] = pts;
                scores_complete_len += 1;
                trace("autocomplete '{s}': {} points\n", .{ line, pts });
            }
        }

        std.sort.sort(u64, scores_complete[0..scores_complete_len], {}, comptime std.sort.asc(u64));

        break :ans [2]u64{ score_syntax, scores_complete[scores_complete_len / 2] };
    };

    return [_][]const u8{
        try std.fmt.allocPrint(gpa, "{}", .{ans12[0]}),
        try std.fmt.allocPrint(gpa, "{}", .{ans12[1]}),
    };
}

test {
    const res = try run(
        \\[({(<(())[]>[[{[]{<()<>>
        \\[(()[<>])]({[<{<<[]>>(
        \\{([(<{}[<>[]}>{[]{[(<()>
        \\(((({<>}<{<{<>}{[]{[]{}
        \\[[<[([]))<([[{}[[()]]]
        \\[{[{({}]{}}([{[{{{}}([]
        \\{<[[]]>}<{[{[{[]{()[[[]
        \\[<(<(<(<{}))><([]([]()
        \\<{([([[(<>()){}]>(<<{{
        \\<{([{{}}[<[[[<>{}]]]>[]]
    , std.testing.allocator);
    defer std.testing.allocator.free(res[0]);
    defer std.testing.allocator.free(res[1]);
    try std.testing.expectEqualStrings("26397", res[0]);
    try std.testing.expectEqualStrings("288957", res[1]);
}
