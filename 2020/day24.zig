const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

const Vec2 = tools.Vec2;
const Map = tools.Map(u1, 400, 400, true);

pub fn run(input_text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var map = Map{ .default_tile = 0 };
    {
        var it = std.mem.tokenize(u8, input_text, "\n\r");
        while (it.next()) |line| {
            var i: usize = 0;
            var p = Vec2{ .x = 0, .y = 0 };
            while (i < line.len) {
                switch (line[i]) {
                    'e' => {
                        p.x += 1;
                        i += 1;
                    },
                    'w' => {
                        p.x -= 1;
                        i += 1;
                    },
                    's' => switch (line[i + 1]) {
                        'e' => {
                            p.x += @mod(p.y, 2);
                            p.y += 1;
                            i += 2;
                        },
                        'w' => {
                            p.x -= (1 - @mod(p.y, 2));
                            p.y += 1;
                            i += 2;
                        },
                        else => unreachable,
                    },
                    'n' => switch (line[i + 1]) {
                        'e' => {
                            p.x += @mod(p.y, 2);
                            p.y -= 1;
                            i += 2;
                        },
                        'w' => {
                            p.x -= (1 - @mod(p.y, 2));
                            p.y -= 1;
                            i += 2;
                        },
                        else => unreachable,
                    },
                    else => unreachable,
                }
            }
            const cur = map.get(p) orelse 0;
            map.set(p, 1 - cur);
        }
    }

    const ans1 = ans: {
        var nb: u32 = 0;
        var it = map.iter(null);
        while (it.next()) |t| nb += t;
        break :ans nb;
    };

    const ans2 = ans: {
        var round: u32 = 0;
        while (round < 100) : (round += 1) {
            var map2 = Map{ .default_tile = 0 };
            map.growBBox(Vec2{ .x = map.bbox.min.x - 1, .y = map.bbox.min.y - 1 });
            map.growBBox(Vec2{ .x = map.bbox.max.x + 1, .y = map.bbox.max.y + 1 });
            var it = map.iter(null);
            while (it.nextEx()) |t| {
                const neib = blk: {
                    const w = t.left orelse 0;
                    const e = t.right orelse 0;
                    var sw: u1 = 0;
                    var se: u1 = 0;
                    var nw: u1 = 0;
                    var ne: u1 = 0;
                    if (@mod(t.p.y, 2) == 0) {
                        nw = t.up_left orelse 0;
                        ne = t.up orelse 0;
                        sw = t.down_left orelse 0;
                        se = t.down orelse 0;
                    } else {
                        nw = t.up orelse 0;
                        ne = t.up_right orelse 0;
                        sw = t.down orelse 0;
                        se = t.down_right orelse 0;
                    }

                    var nb: u8 = 0;
                    nb += w;
                    nb += e;
                    nb += nw;
                    nb += ne;
                    nb += sw;
                    nb += se;
                    break :blk nb;
                };

                if (t.t.* == 1) {
                    if (neib == 0 or neib > 2) {
                        map2.set(t.p, 0);
                    } else {
                        map2.set(t.p, 1);
                    }
                } else {
                    if (neib == 2) {
                        map2.set(t.p, 1);
                    } else {
                        map2.set(t.p, 0);
                    }
                }
            }
            map = map2;
        }

        var nb: u32 = 0;
        var it = map.iter(null);
        while (it.next()) |t| nb += t;
        break :ans nb;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2020/input_day24.txt", run);
