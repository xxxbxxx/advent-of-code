const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub const main = tools.defaultMain("2023/day23.txt", run);

const Map = tools.Map(u8, 256, 256, false);
const Vec2 = tools.Vec2;

const Entry = struct {
    from: u16,
    steps: []Vec2,
};

pub fn run(text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena_alloc = std.heap.ArenaAllocator.init(allocator);
    defer arena_alloc.deinit();
    const arena = arena_alloc.allocator();

    var map: Map = .{ .default_tile = '#' };
    map.initFromText(text);
    const start, const end = blk: {
        var xs: ?i32 = null;
        var xe: ?i32 = null;
        var x = map.bbox.min[0];
        while (x <= map.bbox.max[0]) : (x += 1) {
            if (map.at(Vec2{ x, map.bbox.min[1] }) == '.') xs = x;
            if (map.at(Vec2{ x, map.bbox.max[1] }) == '.') xe = x;
        }
        break :blk .{ Vec2{ xs.?, map.bbox.min[1] }, Vec2{ xe.?, map.bbox.max[1] } };
    };

    const path_work_buf = try allocator.alloc(u16, @intCast(map.bbox.max[0] * map.bbox.max[1]));
    defer allocator.free(path_work_buf);

    const ans1 = ans: {
        var graph = std.AutoArrayHashMap(Vec2, []Entry).init(allocator);
        defer graph.deinit();
        try graph.put(start, &[0]Entry{});
        try graph.put(end, &[0]Entry{});

        const Node2 = struct {
            from: u16,
            steps: []Vec2,
            p: Vec2,
            prev: Vec2,
        };
        var agenda = std.ArrayList(Node2).init(allocator);
        defer agenda.deinit();
        try agenda.append(.{ .from = 0, .steps = &[0]Vec2{}, .p = start, .prev = start });

        while (agenda.popOrNull()) |n| {
            assert(map.at(n.p) != '#');

            var nb_options: u8 = 0;
            var options: [4]Vec2 = undefined;
            for (tools.Vec.cardinal4_dirs) |m| {
                if (@reduce(.And, n.p + m == n.prev)) continue;
                if (map.get(n.p + m)) |t| {
                    const can_move = switch (t) {
                        '#' => false,
                        '.' => true,
                        '>' => m[0] > 0,
                        'v' => m[1] > 0,
                        '<' => unreachable, //m[0] < 0,
                        '^' => unreachable, //m[1] < 0,
                        else => unreachable,
                    };
                    if (!can_move) continue;

                    options[nb_options] = n.p + m;
                    nb_options += 1;
                }
            }
            if (nb_options > 1 or @reduce(.And, n.p == end)) {
                // new grpah node
                const slot = try graph.getOrPut(n.p);
                if (!slot.found_existing) slot.value_ptr.* = &[0]Entry{};
                const new = try arena.realloc(slot.value_ptr.*, slot.value_ptr.len + 1);
                new[slot.value_ptr.len] = .{ .from = n.from, .steps = n.steps };
                slot.value_ptr.* = new;

                if (!slot.found_existing) {
                    const new_steps = try arena.alloc(Vec2, 1);
                    new_steps[0] = n.p;
                    const id: u16 = @intCast(slot.index);
                    for (options[0..nb_options]) |o| {
                        try agenda.append(.{ .from = id, .p = o, .prev = n.p, .steps = new_steps });
                    }
                    try agenda.append(.{ .from = id, .p = n.prev, .prev = n.p, .steps = new_steps });
                }
            } else if (nb_options == 1) {
                const new_steps = try arena.realloc(n.steps, n.steps.len + 1);
                new_steps[n.steps.len] = n.p;
                try agenda.append(.{ .from = n.from, .p = options[0], .prev = n.p, .steps = new_steps });
            }
        }

        // for (graph.keys(), graph.values(), 0..) |p, entry, i| {
        //     std.debug.print("#{} at {}: ", .{ i, p });
        //     for (entry) |n| {
        //         std.debug.print("({} -> {}), ", .{ n.from, n.steps.len });
        //     }
        //     std.debug.print("\n", .{});
        // }

        break :ans longestChain(path_work_buf, graph.values(), 0, 1, 0);
    };

    const ans2 = ans: {
        var graph = std.AutoArrayHashMap(Vec2, []Entry).init(allocator);
        defer graph.deinit();
        try graph.put(start, &[0]Entry{});
        try graph.put(end, &[0]Entry{});

        const Node2 = struct {
            from: u16,
            steps: []Vec2,
            p: Vec2,
            prev: Vec2,
        };
        var agenda = std.ArrayList(Node2).init(allocator);
        defer agenda.deinit();
        try agenda.append(.{ .from = 0, .steps = &[0]Vec2{}, .p = start, .prev = start });

        var visit: tools.Map(u8, 256, 256, false) = .{ .default_tile = 0 };

        while (agenda.popOrNull()) |n| {
            assert(map.at(n.p) != '#');
            visit.set(n.p, 1 + (visit.get(n.p) orelse 0));

            var nb_options: u8 = 0;
            var options: [4]Vec2 = undefined;
            for (tools.Vec.cardinal4_dirs) |m| {
                if (@reduce(.And, n.p + m == n.prev)) continue;
                if (map.get(n.p + m)) |t| {
                    const can_move = switch (t) {
                        '#' => false,
                        '.' => true,
                        '>' => true,
                        'v' => true,
                        '<' => unreachable,
                        '^' => unreachable,
                        else => unreachable,
                    };
                    if (!can_move) continue;

                    options[nb_options] = n.p + m;
                    nb_options += 1;
                }
            }
            if (nb_options > 1 or @reduce(.And, n.p == end)) {
                const slot = try graph.getOrPut(n.p);
                if (!slot.found_existing) slot.value_ptr.* = &[0]Entry{};
                const new = try arena.realloc(slot.value_ptr.*, slot.value_ptr.len + 1);
                new[slot.value_ptr.len] = .{ .from = n.from, .steps = n.steps };
                slot.value_ptr.* = new;

                if (!slot.found_existing) {
                    const new_steps = try arena.alloc(Vec2, 1);
                    new_steps[0] = n.p;
                    const id: u16 = @intCast(slot.index);
                    for (options[0..nb_options]) |o| {
                        try agenda.append(.{ .from = id, .p = o, .prev = n.p, .steps = new_steps });
                    }
                    try agenda.append(.{ .from = id, .p = n.prev, .prev = n.p, .steps = new_steps });
                }
            } else if (nb_options == 1) {
                const new_steps = try arena.realloc(n.steps, n.steps.len + 1);
                new_steps[n.steps.len] = n.p;
                try agenda.append(.{ .from = n.from, .p = options[0], .prev = n.p, .steps = new_steps });
            }
        }

        //var buf: [100000]u8 = undefined;
        //std.debug.print("{s}\n", .{visit.printToBuf(&buf, .{ .tileToCharFn = @TypeOf(visit).intToChar })});

        //for (graph.keys(), graph.values(), 0..) |p, entry, i| {
        //    std.debug.print("#{} at {}: ", .{ i, p });
        //    for (entry) |n| {
        //        std.debug.print("({} -> {}), ", .{ n.from, n.steps.len });
        //    }
        //    std.debug.print("\n", .{});
        //}

        const steps = longestChain(path_work_buf, graph.values(), 0, 1, 0);
        break :ans steps;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

fn longestChain(path: []u16, graph: []const []const Entry, len: u64, cur: u16, path_len: u32) u64 {
    if (cur == 0) return len;

    const entries = graph[cur];
    path[path_len] = cur;

    var max: ?u64 = 0;
    for (entries) |n| {
        if (std.mem.indexOfScalar(u16, path[0..path_len], n.from) == null) {
            const steps = longestChain(path, graph, len + n.steps.len, n.from, path_len + 1);
            if (steps > (max orelse 0)) {
                max = steps;
            }
        }
    }
    return max.?;
}

test {
    const res1 = try run(
        \\#.#####################
        \\#.......#########...###
        \\#######.#########.#.###
        \\###.....#.>.>.###.#.###
        \\###v#####.#v#.###.#.###
        \\###.>...#.#.#.....#...#
        \\###v###.#.#.#########.#
        \\###...#.#.#.......#...#
        \\#####.#.#.#######.#.###
        \\#.....#.#.#.......#...#
        \\#.#####.#.#.#########v#
        \\#.#...#...#...###...>.#
        \\#.#.#v#######v###.###v#
        \\#...#.>.#...>.>.#.###.#
        \\#####v#.#.###v#.#.###.#
        \\#.....#...#...#.#.#...#
        \\#.#########.###.#.#.###
        \\#...###...#...#...#.###
        \\###.###.#.###v#####v###
        \\#...#...#.#.>.>.#.>.###
        \\#.###.###.#.###.#.#v###
        \\#.....###...###...#...#
        \\#####################.#
    , std.testing.allocator);
    defer std.testing.allocator.free(res1[0]);
    defer std.testing.allocator.free(res1[1]);
    try std.testing.expectEqualStrings("94", res1[0]);
    try std.testing.expectEqualStrings("154", res1[1]);
}
