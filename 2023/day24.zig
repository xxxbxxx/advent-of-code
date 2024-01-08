const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub const main = tools.defaultMain("2023/day24.txt", run);

const T = i128; //f64;
const T2 = i256; //f64;
const Vec3 = @Vector(3, T);
const BBox = struct { min: Vec3, max: Vec3 };
const fixed_point: T = 2;

const Hailstone = struct {
    p: Vec3,
    v: Vec3,
};

fn cross(a: Vec3, b: Vec3) Vec3 {
    return Vec3{
        a[1] * b[2] - b[1] * a[2],
        a[2] * b[0] - b[2] * a[0],
        a[0] * b[1] - b[0] * a[1],
    };
}
fn dot(a: Vec3, b: Vec3) T {
    return @reduce(.Add, a * b);
}

fn reduceMagnitude(v: Vec3) Vec3 {
    assert(v[2] == 0);
    const pgcd = tools.pgcd(v[0], v[1]);
    return v / @as(Vec3, @splat(pgcd));
}

fn opppositeSign(a: T, b: T) bool {
    return ((a > 0 and b < 0) or (a < 0 and b > 0));
}

pub fn run(text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena_alloc = std.heap.ArenaAllocator.init(allocator);
    defer arena_alloc.deinit();
    const arena = arena_alloc.allocator();

    const stones, const offset = input: {
        var list = std.ArrayList(Hailstone).init(arena);
        defer list.deinit();

        var it = std.mem.tokenize(u8, text, "\n\r\t");
        while (it.next()) |line| {
            if (tools.match_pattern("{}, {}, {} @ {}, {}, {}", line)) |vals| {
                if (@typeInfo(T) == .Float) {
                    try list.append(.{
                        .p = Vec3{ @floatFromInt(vals[0].imm), @floatFromInt(vals[1].imm), @floatFromInt(vals[2].imm) },
                        .v = Vec3{ @floatFromInt(vals[3].imm), @floatFromInt(vals[4].imm), @floatFromInt(vals[5].imm) },
                    });
                } else {
                    try list.append(.{
                        .p = Vec3{ @intCast(vals[0].imm), @intCast(vals[1].imm), @intCast(vals[2].imm) },
                        .v = Vec3{ @intCast(vals[3].imm), @intCast(vals[4].imm), @intCast(vals[5].imm) },
                    });
                }
            } else unreachable;
        }

        var mid: Vec3 = .{ 0, 0, 0 };
        for (list.items) |s| {
            mid += s.p;
        }
        mid = @divTrunc(mid, @as(Vec3, @splat(@intCast(list.items.len))));
        //std.debug.print("center= {}\n", .{mid});
        for (list.items) |*s| {
            s.p -= mid;
        }

        break :input .{ try list.toOwnedSlice(), mid };
    };

    const ans1 = ans: {
        const is_test_example = stones.len <= 5;
        const p_min: Vec3 = @splat(@as(T, if (is_test_example) 7 else 200000000000000) - offset[0]);
        const p_max: Vec3 = @splat(@as(T, if (is_test_example) 27 else 400000000000000) - offset[1]);
        const fixed = Vec3{ fixed_point, fixed_point, fixed_point };
        var sum: u64 = 0;
        for (stones, 0..) |it0, i| {
            var p0 = it0.p;
            p0[2] = p_min[2];
            var v0 = it0.v;
            v0[2] = 0; //v0 *= @splat(1.0/@sqrt(dot(v0, v0)));
            for (stones[0..i]) |it1| {
                var p1 = it1.p;
                p1[2] = p_min[2];
                var v1 = it1.v;
                v1[2] = 0; //v1 *= @splat(1.0/@sqrt(dot(v1, v1)));

                const n = cross(v0, v1);
                const p = p1 - p0;
                {
                    // toujours vrai en 2D:

                    const norm2 = dot(n, n);
                    if (norm2 == 0) continue;
                    const d = dot(p, n); // / sqrt(norm2);
                    if (d != 0) continue;
                }

                const n0 = reduceMagnitude(cross(n, v1)); //n0 *= @splat(1.0/@sqrt(dot(n0, n0)));
                const n1 = reduceMagnitude(cross(n, v0)); //n1 *= @splat(1.0/@sqrt(dot(n1, n1)));

                //const k0 = dot(n0, p) / dot(n0, v0);
                //const k1 = -dot(n1, p) / dot(n1, v1);
                //const inter0 = p0 + @as(Vec3, @splat(k0)) * v0;
                //const inter1 = p1 + @as(Vec3, @splat(k1)) * v1;
                //std.debug.print("v0 {}, n0={} p={}\n", .{ v0, n0, p });
                if (opppositeSign(dot(n0, p), dot(n0, v0)) or opppositeSign(-dot(n1, p), dot(n1, v1))) continue; // before t=0

                const inter0 = fixed * p0 + (@as(Vec3, @splat(fixed_point * dot(n0, p))) * v0) / @as(Vec3, @splat(dot(n0, v0)));
                const inter1 = fixed * p1 + (@as(Vec3, @splat(fixed_point * -dot(n1, p))) * v1) / @as(Vec3, @splat(dot(n1, v1)));
                //std.debug.print("v0 {}, n0.p={} n0.v0={}\n", .{ v0, dot(n0, p), dot(n0, v0) });
                //std.debug.print("v1 {}, n1.p={} n1.v1={}\n", .{ v1, dot(n1, p), dot(n1, v1) });
                //std.debug.print("inter {}, {}\n", .{ inter0, inter1 });
                assert(@reduce(.Max, @abs(inter0 - inter1)) <= 1);

                sum += @intFromBool(@reduce(.And, inter0 >= p_min * fixed) and @reduce(.And, inter1 <= p_max * fixed));
            }
        }
        break :ans sum;
    };

    const ans2 = ans: {
        //const s0 = stones[0];
        //const s1 = stones[1];
        //const s2 = stones[2];
        for (stones, 0..) |s0, idx0| {
            for (stones[idx0 + 1 ..], 0..) |s1, idx1| {
                next_s: for (stones[idx0 + 1 ..][idx1 + 1 ..]) |s2| {

                    // o.p+o.v*t = s0.p+s0.v*t
                    //
                    // o.p.x+o.v.x*t = s0.p.x+s0.v.x*t
                    // o.p.y+o.v.y*t = s0.p.y+s0.v.y*t
                    // o.p.z+o.v.z*t = s0.p.z+s0.v.z*t
                    //
                    // #1*o.v.y - #2*o.v.x
                    // o.p.x*o.v.y - o.p.y*o.v.x + o.v.x*o.v.y*t - o.v.y*o.v.x*t = s0.p.x*o.v.y - s0.p.y*o.v.x + s0.v.x*o.v.y*t - s0.v.y*o.v.x*t
                    // t = ((o.p.x-s0.p.x)*o.v.y - (o.p.y-s0.p.y)*o.v.x) / (s0.v.x*o.v.y - s0.v.y*o.v.x)

                    //
                    // (o.p.x-s0.p.x) = (s0.v.x-o.v.x)*t
                    // (o.p.y-s0.p.y) = (s0.v.y-o.v.y)*t
                    //
                    // (o.p.x-s0.p.x) * (s0.v.y-o.v.y) = (o.p.y-s0.p.y) * (s0.v.x-o.v.x)
                    //
                    // o.p.x*s0.v.y - s0.p.x*s0.v.y - o.p.x*o.v.y + s0.p.x*o.v.y = o.p.y*s0.v.x - s0.p.y*s0.v.x - o.p.y*o.v.x + s0.p.y*o.v.x
                    //
                    // o.p.x * (s0.v.y) + o.p.y * (-s0.v.x) + o.v.y * (s0.p.x) + o.v.x * (-s0.p.y) + (s0.p.y*s0.v.x - s0.p.x*s0.v.y) = o.p.x*o.v.y - o.p.y*o.v.x
                    //
                    // idem avec s1:
                    // o.p.x * (s0.v.y) + o.p.y * (-s0.v.x) + o.v.x * (-s0.p.y) + o.v.y * (s0.p.x) + (s0.p.y*s0.v.x - s0.p.x*s0.v.y) = o.p.x*o.v.y - o.p.y*o.v.x
                    // o.p.x * (s1.v.y) + o.p.y * (-s1.v.x) + o.v.x * (-s1.p.y) + o.v.y * (s1.p.x) + (s1.p.y*s1.v.x - s1.p.x*s1.v.y) = o.p.x*o.v.y - o.p.y*o.v.x
                    //
                    // o.p.x * (s0.v.y-s1.v.y) + o.p.y * (s1.v.x-s0.v.x) + o.v.x * (s1.p.y-s0.p.y) + o.v.y * (s0.p.x-s1.p.x) + (s0.p.y*s0.v.x - s0.p.x*s0.v.y - s1.p.y*s1.v.x + s1.p.x*s1.v.y) = 0
                    //
                    // et avec x,z.
                    // o.p.x * (s0.v.z-s1.v.z) + o.p.z * (s1.v.x-s0.v.x) + o.v.x * (s1.p.z-s0.p.z) + o.v.z * (s0.p.x-s1.p.x) = -s0.p.z*s0.v.x + s0.p.x*s0.v.z + s1.p.z*s1.v.x - s1.p.x*s1.v.z
                    // et avec y,z.
                    // o.p.y * (s0.v.z-s1.v.z) + o.p.z * (s1.v.y-s0.v.y) + o.v.y * (s1.p.z-s0.p.z) + o.v.z * (s0.p.y-s1.p.y) = -s0.p.z*s0.v.y + s0.p.y*s0.v.z + s1.p.z*s1.v.y - s1.p.y*s1.v.z
                    // idem avec s2:
                    // o.p.x * (s0.v.y-s1.v.y) + o.p.y * (s1.v.x-s0.v.x) + o.v.x * (s1.p.y-s0.p.y) + o.v.y * (s0.p.x-s1.p.x) = -s0.p.y*s0.v.x + s0.p.x*s0.v.y + s1.p.y*s1.v.x - s1.p.x*s1.v.y
                    // o.p.x * (s0.v.y-s2.v.y) + o.p.y * (s2.v.x-s0.v.x) + o.v.x * (s2.p.y-s0.p.y) + o.v.y * (s0.p.x-s2.p.x) = -s0.p.y*s0.v.x + s0.p.x*s0.v.y + s2.p.y*s2.v.x - s2.p.x*s2.v.y

                    const equation: LinearSystem6x6 = .{ .a = .{
                        .{ (s0.v[1] - s1.v[1]), (s1.v[0] - s0.v[0]), 0, (s1.p[1] - s0.p[1]), (s0.p[0] - s1.p[0]), 0 },
                        .{ (s0.v[2] - s1.v[2]), 0, (s1.v[0] - s0.v[0]), (s1.p[2] - s0.p[2]), 0, (s0.p[0] - s1.p[0]) },
                        .{ 0, (s0.v[2] - s1.v[2]), (s1.v[1] - s0.v[1]), 0, (s1.p[2] - s0.p[2]), (s0.p[1] - s1.p[1]) },
                        .{ (s0.v[1] - s2.v[1]), (s2.v[0] - s0.v[0]), 0, (s2.p[1] - s0.p[1]), (s0.p[0] - s2.p[0]), 0 },
                        .{ (s0.v[2] - s2.v[2]), 0, (s2.v[0] - s0.v[0]), (s2.p[2] - s0.p[2]), 0, (s0.p[0] - s2.p[0]) },
                        .{ 0, (s0.v[2] - s2.v[2]), (s2.v[1] - s0.v[1]), 0, (s2.p[2] - s0.p[2]), (s0.p[1] - s2.p[1]) },
                    }, .b = .{
                        -s0.p[1] * s0.v[0] + s0.p[0] * s0.v[1] + s1.p[1] * s1.v[0] - s1.p[0] * s1.v[1],
                        -s0.p[2] * s0.v[0] + s0.p[0] * s0.v[2] + s1.p[2] * s1.v[0] - s1.p[0] * s1.v[2],
                        -s0.p[2] * s0.v[1] + s0.p[1] * s0.v[2] + s1.p[2] * s1.v[1] - s1.p[1] * s1.v[2],
                        -s0.p[1] * s0.v[0] + s0.p[0] * s0.v[1] + s2.p[1] * s2.v[0] - s2.p[0] * s2.v[1],
                        -s0.p[2] * s0.v[0] + s0.p[0] * s0.v[2] + s2.p[2] * s2.v[0] - s2.p[0] * s2.v[2],
                        -s0.p[2] * s0.v[1] + s0.p[1] * s0.v[2] + s2.p[2] * s2.v[1] - s2.p[1] * s2.v[2],
                    } };

                    //std.debug.print("stones: = {}, {}, {}\n", .{s0,s1,s2});
                    //std.debug.print("eq = {}\n", .{equation});

                    if (equation.solve()) |sol| {
                        const o = Vec3{ @intCast(sol[0]), @intCast(sol[1]), @intCast(sol[2]) };
                        const v = Vec3{ @intCast(sol[3]), @intCast(sol[4]), @intCast(sol[5]) };
                        //std.debug.print("v: <{}>  : sol? {}\n", .{ v, o });
                        for (stones) |s| {
                            if (v[0] - s.v[0] != 0) {
                                const t0 = std.math.divExact(T, s.p[0] - o[0], v[0] - s.v[0]) catch continue :next_s;
                                if (t0 <= 0) unreachable; //continue :next_v;
                            }
                            if (v[1] - s.v[1] != 0) {
                                const t1 = std.math.divExact(T, s.p[1] - o[1], v[1] - s.v[1]) catch continue :next_s;
                                if (t1 <= 0) continue :next_s;
                            }
                            if (v[2] - s.v[2] != 0) {
                                const t2 = std.math.divExact(T, s.p[2] - o[2], v[2] - s.v[2]) catch continue :next_s;
                                if (t2 <= 0) continue :next_s;
                            }
                        }
                        const solution = offset + o;
                        break :ans @reduce(.Add, solution);
                    }
                }
            }
        }
        unreachable;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

const LinearSystem6x6 = struct {
    a: [6][6]T2,
    b: [6]T2,

    // solution système linéarie avec le pivot de gauss
    fn solve(self: @This()) ?[6]T2 {
        var eqs = self;

        // forme échelonnée
        var order = [_]u8{ 0, 1, 2, 3, 4, 5 };
        for (0..6) |i| {
            std.mem.sort(u8, &order, eqs, rowGreaterThan);
            //std.debug.print("order={any}\n", .{ order });

            const row_a0 = eqs.a[order[i]];
            const b0 = eqs.b[order[i]];
            if (row_a0[i] == 0) return null; // no solution. (equations pas independantes)
            for (order[i + 1 ..]) |j| {
                const row_a1 = &eqs.a[j];
                const ppcm = tools.ppcm(row_a1[i], row_a0[i]);
                if (ppcm == 0) continue;
                const k0 = @divExact(ppcm, row_a0[i]);
                const k1 = @divExact(ppcm, row_a1[i]);
                const b1 = &eqs.b[j];
                //              std.debug.print("b0={}, b1={}, k={}/{}\n", .{ b0, b1.*, k0, k1 });
                for (row_a0, row_a1) |a0, *a1| a1.* = a1.* * k1 - a0 * k0;
                b1.* = b1.* * k1 - b0 * k0;
            }
            //           std.debug.print("a={any}, b={any}\n", .{ eqs.a, eqs.b });
        }

        var sol: [6]T2 = .{ 0, 0, 0, 0, 0, 0 };
        //std.mem.sort(u8, &order, eqs, rowLessThan);
        //std.debug.print("order={any}\n", .{ order });
        //std.debug.print("a={any}, b={any}\n", .{ eqs.a, eqs.b });
        for (0..6) |i| {
            const row = eqs.a[order[5 - i]];
            var b = eqs.b[order[5 - i]];
            //std.debug.print("row = {any}, b={}, i={},j={}\n", .{ row, b,  5-i, order[5 - i]});
            for (row[1 + 5 - i ..], sol[1 + 5 - i ..]) |ai, si| {
                b -= ai * si;
            }
            sol[5 - i] = std.math.divExact(T2, b, row[5 - i]) catch return null;
            //std.debug.print("row = {any}, b={}, sol={any}\n", .{ row, b, sol });
        }
        return sol;
    }

    fn rowGreaterThan(eqs: @This(), lhs: u8, rhs: u8) bool {
        for (&eqs.a[lhs], &eqs.a[rhs]) |l, r| {
            if (@abs(l) == @abs(r)) continue;
            return (@abs(l) > @abs(r));
        }
        unreachable;
    }
};

test "LinearSolver" {
    const eq00 = LinearSystem6x6{ .a = .{
        .{ 1, 2, 3, 5, 7, 17 },
        .{ 2, 3, 5, 7, 11, 13 },
        .{ 3, 5, 7, 11, 13, 11 },
        .{ 4, 7, 11, 13, 17, 7 },
        .{ 5, 11, 13, 17, 19, 5 },
        .{ 6, 13, 17, 19, 23, 3 },
    }, .b = .{ 0, 0, 0, 0, 0, 0 } };
    try std.testing.expectEqual([6]T2{ 0, 0, 0, 0, 0, 0 }, eq00.solve().?);

    const eq01 = LinearSystem6x6{ .a = .{
        .{ 1, 2, 3, 5, 7, 17 },
        .{ 2, 3, 5, 7, 11, 13 },
        .{ 3, 5, 7, 11, 13, 11 },
        .{ 4, 7, 11, 13, 17, 7 },
        .{ 5, 11, 13, 17, 19, 5 },
        .{ 6, 13, 17, 19, 23, 3 },
    }, .b = .{ 1, 2, 3, 4, 5, 6 } };
    try std.testing.expectEqual([6]T2{ 1, 0, 0, 0, 0, 0 }, eq01.solve().?);

    const eq02 = LinearSystem6x6{ .a = .{
        .{ 1, 2, 3, 5, 7, 17 },
        .{ 2, 3, 5, 7, 11, 13 },
        .{ 3, 5, 7, 11, 13, 11 },
        .{ 4, 7, 11, 13, 17, 7 },
        .{ 5, 11, 13, 17, 19, 5 },
        .{ 6, 13, 17, 19, 23, 3 },
    }, .b = .{ 6 * 6, 5 * 6, 4 * 6, 3 * 6, 2 * 6, 1 * 6 } };
    try std.testing.expectEqual([6]T2{ -8 * 6, 0, 0, 7, 7, 0 }, eq02.solve().?);
}

test {
    const res1 = try run(
        \\19, 13, 30 @ -2,  1, -2
        \\18, 19, 22 @ -1, -1, -2
        \\20, 25, 34 @ -2, -2, -4
        \\12, 31, 28 @ -1, -2, -1
        \\20, 19, 15 @  1, -5, -3
    , std.testing.allocator);
    defer std.testing.allocator.free(res1[0]);
    defer std.testing.allocator.free(res1[1]);
    try std.testing.expectEqualStrings("2", res1[0]);
    try std.testing.expectEqualStrings("47", res1[1]);
}
