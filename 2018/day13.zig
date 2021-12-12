const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

const Vec2 = tools.Vec2;
const Map = tools.Map(u8, 250, 250, false);
const DEAD = 100;

const Kart = struct {
    p: Vec2,
    d: Vec2,
    seq: u32 = 0,

    fn lessThan(_: void, lhs: Kart, rhs: Kart) bool {
        return Vec2.lessThan({}, lhs.p, rhs.p);
    }
};

pub fn run(input_text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    const params: struct { tracks: *const Map, init_karts: []const Kart } = blk: {
        const tracks = try allocator.create(Map);
        errdefer allocator.destroy(tracks);
        tracks.bbox = tools.BBox.empty;
        tracks.default_tile = 0;
        const karts = try allocator.alloc(Kart, 100);
        errdefer allocator.free(karts);

        var nb_kart: usize = 0;
        var y: i32 = 0;
        var it = std.mem.tokenize(u8, input_text, "\n\r");
        while (it.next()) |line| {
            for (line) |sq, i| {
                const p = Vec2{ .x = @intCast(i32, i), .y = y };
                switch (sq) {
                    '^' => {
                        tracks.set(p, '|');
                        karts[nb_kart] = Kart{ .p = p, .d = Vec2{ .x = 0, .y = -1 } };
                        nb_kart += 1;
                    },
                    'v' => {
                        tracks.set(p, '|');
                        karts[nb_kart] = Kart{ .p = p, .d = Vec2{ .x = 0, .y = 1 } };
                        nb_kart += 1;
                    },
                    '<' => {
                        tracks.set(p, '-');
                        karts[nb_kart] = Kart{ .p = p, .d = Vec2{ .x = -1, .y = 0 } };
                        nb_kart += 1;
                    },
                    '>' => {
                        tracks.set(p, '-');
                        karts[nb_kart] = Kart{ .p = p, .d = Vec2{ .x = 1, .y = 0 } };
                        nb_kart += 1;
                    },
                    '|' => tracks.set(p, '|'),
                    '-' => tracks.set(p, '-'),
                    '+' => tracks.set(p, '+'),
                    '\\' => tracks.set(p, '\\'),
                    '/' => tracks.set(p, '/'),
                    ' ' => tracks.set(p, ' '),
                    else => {
                        std.debug.print("unknown char '{c}'\n", .{sq});
                        return error.UnsupportedInput;
                    },
                }
            }
            y += 1;
        }

        break :blk .{ .tracks = tracks, .init_karts = karts[0..nb_kart] };
    };
    defer allocator.destroy(params.tracks);
    defer allocator.free(params.init_karts);

    //var buf: [5000]u8 = undefined;
    //std.debug.print("{}\n", .{params.tracks.printToBuf(null, null, null, &buf)});

    // part1 (buggué car fait tout les karts en un coup et donc ils pourraient se croiser sans crasher "effet tunnel"  -> mais ça passe)
    const ans1 = ans: {
        const turns = [_]Vec2.Rot{ .ccw, .none, .cw };
        const karts = try allocator.dupe(Kart, params.init_karts);
        defer allocator.free(karts);
        while (true) {
            std.sort.sort(Kart, karts, {}, Kart.lessThan);
            for (karts[1..]) |it, i| {
                const prev = karts[i + 1 - 1];
                if (it.p.x == prev.p.x and it.p.y == prev.p.y) break :ans it.p;
            }

            for (karts) |*it| {
                it.p = it.p.add(it.d);
                const sq = params.tracks.at(it.p);
                switch (sq) {
                    '|' => assert(it.d.x == 0),
                    '-' => assert(it.d.y == 0),
                    '\\' => it.d = Vec2.rotate(it.d, if (it.d.x == 0) .ccw else .cw),
                    '/' => it.d = Vec2.rotate(it.d, if (it.d.x == 0) .cw else .ccw),
                    '+' => {
                        it.d = Vec2.rotate(it.d, turns[it.seq]);
                        it.seq = (it.seq + 1) % @intCast(u32, turns.len);
                    },
                    else => unreachable,
                }
                // std.debug.print("{} {}  on '{c}'\n", .{ it.p, it.d, sq });
            }
        }
    };

    // part2 (debuggué , ça passait plus...)
    const ans2 = ans: {
        const turns = [_]Vec2.Rot{ .ccw, .none, .cw };
        const karts = try allocator.dupe(Kart, params.init_karts);
        defer allocator.free(karts);
        while (true) {
            std.sort.sort(Kart, karts, {}, Kart.lessThan);

            for (karts) |*it| {
                if (it.seq == DEAD) continue;

                it.p = it.p.add(it.d);
                const sq = params.tracks.at(it.p);
                switch (sq) {
                    '|' => assert(it.d.x == 0),
                    '-' => assert(it.d.y == 0),
                    '\\' => it.d = Vec2.rotate(it.d, if (it.d.x == 0) .ccw else .cw),
                    '/' => it.d = Vec2.rotate(it.d, if (it.d.x == 0) .cw else .ccw),
                    '+' => {
                        it.d = Vec2.rotate(it.d, turns[it.seq]);
                        it.seq = (it.seq + 1) % @intCast(u32, turns.len);
                    },
                    else => unreachable,
                }
                //std.debug.print("{} {}  on '{c}'\n", .{ it.p, it.d, sq });

                for (karts) |*other| {
                    if (other == it) continue;
                    if (other.seq == DEAD) continue;

                    if (it.p.x == other.p.x and it.p.y == other.p.y) {
                        it.seq = DEAD;
                        other.seq = DEAD;
                        // std.debug.print("krash@{}\n", .{it.p});
                        break;
                    }
                }
            }

            var nb_karts: usize = 0;
            var live: ?Kart = null;
            for (karts) |it| {
                if (it.seq != DEAD) {
                    live = it;
                    nb_karts += 1;
                }
            }
            if (nb_karts == 1) break :ans live.?.p;
        }
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2018/input_day13.txt", run);
