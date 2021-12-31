const std = @import("std");
const tools = @import("tools");

const with_trace = false;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

// enable thread pool: (30% plus lent, le temps est dans des locks..)
pub const io_mode = .evented;

const Vec2 = @Vector(2, i16);

const PortalContext = struct {
    pub fn hash(self: @This(), a: u10) u32 {
        _ = self;
        return a;
    }
    pub fn eql(self: @This(), a: u10, b: u10) bool {
        _ = self;
        return a == b;
    }
};
const Portals = std.ArrayHashMap(u10, struct { out: Vec2, in: Vec2 }, PortalContext, false);

const Edge = enum { inner, outer };

fn addPortal(portals: *Portals, pos: Vec2, letter1: u8, letter2: u8, edge: Edge) void {
    const tag = @intCast(u10, letter1 - 'A') * 26 + @intCast(u10, letter2 - 'A');
    const entry = portals.getOrPut(tag) catch unreachable;
    if (edge == .inner) {
        entry.value_ptr.in = pos;
    } else {
        entry.value_ptr.out = pos;
    }
}

fn parseLine(input: []const u8, stride: usize, p0: Vec2, p1: Vec2, inc: Vec2, edge: Edge, offset_letter1: isize, offset_letter2: isize, portals: *Portals) void {
    var p = p0;
    while (@reduce(.Or, p != p1)) : (p += inc) {
        const o = offset_from_pos(p, stride);
        switch (input[o]) {
            '#' => {},
            '.' => {
                const l1 = input[@intCast(usize, @intCast(isize, o) + offset_letter1)];
                const l2 = input[@intCast(usize, @intCast(isize, o) + offset_letter2)];
                addPortal(portals, p, l1, l2, edge);
            },
            else => unreachable,
        }
    }
}

fn parsePortals(input: []const u8, stride: usize, width: u15, height: u15, portals: *Portals) void {
    const outer_top: u15 = 2;
    const outer_left: u15 = 2;
    const outer_bottom: u15 = height - 3;
    const outer_right: u15 = width - 3;
    assert(input[outer_left + outer_top * stride] == '#' and input[(outer_left + 0) + (outer_top - 1) * stride] == ' ' and input[(outer_left - 1) + (outer_top + 0) * stride] == ' ');
    assert(input[outer_right + outer_bottom * stride] == '#' and input[(outer_right + 0) + (outer_bottom + 1) * stride] == ' ' and input[(outer_right + 1) + (outer_bottom + 0) * stride] == ' ');
    assert(input[outer_left + outer_bottom * stride] == '#' and input[(outer_left + 0) + (outer_bottom + 1) * stride] == ' ' and input[(outer_left - 1) + (outer_bottom + 0) * stride] == ' ');
    assert(input[outer_right + outer_top * stride] == '#' and input[(outer_right + 0) + (outer_top - 1) * stride] == ' ' and input[(outer_right + 1) + (outer_top + 0) * stride] == ' ');

    const inner_top: u15 = 30;
    const inner_left: u15 = 30;
    const inner_bottom: u15 = height - 31;
    const inner_right: u15 = width - 31;
    assert(input[inner_left + inner_top * stride] == '#' and input[(inner_left + 0) + (inner_top + 1) * stride] == '#' and input[(inner_left + 1) + (inner_top + 0) * stride] == '#' and input[(inner_left + 1) + (inner_top + 1) * stride] == ' ');
    assert(input[inner_left + inner_bottom * stride] == '#' and input[(inner_left + 0) + (inner_bottom - 1) * stride] == '#' and input[(inner_left + 1) + (inner_bottom + 0) * stride] == '#' and input[(inner_left + 1) + (inner_bottom - 1) * stride] == ' ');
    assert(input[inner_right + inner_top * stride] == '#' and input[(inner_right + 0) + (inner_top + 1) * stride] == '#' and input[(inner_right - 1) + (inner_top + 0) * stride] == '#' and input[(inner_right - 1) + (inner_top + 1) * stride] == ' ');
    assert(input[inner_right + inner_bottom * stride] == '#' and input[(inner_right + 0) + (inner_bottom - 1) * stride] == '#' and input[(inner_right - 1) + (inner_bottom + 0) * stride] == '#' and input[(inner_right - 1) + (inner_bottom - 1) * stride] == ' ');

    const offset_line = @intCast(isize, stride);
    parseLine(input, stride, Vec2{ outer_left, outer_top }, Vec2{ outer_right, outer_top }, Vec2{ 1, 0 }, .outer, -offset_line * 2, -offset_line, portals);
    parseLine(input, stride, Vec2{ outer_left, outer_bottom }, Vec2{ outer_right, outer_bottom }, Vec2{ 1, 0 }, .outer, offset_line, offset_line * 2, portals);
    parseLine(input, stride, Vec2{ outer_left, outer_top }, Vec2{ outer_left, outer_bottom }, Vec2{ 0, 1 }, .outer, -2, -1, portals);
    parseLine(input, stride, Vec2{ outer_right, outer_top }, Vec2{ outer_right, outer_bottom }, Vec2{ 0, 1 }, .outer, 1, 2, portals);

    parseLine(input, stride, Vec2{ inner_left, inner_top }, Vec2{ inner_right, inner_top }, Vec2{ 1, 0 }, .inner, offset_line, offset_line * 2, portals);
    parseLine(input, stride, Vec2{ inner_left, inner_bottom }, Vec2{ inner_right, inner_bottom }, Vec2{ 1, 0 }, .inner, -offset_line * 2, -offset_line, portals);
    parseLine(input, stride, Vec2{ inner_left, inner_top }, Vec2{ inner_left, inner_bottom }, Vec2{ 0, 1 }, .inner, 1, 2, portals);
    parseLine(input, stride, Vec2{ inner_right, inner_top }, Vec2{ inner_right, inner_bottom }, Vec2{ 0, 1 }, .inner, -2, -1, portals);
}

fn flood_fill_recurse(input: []const u8, stride: usize, p: Vec2, depth: u16, dmap: []u16) void {
    for ([4]Vec2{ Vec2{ 1, 0 }, Vec2{ 0, 1 }, Vec2{ -1, 0 }, Vec2{ 0, -1 } }) |neib| {
        const p1 = p + neib;
        const o = offset_from_pos(p1, stride);
        if (input[o] != '.') continue;
        if (dmap[o] != 0) {
            assert(dmap[o] < depth);
            continue;
        }
        dmap[o] = depth;
        flood_fill_recurse(input, stride, p1, depth + 1, dmap);
    }
}

fn compute_distance_map(input: []const u8, stride: usize, p: Vec2, dmap: []u16) void {
    std.mem.set(u16, dmap, 0);
    flood_fill_recurse(input, stride, p, 1, dmap);
    const o = offset_from_pos(p, stride);
    dmap[o] = 0; // cas special entrée pas géré avant: un pas en avant, un pas en arrière
}

fn offset_from_pos(p: Vec2, stride: usize) usize {
    return @intCast(usize, p[0]) + @intCast(usize, p[1]) * stride;
}

const TaskDesc = struct {
    fn run(input: []const u8, stride: usize, portals: *const Portals, start_idx: usize, start_portal: Portals.Entry, dist_table: []u16, allocator: std.mem.Allocator) !void {

        // on alloue dans le thread principal:
        const portal_count = portals.count() * 2;
        const dmap = try allocator.alloc(u16, input.len);
        defer allocator.free(dmap);

        // puis on yield et se met dans la task pool.
        std.event.Loop.startCpuBoundOperation();

        inline for ([_]Edge{ .inner, .outer }) |e| {
            compute_distance_map(input, stride, if (e == .inner) start_portal.value_ptr.in else start_portal.value_ptr.out, dmap);

            var idx2: usize = 0;
            var it2 = portals.iterator();
            while (it2.next()) |portal2| : (idx2 += 1) {
                const p_in = portal2.value_ptr.in;
                const p_out = portal2.value_ptr.out;

                const o_in = offset_from_pos(p_in, stride);
                const o_out = offset_from_pos(p_out, stride);

                if (idx2 == start_idx) {
                    if (e == .inner) {
                        assert(dmap[o_in] == 0);
                    } else {
                        assert(dmap[o_out] == 0);
                    }
                }
                const row = (start_idx * 2 + (if (e == .inner) @as(usize, 0) else 1));

                // BUG: faudrait un lock. ou au moins des u32 atomiques...
                dist_table[row * portal_count + (idx2 * 2 + 0)] = dmap[o_in];
                dist_table[row * portal_count + (idx2 * 2 + 1)] = dmap[o_out];
            }
        }
    }
};

pub fn run(input: []const u8, allocator: std.mem.Allocator) tools.RunError![2][]const u8 {

    // 1. lire le laby
    // 2. calculer les paires de distances
    // 3. trouver la meilleure séquence de paires

    const stride = std.mem.indexOfScalar(u8, input, '\n').? + 1;
    const height = @intCast(u15, input.len / stride);
    const width = @intCast(u15, stride - 1);

    var portals = Portals.init(allocator);
    defer portals.deinit();
    const tagAA = @intCast(u10, 0) * 26 + @intCast(u10, 0);
    const tagZZ = @intCast(u10, 'Z' - 'A') * 26 + @intCast(u10, 'Z' - 'A');
    {
        const entryAA = portals.getOrPut(tagAA) catch unreachable;
        const entryZZ = portals.getOrPut(tagZZ) catch unreachable;
        entryAA.value_ptr.in = Vec2{ 50, 50 }; // n'existe pas -> point inatteignable au centre
        entryZZ.value_ptr.in = Vec2{ 52, 52 }; // n'existe pas -> point inatteignable au centre

        parsePortals(input, stride, width, height, &portals);

        trace("portals: count={}\n", .{portals.count()});
        var it = portals.iterator();
        while (it.next()) |e| {
            trace("  {c}{c}: {} -> {}\n", .{ 'A' + @intCast(u8, e.key_ptr.* / 26), 'A' + @intCast(u8, e.key_ptr.* % 26), e.value_ptr.in, e.value_ptr.out });
        }
    }
    const indexAA = @intCast(u8, portals.getIndex(tagAA).? * 2 + 1);
    const indexZZ = @intCast(u8, portals.getIndex(tagZZ).? * 2 + 1);

    const portal_count = portals.count() * 2;
    var dist_table = try allocator.alloc(u16, portal_count * portal_count);
    defer allocator.free(dist_table);
    {
        const TaskFrame = @Frame(TaskDesc.run);
        var tasks = try allocator.alloc(TaskFrame, portal_count / 2);
        defer allocator.free(tasks);

        var idx1: usize = 0;
        var it = portals.iterator();
        while (it.next()) |portal| : (idx1 += 1) {
            tasks[idx1] = async TaskDesc.run(input, stride, &portals, idx1, portal, dist_table, allocator);
        }

        for (tasks) |*t| {
            try await t.*;
        }

        {
            trace("distances:\n    ", .{});
            var i: usize = 0;
            while (i < portal_count) : (i += 1) {
                trace("{c}{c} ", .{ 'A' + @intCast(u8, portals.keys()[i / 2] / 26), 'A' + @intCast(u8, portals.keys()[i / 2] % 26) });
            }
            trace("\n", .{});

            i = 0;
            while (i < portal_count) : (i += 1) {
                var j: usize = 0;
                trace("{c}{c} ", .{ 'A' + @intCast(u8, portals.keys()[i / 2] / 26), 'A' + @intCast(u8, portals.keys()[i / 2] % 26) });
                while (j < portal_count) : (j += 1) {
                    assert(dist_table[j + i * portal_count] == dist_table[i + j * portal_count]); // sanity check.
                    trace(" {:2}", .{dist_table[j + i * portal_count]});
                }
                trace("\n", .{});
            }
        }
    }

    // TODO? on pourrait completer la table en accumulant les chemin composites. mais c'est probablement pas rentable?
    // TODO? bon évidement le gros du temps est passé dans les hashtables ci dessous, inutiles car on a que des ptits indexs et des states super simples...

    var part1: u64 = part1: {
        const BestFirstSearch = tools.BestFirstSearch(u8, void);
        var bfs = BestFirstSearch.init(allocator);
        defer bfs.deinit();

        try bfs.insert(BestFirstSearch.Node{
            .rating = 0,
            .cost = 0,
            .state = indexAA,
            .trace = {},
        });

        var best: u32 = 999999;
        while (bfs.pop()) |node| {
            if (node.cost >= best)
                continue;

            trace("at {} ({}):\n", .{ node.state, node.cost });

            //walk:
            var i: u8 = 0;
            while (i < portal_count) : (i += 1) {
                const d = dist_table[node.state * portal_count + i];
                if (d == 0) continue;
                const steps = node.cost + d;
                if (steps >= best) continue;
                if (i == indexZZ) { // exit found
                    trace("  exit: ...{} -{}-> OUT  ({})\n", .{ node.state, d, steps });
                    best = steps;
                    continue;
                }
                trace("  walk: ...{} -{}-> {}  ({})\n", .{ node.state, d, i, steps });
                try bfs.insert(BestFirstSearch.Node{
                    .rating = @intCast(i32, steps),
                    .cost = steps,
                    .state = i,
                    .trace = {},
                });
            }

            //teleport:
            if (node.state != indexAA and node.state != indexZZ) {
                const index = node.state ^ 1;
                const steps = node.cost + 1;
                trace("  tele: ...{} -1-> {}  ({})\n", .{ node.state, index, steps });
                try bfs.insert(BestFirstSearch.Node{
                    .rating = @intCast(i32, steps),
                    .cost = steps,
                    .state = index,
                    .trace = {},
                });
            }
        }
        break :part1 best;
    };

    var part2: u64 = part2: {
        const BestFirstSearch = tools.BestFirstSearch(struct { tp: u8, level: u8 }, void);
        var bfs = BestFirstSearch.init(allocator);
        defer bfs.deinit();

        try bfs.insert(BestFirstSearch.Node{
            .rating = 0,
            .cost = 0,
            .state = .{ .tp = indexAA, .level = 0 },
            .trace = {},
        });

        var best: u32 = 999999;
        while (bfs.pop()) |node| {
            if (node.cost >= best)
                continue;

            trace("at {} ({}):\n", .{ node.state, node.cost });

            //walk:
            var i: u8 = 0;
            while (i < portal_count) : (i += 1) {
                const d = dist_table[node.state.tp * portal_count + i];
                if (d == 0) continue;
                const steps = node.cost + d;
                if (steps >= best) continue;
                if (i == indexZZ and node.state.level == 0) { // exit found
                    trace("  exit: ...{} -{}-> OUT  ({})\n", .{ node.state, d, steps });
                    best = steps;
                    continue;
                } else if (i == indexZZ or i == indexAA) continue;
                trace("  walk: ...{} -{}-> {}  ({})\n", .{ node.state, d, i, steps });
                try bfs.insert(BestFirstSearch.Node{
                    .rating = @intCast(i32, steps + 8 * @as(u32, node.state.level)),
                    .cost = steps,
                    .state = .{ .tp = i, .level = node.state.level },
                    .trace = {},
                });
            }

            //teleport:
            if (node.state.tp != indexAA and node.state.tp != indexZZ) {
                const is_outer = (node.state.tp & 1) == 1;
                if (!is_outer or node.state.level > 0) {
                    const index = node.state.tp ^ 1;
                    const steps = node.cost + 1;
                    trace("  tele: ...{} -1-> {}  ({})\n", .{ node.state, index, steps });
                    try bfs.insert(BestFirstSearch.Node{
                        .rating = @intCast(i32, steps + 8 * @as(u32, node.state.level)),
                        .cost = steps,
                        .state = .{ .tp = index, .level = if (is_outer) node.state.level - 1 else node.state.level + 1 },
                        .trace = {},
                    });
                }
            }
        }
        break :part2 best;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{part1}),
        try std.fmt.allocPrint(allocator, "{}", .{part2}),
    };
}

pub const main = tools.defaultMain("2019/day20.txt", run);
