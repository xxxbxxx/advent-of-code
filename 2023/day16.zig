const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub const main = tools.defaultMain("2023/day16.txt", run);
const Map = tools.Map(u8, 150, 150, false);
const Vec2 = tools.Vec2;

const up = 0;
const left = 1;
const right = 2;
const down = 3;
const Ray = struct { p: Vec2, dir: u3 };

fn rayTrace(lightmap: *Map, map: *const Map, ray0: Ray, allocator: std.mem.Allocator) !void {
    const Rays = struct {
        queue: std.ArrayList(Ray),
        bbox: tools.BBox,
        fn propagate(self: *@This(), p0: Vec2, dir: u3) void {
            const p1 = p0 + tools.Vec.cardinal4_dirs[dir];
            if (self.bbox.includes(p1)) self.queue.appendAssumeCapacity(.{ .p = p1, .dir = dir });
        }
    };
    var rays: Rays = .{ .queue = std.ArrayList(Ray).init(allocator), .bbox = map.bbox };
    defer rays.queue.deinit();

    try rays.queue.append(ray0);

    while (rays.queue.popOrNull()) |ray| {
        {
            const dir_mask = @as(u8, 1) << ray.dir;
            const l = lightmap.get(ray.p) orelse 0;
            if (l & dir_mask != 0) continue;
            lightmap.set(ray.p, l | dir_mask);
        }

        try rays.queue.ensureUnusedCapacity(2);
        switch (map.at(ray.p)) {
            '.' => rays.propagate(ray.p, ray.dir),
            '\\' => {
                const dir: u3 = switch (ray.dir) {
                    up => left,
                    down => right,
                    right => down,
                    left => up,
                    else => unreachable,
                };
                rays.propagate(ray.p, dir);
            },
            '/' => {
                const dir: u3 = switch (ray.dir) {
                    up => right,
                    down => left,
                    left => down,
                    right => up,
                    else => unreachable,
                };
                rays.propagate(ray.p, dir);
            },
            '-' => switch (ray.dir) {
                left, right => rays.propagate(ray.p, ray.dir),
                up, down => {
                    rays.propagate(ray.p, left);
                    rays.propagate(ray.p, right);
                },
                else => unreachable,
            },
            '|' => switch (ray.dir) {
                up, down => rays.propagate(ray.p, ray.dir),
                left, right => {
                    rays.propagate(ray.p, up);
                    rays.propagate(ray.p, down);
                },
                else => unreachable,
            },
            else => unreachable,
        }
    }
}

pub fn run(text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena_alloc = std.heap.ArenaAllocator.init(allocator);
    defer arena_alloc.deinit();
    const arena = arena_alloc.allocator();
    _ = arena;

    var map: Map = .{ .default_tile = '.' };
    map.initFromText(text);

    const ans1 = ans: {
        var lightmap: Map = .{ .default_tile = 0 };
        try rayTrace(&lightmap, &map, .{ .p = .{ 0, 0 }, .dir = right }, allocator);

        var sum: u32 = 0;
        var it = lightmap.iter(null);
        while (it.next()) |l| sum += @intFromBool(l != 0);
        break :ans sum;
    };

    const ans2 = ans: {
        var max: u32 = 0;

        for (&[_]struct { u3, u8, Vec2 }{ .{ right, 1, map.bbox.min }, .{ 1, left, map.bbox.max }, .{ down, 0, map.bbox.min }, .{ up, 0, map.bbox.max } }) |params| {
            const init_dir, const axis, const start = params;
            var p = map.bbox.min;
            p[1 - axis] = start[1 - axis];
            while (p[axis] <= map.bbox.max[axis]) : (p[axis] += 1) {
                var lightmap: Map = .{ .default_tile = 0 };
                try rayTrace(&lightmap, &map, .{ .p = p, .dir = init_dir }, allocator);

                var sum: u32 = 0;
                var it = lightmap.iter(null);
                while (it.next()) |l| sum += @intFromBool(l != 0);
                max = @max(max, sum);
            }
        }

        break :ans max;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

test {
    const res1 = try run(
        \\.|...\....
        \\|.-.\.....
        \\.....|-...
        \\........|.
        \\..........
        \\.........\
        \\..../.\\..
        \\.-.-/..|..
        \\.|....-|.\
        \\..//.|....
    , std.testing.allocator);
    defer std.testing.allocator.free(res1[0]);
    defer std.testing.allocator.free(res1[1]);
    try std.testing.expectEqualStrings("46", res1[0]);
    try std.testing.expectEqualStrings("51", res1[1]);
}
