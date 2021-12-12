const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

const Vec2 = tools.Vec2;
const Map = tools.Map(u8, 64, 64, false);

pub fn run(input_text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var maps = [_]Map{ Map{ .default_tile = 0 }, Map{ .default_tile = 0 } };
    {
        maps[0].fill('.', null);
        maps[1].fill('.', null);
        var p = Vec2{ .x = 0, .y = 0 };
        var it = std.mem.tokenize(u8, input_text, "\n\r");
        while (it.next()) |line| {
            maps[0].setLine(p, line);
            p.y += 1;
        }
    }

    const ans1 = ans: {
        var gen: u32 = 0;
        while (gen < 10) : (gen += 1) {
            const map0 = &maps[gen % 2];
            const map1 = &maps[1 - gen % 2];
            var it = map0.iter(null);
            while (it.nextEx()) |sq| {
                const up_left = if (sq.up_left) |x| x else '.';
                const up = if (sq.up) |x| x else '.';
                const up_right = if (sq.up_right) |x| x else '.';
                const left = if (sq.left) |x| x else '.';
                const right = if (sq.right) |x| x else '.';
                const down_left = if (sq.down_left) |x| x else '.';
                const down = if (sq.down) |x| x else '.';
                const down_right = if (sq.down_right) |x| x else '.';
                const neib = [_]u8{ up_left, up, up_right, left, right, down_left, down, down_right };

                var nb_tree: u32 = 0;
                var nb_lumber: u32 = 0;
                for (neib) |n| {
                    switch (n) {
                        '#' => nb_lumber += 1,
                        '|' => nb_tree += 1,
                        else => continue,
                    }
                }

                var t = sq.t.*;
                switch (t) {
                    '#' => {
                        if (nb_lumber == 0 or nb_tree == 0) t = '.';
                    },
                    '|' => {
                        if (nb_lumber >= 3) t = '#';
                    },
                    '.' => {
                        if (nb_tree >= 3) t = '|';
                    },
                    else => unreachable,
                }
                map1.set(sq.p, t);
            }

            //var buf: [100 * 100]u8 = undefined;
            //std.debug.print("{}\n", .{map1.printToBuf(null, null, null, &buf)});
        }

        var nb_tree: u32 = 0;
        var nb_lumber: u32 = 0;
        var it = maps[gen % 2].iter(null);
        while (it.next()) |sq| {
            switch (sq) {
                '#' => nb_lumber += 1,
                '|' => nb_tree += 1,
                else => continue,
            }
        }
        break :ans nb_tree * nb_lumber;
    };

    const ans2 = ans: {
        var results: [1001]u32 = undefined;

        var gen: u32 = 10;
        while (gen < 1000) : (gen += 1) {
            const map0 = &maps[gen % 2];
            const map1 = &maps[1 - gen % 2];

            var total_tree: u32 = 0;
            var total_lumber: u32 = 0;

            var it = map0.iter(null);
            while (it.nextEx()) |sq| {
                const up_left = if (sq.up_left) |x| x else '.';
                const up = if (sq.up) |x| x else '.';
                const up_right = if (sq.up_right) |x| x else '.';
                const left = if (sq.left) |x| x else '.';
                const right = if (sq.right) |x| x else '.';
                const down_left = if (sq.down_left) |x| x else '.';
                const down = if (sq.down) |x| x else '.';
                const down_right = if (sq.down_right) |x| x else '.';
                const neib = [_]u8{ up_left, up, up_right, left, right, down_left, down, down_right };

                var nb_tree: u32 = 0;
                var nb_lumber: u32 = 0;
                for (neib) |n| {
                    switch (n) {
                        '#' => nb_lumber += 1,
                        '|' => nb_tree += 1,
                        else => continue,
                    }
                }

                var t = sq.t.*;
                switch (t) {
                    '#' => {
                        if (nb_lumber == 0 or nb_tree == 0) t = '.';
                    },
                    '|' => {
                        if (nb_lumber >= 3) t = '#';
                    },
                    '.' => {
                        if (nb_tree >= 3) t = '|';
                    },
                    else => unreachable,
                }
                map1.set(sq.p, t);

                switch (t) {
                    '#' => total_lumber += 1,
                    '|' => total_tree += 1,
                    else => continue,
                }
            }

            results[gen + 1] = total_tree * total_lumber;

            // var buf: [100 * 100]u8 = undefined;
            // std.debug.print("{}\n", .{map1.printToBuf(null, null, null, &buf)});
            //std.debug.print("gen={}  => {}\n", .{ gen + 1, total_tree * total_lumber });
        }

        var period: u32 = 1;
        while (results[1000 - period] != results[1000]) : (period += 1) {}
        const phase = (1000 % period);

        assert(results[(1000 - period - phase) + (1000 % period)] == results[1000]);
        const res = results[(1000 - period - phase) + (1000000000 % period)]; //203236 too low
        //std.debug.print("period={} v={}\n", .{ period, res });

        break :ans res;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2018/input_day18.txt", run);
