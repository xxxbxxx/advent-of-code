const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

const MarbleCircle = tools.CircularBuffer(u32);

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    //const input = "9 players; last marble is worth 25 points";
    //const input = "10 players; last marble is worth 1618 points";
    //const input = "21 players; last marble is worth 6111 points";
    const params: struct { nb_players: u32, nb_marbles: u32 } = blk: {
        var it = std.mem.tokenize(u8, input, "\n\r");
        const fields = tools.match_pattern("{} players; last marble is worth {} points", it.next().?) orelse unreachable;
        break :blk .{
            .nb_players = @intCast(u32, fields[0].imm),
            .nb_marbles = @intCast(u32, fields[1].imm) + 1,
        };
    };

    // part1
    const ans1 = ans: {
        const scores = try allocator.alloc(u32, params.nb_players);
        defer allocator.free(scores);
        std.mem.set(u32, scores, 0);
        var highscore_player: u32 = 0;

        var circle2 = MarbleCircle.init(allocator);
        defer circle2.deinit();
        try circle2.pushHead(0);

        var circle = std.ArrayList(u32).init(allocator);
        defer circle.deinit();
        try circle.ensureTotalCapacity(params.nb_marbles);
        try circle.append(0);

        var current: usize = 0;
        var marble: u32 = 1;
        while (marble < params.nb_marbles) : (marble += 1) {
            const player = (marble - 1) % params.nb_players;
            if (marble % 23 == 0) {
                circle2.rotate(-7);
                const bonus2 = circle2.pop();

                const bonus_marble_index = (current + circle.items.len - 7) % circle.items.len;
                const bonus = circle.orderedRemove(bonus_marble_index);
                std.debug.assert(bonus2 == bonus);

                scores[player] += marble + bonus;
                if (scores[player] > scores[highscore_player]) highscore_player = player;
                current = bonus_marble_index % circle.items.len;
            } else {
                circle2.rotate(2);
                try circle2.pushHead(marble);

                const index = 1 + (current + 1) % (circle.items.len);
                try circle.insert(index, marble);
                current = index;
            }

            if (false) {
                std.debug.print("[{}]: ", .{player + 1});
                var iter = circle2.iter();
                while (iter.next()) |it| {
                    std.debug.print("{} ", .{it});
                }
                std.debug.print("\n", .{});

                std.debug.print("[{}]: ", .{player + 1});
                for (circle.items) |it, i| {
                    if (i == current) {
                        std.debug.print("({}) ", .{it});
                    } else {
                        std.debug.print("{} ", .{it});
                    }
                }
                std.debug.print("\n", .{});
            }
        }
        if (false) {
            std.debug.print("Scores: ", .{});
            for (scores) |it, i| {
                if (i == highscore_player) {
                    std.debug.print(">{}< ", .{it});
                } else {
                    std.debug.print("{} ", .{it});
                }
            }
            std.debug.print("\n", .{});

            std.debug.print("xinner {} : {}\n", .{ highscore_player + 1, scores[highscore_player] });
        }
        break :ans scores[highscore_player];
    };

    // part2
    const ans2 = ans: {
        const scores = try allocator.alloc(u32, params.nb_players);
        defer allocator.free(scores);
        std.mem.set(u32, scores, 0);
        var highscore_player: u32 = 0;

        var circle = MarbleCircle.init(allocator);
        defer circle.deinit();
        try circle.pushHead(0);

        var marble: u32 = 1;
        while (marble < params.nb_marbles * 100) : (marble += 1) {
            const player = (marble - 1) % params.nb_players;
            if (marble % 23 == 0) {
                circle.rotate(-7);
                const bonus = circle.pop().?;
                scores[player] += marble + bonus;
                if (scores[player] > scores[highscore_player]) highscore_player = player;
            } else {
                circle.rotate(2);
                try circle.pushHead(marble);
            }
        }
        break :ans scores[highscore_player];
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    //const limit = 1 * 1024 * 1024 * 1024;
    //const text = try std.fs.cwd().readFileAlloc(allocator, "2018/input_day08.txt", limit);
    //defer allocator.free(text);
    const text = "473 players; last marble is worth 70904 points";

    const ans = try run(text, allocator);
    defer allocator.free(ans[0]);
    defer allocator.free(ans[1]);

    try stdout.print("PART 1: {s}\nPART 2: {s}\n", .{ ans[0], ans[1] });
}
