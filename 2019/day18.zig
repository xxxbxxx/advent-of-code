const std = @import("std");
const tools = @import("tools");

const with_trace = false;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

const Vec2 = tools.Vec2;
const Map = tools.Map(u8, 85, 85, false);

const PoiDist = struct {
    poi: u7,
    dist: u32,
};
const MapNode = struct {
    poi: u8,
    list: []PoiDist,
};
fn compute_dists_list(map: *const Map, from: u8, buf: []PoiDist) []PoiDist {
    var dmap = [1]u16{65535} ** (Map.stride * Map.stride);
    var poi_dist = [1]u32{65535} ** (('z' - 'a' + 1) + ('Z' - 'A' + 1));

    var changed = true;
    while (changed) {
        changed = false;

        var p = map.bbox.min;
        p.y = map.bbox.min.y + 1;
        while (p.y <= map.bbox.max.y - 1) : (p.y += 1) {
            p.x = map.bbox.min.x + 1;
            while (p.x <= map.bbox.max.x - 1) : (p.x += 1) {
                const offset = map.offsetof(p);
                const m = map.map[offset];

                const cur_dist: u16 = blk: {
                    if (m == from) {
                        if (dmap[offset] > 0) {
                            dmap[offset] = 0;
                            changed = true;
                        }
                        break :blk 0;
                    } else {
                        const up = Vec2{ .x = p.x, .y = p.y - 1 };
                        const down = Vec2{ .x = p.x, .y = p.y + 1 };
                        const left = Vec2{ .x = p.x - 1, .y = p.y };
                        const right = Vec2{ .x = p.x + 1, .y = p.y };

                        const offsetup = map.offsetof(up);
                        const offsetdown = map.offsetof(down);
                        const offsetleft = map.offsetof(left);
                        const offsetright = map.offsetof(right);

                        var d: u16 = 65534;
                        if (d > dmap[offsetup]) d = dmap[offsetup];
                        if (d > dmap[offsetdown]) d = dmap[offsetdown];
                        if (d > dmap[offsetleft]) d = dmap[offsetleft];
                        if (d > dmap[offsetright]) d = dmap[offsetright];
                        d += 1;

                        break :blk d;
                    }
                };

                switch (m) {
                    '.', '@', '1'...'4' => {
                        if (dmap[offset] > cur_dist) {
                            dmap[offset] = cur_dist;
                            changed = true;
                        }
                    },
                    'a'...'z' => {
                        poi_dist[m - 'a'] = cur_dist;
                    },
                    'A'...'Z' => {
                        poi_dist[m - 'A' + ('z' - 'a' + 1)] = cur_dist;
                    },
                    '#' => continue,
                    else => unreachable,
                }
            }
        }
    }

    var i: u32 = 0;
    for (poi_dist) |d, p| {
        if (d == 65535 or d == 0)
            continue;
        if (p <= 'z' - 'a') {
            buf[i] = .{ .dist = d, .poi = @intCast(u7, p + 'a') };
        } else {
            buf[i] = .{ .dist = d, .poi = @intCast(u7, p - ('z' - 'a' + 1) + 'A') };
        }
        i += 1;
    }
    return buf[0..i];
}

fn recurse_updatedists(from: u7, keys: []const u1, graph: []const MapNode, steps: u16, dists: []u16) void {
    const list = graph[from].list;
    for (list) |l| {
        const p = l.poi;
        const is_door = (p >= 'A' and p <= 'Z');
        const is_locked_door = (is_door and keys[p - 'A'] == 0);
        if (is_locked_door)
            continue;

        const dist = @intCast(u16, steps + l.dist);
        if (dist >= dists[p])
            continue;
        dists[p] = dist;

        const is_key = (p >= 'a' and p <= 'z');
        const is_new_key = (is_key and keys[p - 'a'] == 0);
        if (is_new_key)
            continue;

        recurse_updatedists(p, keys, graph, dist, dists);
    }
}

fn enumerate_capturables(from: u7, keys: []const u1, graph: []const MapNode, pool: []PoiDist) []PoiDist {
    var dists = [1]u16{65535} ** 127;
    dists[from] = 0;
    recurse_updatedists(from, keys, graph, 0, &dists);

    var len: usize = 0;
    for ("abcdefghijklmnopqrstuvwxyz") |k| {
        const d = dists[k];
        if (d == 65535 or d == 0)
            continue;

        const is_new_key = (keys[k - 'a'] == 0);
        if (!is_new_key)
            continue;

        pool[len] = PoiDist{ .poi = @intCast(u7, k), .dist = d };
        len += 1;
    }
    return pool[0..len];
}

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var all_keys = [1]u1{0} ** 26;
    var map = Map{ .default_tile = 0 };
    {
        var map_cursor = Vec2{ .x = 0, .y = 0 };
        for (input) |c| {
            if (c == '\n') {
                map_cursor = Vec2{ .x = 0, .y = map_cursor.y + 1 };
            } else {
                map.set(map_cursor, c);
                map_cursor.x += 1;
            }
            if (c >= 'a' and c <= 'z')
                all_keys[c - 'a'] = 1;
        }
    }

    const Trace = struct {
        poi_list: [100]u8,
        poi_len: usize,
    };

    // compiler bug workl around:  make unique names for the state type.
    const State1 = struct {
        cur: u7,
        keys: [26]u1,
    };
    const init_state1 = State1{
        .cur = '@',
        .keys = [1]u1{0} ** 26,
    };

    const State2 = struct {
        cur: [4]u7,
        keys: [26]u1,
    };
    const init_state2 = State2{
        .cur = [4]u7{ '1', '2', '3', '4' },
        .keys = [1]u1{0} ** 26,
    };

    var answers: [3]u32 = undefined;

    inline for ([_]u2{ 1, 2 }) |part| {

        // patch center for phase2.
        if (part == 2) {
            const center = Vec2{ .x = @divFloor(map.bbox.min.x + map.bbox.max.x, 2), .y = @divFloor(map.bbox.min.y + map.bbox.max.y, 2) };
            assert(map.at(center) == '@');
            map.set(Vec2{ .x = center.x + 0, .y = center.y + 0 }, '#');
            map.set(Vec2{ .x = center.x + 1, .y = center.y + 0 }, '#');
            map.set(Vec2{ .x = center.x - 1, .y = center.y + 0 }, '#');
            map.set(Vec2{ .x = center.x + 0, .y = center.y + 1 }, '#');
            map.set(Vec2{ .x = center.x + 0, .y = center.y - 0 }, '#');
            map.set(Vec2{ .x = center.x + 1, .y = center.y + 1 }, '1');
            map.set(Vec2{ .x = center.x + 1, .y = center.y - 1 }, '2');
            map.set(Vec2{ .x = center.x - 1, .y = center.y - 1 }, '3');
            map.set(Vec2{ .x = center.x - 1, .y = center.y + 1 }, '4');
        }

        {
            var buf: [15000]u8 = undefined;
            trace("{}\n", .{map.printToBuf(null, null, null, &buf)});
        }

        // compute the simplified distance graph to explore:
        var pooldists: [1000]PoiDist = undefined;
        var graph: [256]MapNode = [1]MapNode{.{ .poi = 0, .list = &[0]PoiDist{} }} ** 256;
        {
            const startpoints = "@1234";
            const keys = "abcdefghijklmnopqrstuvwxyz";
            const doors = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
            var pool_len: usize = 0;
            for (startpoints ++ keys ++ doors) |poi| {
                const list = compute_dists_list(&map, poi, pooldists[pool_len..]);
                graph[poi] = MapNode{ .poi = poi, .list = list };
                pool_len += list.len;
            }
        }

        if (with_trace) {
            trace("list from '@': ", .{});
            for (graph['@'].list) |l| {
                trace("{},", .{l});
            }
            trace("\n", .{});
        }

        // search the best path
        // compiler fails with:
        //   const State = struct {
        //       cur: if (part == 1) u7 else [4]u8,
        //       keys: [26]u1,
        //   };
        //   const init_state = State{
        //       .cur = if (part == 1) '@' else [4]u8{ '1', '2', '3', '4' },
        //       .keys = [1]u1{0} ** 26,
        //   };
        const State = if (part == 1) State1 else State2;
        const init_state = if (part == 1) init_state1 else init_state2;
        const BFS = tools.BestFirstSearch(State, Trace);

        var searcher = BFS.init(allocator);
        defer searcher.deinit();

        try searcher.insert(.{
            .rating = 0,
            .steps = 0,
            .state = init_state,
            .trace = Trace{
                .poi_list = undefined,
                .poi_len = 0,
            },
        });

        var trace_dep: usize = 0;
        var trace_visited: usize = 0;
        var best: u32 = 10000;
        while (searcher.pop()) |node| {
            if (node.steps >= best)
                continue;

            if (with_trace) {
                const history = node.trace.poi_list[0..node.trace.poi_len];
                if (history.len > trace_dep or searcher.visited.count() > trace_visited + 50000) {
                    trace_dep = history.len;
                    trace_visited = searcher.visited.count();
                    trace("so far... steps={}, agendalen={}, visited={}, trace[{}]={}\n", .{ node.steps, searcher.agenda.items.len, searcher.visited.count(), history.len, history });
                }
            }

            var robot: usize = 0;
            const nbrobots = if (part == 1) 1 else 4;
            while (robot < nbrobots) : (robot += 1) {
                const cur = if (part == 1) node.state.cur else node.state.cur[robot];

                // si on fait directement "for (graph[cur].list) |l|" ça marche, mais ya trops de combinaisons d'etats inutiles:
                // -> on ne génère que des etats où une nouvelle clef est capturée
                var capturepool: [50]PoiDist = undefined;
                var capturelist = enumerate_capturables(cur, &node.state.keys, &graph, &capturepool);

                for (capturelist) |l| {
                    const p = l.poi;
                    const is_key = (p >= 'a' and p <= 'z');
                    const is_door = (p >= 'A' and p <= 'Z');
                    const is_locked_door = (is_door and node.state.keys[p - 'A'] == 0);
                    if (is_locked_door) continue;

                    var next = node;
                    next.steps = node.steps + l.dist;
                    if (is_key) next.state.keys[p - 'a'] = 1;
                    if (part == 1) {
                        next.state.cur = p;
                    } else {
                        next.state.cur[robot] = p;
                    }

                    if (is_key and node.state.keys[p - 'a'] == 0) {
                        next.trace.poi_list[node.trace.poi_len] = p;
                        next.trace.poi_list[node.trace.poi_len + 1] = ',';
                        next.trace.poi_len = node.trace.poi_len + 2;
                    }
                    // else if (is_door) {
                    //    next.trace.poi_list[node.trace.poi_len] = p;
                    //    next.trace.poi_len = node.trace.poi_len + 1;
                    //}

                    // rating:
                    var key_count: u32 = 0;
                    for (next.state.keys) |k| {
                        key_count += k;
                    }
                    next.rating = @intCast(i32, next.steps) - 100 * @intCast(i32, key_count);

                    if (next.steps >= best)
                        continue;
                    if (std.mem.eql(u1, &next.state.keys, &all_keys) and next.steps < best) {
                        trace("Solution: steps={}, agendalen={}, visited={}, trace={}\n", .{ next.steps, searcher.agenda.items.len, searcher.visited.count(), next.trace.poi_list[0..next.trace.poi_len] });
                        best = next.steps;
                        continue;
                    }

                    try searcher.insert(next);
                }
            }
        }

        answers[part] = best;
        trace("PART {}: min steps={}  (unique nodes visited={})\n", .{ part, best, searcher.visited.count() });
    }

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{answers[1]}),
        try std.fmt.allocPrint(allocator, "{}", .{answers[2]}),
    };
}

pub const main = tools.defaultMain("2019/day18.txt", run);
