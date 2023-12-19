const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub const main = tools.defaultMain("2023/day18.txt", run);
const Map = tools.Map(u8, 512, 512, true);
const Vec2 = tools.Vec2;

pub fn run(text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena_alloc = std.heap.ArenaAllocator.init(allocator);
    defer arena_alloc.deinit();
    const arena = arena_alloc.allocator();
    _ = arena;

    const ans1 = ans: {
        var map: Map = .{ .default_tile = '.' };
        {
            var p: Vec2 = .{ 0, 0 };
            var it = std.mem.tokenize(u8, text, "\n\r\t");
            while (it.next()) |line| {
                const vals = tools.match_pattern("{} {} ({})", line) orelse continue;
                const dir = vals[0].lit;
                const len: u32 = @intCast(vals[1].imm);
                assert(vals[2].lit[0] == '#');
                const color = std.fmt.parseInt(u32, vals[2].lit[1..], 16) catch unreachable;
                _ = color;

                assert(dir.len == 1);
                const d: Vec2 = switch (dir[0]) {
                    'U' => .{ 0, -1 },
                    'D' => .{ 0, 1 },
                    'L' => .{ -1, 0 },
                    'R' => .{ 1, 0 },
                    else => unreachable,
                };
                for (0..len) |_| {
                    map.set(p, '#');
                    p += d;
                }
            }
        }

        floodfill(&map, Vec2{ 1, 1 }); // 1,1 : dans la surface pour l'exemple et l'input.
        var sum: u32 = 0;
        var it = map.iter(null);
        while (it.next()) |t| sum += @intFromBool(t == '#');
        break :ans sum;
    };

    const ans2 = ans: {
        var sum: i64 = 0;

        const p0: Vec2 = .{ 0, 0 };
        var prev: Vec2 = p0;
        var p: Vec2 = p0;

        var it = std.mem.tokenize(u8, text, "\n\r\t");
        while (it.next()) |line| {
            const vals = tools.match_pattern("{} ({})", line) orelse continue;
            _ = vals[0].lit;
            assert(vals[1].lit[0] == '#');
            const len = std.fmt.parseInt(u31, vals[1].lit[1 .. vals[1].lit.len - 1], 16) catch unreachable;
            const dir = std.fmt.parseInt(u32, vals[1].lit[vals[1].lit.len - 1 ..], 16) catch unreachable;

            const d: Vec2 = switch (dir) {
                3 => .{ 0, -1 },
                1 => .{ 0, 1 },
                2 => .{ -1, 0 },
                0 => .{ 1, 0 },
                else => unreachable,
            };

            const p1 = p + d * Vec2{ len, len };

            // triangle surface
            const u = p - p0;
            const v = p1 - p0;
            const cross = @as(i64, u[0]) * @as(i64, v[1]) - @as(i64, u[1]) * @as(i64, v[0]);
            const signed_surf_doubled = cross;
            sum += signed_surf_doubled;
            sum += len; // + les pixels sur la ligne autour de la surface. mais pourquoi? et pouquoi /2?

            prev = p;
            p = p1;
        }

        break :ans @divExact(sum, 2) + 1;

        // ah! l'explication: https://www.reddit.com/r/adventofcode/comments/18l8mao/2023_day_18_intuition_for_why_spoiler_alone/
    };

    // slow rasterize version
    if (false) {
        const VerticalEdge = struct {
            x: i32,
            ymin: i32,
            ymax: i32,
            fn lessThanByY(_: void, a: @This(), b: @This()) bool {
                return (a.ymax < b.ymax);
            }
            fn lessThanByX(_: void, a: @This(), b: @This()) bool {
                return (a.x < b.x);
            }
        };
        var edges = std.ArrayList(VerticalEdge).init(allocator);
        defer edges.deinit();

        var p: Vec2 = .{ 0, 0 };
        var bbox = tools.BBox.empty;
        var it = std.mem.tokenize(u8, text, "\n\r\t");
        while (it.next()) |line| {
            const vals = tools.match_pattern("{} ({})", line) orelse continue;
            _ = vals[0].lit;
            assert(vals[1].lit[0] == '#');
            const len = std.fmt.parseInt(u31, vals[1].lit[1 .. vals[1].lit.len - 1], 16) catch unreachable;
            const dir = std.fmt.parseInt(u32, vals[1].lit[vals[1].lit.len - 1 ..], 16) catch unreachable;

            const d: Vec2 = switch (dir) {
                3 => .{ 0, -1 },
                1 => .{ 0, 1 },
                2 => .{ -1, 0 },
                0 => .{ 1, 0 },
                else => unreachable,
            };
            const p1 = p + d * Vec2{ len, len };
            bbox.min = @min(bbox.min, p1);
            bbox.max = @max(bbox.max, p1);
            if (d[0] == 0) {
                if (p1[1] < p[1]) {
                    try edges.append(.{ .x = p[0], .ymin = p1[1], .ymax = p[1] });
                } else {
                    try edges.append(.{ .x = p[0], .ymin = p[1], .ymax = p1[1] });
                }
            }
            p = p1;
        }
        std.mem.sort(VerticalEdge, edges.items, {}, VerticalEdge.lessThanByY);

        // rasterize
        var sum: i64 = 0;
        var line_edges = std.ArrayList(VerticalEdge).init(allocator);
        defer line_edges.deinit();

        var start_index: usize = 0;
        var y = bbox.min[1];
        while (y <= bbox.max[1]) : (y += 1) {
            line_edges.clearRetainingCapacity();
            while (edges.items[start_index].ymax < y) : (start_index += 1) {}
            for (edges.items[start_index..]) |e| {
                if (e.ymin <= y and y <= e.ymax)
                    try line_edges.append(e);
            }

            std.mem.sort(VerticalEdge, line_edges.items, {}, VerticalEdge.lessThanByX);
            const Corner = enum { none, up, down };

            var in = false;
            var on_edge: Corner = .none;
            var prev: ?i32 = null;
            for (line_edges.items) |e| {
                const corner: Corner = if (e.ymin == y and e.ymax != y) .down else if (e.ymax == y and e.ymin != y) .up else .none;

                if (on_edge != .none) {
                    assert(corner != .none);
                    sum += e.x - prev.? - 1;
                    if (corner != on_edge) in = !in;
                    if (!in) sum += 1;
                    on_edge = .none;
                } else if (corner != .none) {
                    on_edge = corner;
                    if (in) {
                        sum += e.x - prev.? + 1;
                    } else {
                        sum += 1;
                    }
                } else {
                    if (in)
                        sum += e.x - prev.? + 1;
                    in = !in;
                }
                prev = e.x;
            }
            assert(!in and on_edge == .none);
        }
        assert(ans2 == sum);
    }

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

fn floodfill(map: *Map, p: Vec2) void {
    if (map.at(p) == '#') return;
    map.set(p, '#');
    for (tools.Vec.cardinal4_dirs) |d| {
        if (map.get(p + d)) |t| {
            _ = t;

            floodfill(map, p + d);
        }
    }
}

test {
    const res1 = try run(
        \\R 6 (#70c710)
        \\D 5 (#0dc571)
        \\L 2 (#5713f0)
        \\D 2 (#d2c081)
        \\R 2 (#59c680)
        \\D 2 (#411b91)
        \\L 5 (#8ceee2)
        \\U 2 (#caa173)
        \\L 1 (#1b58a2)
        \\U 2 (#caa171)
        \\R 2 (#7807d2)
        \\U 3 (#a77fa3)
        \\L 2 (#015232)
        \\U 2 (#7a21e3)
    , std.testing.allocator);
    defer std.testing.allocator.free(res1[0]);
    defer std.testing.allocator.free(res1[1]);
    try std.testing.expectEqualStrings("62", res1[0]);
    try std.testing.expectEqualStrings("952408144115", res1[1]);
}
