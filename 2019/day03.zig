const std = @import("std");
const tools = @import("tools");

const with_trace = false;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

const Vec2 = struct {
    x: i32,
    y: i32,
};
const Segment = struct {
    o: Vec2,
    d: Vec2,
    l: i32,
    L: i32,
};

fn parse_segments(insns: []const u8, pool: []Segment) []Segment {
    var segments: u32 = 0;
    var p = Vec2{ .x = 0, .y = 0 };
    var L: i32 = 0;

    var i: usize = 0;
    while (i < insns.len) {
        var dir = insns[i];
        i += 1;
        if (dir == ',') {
            dir = insns[i];
            i += 1;
        }
        var len: i32 = 0;
        while (i < insns.len and insns[i] != ',') : (i += 1) {
            len = len * 10 + @as(i32, @intCast(insns[i] - '0'));
        }

        var d = Vec2{ .x = 0, .y = 0 };
        switch (dir) {
            'L' => d.x = -1,
            'R' => d.x = 1,
            'U' => d.y = -1,
            'D' => d.y = 1,
            else => unreachable,
        }

        pool[segments] = Segment{
            .o = p,
            .d = d,
            .l = len,
            .L = L,
        };
        segments += 1;

        L += len;
        p.x += d.x * len;
        p.y += d.y * len;
    }

    return pool[0..segments];
}

fn distance(p: Vec2) u32 {
    return (if (p.x < 0) @as(u32, @intCast(-p.x)) else @as(u32, @intCast(p.x))) + (if (p.y < 0) @as(u32, @intCast(-p.y)) else @as(u32, @intCast(p.y)));
}
const Intersec = struct {
    dist: u32,
    score: i32,
};

fn intersect(s1: *const Segment, s2: *const Segment) ?Intersec {
    var isec: ?Intersec = null;
    var l: i32 = 0;
    while (l < s2.l) : (l += 1) {
        const delta = Vec2{
            .x = s2.o.x + s2.d.x * l - s1.o.x,
            .y = s2.o.y + s2.d.y * l - s1.o.y,
        };
        const d = delta.x * s1.d.x + delta.y * s1.d.y;
        if (d >= 0 and d < s1.l and d * s1.d.x == delta.x and d * s1.d.y == delta.y) {
            const p = Vec2{ .x = d * s1.d.x + s1.o.x, .y = d * s1.d.y + s1.o.y };

            trace("isec ({},{})  S1=[({},{})+{} * ({},{}), {}]  S2=[({},{})+{} * ({},{}), {}]\n", .{
                p.x,    p.y,
                s1.o.x, s1.o.y,
                s1.l,   s1.d.x,
                s1.d.y, s1.L,
                s2.o.x, s2.o.y,
                s2.l,   s2.d.x,
                s2.d.y, s2.L,
            });

            if (p.x == 0 and p.y == 0)
                continue;

            const sc = s1.L + s2.L + d + l;
            const dist = distance(p);
            if (isec == null) {
                isec = Intersec{ .dist = dist, .score = sc };
            } else {
                if (sc < isec.?.score)
                    isec.?.score = sc;
                if (dist < isec.?.dist)
                    isec.?.dist = dist;
            }
        }
    }
    return isec;
}

fn intersects(segs1: []const Segment, segs2: []const Segment) ?Intersec {
    var isec: ?Intersec = null;
    for (segs2) |*sg2| {
        for (segs1) |*sg1| {
            if (intersect(sg1, sg2)) |it| {
                if (isec == null) {
                    isec = it;
                } else {
                    if (it.score < isec.?.score)
                        isec.?.score = it.score;
                    if (it.dist < isec.?.dist)
                        isec.?.dist = it.dist;
                }
            }
        }
    }
    return isec;
}

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var pool: [1000]Segment = undefined;

    var it = std.mem.split(u8, input, "\n");
    const l1 = std.mem.trim(u8, it.next() orelse unreachable, &std.ascii.whitespace);
    const l2 = std.mem.trim(u8, it.next() orelse unreachable, &std.ascii.whitespace);
    const segs1 = parse_segments(l1, pool[0..]);
    const segs2 = parse_segments(l2, pool[segs1.len..]);

    const isec = intersects(segs1, segs2).?;

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{isec.dist}),
        try std.fmt.allocPrint(allocator, "{}", .{isec.score}),
    };
}

pub const main = tools.defaultMain("2019/day03.txt", run);
