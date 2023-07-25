const std = @import("std");
const tools = @import("tools");

const with_trace = false;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}
const assert = std.debug.assert;

pub const main = tools.defaultMain("2021/day09.txt", run);

const Vec2 = tools.Vec2;
const Map = tools.Map(u8, 128, 128, false);

fn floodFill(map: *const Map, pos: Vec2) u32 {
    const Bitmap = tools.Map(u1, 128, 128, false);
    const Local = struct {
        fn recurse(m: *const Map, filled: *Bitmap, p: Vec2) u32 {
            if ((m.get(p) orelse 9) >= 9) return 0;
            if ((filled.get(p) orelse 0) != 0) return 0;

            filled.set(p, 1);
            var count: u32 = 1;
            for (tools.Vec.cardinal4_dirs) |d| count += @This().recurse(m, filled, p + d);
            return count;
        }
    };

    var filled = Bitmap{ .default_tile = 0 };
    return Local.recurse(map, &filled, pos);
}

pub fn run(input: []const u8, gpa: std.mem.Allocator) tools.RunError![2][]const u8 {
    var map = Map{ .default_tile = 0 };

    {
        var it = std.mem.tokenize(u8, input, "\n");
        var y: u32 = 0;
        while (it.next()) |line| : (y += 1) {
            for (line, 0..) |c, x| {
                switch (c) {
                    '0'...'9' => map.set(Vec2{ @as(i32, @intCast(x)), @as(i32, @intCast(y)) }, c - '0'),
                    else => {},
                }
            }
        }
    }

    var lowpoints_storage: [500]Vec2 = undefined;
    var lowpoints: []Vec2 = lowpoints_storage[0..0];
    const ans1 = ans: {
        var score: u32 = 0;
        var it = map.iter(null);
        while (it.nextEx()) |t| {
            var count: i32 = 0;
            for (t.neib4) |n| {
                if (n) |t1| {
                    count += @intFromBool(t.t.* < t1);
                } else {
                    count += 1;
                }
            }
            if (count == 4) {
                score += t.t.* + 1;

                lowpoints_storage[lowpoints.len] = t.p;
                lowpoints = lowpoints_storage[0 .. lowpoints.len + 1];
            }
        }
        break :ans score;
    };

    const ans2 = ans: {
        var largest_basins = [3]u32{ 0, 0, 0 };
        for (lowpoints) |lp| {
            const size = floodFill(&map, lp);
            trace("bassin @{} = {}\n", .{ lp, size });
            if (size > largest_basins[0]) {
                largest_basins[2] = largest_basins[1];
                largest_basins[1] = largest_basins[0];
                largest_basins[0] = size;
            } else if (size > largest_basins[1]) {
                largest_basins[2] = largest_basins[1];
                largest_basins[1] = size;
            } else if (size > largest_basins[2]) {
                largest_basins[2] = size;
            }
        }
        break :ans largest_basins[0] * largest_basins[1] * largest_basins[2];
    };

    return [_][]const u8{
        try std.fmt.allocPrint(gpa, "{}", .{ans1}),
        try std.fmt.allocPrint(gpa, "{}", .{ans2}),
    };
}

test {
    const res = try run(
        \\2199943210
        \\3987894921
        \\9856789892
        \\8767896789
        \\9899965678
    , std.testing.allocator);
    defer std.testing.allocator.free(res[0]);
    defer std.testing.allocator.free(res[1]);
    try std.testing.expectEqualStrings("15", res[0]);
    try std.testing.expectEqualStrings("1134", res[1]);
}
