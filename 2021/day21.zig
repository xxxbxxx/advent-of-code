const std = @import("std");
const tools = @import("tools");

const with_trace = false;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}
const assert = std.debug.assert;

pub const main = tools.defaultMain("2021/day21.txt", run);

pub fn run(input: []const u8, gpa: std.mem.Allocator) tools.RunError![2][]const u8 {
    //    var arena_alloc = std.heap.ArenaAllocator.init(gpa);
    //    defer arena_alloc.deinit();
    //    const arena = arena_alloc.allocator();

    var it = std.mem.tokenize(u8, input, "\n");
    const player1_start_pos = if (tools.match_pattern("Player 1 starting position: {}", it.next().?)) |val| @intCast(u4, val[0].imm - 1) else unreachable;
    const player2_start_pos = if (tools.match_pattern("Player 2 starting position: {}", it.next().?)) |val| @intCast(u4, val[0].imm - 1) else unreachable;

    const ans1 = ans: {
        var scores = [2]u32{ 0, 0 };
        var die: u16 = 1;
        var positions = [2]u4{ player1_start_pos, player2_start_pos };
        var turn: u1 = 0;
        var roll_count: u32 = 0;

        const die_faces = 100;
        const score_win = 1000;

        while (scores[0] < score_win and scores[1] < score_win) {
            const roll = (((die - 1) % die_faces) + 1) + (((die + 1 - 1) % die_faces) + 1) + (((die + 2 - 1) % die_faces) + 1);
            die = ((die + 3 - 1) % die_faces + 1);
            roll_count += 3;
            positions[turn] = @intCast(u4, (positions[turn] + roll) % 10);
            scores[turn] += (positions[turn] + 1);
            trace("player{}, rolls {}, pos={}, score={}\n", .{ turn, roll, positions[turn] + 1, scores[turn] });
            turn +%= 1;
        }
        break :ans roll_count * scores[turn];
    };

    const ans2 = ans: {
        const victory_score = 21;
        const cardinal = try gpa.create([42][victory_score + 10][victory_score + 10][10][10]u64);
        defer gpa.destroy(cardinal);
        //var cardinal = std.mem.zeroes([42][victory_score+10][victory_score+10][10][10]u64);
        @memset(@ptrCast([*]u8, cardinal), 0, @sizeOf(@TypeOf(cardinal.*)));
        cardinal[0][0][0][player1_start_pos][player2_start_pos] = 1;
        const rolls = [_]struct { score: u8, nb: u8 }{
            .{ .score = 3, .nb = 1 },
            .{ .score = 4, .nb = 3 },
            .{ .score = 5, .nb = 6 },
            .{ .score = 6, .nb = 7 },
            .{ .score = 7, .nb = 6 },
            .{ .score = 8, .nb = 3 },
            .{ .score = 9, .nb = 1 },
        };
        var wins1: u128 = 0;
        var wins2: u128 = 0;
        var turn: u32 = 1;
        while (turn < 42) : (turn += 1) {
            for ([_]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 }) |pos1| {
                for ([_]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 }) |pos2| {
                    var score1: u32 = 0;
                    while (score1 <= victory_score + 9) : (score1 += 1) {
                        var score2: u32 = 0;
                        while (score2 <= victory_score + 9) : (score2 += 1) {
                            for (rolls) |roll| {
                                const prevpos1 = (pos1 + 10 - roll.score) % 10;
                                const prevpos2 = (pos2 + 10 - roll.score) % 10;
                                if (score1 >= (pos1 + 1) and (turn % 2 == 1)) {
                                    const prevscore1 = score1 - (pos1 + 1);
                                    if (prevscore1 < victory_score and score2 < victory_score)
                                        cardinal[turn][score1][score2][pos1][pos2] +=
                                            cardinal[turn - 1][prevscore1][score2][prevpos1][pos2] * roll.nb;
                                }
                                if (score2 >= (pos2 + 1) and (turn % 2 == 0)) {
                                    const prevscore2 = score2 - (pos2 + 1);
                                    if (prevscore2 < victory_score and score1 < victory_score)
                                        cardinal[turn][score1][score2][pos1][pos2] +=
                                            cardinal[turn - 1][score1][prevscore2][pos1][prevpos2] * roll.nb;
                                }
                            }
                            if (cardinal[turn][score1][score2][pos1][pos2] > 0)
                                trace("card[turn: {d}][score1: {d}][score2: {d}][p1: {d}][p2: {d}]={d}\n", .{ turn, score1, score2, pos1, pos2, cardinal[turn][score1][score2][pos1][pos2] });
                            wins1 += @boolToInt(score1 >= victory_score and score2 < victory_score) * cardinal[turn][score1][score2][pos1][pos2];
                            wins2 += @boolToInt(score1 < victory_score and score2 >= victory_score) * cardinal[turn][score1][score2][pos1][pos2];
                        }
                    }
                }
            }
        }
        break :ans @maximum(wins1, wins2);
    };

    return [_][]const u8{
        try std.fmt.allocPrint(gpa, "{}", .{ans1}),
        try std.fmt.allocPrint(gpa, "{}", .{ans2}),
    };
}

test {
    {
        const res = try run(
            \\Player 1 starting position: 4
            \\Player 2 starting position: 8
        , std.testing.allocator);
        defer std.testing.allocator.free(res[0]);
        defer std.testing.allocator.free(res[1]);
        try std.testing.expectEqualStrings("739785", res[0]);
        try std.testing.expectEqualStrings("444356092776315", res[1]);
    }
}
