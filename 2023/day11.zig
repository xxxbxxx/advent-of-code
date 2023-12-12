const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub const main = tools.defaultMain("2023/day11.txt", run);
const Map = tools.Map(u8, 150, 150, false);
const Vec2 = tools.Vec2;

pub fn run(text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena_alloc = std.heap.ArenaAllocator.init(allocator);
    defer arena_alloc.deinit();
    const arena = arena_alloc.allocator();

    var map: Map = .{ .default_tile = '.' };
    map.initFromText(text);

    const empty_lines, const empty_cols, const galaxies = input: {
        const lines = try arena.alloc(bool, @intCast(1 + map.bbox.max[1] - map.bbox.min[1]));
        const cols = try arena.alloc(bool, @intCast(1 + map.bbox.max[0] - map.bbox.min[0]));
        var gals = std.ArrayList(Vec2).init(arena);
        defer gals.deinit();
        @memset(lines, true);
        @memset(cols, true);
        var it = map.iter(null);
        while (it.nextPos()) |p| {
            switch (map.at(p)) {
                else => unreachable,
                '.' => continue,
                '#' => {
                    try gals.append(p);
                    lines[@intCast(p[1])] = false;
                    cols[@intCast(p[0])] = false;
                },
            }
        }
        break :input .{ lines, cols, try gals.toOwnedSlice() };
    };

    const ans1, const ans2 = ans: {
        var sum: @Vector(2, u64) = .{ 0, 0 }; // compute part1 and 2 simultaneously
        const inc: @Vector(2, u64) = .{ 1, 1000000 - 1 };
        for (galaxies[0 .. galaxies.len - 1], 0..) |p0, i| {
            for (galaxies[i + 1 ..]) |p1| {
                const pmin: @Vector(2, u32) = @intCast(@min(p0, p1));
                const pmax: @Vector(2, u32) = @intCast(@max(p0, p1));
                var d: @Vector(2, u64) = @splat(@reduce(.Add, pmax - pmin));
                for (empty_lines[pmin[1]..pmax[1]]) |empty| d += @as(@Vector(2, u64), @splat(@intFromBool(empty))) * inc; // todo: diff of sums instead of loop
                for (empty_cols[pmin[0]..pmax[0]]) |empty| d += @as(@Vector(2, u64), @splat(@intFromBool(empty))) * inc;
                sum += d;
            }
        }
        break :ans sum;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

test {
    const res1 = try run(
        \\...#......
        \\.......#..
        \\#.........
        \\..........
        \\......#...
        \\.#........
        \\.........#
        \\..........
        \\.......#..
        \\#...#.....
    , std.testing.allocator);
    defer std.testing.allocator.free(res1[0]);
    defer std.testing.allocator.free(res1[1]);
    try std.testing.expectEqualStrings("374", res1[0]);
    try std.testing.expectEqualStrings("82000210", res1[1]);
}
