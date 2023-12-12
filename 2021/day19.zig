const std = @import("std");
const tools = @import("tools");

const with_trace = false;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}
const assert = std.debug.assert;

pub const main = tools.defaultMain("2021/day19.txt", run);

pub fn run(input: []const u8, gpa: std.mem.Allocator) tools.RunError![2][]const u8 {
    var arena_alloc = std.heap.ArenaAllocator.init(gpa);
    defer arena_alloc.deinit();
    const arena = arena_alloc.allocator();

    const DistIdx = struct {
        dist: u32,
        idx1: u16,
        idx2: u16,
        pub fn lessThan(context: void, a: @This(), b: @This()) bool {
            _ = context;
            return a.dist < b.dist;
        }
    };

    const Scan = struct {
        points: []const Vec3,
        pair_dists: []const DistIdx = undefined, // distance entre les paires de points du scan.  -> plus de calculs (n.n+1)/2  mais permet d'avoir l'index du point de ref sans tout scanner.

        positionned: bool = false,
        rotation: Mat3 = undefined,
        translation: Vec3 = undefined,
    };
    const scans = blk: {
        var scans = std.ArrayList(Scan).init(arena);
        var points: std.ArrayList(Vec3) = undefined;
        var it = std.mem.tokenize(u8, input, "\n");
        while (it.next()) |line| {
            if (tools.match_pattern("--- scanner {} ---", line)) |val| {
                if (val[0].imm != 0)
                    try scans.append(Scan{ .points = points.items });
                assert(scans.items.len == val[0].imm);
                points = std.ArrayList(Vec3).init(arena);
            } else if (tools.match_pattern("{},{},{}", line)) |val| {
                const v = Vec3{
                    @as(i32, @intCast(val[0].imm)),
                    @as(i32, @intCast(val[1].imm)),
                    @as(i32, @intCast(val[2].imm)),
                };
                try points.append(v);
            } else {
                trace("skipping '{s}'\n", .{line});
            }
        }
        try scans.append(Scan{ .points = points.items });

        for (scans.items) |*scan| {
            var dists = std.ArrayList(DistIdx).init(arena);
            for (scan.points, 0..) |p0, idx0| {
                for (scan.points[idx0 + 1 ..], 0..) |p1, offset| {
                    const d = norm1(p1 - p0);
                    try dists.append(.{ .dist = d, .idx1 = @as(u16, @intCast(idx0)), .idx2 = @as(u16, @intCast(idx0 + 1 + offset)) });
                }
            }
            std.mem.sort(DistIdx, dists.items, {}, DistIdx.lessThan);
            scan.pair_dists = dists.items;
        }

        trace("read {} scans.\n", .{scans.items.len});
        break :blk scans.items;
    };

    const ans1 = ans: {
        const refscan = &scans[0];
        refscan.rotation = identity;
        refscan.translation = Vec3{ 0, 0, 0 };
        refscan.positionned = true;

        var point_set = std.AutoArrayHashMap(Vec3, void).init(gpa);
        defer point_set.deinit();
        try point_set.ensureUnusedCapacity(refscan.points.len * scans.len);
        for (refscan.points) |p| {
            try point_set.put(p, {});
        }

        var nb_positionned_scans: u32 = 1;
        var pass_num: u32 = 0;
        while (true) : (pass_num += 1) {
            nextscan: for (scans, 0..) |*scan, scan_idx| {
                if (scan.positionned) continue;
                trace("try to match scan{}...\n", .{scan_idx});

                // on regarde si on a un scan qui matche parmis ceux déjà positionnés
                var maybe_ref_point_idx: u32 = 0;
                var maybe_ref_point_positionned: [2]Vec3 = undefined;
                const maybe_match = maybe_match: {
                    for (scans, 0..) |s, other_idx| {
                        if (!s.positionned) continue;

                        var i: u32 = 0;
                        var j: u32 = 0;
                        var nb_matches: u32 = 0;
                        while (i < scan.pair_dists.len and j < s.pair_dists.len) {
                            const d1 = scan.pair_dists[i].dist;
                            const d2 = s.pair_dists[j].dist;
                            if (d1 == d2) {
                                nb_matches += 1;
                                if (nb_matches >= (13 * 12) / 2) {
                                    trace("maybe match with {}...\n", .{other_idx});

                                    maybe_ref_point_idx = scan.pair_dists[i].idx1;
                                    maybe_ref_point_positionned[0] = mul(s.rotation, s.points[s.pair_dists[j].idx1]) + s.translation;
                                    maybe_ref_point_positionned[1] = mul(s.rotation, s.points[s.pair_dists[j].idx2]) + s.translation;
                                    assert(point_set.get(maybe_ref_point_positionned[0]) != null);
                                    assert(point_set.get(maybe_ref_point_positionned[1]) != null);

                                    break :maybe_match true;
                                }

                                i += 1;
                                j += 1;
                            } else if (d1 < d2) {
                                i += 1;
                            } else {
                                j += 1;
                            }
                        }
                    } else break :maybe_match false;
                };
                if (!maybe_match)
                    continue :nextscan;

                const match_pos: ?struct { r: Mat3, t: Vec3 } = cur_match: {
                    // get lucky with pair dist heuristic:
                    //  (peut être une distance égale par hasard, et on essaye qu'un deux indexes possibles pour la paire)
                    for (rotations) |r| {
                        const p0 = mul(r, scan.points[maybe_ref_point_idx]);
                        for (maybe_ref_point_positionned) |ref| {
                            const t = ref - p0;

                            var match_count: u32 = 0;
                            for (scan.points) |orig| {
                                const p = mul(r, orig) + t;
                                match_count += @intFromBool(point_set.get(p) != null);
                                if (match_count >= 12) {
                                    trace("Found lucky match for scan{}: t={}, r={any} with {} positionned points\n", .{ scan_idx, t, r, point_set.count() });
                                    break :cur_match .{ .r = r, .t = t };
                                }
                            }
                            assert(match_count > 0); // il y a au moins p0
                        }
                    }

                    trace("no luck, fallback to exhaustive search for ref point\n", .{});
                    for (rotations) |r| {
                        const p0 = mul(r, scan.points[pass_num % scan.points.len]);
                        var it = point_set.iterator();
                        while (it.next()) |ref_point| {
                            const ref = ref_point.key_ptr.*;
                            const t = ref - p0;

                            var match_count: u32 = 0;
                            for (scan.points) |orig| {
                                const p = mul(r, orig) + t;
                                match_count += @intFromBool(point_set.get(p) != null);
                                if (match_count >= 12) {
                                    trace("Found match for scan{}: t={}, r={any} with {} positionned points\n", .{ scan_idx, t, r, point_set.count() });
                                    break :cur_match .{ .r = r, .t = t };
                                }
                            }
                            assert(match_count > 0); // il y a au moins p0
                        }
                    }
                    break :cur_match null;
                };
                if (match_pos) |match| {
                    scan.rotation = match.r;
                    scan.translation = match.t;
                    scan.positionned = true;
                    for (scan.points) |orig| {
                        try point_set.put(mul(match.r, orig) + match.t, {});
                    }

                    nb_positionned_scans += 1;
                    if (nb_positionned_scans == scans.len) break :ans point_set.count();
                    continue :nextscan;
                } else {
                    trace("no match for scan{} so far, with {} positionned points\n", .{ scan_idx, point_set.count() });
                }
            }
        }
        unreachable;
    };

    const ans2 = ans: {
        var max_dist: i32 = 0;
        for (scans) |scan1| {
            for (scans) |scan2| {
                const signed_dist = (scan1.translation - scan2.translation);
                const dist = @max(signed_dist, -signed_dist);
                max_dist = @max(max_dist, @reduce(.Add, dist));
            }
        }

        break :ans max_dist;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(gpa, "{}", .{ans1}),
        try std.fmt.allocPrint(gpa, "{}", .{ans2}),
    };
}

// -----------------------------------------------------
// matrix math
// -----------------------------------------------------

const Vec3 = @Vector(3, i32);
const Mat3 = [3]Vec3;

fn cross(a: Vec3, b: Vec3) Vec3 {
    return Vec3{
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    };
}

fn dot(a: Vec3, b: Vec3) i32 {
    return @reduce(.Add, a * b);
}

fn norm1(a: Vec3) u32 {
    return @as(u32, @intCast(@reduce(.Add, @max(a, -a))));
}

fn mul(m: Mat3, v: Vec3) Vec3 {
    return Vec3{
        @reduce(.Add, m[0] * v),
        @reduce(.Add, m[1] * v),
        @reduce(.Add, m[2] * v),
    };
}

fn mat3FromLeftAndUp(left: Vec3, up: Vec3) Mat3 {
    const front = cross(left, up);
    return Mat3{
        Vec3{ left[0], up[0], front[0] },
        Vec3{ left[1], up[1], front[1] },
        Vec3{ left[2], up[2], front[2] },
    };
}

const rotations = blk: {
    var rots: [6 * 4]Mat3 = undefined;
    var len: u32 = 0;
    for ([_]Vec3{ .{ 1, 0, 0 }, .{ -1, 0, 0 }, .{ 0, 1, 0 }, .{ 0, -1, 0 }, .{ 0, 0, 1 }, .{ 0, 0, -1 } }) |left| {
        for ([_]Vec3{ .{ 1, 0, 0 }, .{ -1, 0, 0 }, .{ 0, 1, 0 }, .{ 0, -1, 0 }, .{ 0, 0, 1 }, .{ 0, 0, -1 } }) |up| {
            if (dot(left, up) != 0) continue;
            rots[len] = mat3FromLeftAndUp(left, up);
            len += 1;
        }
    }
    break :blk rots;
};
const identity = rotations[0];

test "matrix stuff" {
    const x = Vec3{ 1, 0, 0 };
    const y = Vec3{ 0, 1, 0 };
    const z = Vec3{ 0, 0, 1 };
    try std.testing.expectEqual(z, cross(x, y));
    try std.testing.expectEqual(x, mul(rotations[0], x));
    try std.testing.expectEqual(rotations[7][1], cross(rotations[7][2], rotations[7][0]));
}

// -----------------------------------------------------

test {
    {
        const res = try run(
            \\--- scanner 0 ---
            \\404,-588,-901
            \\528,-643,409
            \\-838,591,734
            \\390,-675,-793
            \\-537,-823,-458
            \\-485,-357,347
            \\-345,-311,381
            \\-661,-816,-575
            \\-876,649,763
            \\-618,-824,-621
            \\553,345,-567
            \\474,580,667
            \\-447,-329,318
            \\-584,868,-557
            \\544,-627,-890
            \\564,392,-477
            \\455,729,728
            \\-892,524,684
            \\-689,845,-530
            \\423,-701,434
            \\7,-33,-71
            \\630,319,-379
            \\443,580,662
            \\-789,900,-551
            \\459,-707,401
            \\
            \\--- scanner 1 ---
            \\686,422,578
            \\605,423,415
            \\515,917,-361
            \\-336,658,858
            \\95,138,22
            \\-476,619,847
            \\-340,-569,-846
            \\567,-361,727
            \\-460,603,-452
            \\669,-402,600
            \\729,430,532
            \\-500,-761,534
            \\-322,571,750
            \\-466,-666,-811
            \\-429,-592,574
            \\-355,545,-477
            \\703,-491,-529
            \\-328,-685,520
            \\413,935,-424
            \\-391,539,-444
            \\586,-435,557
            \\-364,-763,-893
            \\807,-499,-711
            \\755,-354,-619
            \\553,889,-390
            \\
            \\--- scanner 2 ---
            \\649,640,665
            \\682,-795,504
            \\-784,533,-524
            \\-644,584,-595
            \\-588,-843,648
            \\-30,6,44
            \\-674,560,763
            \\500,723,-460
            \\609,671,-379
            \\-555,-800,653
            \\-675,-892,-343
            \\697,-426,-610
            \\578,704,681
            \\493,664,-388
            \\-671,-858,530
            \\-667,343,800
            \\571,-461,-707
            \\-138,-166,112
            \\-889,563,-600
            \\646,-828,498
            \\640,759,510
            \\-630,509,768
            \\-681,-892,-333
            \\673,-379,-804
            \\-742,-814,-386
            \\577,-820,562
            \\
            \\--- scanner 3 ---
            \\-589,542,597
            \\605,-692,669
            \\-500,565,-823
            \\-660,373,557
            \\-458,-679,-417
            \\-488,449,543
            \\-626,468,-788
            \\338,-750,-386
            \\528,-832,-391
            \\562,-778,733
            \\-938,-730,414
            \\543,643,-506
            \\-524,371,-870
            \\407,773,750
            \\-104,29,83
            \\378,-903,-323
            \\-778,-728,485
            \\426,699,580
            \\-438,-605,-362
            \\-469,-447,-387
            \\509,732,623
            \\647,635,-688
            \\-868,-804,481
            \\614,-800,639
            \\595,780,-596
            \\
            \\--- scanner 4 ---
            \\727,592,562
            \\-293,-554,779
            \\441,611,-461
            \\-714,465,-776
            \\-743,427,-804
            \\-660,-479,-426
            \\832,-632,460
            \\927,-485,-438
            \\408,393,-506
            \\466,436,-512
            \\110,16,151
            \\-258,-428,682
            \\-393,719,612
            \\-211,-452,876
            \\808,-476,-593
            \\-575,615,604
            \\-485,667,467
            \\-680,325,-822
            \\-627,-443,-432
            \\872,-547,-609
            \\833,512,582
            \\807,604,487
            \\839,-516,451
            \\891,-625,532
            \\-652,-548,-490
            \\30,-46,-14
        , std.testing.allocator);
        defer std.testing.allocator.free(res[0]);
        defer std.testing.allocator.free(res[1]);
        try std.testing.expectEqualStrings("79", res[0]);
        try std.testing.expectEqualStrings("3621", res[1]);
    }
}
