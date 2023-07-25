const std = @import("std");
const tools = @import("tools");

const with_trace = false;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}
const assert = std.debug.assert;

pub const main = tools.defaultMain("2021/day22.txt", run);

const Vec3 = @Vector(3, i32);
const Box = struct {
    min: Vec3,
    max: Vec3,
    on: bool,
    order: u32,
    fn lessThan2(ctx: void, a: @This(), b: @This()) bool {
        _ = ctx;
        if (a.min[2] < b.min[2]) return true;
        if (a.min[2] > b.min[2]) return false;
        //  if (a.max[2] < b.max[2]) return true;
        //  if (a.max[2] > b.max[2]) return false;
        return false; // eq.
    }
    fn compareOrder(_: void, a: @This(), b: @This()) std.math.Order {
        return std.math.order(b.order, a.order);
    }
};

fn boxListEqual(as: []const Box, bs: []const Box) bool {
    if (as.len != bs.len) return false;
    for (as) |a, i| {
        const b = bs[i];
        if (a.order != b.order) return false;
        assert(a.on == b.on and @reduce(.And, a.min == b.min) and @reduce(.And, a.max == b.max));
    } else return true;
}

fn countNbLit(allocator: std.mem.Allocator, min: Vec3, max: Vec3, sorted_list: []const Box) !u64 {
    var sublist1 = std.ArrayList(Box).init(allocator);
    defer sublist1.deinit();
    var sublist2 = std.ArrayList(Box).init(allocator);
    defer sublist2.deinit();

    var nb_lit_1: u64 = 0;
    var cursublist1 = std.ArrayList(Box).init(allocator);
    defer cursublist1.deinit();

    var nb_lit_2: u64 = 0;
    var cursublist2 = std.ArrayList(Box).init(allocator);
    defer cursublist2.deinit();

    var stack = std.PriorityQueue(Box, void, Box.compareOrder).init(allocator, {});
    defer stack.deinit();

    var nb_lit: u64 = 0;

    var p = min;
    while (p[0] <= max[0]) : (p += Vec3{ 1, 0, 0 }) {
        sublist1.clearRetainingCapacity();
        for (sorted_list) |box| {
            if (box.min[0] <= p[0] and p[0] <= box.max[0]) try sublist1.append(box);
        }
        //trace("p.x={}  {} boxes\n", .{ p[0], sublist1.items.len });

        if (!boxListEqual(cursublist1.items, sublist1.items)) {
            cursublist1.clearRetainingCapacity();
            try cursublist1.appendSlice(sublist1.items);
            nb_lit_1 = 0;
            nb_lit_2 = 0;
            p[1] = min[1];
            while (p[1] <= max[1]) : (p += Vec3{ 0, 1, 0 }) {
                sublist2.clearRetainingCapacity();
                for (sublist1.items) |box| {
                    if (box.min[1] <= p[1] and p[1] <= box.max[1]) try sublist2.append(box);
                }
                // trace("  p.y={}  {} boxes\n", .{ p[1], sublist2.items.len });

                if (!boxListEqual(cursublist2.items, sublist2.items)) {
                    cursublist2.clearRetainingCapacity();
                    try cursublist2.appendSlice(sublist2.items);

                    //if (p[0] == 20 and p[1]==-10)
                    //    trace("boxes={any}\n", .{ sublist2.items });
                    while (stack.removeOrNull()) |_| {}

                    nb_lit_2 = 0;
                    var idx: u32 = 0;
                    p[2] = min[2];
                    while (p[2] <= max[2]) : (p += Vec3{ 0, 0, 1 }) {
                        while (idx < sublist2.items.len and sublist2.items[idx].min[2] <= p[2]) : (idx += 1)
                            try stack.add(sublist2.items[idx]);

                        var it = stack.iterator();
                        var i: u32 = 0;
                        while (it.next()) |box| {
                            assert(@reduce(.And, p >= box.min));
                            if (p[2] > box.max[2]) {
                                _ = stack.removeIndex(i);
                                it.reset();
                                i = 0;
                            } else {
                                assert(@reduce(.And, p <= box.max));
                                i += 1;
                            }
                        }
                        if (@reduce(.And, p == Vec3{ 0, 0, 0 }))
                            trace("raster: pointlit00={}\n", .{(if (stack.peek()) |b| b.on else false)});

                        nb_lit_2 += @boolToInt(if (stack.peek()) |b| b.on else false);
                    }
                }
                nb_lit_1 += nb_lit_2;
            }
        }
        nb_lit += nb_lit_1;
    }
    return nb_lit;
}

fn countNbLit_octree_rasterize(min: Vec3, max: Vec3, octree: *const Octree) u64 {
    var nb_lit: u64 = 0;
    var p = min;
    while (p[0] <= max[0]) : (p += Vec3{ 1, 0, 0 }) {
        p[1] = min[1];
        while (p[1] <= max[1]) : (p += Vec3{ 0, 1, 0 }) {
            p[2] = min[2];
            while (p[2] <= max[2]) : (p += Vec3{ 0, 0, 1 }) {
                nb_lit += @boolToInt(octree.isPointLit(p));
            }
        }
    }
    return nb_lit;
}

const Octree = struct {
    const Node = union(enum) {
        leave_islit: bool,
        node: struct {
            p: Vec3,
            childs: [8]*Node,
        },
    };
    root: *Node,
    arena: std.heap.ArenaAllocator,

    pub fn init(allocator: std.mem.Allocator) !@This() {
        var arena = std.heap.ArenaAllocator.init(allocator);
        errdefer arena.deinit();
        const root = try arena.allocator().create(Node);
        root.* = Node{ .leave_islit = false };
        return Octree{
            .arena = arena,
            .root = root,
        };
    }
    pub fn deinit(self: *const @This()) void {
        self.arena.deinit();
    }

    fn addBoxRecurse(self: *@This(), min: Vec3, max: Vec3, is_lit: bool, cur: *Node) std.mem.Allocator.Error!*Node {
        if (@reduce(.Or, max <= min)) return cur;
        const allocator = self.arena.allocator();
        if (cur.* == .leave_islit) {
            if (is_lit == cur.leave_islit) return cur;
            const newleave = try allocator.create(Node);
            const newnode1 = try allocator.create(Node);
            const newnode2 = try allocator.create(Node);
            newnode1.* = Node{ .node = .{ .p = min, .childs = undefined } };
            newnode2.* = Node{ .node = .{ .p = max, .childs = undefined } };
            newleave.* = Node{ .leave_islit = is_lit };
            newnode1.node.childs[0b000] = cur;
            newnode1.node.childs[0b001] = cur;
            newnode1.node.childs[0b010] = cur;
            newnode1.node.childs[0b011] = cur;
            newnode1.node.childs[0b100] = cur;
            newnode1.node.childs[0b101] = cur;
            newnode1.node.childs[0b110] = cur;
            newnode1.node.childs[0b111] = newnode2;
            newnode2.node.childs[0b000] = newleave;
            newnode2.node.childs[0b001] = cur;
            newnode2.node.childs[0b010] = cur;
            newnode2.node.childs[0b011] = cur;
            newnode2.node.childs[0b100] = cur;
            newnode2.node.childs[0b101] = cur;
            newnode2.node.childs[0b110] = cur;
            newnode2.node.childs[0b111] = cur;
            return newnode1;
        } else {
            const min_000 = @max(min, Vec3{ min[0], min[1], min[2] });
            const min_001 = @max(min, Vec3{ min[0], min[1], cur.node.p[2] });
            const min_010 = @max(min, Vec3{ min[0], cur.node.p[1], min[2] });
            const min_011 = @max(min, Vec3{ min[0], cur.node.p[1], cur.node.p[2] });
            const min_100 = @max(min, Vec3{ cur.node.p[0], min[1], min[2] });
            const min_101 = @max(min, Vec3{ cur.node.p[0], min[1], cur.node.p[2] });
            const min_110 = @max(min, Vec3{ cur.node.p[0], cur.node.p[1], min[2] });
            const min_111 = @max(min, Vec3{ cur.node.p[0], cur.node.p[1], cur.node.p[2] });

            const max_000 = @min(max, Vec3{ cur.node.p[0], cur.node.p[1], cur.node.p[2] });
            const max_001 = @min(max, Vec3{ cur.node.p[0], cur.node.p[1], max[2] });
            const max_010 = @min(max, Vec3{ cur.node.p[0], max[1], cur.node.p[2] });
            const max_011 = @min(max, Vec3{ cur.node.p[0], max[1], max[2] });
            const max_100 = @min(max, Vec3{ max[0], cur.node.p[1], cur.node.p[2] });
            const max_101 = @min(max, Vec3{ max[0], cur.node.p[1], max[2] });
            const max_110 = @min(max, Vec3{ max[0], max[1], cur.node.p[2] });
            const max_111 = @min(max, Vec3{ max[0], max[1], max[2] });

            cur.node.childs[0b000] = try addBoxRecurse(self, min_000, max_000, is_lit, cur.node.childs[0b000]);
            cur.node.childs[0b001] = try addBoxRecurse(self, min_001, max_001, is_lit, cur.node.childs[0b001]);
            cur.node.childs[0b010] = try addBoxRecurse(self, min_010, max_010, is_lit, cur.node.childs[0b010]);
            cur.node.childs[0b011] = try addBoxRecurse(self, min_011, max_011, is_lit, cur.node.childs[0b011]);
            cur.node.childs[0b100] = try addBoxRecurse(self, min_100, max_100, is_lit, cur.node.childs[0b100]);
            cur.node.childs[0b101] = try addBoxRecurse(self, min_101, max_101, is_lit, cur.node.childs[0b101]);
            cur.node.childs[0b110] = try addBoxRecurse(self, min_110, max_110, is_lit, cur.node.childs[0b110]);
            cur.node.childs[0b111] = try addBoxRecurse(self, min_111, max_111, is_lit, cur.node.childs[0b111]);

            //const volume = @reduce(.Mul, @intCast(@Vector(3, u64), max - min));
            //if (computeVolumeRecurse(self, is_lit, min, max, cur) == volume) {
            //    const newleave = try allocator.create(Node);
            //    newleave.* = Node{ .leave_islit = is_lit };
            //    trace("collapsing to leave.\n", .{});
            //    return newleave;
            //} else {
            //    return cur;
            //}
            return cur;
        }
    }
    pub fn addBox(self: *@This(), box: Box) !void {
        self.root = try addBoxRecurse(self, box.min, box.max + Vec3{ 1, 1, 1 }, box.on, self.root);
    }

    fn isPointLitRecurse(self: *const @This(), p: Vec3, cur: *const Node) bool {
        //trace("    node: {}\n", .{cur.*});

        switch (cur.*) {
            .leave_islit => |on| return on,
            .node => |n| {
                const quadrant: u3 = @boolToInt(p[0] >= n.p[0]) * @as(u3, 0b100) + @boolToInt(p[1] >= n.p[1]) * @as(u3, 0b010) + @boolToInt(p[2] >= n.p[2]) * @as(u3, 0b001);
                return isPointLitRecurse(self, p, n.childs[quadrant]);
            },
        }
    }
    pub fn isPointLit(self: *const @This(), p: Vec3) bool {
        //trace("octree: ispointlit@{}\n", .{p});
        return isPointLitRecurse(self, p, self.root);
    }

    fn computeVolumeRecurse(self: *const @This(), is_lit: bool, min: Vec3, max: Vec3, cur: *const Node) u64 {
        if (@reduce(.Or, max <= min)) return 0;
        switch (cur.*) {
            .leave_islit => |on| {
                //trace("volume+= {} * {}..{}\n", .{@boolToInt(on), min, max });
                return @boolToInt(on == is_lit) * @reduce(.Mul, @intCast(@Vector(3, u64), max - min));
            },
            .node => |n| {
                const vol000 = computeVolumeRecurse(self, is_lit, @max(min, Vec3{ min[0], min[1], min[2] }), @min(max, Vec3{ n.p[0], n.p[1], n.p[2] }), n.childs[0b000]);
                const vol001 = computeVolumeRecurse(self, is_lit, @max(min, Vec3{ min[0], min[1], n.p[2] }), @min(max, Vec3{ n.p[0], n.p[1], max[2] }), n.childs[0b001]);
                const vol010 = computeVolumeRecurse(self, is_lit, @max(min, Vec3{ min[0], n.p[1], min[2] }), @min(max, Vec3{ n.p[0], max[1], n.p[2] }), n.childs[0b010]);
                const vol011 = computeVolumeRecurse(self, is_lit, @max(min, Vec3{ min[0], n.p[1], n.p[2] }), @min(max, Vec3{ n.p[0], max[1], max[2] }), n.childs[0b011]);
                const vol100 = computeVolumeRecurse(self, is_lit, @max(min, Vec3{ n.p[0], min[1], min[2] }), @min(max, Vec3{ max[0], n.p[1], n.p[2] }), n.childs[0b100]);
                const vol101 = computeVolumeRecurse(self, is_lit, @max(min, Vec3{ n.p[0], min[1], n.p[2] }), @min(max, Vec3{ max[0], n.p[1], max[2] }), n.childs[0b101]);
                const vol110 = computeVolumeRecurse(self, is_lit, @max(min, Vec3{ n.p[0], n.p[1], min[2] }), @min(max, Vec3{ max[0], max[1], n.p[2] }), n.childs[0b110]);
                const vol111 = computeVolumeRecurse(self, is_lit, @max(min, Vec3{ n.p[0], n.p[1], n.p[2] }), @min(max, Vec3{ max[0], max[1], max[2] }), n.childs[0b111]);
                return vol000 + vol001 + vol010 + vol011 + vol100 + vol101 + vol110 + vol111;
            },
        }
    }
    pub fn computeVolumeLit(self: *const @This(), min: Vec3, max: Vec3) u64 {
        return computeVolumeRecurse(self, true, min, max, self.root);
    }
};

test "octree" {
    var octree = try Octree.init(std.testing.allocator);
    defer octree.deinit();

    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ 1, 2, 3 }));
    try std.testing.expectEqual(@as(u64, 0), octree.computeVolumeLit(Vec3{ -10000, -10000, -10000 }, Vec3{ 10000, 10000, 10000 }));

    try octree.addBox(Box{ .min = Vec3{ -1, -2, -3 }, .max = Vec3{ 1, 2, 3 }, .on = true, .order = 0 });
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ 1, 2, 3 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ -1, -2, -3 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ 0, 0, 0 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ 2, 2, 3 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ 1, 3, 3 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ 1, 2, 4 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ -3, -3, -3 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ -2, -2, -2 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ -1, -1, -1 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ -10, 0, 10 }));
    try std.testing.expectEqual(@as(u64, 8), octree.computeVolumeLit(Vec3{ -1, -1, -1 }, Vec3{ 1, 1, 1 }));
    try std.testing.expectEqual(@as(u64, 105), octree.computeVolumeLit(Vec3{ -10000, -10000, -10000 }, Vec3{ 10000, 10000, 10000 }));

    try octree.addBox(Box{ .min = Vec3{ -3, -3, -3 }, .max = Vec3{ 3, 3, 3 }, .on = true, .order = 0 });
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ 1, 2, 3 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ -1, -2, -3 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ 0, 0, 0 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ 2, 2, 3 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ 1, 3, 3 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ 1, 2, 4 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ -3, -3, -3 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ -2, -2, -2 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ -1, -1, -1 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ -10, 0, 10 }));
    try std.testing.expectEqual(@as(u64, 8), octree.computeVolumeLit(Vec3{ -1, -1, -1 }, Vec3{ 1, 1, 1 }));
    try std.testing.expectEqual(@as(u64, 343), octree.computeVolumeLit(Vec3{ -10000, -10000, -10000 }, Vec3{ 10000, 10000, 10000 }));

    try octree.addBox(Box{ .min = Vec3{ -3, -3, -3 }, .max = Vec3{ -2, -2, -2 }, .on = false, .order = 0 });
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ 1, 2, 3 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ -1, -2, -3 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ 0, 0, 0 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ 2, 2, 3 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ 1, 3, 3 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ 1, 2, 4 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ -3, -3, -3 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ -2, -2, -2 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ -1, -1, -1 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ -10, 0, 10 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ 0, 1, 0 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ 0, 1, 1 }));
    try std.testing.expectEqual(@as(u64, 8), octree.computeVolumeLit(Vec3{ -1, -1, -1 }, Vec3{ 1, 1, 1 }));
    try std.testing.expectEqual(@as(u64, 343 - 8), octree.computeVolumeLit(Vec3{ -10000, -10000, -10000 }, Vec3{ 10000, 10000, 10000 }));

    try octree.addBox(Box{ .min = Vec3{ 0, 0, 0 }, .max = Vec3{ 1, 1, 1 }, .on = false, .order = 0 });
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ 1, 2, 3 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ -1, -2, -3 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ 0, 0, 0 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ 0, 1, 0 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ 0, 1, 1 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ 1, 1, 1 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ -1, 0, 0 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ 2, 0, 0 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ 2, 1, 1 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ 2, 2, 3 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ 1, 3, 3 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ 1, 2, 4 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ -3, -3, -3 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ -2, -2, -2 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ -1, -1, -1 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ -10, 0, 10 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ -10, 0, 10 }));
    try std.testing.expectEqual(@as(u64, 7), octree.computeVolumeLit(Vec3{ -1, -1, -1 }, Vec3{ 1, 1, 1 }));
    try std.testing.expectEqual(@as(u64, 343 - 8 - 8), octree.computeVolumeLit(Vec3{ -10000, -10000, -10000 }, Vec3{ 10000, 10000, 10000 }));

    try octree.addBox(Box{ .min = Vec3{ 0, 1, 0 }, .max = Vec3{ 0, 1, 0 }, .on = true, .order = 0 });
    try octree.addBox(Box{ .min = Vec3{ 0, 1, 0 }, .max = Vec3{ 0, 1, 0 }, .on = false, .order = 0 });
    try octree.addBox(Box{ .min = Vec3{ 0, 1, 0 }, .max = Vec3{ 0, 1, 0 }, .on = true, .order = 0 });
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ 1, 2, 3 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ -1, -2, -3 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ 0, 0, 0 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ 0, 1, 0 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ 0, 1, 1 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ 1, 1, 1 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ -1, 0, 0 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ 2, 0, 0 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ 2, 1, 1 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ 2, 2, 3 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ 1, 3, 3 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ 1, 2, 4 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ -3, -3, -3 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ -2, -2, -2 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ -1, -1, -1 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ -10, 0, 10 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ 10, 10000, -10 }));
    try std.testing.expectEqual(@as(u64, 7), octree.computeVolumeLit(Vec3{ -1, -1, -1 }, Vec3{ 1, 1, 1 }));
    try std.testing.expectEqual(@as(u64, 343 - 8 - 8 + 1), octree.computeVolumeLit(Vec3{ -10000, -10000, -10000 }, Vec3{ 10000, 10000, 10000 }));

    try octree.addBox(Box{ .min = Vec3{ -100, -100, -100 }, .max = Vec3{ 100, 100, 0 }, .on = true, .order = 0 });
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ 1, 2, 3 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ -1, -2, -3 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ 0, 0, 0 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ 0, 1, 0 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ 0, 1, 1 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ 1, 1, 1 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ -1, 0, 0 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ 2, 0, 0 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ 2, 1, 1 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ 2, 2, 3 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ 1, 3, 3 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ 1, 2, 4 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ -3, -3, -3 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ -2, -2, -2 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ -1, -1, -1 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ -10, 0, 10 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ 10, 10000, -10 }));
    try std.testing.expectEqual(@as(u64, 8), octree.computeVolumeLit(Vec3{ -1, -1, -1 }, Vec3{ 1, 1, 1 }));
    try std.testing.expectEqual(@as(u64, 4080644), octree.computeVolumeLit(Vec3{ -10000, -10000, -10000 }, Vec3{ 10000, 10000, 10000 }));

    try octree.addBox(Box{ .min = Vec3{ -100, -100, -100 }, .max = Vec3{ 100, 100, 0 }, .on = false, .order = 0 });
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ 1, 2, 3 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ -1, -2, -3 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ 0, 0, 0 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ 0, 1, 0 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ 0, 1, 1 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ 1, 1, 1 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ -1, 0, 0 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ 2, 0, 0 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ 2, 1, 1 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ 2, 2, 3 }));
    try std.testing.expectEqual(true, octree.isPointLit(Vec3{ 1, 3, 3 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ 1, 2, 4 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ -3, -3, -3 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ -2, -2, -2 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ -1, -1, -1 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ -10, 0, 10 }));
    try std.testing.expectEqual(false, octree.isPointLit(Vec3{ 10, 10000, -10 }));
    try std.testing.expectEqual(@as(u64, 0), octree.computeVolumeLit(Vec3{ -1, -1, -1 }, Vec3{ 1, 1, 1 }));
    try std.testing.expectEqual(@as(u64, 143), octree.computeVolumeLit(Vec3{ -10000, -10000, -10000 }, Vec3{ 10000, 10000, 10000 }));

    try octree.addBox(Box{ .min = Vec3{ -1000, -1000, -1000 }, .max = Vec3{ 1000, 1000, 1000 }, .on = false, .order = 0 });
    try std.testing.expectEqual(@as(u64, 0), octree.computeVolumeLit(Vec3{ -1, -1, -1 }, Vec3{ 1, 1, 1 }));
    try std.testing.expectEqual(@as(u64, 0), octree.computeVolumeLit(Vec3{ -10000, -10000, -10000 }, Vec3{ 10000, 10000, 10000 }));
}

pub fn run(input: []const u8, gpa: std.mem.Allocator) tools.RunError![2][]const u8 {
    //    var arena_alloc = std.heap.ArenaAllocator.init(gpa);
    //    defer arena_alloc.deinit();
    //    const arena = arena_alloc.allocator();

    var list = std.ArrayList(Box).init(gpa);
    defer list.deinit();
    {
        var it = std.mem.tokenize(u8, input, "\n");
        while (it.next()) |line| {
            if (tools.match_pattern("on x={}..{},y={}..{},z={}..{}", line)) |val| {
                const min = Vec3{ @intCast(i32, val[0].imm), @intCast(i32, val[2].imm), @intCast(i32, val[4].imm) };
                const max = Vec3{ @intCast(i32, val[1].imm), @intCast(i32, val[3].imm), @intCast(i32, val[5].imm) };
                try list.append(Box{ .min = min, .max = max, .on = true, .order = @intCast(u32, list.items.len) });
            } else if (tools.match_pattern("off x={}..{},y={}..{},z={}..{}", line)) |val| {
                const min = Vec3{ @intCast(i32, val[0].imm), @intCast(i32, val[2].imm), @intCast(i32, val[4].imm) };
                const max = Vec3{ @intCast(i32, val[1].imm), @intCast(i32, val[3].imm), @intCast(i32, val[5].imm) };
                try list.append(Box{ .min = min, .max = max, .on = false, .order = @intCast(u32, list.items.len) });
            } else {
                trace("skipping '{s}'...\n", .{line});
            }
        }
    }

    var octree = try Octree.init(gpa);
    defer octree.deinit();
    for (list.items) |box| {
        try octree.addBox(box);
    }

    std.sort.sort(Box, list.items, {}, Box.lessThan2);
    const ans1 = try countNbLit(gpa, Vec3{ -50, -50, -50 }, Vec3{ 50, 50, 50 }, list.items);
    const ans1b = countNbLit_octree_rasterize(Vec3{ -50, -50, -50 }, Vec3{ 50, 50, 50 }, &octree);
    trace("ans1a={}, ans1b={}\n", .{ ans1, ans1b });
    assert(ans1 == ans1b);

    //const ans2 = ans: {
    //    var min = Vec3{ 0, 0, 0 };
    //    var max = Vec3{ 0, 0, 0 };
    //    for (list.items) |b| {
    //        min = @minimum(min, b.min);
    //        max = @maximum(max, b.max);
    //    }
    //    min -= Vec3{ 1, 1, 1 };
    //    max += Vec3{ 1, 1, 1 };
    //    trace("range={}...{}, boxes={}\n", .{ min, max, list.items.len });
    //    break :ans try countNbLit(gpa, min, max, list.items); // 1227348091315801  too high
    //};

    const ans2b = octree.computeVolumeLit(Vec3{ -1000000, -1000000, -1000000 }, Vec3{ 1000000, 1000000, 1000000 });
    //trace("ans2a={}, ans2b={}\n", .{ ans2, ans2b });
    //assert(ans2 == ans2b);

    return [_][]const u8{
        try std.fmt.allocPrint(gpa, "{}", .{ans1b}),
        try std.fmt.allocPrint(gpa, "{}", .{ans2b}),
    };
}

test {
    if (false) {
        const res = try run(
            \\on x=-20..26,y=-36..17,z=-47..7
            \\on x=-20..33,y=-21..23,z=-26..28
            \\on x=-22..28,y=-29..23,z=-38..16
            \\on x=-46..7,y=-6..46,z=-50..-1
            \\on x=-49..1,y=-3..46,z=-24..28
            \\on x=2..47,y=-22..22,z=-23..27
            \\on x=-27..23,y=-28..26,z=-21..29
            \\on x=-39..5,y=-6..47,z=-3..44
            \\on x=-30..21,y=-8..43,z=-13..34
            \\on x=-22..26,y=-27..20,z=-29..19
            \\off x=-48..-32,y=26..41,z=-47..-37
            \\on x=-12..35,y=6..50,z=-50..-2
            \\off x=-48..-32,y=-32..-16,z=-15..-5
            \\on x=-18..26,y=-33..15,z=-7..46
            \\off x=-40..-22,y=-38..-28,z=23..41
            \\on x=-16..35,y=-41..10,z=-47..6
            \\off x=-32..-23,y=11..30,z=-14..3
            \\on x=-49..-5,y=-3..45,z=-29..18
            \\off x=18..30,y=-20..-8,z=-3..13
            \\on x=-41..9,y=-7..43,z=-33..15
            \\on x=-54112..-39298,y=-85059..-49293,z=-27449..7877
            \\on x=967..23432,y=45373..81175,z=27513..53682
        , std.testing.allocator);
        defer std.testing.allocator.free(res[0]);
        defer std.testing.allocator.free(res[1]);
        try std.testing.expectEqualStrings("590784", res[0]);
        try std.testing.expectEqualStrings("39769202357779", res[1]);
    }
    if (false) {
        const res = try run(
            \\on x=-5..47,y=-31..22,z=-19..33
            \\on x=-44..5,y=-27..21,z=-14..35
            \\on x=-49..-1,y=-11..42,z=-10..38
            \\on x=-20..34,y=-40..6,z=-44..1
            \\off x=26..39,y=40..50,z=-2..11
            \\on x=-41..5,y=-41..6,z=-36..8
            \\off x=-43..-33,y=-45..-28,z=7..25
            \\on x=-33..15,y=-32..19,z=-34..11
            \\off x=35..47,y=-46..-34,z=-11..5
            \\on x=-14..36,y=-6..44,z=-16..29
            \\on x=-57795..-6158,y=29564..72030,z=20435..90618
            \\on x=36731..105352,y=-21140..28532,z=16094..90401
            \\on x=30999..107136,y=-53464..15513,z=8553..71215
            \\on x=13528..83982,y=-99403..-27377,z=-24141..23996
            \\on x=-72682..-12347,y=18159..111354,z=7391..80950
            \\on x=-1060..80757,y=-65301..-20884,z=-103788..-16709
            \\on x=-83015..-9461,y=-72160..-8347,z=-81239..-26856
            \\on x=-52752..22273,y=-49450..9096,z=54442..119054
            \\on x=-29982..40483,y=-108474..-28371,z=-24328..38471
            \\on x=-4958..62750,y=40422..118853,z=-7672..65583
            \\on x=55694..108686,y=-43367..46958,z=-26781..48729
            \\on x=-98497..-18186,y=-63569..3412,z=1232..88485
            \\on x=-726..56291,y=-62629..13224,z=18033..85226
            \\on x=-110886..-34664,y=-81338..-8658,z=8914..63723
            \\on x=-55829..24974,y=-16897..54165,z=-121762..-28058
            \\on x=-65152..-11147,y=22489..91432,z=-58782..1780
            \\on x=-120100..-32970,y=-46592..27473,z=-11695..61039
            \\on x=-18631..37533,y=-124565..-50804,z=-35667..28308
            \\on x=-57817..18248,y=49321..117703,z=5745..55881
            \\on x=14781..98692,y=-1341..70827,z=15753..70151
            \\on x=-34419..55919,y=-19626..40991,z=39015..114138
            \\on x=-60785..11593,y=-56135..2999,z=-95368..-26915
            \\on x=-32178..58085,y=17647..101866,z=-91405..-8878
            \\on x=-53655..12091,y=50097..105568,z=-75335..-4862
            \\on x=-111166..-40997,y=-71714..2688,z=5609..50954
            \\on x=-16602..70118,y=-98693..-44401,z=5197..76897
            \\on x=16383..101554,y=4615..83635,z=-44907..18747
            \\off x=-95822..-15171,y=-19987..48940,z=10804..104439
            \\on x=-89813..-14614,y=16069..88491,z=-3297..45228
            \\on x=41075..99376,y=-20427..49978,z=-52012..13762
            \\on x=-21330..50085,y=-17944..62733,z=-112280..-30197
            \\on x=-16478..35915,y=36008..118594,z=-7885..47086
            \\off x=-98156..-27851,y=-49952..43171,z=-99005..-8456
            \\off x=2032..69770,y=-71013..4824,z=7471..94418
            \\on x=43670..120875,y=-42068..12382,z=-24787..38892
            \\off x=37514..111226,y=-45862..25743,z=-16714..54663
            \\off x=25699..97951,y=-30668..59918,z=-15349..69697
            \\off x=-44271..17935,y=-9516..60759,z=49131..112598
            \\on x=-61695..-5813,y=40978..94975,z=8655..80240
            \\off x=-101086..-9439,y=-7088..67543,z=33935..83858
            \\off x=18020..114017,y=-48931..32606,z=21474..89843
            \\off x=-77139..10506,y=-89994..-18797,z=-80..59318
            \\off x=8476..79288,y=-75520..11602,z=-96624..-24783
            \\on x=-47488..-1262,y=24338..100707,z=16292..72967
            \\off x=-84341..13987,y=2429..92914,z=-90671..-1318
            \\off x=-37810..49457,y=-71013..-7894,z=-105357..-13188
            \\off x=-27365..46395,y=31009..98017,z=15428..76570
            \\off x=-70369..-16548,y=22648..78696,z=-1892..86821
            \\on x=-53470..21291,y=-120233..-33476,z=-44150..38147
            \\off x=-93533..-4276,y=-16170..68771,z=-104985..-24507
        , std.testing.allocator);
        defer std.testing.allocator.free(res[0]);
        defer std.testing.allocator.free(res[1]);
        try std.testing.expectEqualStrings("474140", res[0]);
        try std.testing.expectEqualStrings("2758514936282235", res[1]);
    }
}
