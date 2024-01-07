const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub const main = tools.defaultMain("2023/day22.txt", run);

const Vec3 = @Vector(3, i32);
const BBox = struct { min: Vec3, max: Vec3 };

fn zLessThan(_: void, lhs: BBox, rhs: BBox) bool {
    return lhs.min[2] < rhs.min[2];
}

fn intersect(pile: []const u16, b: BBox) bool {
    var ppp = b.min;
    while (ppp[2] <= b.max[2]) : (ppp += Vec3{ 0, 0, 1 }) {
        var pp = ppp;
        while (pp[1] <= b.max[1]) : (pp += Vec3{ 0, 1, 0 }) {
            var p = pp;
            while (p[0] <= b.max[0]) : (p += Vec3{ 1, 0, 0 }) {
                const idx: usize = @intCast(p[0] + p[1] * 10 + p[2] * 10 * 10);
                if (pile[idx] != 0) return true;
            }
        }
    }
    return false;
}

fn fill(pile: []u16, v: u16, b: BBox) void {
    var ppp = b.min;
    while (ppp[2] <= b.max[2]) : (ppp += Vec3{ 0, 0, 1 }) {
        var pp = ppp;
        while (pp[1] <= b.max[1]) : (pp += Vec3{ 0, 1, 0 }) {
            var p = pp;
            while (p[0] <= b.max[0]) : (p += Vec3{ 1, 0, 0 }) {
                const idx: usize = @intCast(p[0] + p[1] * 10 + p[2] * 10 * 10);
                assert(pile[idx] == 0);
                pile[idx] = v;
            }
        }
    }
}

fn swapRemove(list: *[]u16, e: u16) void {
    const i = std.mem.indexOfScalar(u16, list.*, e).?;
    if (list.len > 1) {
        list.*[i] = list.*[list.len - 1];
    }
    list.len -= 1;
}

pub fn run(text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena_alloc = std.heap.ArenaAllocator.init(allocator);
    defer arena_alloc.deinit();
    const arena = arena_alloc.allocator();

    const bricks = input: {
        var brcks = std.ArrayList(BBox).init(arena);
        defer brcks.deinit();

        var it = std.mem.tokenize(u8, text, "\n\r\t");
        while (it.next()) |line| {
            if (tools.match_pattern("{},{},{}~{},{},{}", line)) |vals| {
                try brcks.append(.{
                    .min = Vec3{ @intCast(vals[0].imm), @intCast(vals[1].imm), @intCast(vals[2].imm) },
                    .max = Vec3{ @intCast(vals[3].imm), @intCast(vals[4].imm), @intCast(vals[5].imm) },
                });
            } else unreachable;
        }
        break :input try brcks.toOwnedSlice();
    };

    const Relation = struct {
        supports: std.ArrayList(u16),
        supported_by: []const u16,
    };
    const bricks_graph: []const Relation = grph: {
        std.mem.sort(BBox, bricks, {}, zLessThan);
        const graph = try arena.alloc(Relation, bricks.len);
        //defer arena.free(graph);
        for (graph) |*g| {
            g.* = .{
                .supports = std.ArrayList(u16).init(arena),
                .supported_by = &[0]u16{},
            };
        }

        const pile = try allocator.alloc(u16, 10 * 10 * 500);
        defer allocator.free(pile);
        @memset(pile, 0);

        for (bricks, graph, 1..) |b, *g, brck_idx| {
            assert(!intersect(pile, b));
            var z: i32 = 1;
            const fall = while (z < b.min[2]) : (z += 1) {
                if (intersect(pile, BBox{ .min = b.min - Vec3{ 0, 0, z }, .max = b.max - Vec3{ 0, 0, z } })) break z - 1;
            } else b.min[2] - 1;

            fill(pile, @intCast(brck_idx), BBox{ .min = b.min - Vec3{ 0, 0, fall }, .max = b.max - Vec3{ 0, 0, fall } });

            const supported_by = sup: {
                var list = std.ArrayList(u16).init(arena);
                defer list.deinit();
                var pp = b.min - Vec3{ 0, 0, fall + 1 };
                while (pp[1] <= b.max[1]) : (pp += Vec3{ 0, 1, 0 }) {
                    var p = pp;
                    while (p[0] <= b.max[0]) : (p += Vec3{ 1, 0, 0 }) {
                        const idx: usize = @intCast(p[0] + p[1] * 10 + p[2] * 10 * 10);
                        const i = pile[idx];
                        if (i == 0) continue;
                        if (std.mem.indexOfScalar(u16, list.items, i) == null)
                            try list.append(i);
                    }
                }

                break :sup try list.toOwnedSlice();
            };
            g.supported_by = supported_by;
            for (supported_by) |i| {
                try graph[i - 1].supports.append(@intCast(brck_idx));
            }
        }

        if (false) {
            for (1..10) |z| {
                std.debug.print("z={}\n", .{z});
                var pp = Vec3{ 0, 0, @intCast(z) };
                while (pp[1] < 10) : (pp += Vec3{ 0, 1, 0 }) {
                    var p = pp;
                    while (p[0] < 10) : (p += Vec3{ 1, 0, 0 }) {
                        const idx: usize = @intCast(p[0] + p[1] * 10 + p[2] * 10 * 10);
                        const b = pile[idx];
                        std.debug.print("{c}", .{@as(u8, if (b == 0) '.' else @intCast('A' + b - 1))});
                    }
                    std.debug.print("\n", .{});
                }
                std.debug.print("\n", .{});
            }
        }

        if (false) {
            for (graph, 1..) |g, i| {
                std.debug.print("brick n°{} supports={any}, supported_by={any}\n", .{ i, g.supports.items, g.supported_by });
            }
        }

        break :grph graph;
    };

    const ans1 = ans: {
        var sum: u64 = 0;
        for (bricks_graph, 1..) |g, idx| {
            const can_be_removed = for (g.supports.items) |b| {
                assert(std.mem.indexOfScalar(u16, bricks_graph[b - 1].supported_by, @intCast(idx)) != null);
                if (bricks_graph[b - 1].supported_by.len <= 1) break false;
            } else true;
            sum += @intFromBool(can_be_removed);
        }
        break :ans sum;
    };

    const ans2 = ans: {
        var falling = std.ArrayList(u16).init(allocator);
        defer falling.deinit();

        var sum: u64 = 0;
        for (bricks_graph, 1..) |_, root_idx| {
            try falling.append(@intCast(root_idx));

            var arena2_alloc = std.heap.ArenaAllocator.init(allocator);
            defer arena2_alloc.deinit();
            const arena2 = arena2_alloc.allocator();
            const DynRel = struct {
                supports: []u16,
                supported_by: []u16,
            };
            const tmp = try arena2.alloc(DynRel, bricks_graph.len);
            for (bricks_graph, 0..) |g, i| {
                tmp[i] = .{
                    .supports = try arena2.dupe(u16, g.supports.items),
                    .supported_by = try arena2.dupe(u16, g.supported_by),
                };
            }

            var count: u32 = 0;
            while (falling.popOrNull()) |b| {
                for (tmp[b - 1].supported_by) |i| {
                    swapRemove(&tmp[i - 1].supports, b);
                }
                for (tmp[b - 1].supports) |i| {
                    swapRemove(&tmp[i - 1].supported_by, b);
                    if (tmp[i - 1].supported_by.len == 0) {
                        if (std.mem.indexOfScalar(u16, falling.items, i) == null) {
                            count += 1;
                            try falling.append(@intCast(i));
                        }
                    }
                }
            }
            sum += count;
        }
        break :ans sum;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

test {
    const res1 = try run(
        \\1,0,1~1,2,1
        \\0,0,2~2,0,2
        \\0,2,3~2,2,3
        \\0,0,4~0,2,4
        \\2,0,5~2,2,5
        \\0,1,6~2,1,6
        \\1,1,8~1,1,9
    , std.testing.allocator);
    defer std.testing.allocator.free(res1[0]);
    defer std.testing.allocator.free(res1[1]);
    try std.testing.expectEqualStrings("5", res1[0]);
    try std.testing.expectEqualStrings("7", res1[1]);
}
