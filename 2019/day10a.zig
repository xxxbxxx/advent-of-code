const std = @import("std");
const tools = @import("tools");

const with_trace = false;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

// horrible -> O(n3) + sloppy floats..

const map_width = 36;
const eps = 0.001;
const Map = [map_width * map_width]bool;
const Vec2 = struct {
    x: f32,
    y: f32,
};
fn length(d: Vec2) f32 {
    return @sqrt(d.x * d.x + d.y * d.y);
}
fn dist(a: Vec2, b: Vec2) f32 {
    return length(Vec2{ .x = a.x - b.x, .y = a.y - b.y });
}

fn is_visible(map: Map, eye: Vec2, target: Vec2) bool {
    const d = Vec2{ .x = target.x - eye.x, .y = target.y - eye.y };
    const l = length(d);
    if (l < eps)
        return false;

    const v = Vec2{ .x = d.x / l, .y = d.y / l };

    for (map, 0..) |has_asteroid, i| {
        if (!has_asteroid) continue;
        const x = i % map_width;
        const y = i / map_width;
        const p = Vec2{ .x = @floatFromInt(x) - eye.x, .y = @floatFromInt(y) - eye.y };
        const s = v.x * p.x + v.y * p.y;
        if (s < eps or s > l - eps)
            continue;
        const proj = Vec2{ .x = s * v.x, .y = s * v.y };
        if (dist(p, proj) < eps)
            return false;
    }
    return true;
}

fn mod2pi(a0: f32) f32 {
    var a = a0;
    while (a < 0) {
        a += std.math.pi * 2.0;
    }
    while (a > std.math.pi * 2.0) {
        a -= std.math.pi * 2.0;
    }
    return a;
}
fn angle(v: Vec2) f32 {
    return mod2pi(-std.math.atan2(f32, v.x, v.y));
}
fn next_to_destroy(map: Map, eye: Vec2, prev_target: Vec2) ?struct {
    x: u32,
    y: u32,
} {
    const d = Vec2{ .x = prev_target.x - eye.x, .y = prev_target.y - eye.y };
    const angleref = angle(d);
    var bestangle: f32 = 7;
    var bestx: u32 = undefined;
    var besty: u32 = undefined;
    for (map, 0..) |has_asteroid, i| {
        if (!has_asteroid) continue;
        const x = i % map_width;
        const y = i / map_width;
        if (!is_visible(map, eye, Vec2{ .x = @floatFromInt(x), .y = @floatFromInt(y) }))
            continue;
        const p = Vec2{ .x = @floatFromInt(x) - eye.x, .y = @floatFromInt(y) - eye.y };
        const a = angle(p);
        if (mod2pi(a - angleref) > 0 and mod2pi(a - angleref) < bestangle) {
            bestangle = mod2pi(a - angleref);
            bestx = @intCast(x);
            besty = @intCast(y);
        }
    }
    return if (bestangle < 6.5) .{ .x = bestx, .y = besty } else null;
}

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var map: Map = undefined;
    {
        var i: u32 = 0;
        for (input) |c| {
            if (c != '.' and c != '#')
                continue;
            map[i] = (c == '#');
            i += 1;
        }
    }

    var best: u32 = 0;
    var besteye: Vec2 = undefined;
    for (map, 0..) |has_asteroid0, i| {
        if (!has_asteroid0) continue;
        const x0 = i % map_width;
        const y0 = i / map_width;
        const eye = Vec2{ .x = @floatFromInt(x0), .y = @floatFromInt(y0) };
        var counter: u32 = 0;
        for (map, 0..) |has_asteroid1, j| {
            if (!has_asteroid1) continue;
            const x1 = j % map_width;
            const y1 = j / map_width;
            if (x1 == x0 and y1 == y0)
                continue;
            const tgt = Vec2{ .x = @floatFromInt(x1), .y = @floatFromInt(y1) };
            if (is_visible(map, eye, tgt)) {
                //                trace("can see  {},{}\n", .{ x1, y1});
                counter += 1;
            }
        }
        if (counter > best) {
            best = counter;
            besteye = eye;
            trace("new best {} @ {},{}\n", .{ counter, x0, y0 });
        }
    }

    const asteroid200 = ans: {
        var ord: u32 = 1;
        var prev = Vec2{ .x = besteye.x - eps, .y = -10 };
        while (next_to_destroy(map, besteye, prev)) |target| {
            trace("shootn°{} {}\n", .{ ord, target });
            assert(map[target.x + map_width * target.y]);
            map[target.x + map_width * target.y] = false;
            prev = Vec2{ .x = @floatFromInt(target.x), .y = @floatFromInt(target.y) };
            if (ord == 200)
                break :ans (target.x * 100 + target.y);
            ord += 1;
        } else {
            unreachable;
        }
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{best}),
        try std.fmt.allocPrint(allocator, "{}", .{asteroid200}),
    };
}

pub const main = tools.defaultMain("2019/day10.txt", run);
