const std = @import("std");
const tools = @import("tools");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

const Map = tools.Map(200, 100, false);
const Vec2 = tools.Vec2;

fn compute_dists(start: u8, map: *const Map, dists: []u32) void {
    var dmap_max: [200 * 100]u16 = [1]u16{9999} ** (200 * 100);
    assert(map.bbox.min.x == 0 and map.bbox.min.y == 0);
    const w = @intCast(u32, map.bbox.max.x) + 1;
    const h = @intCast(u32, map.bbox.max.y) + 1;
    const stride = w;
    const dmap = dmap_max[0 .. w + stride * h];

    var done = false;
    while (!done) {
        done = true;
        var p = Vec2{ .x = 0, .y = 0 };
        while (p.y < h) : (p.y += 1) {
            p.x = 0;
            while (p.x < w) : (p.x += 1) {
                const o = @intCast(u32, p.x) + stride * @intCast(u32, p.y);
                const m = map.at(p);
                if (m == '#')
                    continue;

                var d = dmap[o];
                if (m == start) {
                    d = 0;
                } else {
                    for ([_]Vec2{ .{ .x = 0, .y = 1 }, .{ .x = 0, .y = -1 }, .{ .x = 1, .y = 0 }, .{ .x = -1, .y = 0 } }) |dir| {
                        const p1 = Vec2{ .x = p.x + dir.x, .y = p.y + dir.y };
                        if (map.get(p1)) |m1| {
                            if (m1 == '#')
                                continue;
                            const o1 = @intCast(u32, p1.x) + stride * @intCast(u32, p1.y);
                            if (d > dmap[o1] + 1) {
                                d = dmap[o1] + 1;
                            }
                        }
                    }
                }
                if (d < dmap[o]) {
                    dmap[o] = d;
                    done = false;
                }

                if (m >= '0' and m <= '9') {
                    dists[m - '0'] = d;
                }
            }
        }
    }
}

fn fact(n: u32) u32 {
    var f: u32 = 1;
    var i: u32 = 0;
    while (i < n) : (i += 1) f *= (i + 1);
    return f;
}
pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day24.txt", limit);
    defer allocator.free(text);

    var map = Map{ .default_tile = 0 };
    var nb_chkpts: u32 = 0;
    {
        var p = Vec2{ .x = 0, .y = 0 };
        for (text) |c| {
            if (c == '\n') {
                p.y += 1;
                p.x = 0;
                continue;
            }
            map.set(p, c);
            p.x += 1;
            if (c >= '0' and c <= '9')
                nb_chkpts = if (nb_chkpts < 1 + c - '0') 1 + c - '0' else nb_chkpts;
        }
        trace("nb_chkpts={}, map_size={}\n", .{ nb_chkpts, map.bbox.max });

        //var buf: [100 * 200]u8 = undefined;
        //trace("{}\n", .{map.printToBuf(p, null, &buf)});
    }

    var distances: [10 * 10]u32 = undefined;
    {
        var i: u8 = 0;
        while (i < nb_chkpts) : (i += 1) {
            compute_dists('0' + i, &map, distances[i * nb_chkpts .. i * nb_chkpts + nb_chkpts]);
            for (distances[i * nb_chkpts .. i * nb_chkpts + nb_chkpts]) |d| {
                trace("{:>2} ", .{d});
            }
            trace("\n", .{});
        }
    }

    // part 1:
    {
        var best_dist: u32 = 99999;
        const permuts = fact(nb_chkpts - 1);
        var p: u32 = 0;
        while (p < permuts) : (p += 1) {
            var allcheckpoints = [_]u32{ 1, 2, 3, 4, 5, 6, 7, 8, 9 };
            const order = allcheckpoints[0 .. nb_chkpts - 1];
            {
                var mod: u32 = nb_chkpts - 1;
                var k = p;
                for (order) |*c, i| {
                    const t = c.*;
                    c.* = order[i + k % mod];
                    order[i + k % mod] = t;
                    k /= mod;
                    mod -= 1;
                }
            }

            var dist: u32 = 0;
            var prev: u32 = 0;
            //trace("0", .{});
            for (order) |c| {
                dist += distances[c * nb_chkpts + prev];
                prev = c;
                //    trace("->{}", .{c});
            }
            //trace(": {}\n", .{dist});

            if (dist < best_dist)
                best_dist = dist;
        }
        try stdout.print("best dist = {}\n", .{best_dist});
    }

    // part 2:
    {
        var best_dist: u32 = 99999;
        const permuts = fact(nb_chkpts - 1);
        var p: u32 = 0;
        while (p < permuts) : (p += 1) {
            var allcheckpoints = [_]u32{ 1, 2, 3, 4, 5, 6, 7, 8, 9 };
            const order = allcheckpoints[0 .. nb_chkpts - 1];
            {
                var mod: u32 = nb_chkpts - 1;
                var k = p;
                for (order) |*c, i| {
                    const t = c.*;
                    c.* = order[i + k % mod];
                    order[i + k % mod] = t;
                    k /= mod;
                    mod -= 1;
                }
            }

            var dist: u32 = 0;
            var prev: u32 = 0;
            //trace("0", .{});
            for (order) |c| {
                dist += distances[c * nb_chkpts + prev];
                prev = c;
                //    trace("->{}", .{c});
            }
            //trace(": {}\n", .{dist});

            dist += distances[0 * nb_chkpts + prev];

            if (dist < best_dist)
                best_dist = dist;
        }
        try stdout.print("best dist avec retour = {}\n", .{best_dist});
    }
}
