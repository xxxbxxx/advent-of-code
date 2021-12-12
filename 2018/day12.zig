const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var pots = [_]u1{0} ** 1000;
    const pot_offset = pots.len / 2;
    var pot_min: usize = 1000;
    var pot_max: usize = 0;
    var rules = [_]u1{0} ** 32;
    const filled: u1 = 1;
    const empty: u1 = 0;

    {
        var it = std.mem.tokenize(u8, input, "\n\r");
        {
            const fields = tools.match_pattern("initial state: {}", it.next().?) orelse unreachable;
            const init = fields[0].lit;
            for (init) |c, i| {
                const pot_index = i + pot_offset;
                pots[pot_index] = if (c == '#') filled else empty;
                if (pots[pot_index] != 0) {
                    pot_min = if (pot_index < pot_min) pot_index else pot_min;
                    pot_max = if (pot_index > pot_max) pot_index else pot_max;
                }
            }
        }

        while (it.next()) |line| {
            const fields = tools.match_pattern("{} => {}", line) orelse unreachable;
            const out = if (fields[1].lit[0] == '#') filled else empty;
            var in: u32 = 0;
            for (fields[0].lit) |c| {
                in = (in << 1) | (if (c == '#') filled else empty);
            }
            rules[in] = out;
        }
    }

    // part1
    const ans1 = ans: {
        var prev = [_]u1{0} ** 1000;
        var next = [_]u1{0} ** 1000;
        std.mem.copy(u1, &prev, &pots);
        var prev_min = pot_min;
        var prev_max = pot_max;

        var gen: u32 = 1;
        while (gen <= 20) : (gen += 1) {
            var next_min: usize = 10000;
            var next_max: usize = 0;
            for (next[prev_min - 2 .. prev_max + 2 + 1]) |*it, index| {
                const i = index + (prev_min - 2);
                const p: usize = @as(usize, prev[i - 2]) * 16 + @as(usize, prev[i - 1]) * 8 + @as(usize, prev[i + 0]) * 4 + @as(usize, prev[i + 1]) * 2 + @as(usize, prev[i + 2]) * 1;
                it.* = rules[p];

                if (rules[p] != 0) {
                    next_min = if (i < next_min) i else next_min;
                    next_max = if (i > next_max) i else next_max;
                }
            }

            std.mem.copy(u1, &prev, &next);
            prev_min = next_min;
            prev_max = next_max;
        }

        var score: i32 = 0;
        for (prev[prev_min .. prev_max + 1]) |p, i| {
            if (p != 0)
                score += (@intCast(i32, i + prev_min) - @intCast(i32, pot_offset));
        }
        break :ans score;
    };

    // part2
    const ans2 = ans: {
        var prev = [_]u1{0} ** 1000;
        var next = [_]u1{0} ** 1000;
        std.mem.copy(u1, &prev, &pots);
        var prev_min = pot_min;
        var prev_max = pot_max;

        var prev_score: i32 = 0;
        var a: i64 = 0;
        var b: i64 = 0;
        var gen: u32 = 1;
        while (true) : (gen += 1) {
            //std.debug.print("gen n°{}: [{}, {}] ", .{ gen, prev_min, prev_max });
            //for (prev[prev_min .. prev_max + 1]) |p, i| {
            //    const c: u8 = if (p != 0) '#' else '.';
            //    std.debug.print("{c}", .{c});
            //}
            //std.debug.print("\n", .{});
            var next_min: usize = 10000;
            var next_max: usize = 0;
            for (next[prev_min - 2 .. prev_max + 2 + 1]) |*it, index| {
                const i = index + (prev_min - 2);
                const p: usize = @as(usize, prev[i - 2]) * 16 + @as(usize, prev[i - 1]) * 8 + @as(usize, prev[i + 0]) * 4 + @as(usize, prev[i + 1]) * 2 + @as(usize, prev[i + 2]) * 1;
                it.* = rules[p];

                if (rules[p] != 0) {
                    next_min = if (i < next_min) i else next_min;
                    next_max = if (i > next_max) i else next_max;
                }
            }

            std.mem.copy(u1, &prev, &next);
            prev_min = next_min;
            prev_max = next_max;

            var score: i32 = 0;
            for (prev[prev_min .. prev_max + 1]) |p, i| {
                if (p != 0)
                    score += (@intCast(i32, i + prev_min) - @intCast(i32, pot_offset));
            }
            //std.debug.print("gen={}, score={}, min={}, recentre={}, moy={}\n", .{ gen, score, prev_min, score - @intCast(i32, prev_min), @divTrunc((score - @intCast(i32, (prev_min + prev_max) / 2)), @intCast(i32, prev_max - prev_min)) });

            // on constate que le pattern devient fixe après quelques generations (152) et se decale a vitesse constante. -> on doit pouvoir extrapoler
            {
                const g = @intCast(i32, gen);
                const na = (score - prev_score);
                const nb = score - g * na;
                // std.debug.print("gen={}, a={}, b={}, check={}\n", .{ gen, na, nb, na * g + nb });

                if (na == a and nb == b) { // stabilized!
                    break :ans a * 50000000000 + b;
                }
                a = na;
                b = nb;
            }
            prev_score = score;
        }
        unreachable;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2018/input_day12.txt", run);
