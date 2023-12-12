const std = @import("std");
const tools = @import("tools");

const with_trace = false;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

const Map = struct {
    tiles: []const u8,
    width: usize,
    height: usize,
    stride: usize,
};

const Vec2 = @Vector(2, i32);

fn pgcd(_a: u32, _b: u32) u32 {
    var a = _a;
    var b = _b;
    while (b != 0) {
        const t = b;
        b = a % b;
        a = t;
    }
    return a;
}

fn normalize(d: Vec2) Vec2 {
    const div = pgcd(@abs(d[0]), @abs(d[1]));
    return @divExact(d, @as(Vec2, @splat(@intCast(div))));
}

fn includes(list: []Vec2, e: Vec2) bool {
    for (list) |it| {
        if (@reduce(.And, e == it)) return true;
    } else return false;
}

fn angleLessThan(_: void, a: Vec2, b: Vec2) bool {
    const angle_a = std.math.atan2(f32, @as(f32, @floatFromInt(a[0])), @as(f32, @floatFromInt(a[1])));
    const angle_b = std.math.atan2(f32, @as(f32, @floatFromInt(b[0])), @as(f32, @floatFromInt(b[1])));
    return angle_a > angle_b;
}

pub fn run(input: []const u8, gpa: std.mem.Allocator) ![2][]const u8 {
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();
    const allocator = arena.allocator();

    // parse map:
    const map = blk: {
        const line_len = std.mem.indexOfScalar(u8, input, '\n') orelse return error.UnsupportedInput;
        break :blk Map{
            .tiles = input,
            .width = line_len,
            .stride = 1 + line_len,
            .height = (input.len + 1) / (line_len + 1),
        };
    };

    // liste des astéroïdes:
    const asteroids = blk: {
        var list = std.ArrayList(Vec2).init(allocator);
        for (map.tiles, 0..) |t, i| {
            if (t != '#') continue;
            const x0: i32 = @intCast(i % map.stride);
            const y0: i32 = @intCast(i / map.stride);
            try list.append(Vec2{ x0, y0 });
        }
        trace("nb astéroïdes: {}\n", .{list.items.len});
        break :blk list.items;
    };

    // part1
    var best_i: usize = undefined;
    var best_dirs: []Vec2 = undefined;
    const best = ans: {
        var best_visibility: usize = 0;
        for (asteroids, 0..) |a, i| {
            var dirs = std.ArrayList(Vec2).init(gpa);
            defer dirs.deinit();
            for (asteroids, 0..) |o, j| {
                if (i == j) continue;
                const d = normalize(o - a);
                if (!includes(dirs.items, d)) {
                    try dirs.append(d);
                }
            }
            if (dirs.items.len > best_visibility) {
                best_visibility = dirs.items.len;
                best_i = i;
                best_dirs = try allocator.dupe(Vec2, dirs.items);
            }
        }
        break :ans best_visibility;
    };

    const asteroid200 = ans: {
        // sort by angle:
        std.mem.sort(Vec2, best_dirs, {}, angleLessThan);

        // carte des astéroïdes pas encore détruits:
        const alive = try allocator.alloc(u1, map.width * map.height);
        defer allocator.free(alive);
        {
            @memset(alive, 0);
            for (asteroids) |a| {
                const x: usize = @intCast(a[0]);
                const y: usize = @intCast(a[1]);
                alive[map.width * y + x] = 1;
            }
        }

        const orig = asteroids[best_i];
        const bound = Vec2{ @intCast(map.width), @intCast(map.height) };

        var destroy_count: u32 = 0;
        while (true) {
            for (best_dirs) |d| {
                var p = orig + d;
                next_dir: while (@reduce(.And, p >= Vec2{ 0, 0 }) and @reduce(.And, p < bound)) : (p += d) {
                    const x: usize = @intCast(p[0]);
                    const y: usize = @intCast(p[1]);
                    if (alive[map.width * y + x] != 0) {
                        alive[map.width * y + x] = 0;

                        destroy_count += 1;
                        if (destroy_count == 200) break :ans x * 100 + y;

                        break :next_dir;
                    }
                }
            }
        }
        unreachable;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(gpa, "{}", .{best}),
        try std.fmt.allocPrint(gpa, "{}", .{asteroid200}),
    };
}

pub const main = tools.defaultMain("2019/day10.txt", run);
