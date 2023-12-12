const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub const main = tools.defaultMain("2023/day03.txt", run);

const Map = tools.Map(u8, 256, 256, false);
const Vec2 = tools.Vec2;

fn cat(t: u8) enum { empty, digit, symbol, gear } {
    return switch (t) {
        '0'...'9' => .digit,
        '.' => .empty,
        '*' => .gear,
        else => .symbol,
    };
}

pub fn run(text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena_alloc = std.heap.ArenaAllocator.init(allocator);
    defer arena_alloc.deinit();
    const arena = arena_alloc.allocator();
    _ = arena;

    var map = Map{ .default_tile = '.' };
    map.initFromText(text);

    const ans1 = ans: {
        var sum: usize = 0;
        var cur_num: u32 = 0;
        var cur_is_piece = false;
        var it = map.iter(null);
        while (it.nextEx()) |tile| {
            const t = tile.t.*;

            if (cat(t) != .digit or tile.p[0] == 0) {
                if (cur_is_piece) sum += cur_num;
                cur_num = 0;
                cur_is_piece = false;
            }
            if (cat(t) == .digit) {
                cur_num = cur_num * 10 + t - '0';
                for (tile.neib8) |neib| {
                    if (neib) |n| {
                        cur_is_piece = cur_is_piece or cat(n) == .symbol or cat(n) == .gear;
                    }
                }
            }
        }
        if (cur_is_piece) sum += cur_num;
        break :ans sum;
    };

    const ans2 = ans: {
        const Cluster = struct { id: u32, payload: u32 };
        var map_numbers = tools.Map(Cluster, 256, 256, false){ .default_tile = .{ .id = 0, .payload = undefined } };
        {
            var cluster: u32 = 1;
            var cur_num: u32 = 0;
            var cur_start: ?Vec2 = null;
            var cur_end: ?Vec2 = null;
            var it = map.iter(null);
            while (it.nextEx()) |tile| {
                const t = tile.t.*;
                if (cat(t) != .digit or tile.p[0] == 0) {
                    if (cur_start) |start| {
                        const end = cur_end.?;
                        map_numbers.fill(Cluster{ .id = cluster, .payload = cur_num }, tools.BBox{ .min = start, .max = end });
                        cluster += 1;
                    }
                    cur_num = 0;
                    cur_start = null;
                    cur_end = null;
                }

                if (cat(t) == .digit) {
                    cur_num = cur_num * 10 + t - '0';
                    if (cur_start == null) cur_start = tile.p;
                    cur_end = tile.p;
                }
            }
            if (cur_start) |start| {
                const end = cur_end.?;
                map_numbers.fill(Cluster{ .id = cluster, .payload = cur_num }, tools.BBox{ .min = start, .max = end });
            }
        }

        var sum: usize = 0;
        var it = map_numbers.iter(null);
        while (it.nextEx()) |tile| {
            const t = map.at(tile.p);
            if (cat(t) != .gear) continue;

            var cluster1: u32 = 0;
            var cluster2: u32 = 0;
            var gear_ratio: u32 = 1;
            for (tile.neib8) |neib| {
                if (neib) |cluster| {
                    if (cluster.id == 0) continue;
                    if (cluster.id == cluster1 or cluster.id == cluster2) continue;
                    if (cluster1 == 0) {
                        cluster1 = cluster.id;
                        gear_ratio *= cluster.payload;
                    } else if (cluster2 == 0) {
                        cluster2 = cluster.id;
                        gear_ratio *= cluster.payload;
                    } else {
                        gear_ratio = 0; // 3 or more clusters.
                    }
                }
            }
            if (cluster1 != 0 and cluster2 != 0) sum += gear_ratio;
        }

        break :ans sum;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

test {
    const res = try run(
        \\467..114..
        \\...*......
        \\..35..633.
        \\......#...
        \\617*......
        \\.....+.58.
        \\..592.....
        \\......755.
        \\...$.*....
        \\.664.598..
    , std.testing.allocator);
    defer std.testing.allocator.free(res[0]);
    defer std.testing.allocator.free(res[1]);
    try std.testing.expectEqualStrings("4361", res[0]);
    try std.testing.expectEqualStrings("467835", res[1]);
}
