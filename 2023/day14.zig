const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub const main = tools.defaultMain("2023/day14.txt", run);
const Map = tools.Map(u8, 150, 150, false);
const Vec2 = tools.Vec2;

pub fn run(text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena_alloc = std.heap.ArenaAllocator.init(allocator);
    defer arena_alloc.deinit();
    const arena = arena_alloc.allocator();

    var map: Map = .{ .default_tile = '.' };
    map.initFromText(text);

    const ans1 = ans: {
        var sum: usize = 0;
        const min: @Vector(2, u32) = @intCast(map.bbox.min);
        const max: @Vector(2, u32) = @intCast(map.bbox.max);
        for (min[0]..max[0] + 1) |x| {
            var load: usize = 1 + max[1] - min[1];
            for (min[1]..max[1] + 1) |y| {
                const t = map.at(.{ @intCast(x), @intCast(y) });
                switch (t) {
                    else => unreachable,
                    '.' => {},
                    'O' => {
                        sum += load;
                        load -= 1;
                    },
                    '#' => {
                        load = max[1] - y;
                    },
                }
            }
        }
        break :ans sum;
    };

    // north, then west, then south, then east.
    const ans2 = ans: {
        const min = map.bbox.min;
        const max = map.bbox.max;
        var history = std.StringArrayHashMap(usize).init(allocator);
        defer history.deinit();

        for (0..1000000000) |i| {
            inline for (.{ .{ true, 1 }, .{ true, 0 }, .{ false, 1 }, .{ false, 0 } }) |step| {
                const min_to_max = step[0]; // direction
                const axis = step[1]; // x, y
                const inc: Vec2 = Vec2{ @intFromBool(axis == 0), @intFromBool(axis == 1) } * @as(Vec2, @splat(if (min_to_max) 1 else -1));

                var p: Vec2 = min;
                while (p[1 - axis] <= max[1 - axis]) : (p[1 - axis] += 1) {
                    p[axis] = if (min_to_max) min[axis] else max[axis];
                    var p0 = p;
                    while (if (min_to_max) p[axis] <= max[axis] else p[axis] >= min[axis]) : (p += inc) {
                        switch (map.at(p)) {
                            else => unreachable,
                            '.' => {},
                            'O' => {
                                if (p0[axis] != p[axis]) {
                                    assert(map.at(p0) == '.');
                                    map.set(p0, 'O');
                                    map.set(p, '.');
                                }
                                p0 += inc;
                            },
                            '#' => {
                                p0 = p + inc;
                            },
                        }
                    }
                }

                //var buf : [10000]u8 = undefined;
                //std.debug.print("map: {s}\n", .{ map.printToBuf(&buf, .{})});
            }

            const m = try arena.dupe(u8, &map.map);
            if (try history.fetchPut(m, i)) |KV| {
                const idx_loop_start = KV.value;
                const idx_loop_end = i;
                const final_loop_pos = ((1000000000 - 1) - idx_loop_start) % (idx_loop_end - idx_loop_start);
                // fast-forward!
                @memcpy(&map.map, history.keys()[final_loop_pos + idx_loop_start]);
                break;
            }
        }

        var sum: usize = 0;
        var it = map.iter(null);
        while (it.nextPos()) |p| sum += @as(usize, @intCast(1 + max[1] - p[1])) * @intFromBool(map.at(p) == 'O');
        break :ans sum;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

test {
    const res1 = try run(
        \\O....#....
        \\O.OO#....#
        \\.....##...
        \\OO.#O....O
        \\.O.....O#.
        \\O.#..O.#.#
        \\..O..#O..O
        \\.......O..
        \\#....###..
        \\#OO..#....
    , std.testing.allocator);
    defer std.testing.allocator.free(res1[0]);
    defer std.testing.allocator.free(res1[1]);
    try std.testing.expectEqualStrings("136", res1[0]);
    try std.testing.expectEqualStrings("64", res1[1]);
}
