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
        var t = b;
        b = a % b;
        a = t;
    }
    return a;
}
fn abs(a: i32) u32 {
    return @intCast(u32, std.math.absInt(a) catch unreachable);
}

fn normalize(d: Vec2) Vec2 {
    const div = pgcd(abs(d[0]), abs(d[1]));
    return @divExact(d, @intCast(Vec2, @splat(2, div)));
}

fn includes(list: []Vec2, e: Vec2) bool {
    for (list) |it| {
        if (@reduce(.And, e == it)) return true;
    } else return false;
}

fn angleLessThan(_: void, a: Vec2, b: Vec2) bool {
    const angle_a = std.math.atan2(f32, @intToFloat(f32, a[0]), @intToFloat(f32, a[1]));
    const angle_b = std.math.atan2(f32, @intToFloat(f32, b[0]), @intToFloat(f32, b[1]));
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
        for (map.tiles) |t, i| {
            if (t != '#') continue;
            const x0 = @intCast(i32, i % map.stride);
            const y0 = @intCast(i32, i / map.stride);
            try list.append(Vec2{ x0, y0 });
        }
        trace("nb astéroïdes: {}\n", .{list.items.len});
        break :blk list.items;
    };

    // part1
    var best_i: usize = undefined;
    var best_dirs: []Vec2 = undefined;
    var best = ans: {
        var best_visibility: usize = 0;
        for (asteroids) |a, i| {
            var dirs = std.ArrayList(Vec2).init(gpa);
            defer dirs.deinit();
            for (asteroids) |o, j| {
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
        std.sort.sort(Vec2, best_dirs, {}, angleLessThan);

        // carte des astéroïdes pas encore détruits:
        const alive = try allocator.alloc(u1, map.width * map.height);
        defer allocator.free(alive);
        {
            std.mem.set(u1, alive, 0);
            for (asteroids) |a| {
                const x = @intCast(usize, a[0]);
                const y = @intCast(usize, a[1]);
                alive[map.width * y + x] = 1;
            }
        }

        const orig = asteroids[best_i];
        const bound = Vec2{ @intCast(i32, map.width), @intCast(i32, map.height) };

        var destroy_count: u32 = 0;
        while (true) {
            for (best_dirs) |d| {
                var p = orig + d;
                next_dir: while (@reduce(.And, p >= Vec2{ 0, 0 }) and @reduce(.And, p < bound)) : (p += d) {
                    const x = @intCast(usize, p[0]);
                    const y = @intCast(usize, p[1]);
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
