const std = @import("std");
const assert = std.debug.assert;
const print = std.debug.print;
const tools = @import("tools");

const Vec2 = tools.Vec2;

const stride: usize = 11;
const width = 10;
const height = 10;
const Border = u10;

const Map = struct {
    ident: u32,
    map: []const u8,
    borders: ?struct { canon: [4]Border, transformed: [8][4]Border },
};

fn push_bit(v: *u10, tile: u8) void {
    v.* = (v.* << 1) | (if (tile == '.') @as(u1, 0) else @as(u1, 1));
}
fn extractBorders(map: []const u8) [4]Border {
    var b: [4]Border = undefined;
    var i: usize = 0;
    while (i < width) : (i += 1) {
        push_bit(&b[0], map[i]);
        push_bit(&b[1], map[i * stride + (width - 1)]);
        push_bit(&b[2], map[i + (height - 1) * stride]);
        push_bit(&b[3], map[i * stride + 0]);
    }
    return b;
}

// tranforme la "map" de t par rapport à son centre.
fn transform(in: Map, t: Vec2.Transfo, out_buf: []u8) Map {
    const r = Vec2.referential(t);
    const c2 = Vec2{ .x = width - 1, .y = height - 1 }; // coordonées doublées pour avoir le centre entre deux cases.

    var j: i32 = 0;
    while (j < height) : (j += 1) {
        var i: i32 = 0;
        while (i < width) : (i += 1) {
            const o2 = Vec2{ .x = i * 2 - c2.x, .y = j * 2 - c2.y };
            const p2 = Vec2.add(Vec2.scale(o2.x, r.x), Vec2.scale(o2.y, r.y));
            const p = Vec2{ .x = @intCast(u16, p2.x + c2.x) / 2, .y = @intCast(u16, p2.y + c2.y) / 2 };
            //   print("{} <- {} == {}\n", .{ o2, p2, w });

            out_buf[@intCast(u32, i) + @intCast(u32, j) * stride] = in.map[@intCast(u32, p.x) + @intCast(u32, p.y) * stride];
        }
        out_buf[width + @intCast(u32, j) * stride] = '\n';
    }

    return Map{
        .ident = in.ident,
        .map = out_buf[0 .. height * stride],
        .borders = null,
    };
}

fn computeTransormedBorders(in: *Map) void {
    var borders: [8][4]Border = undefined;
    for (Vec2.all_tranfos) |t| {
        var buf: [stride * height]u8 = undefined;
        const m = transform(in.*, t, &buf);
        borders[@enumToInt(t)] = extractBorders(m.map);
    }

    var canon: [4]Border = undefined;
    for (canon) |*it, i| {
        it.* = if (borders[0][i] < @bitReverse(Border, borders[0][i])) borders[0][i] else @bitReverse(Border, borders[0][i]);
    }

    const b = borders[0];
    assert((b[0] | b[1] | b[2] | b[3]) != 0); // valeur spéciale reservée

    in.borders = .{ .canon = canon, .transformed = borders };
}

fn debugPrint(m: Map) void {
    print("map n°{}: borders={b},{b},{b},{b}\n", .{ m.ident, m.borders[0], m.borders[1], m.borders[2], m.borders[3] });
    print("{}", .{m.map});
}

const State = struct {
    placed: u8,
    list: [150]struct { map_idx: u8, t: Vec2.Transfo },
};

fn bigPosFromIndex(idx: usize, big_stride: usize) Vec2 {
    if (true) { // sens de lecture  -> permet de placer un coin dès le debut au bon endroit.
        return Vec2{ .y = @intCast(i32, idx / big_stride), .x = @intCast(i32, idx % big_stride) };
    } else { // spirale partant du centre.
        const c = Vec2{ .y = @intCast(i32, big_stride / 2), .x = @intCast(i32, big_stride / 2) };
        const p = Vec2.add(c, tools.posFromSpiralIndex(idx));
        const s = @intCast(i32, big_stride);
        return Vec2{ .x = @intCast(i32, @mod(p.x, s)), .y = @intCast(i32, @mod(p.y, s)) }; // gère le fait que c'est décentré si la taille est paire
    }
}

fn checkValid(s: State, maps: []const Map) bool {
    const big_stride = std.math.sqrt(maps.len);

    var borders_mem = [_][4]Border{.{ 0, 0, 0, 0 }} ** (16 * 16);
    var borders = borders_mem[0 .. big_stride * big_stride];
    for (s.list[0..s.placed]) |it, i| {
        const p = bigPosFromIndex(i, big_stride);
        assert(p.y >= 0 and p.y < big_stride and p.x >= 0 and p.x < big_stride);
        borders[@intCast(usize, p.x) + @intCast(usize, p.y) * big_stride] = maps[it.map_idx].borders.?.transformed[@enumToInt(it.t)];
    }

    for (borders[0 .. big_stride * big_stride]) |b, i| {
        if ((b[0] | b[1] | b[2] | b[3]) == 0) continue;
        const p = Vec2{ .x = @intCast(i32, i % big_stride), .y = @intCast(i32, i / big_stride) };
        const border_list = [_]struct { this: u8, other: u8, d: Vec2 }{
            .{ .this = 0, .other = 2, .d = Vec2{ .x = 0, .y = -1 } },
            .{ .this = 3, .other = 1, .d = Vec2{ .x = -1, .y = 0 } },
            .{ .this = 1, .other = 3, .d = Vec2{ .x = 1, .y = 0 } },
            .{ .this = 2, .other = 0, .d = Vec2{ .x = 0, .y = 1 } },
        };
        for (border_list) |it| {
            const n = Vec2.add(p, it.d);
            const neib = if (n.y >= 0 and n.y < big_stride and n.x >= 0 and n.x < big_stride) borders[@intCast(usize, n.x) + @intCast(usize, n.y) * big_stride] else [4]Border{ 0, 0, 0, 0 };
            const empty = ((neib[0] | neib[1] | neib[2] | neib[3]) == 0);
            if (!empty and b[it.this] != neib[it.other]) return false;
        }
    }

    return true;
}

fn replaceIfMatches(pat: []const []const u8, p: Vec2, t: Vec2.Transfo, map: []u8, w: usize, h: usize) void {
    const r = Vec2.referential(t);

    // check if pattern matches...
    for (pat) |line, j| {
        for (line) |c, i| {
            if (c == ' ') continue;
            assert(c == '#');
            const p1 = p.add(Vec2.scale(@intCast(i32, i), r.x)).add(Vec2.scale(@intCast(i32, j), r.y));
            if (p1.x < 0 or p1.x >= w) return;
            if (p1.y < 0 or p1.y >= h) return;
            if (map[@intCast(usize, p1.y) * w + @intCast(usize, p1.x)] != c) return;
        }
    }

    // .. if ok, replace pattern
    for (pat) |line, j| {
        for (line) |c, i| {
            if (c == ' ') continue;
            const p1 = p.add(Vec2.scale(@intCast(i32, i), r.x)).add(Vec2.scale(@intCast(i32, j), r.y));
            map[@intCast(usize, p1.y) * w + @intCast(usize, p1.x)] = '0';
        }
    }
}

pub fn run(input_text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const param: struct {
        maps: []const Map,
        big_stride: usize,
    } = blk: {
        var maps = std.ArrayList(Map).init(arena.allocator());

        var ident: ?u32 = null;
        var it = std.mem.tokenize(u8, input_text, "\n\r");
        while (it.next()) |line| {
            if (tools.match_pattern("Tile {}:", line)) |fields| {
                ident = @intCast(u32, fields[0].imm);
            } else {
                const w = std.mem.indexOfScalar(u8, input_text, '\n').?;
                assert(w == width);
                assert(ident != null);
                var map = line;
                map.len = stride * height;
                var m = Map{ .ident = ident.?, .map = map, .borders = null };
                computeTransormedBorders(&m);
                try maps.append(m);

                var h: usize = 1;
                while (h < height) : (h += 1) {
                    _ = it.next();
                }
                ident = null;
            }
        }

        //print("{}\n", .{maps.items.len});
        break :blk .{
            .maps = maps.items,
            .big_stride = std.math.sqrt(maps.items.len),
        };
    };

    // corner candidate pieces:
    const corners: []u8 = blk: {
        const occurences = try allocator.alloc(u8, 1 << 10);
        defer allocator.free(occurences);

        std.mem.set(u8, occurences, 0);
        for (param.maps) |m| {
            for (m.borders.?.canon) |b| occurences[b] += 1;
        }
        for (occurences) |it| assert(it <= 2); // pff en fait il n'y a pas d'ambiguités...

        var corners = std.ArrayList(u8).init(arena.allocator());
        for (param.maps) |m, i| {
            var uniq: u32 = 0;
            for (m.borders.?.canon) |b| uniq += @boolToInt(occurences[b] == 1);
            assert(uniq <= 2);
            if (uniq == 2) // deux bords uniques -> coin!
                try corners.append(@intCast(u8, i));
        }
        //print("found corner pieces: {}\n", .{corners.items});
        break :blk corners.items;
    };

    var final_state: State = undefined;
    const ans1 = ans: {
        // nb: vu qu'il n'y a pas d'ambiguité, on pourrait juste faire corners[0]*..*corner[3] pour ans1.
        const BFS = tools.BestFirstSearch(State, void);
        var bfs = BFS.init(allocator);
        defer bfs.deinit();

        const initial_state = blk: {
            var s = State{ .placed = 0, .list = undefined };
            for (s.list) |*m, i| {
                m.map_idx = if (i < param.maps.len) @intCast(u8, i) else undefined;
                m.t = .r0;
            }

            // comment avec un coin, ça permet de trouver direct une bonne solution
            s.list[0].map_idx = corners[0];
            s.list[corners[0]].map_idx = 0;
            break :blk s;
        };

        try bfs.insert(BFS.Node{ .state = initial_state, .trace = {}, .rating = @intCast(i32, param.maps.len), .steps = 0 });

        final_state = result: while (bfs.pop()) |n| {
            //print("agenda: {}, steps:{}\n", .{ bfs.agenda.count(), n.steps });
            var next_candidate = n.state.placed;
            while (next_candidate < param.maps.len) : (next_candidate += 1) {
                var next = n;
                next.steps = n.steps + 1;
                next.rating = n.rating - 1;
                next.state.list[n.state.placed] = n.state.list[next_candidate];
                next.state.list[next_candidate] = n.state.list[n.state.placed];
                next.state.placed = n.state.placed + 1;
                for (Vec2.all_tranfos) |t| {
                    if (n.steps == 0 and t != .r0) continue; // pas la peine d'explorer les 8 sytémetries et trouver 8 resultats..
                    next.state.list[n.state.placed].t = t;
                    if (!checkValid(next.state, param.maps)) continue;
                    if (next.state.placed == param.maps.len) break :result next.state; // bingo!
                    try bfs.insert(next);
                }
            }
        } else unreachable;

        if (false) {
            print("final state: ", .{});
            for (final_state.list[0..param.maps.len]) |it, i| {
                const p = bigPosFromIndex(i, param.big_stride);
                print("{}:{}{}, ", .{ p, param.maps[it.map_idx].ident, it.t });
            }
            print("\n", .{});
        }
        var checksum: u64 = 1;
        checksum *= param.maps[final_state.list[0].map_idx].ident;
        checksum *= param.maps[final_state.list[param.big_stride - 1].map_idx].ident;
        checksum *= param.maps[final_state.list[param.maps.len - 1].map_idx].ident;
        checksum *= param.maps[final_state.list[param.maps.len - param.big_stride].map_idx].ident;
        break :ans checksum;
    };

    const ans2 = ans: {
        const h = (height - 2) * param.big_stride;
        const w = (width - 2) * param.big_stride;

        var big = try allocator.alloc(u8, w * h);
        defer allocator.free(big);

        // build merged map
        for (final_state.list[0..final_state.placed]) |it, i| {
            const big_p = bigPosFromIndex(i, param.big_stride);

            var buf: [stride * height]u8 = undefined;
            const m = transform(param.maps[it.map_idx], it.t, &buf);
            var j: usize = 0;
            while (j < height - 2) : (j += 1) {
                const o = ((@intCast(u32, big_p.y) * (height - 2) + j) * w + @intCast(u32, big_p.x) * (width - 2));
                std.mem.copy(u8, big[o .. o + (width - 2)], m.map[(j + 1) * stride + 1 .. (j + 1) * stride + 1 + (width - 2)]);
            }
        }

        {
            const monster = [_][]const u8{
                "                  # ",
                "#    ##    ##    ###",
                " #  #  #  #  #  #   ",
            };
            for (Vec2.all_tranfos) |t| {
                var j: i32 = 0;
                while (j < h) : (j += 1) {
                    var i: i32 = 0;
                    while (i < w) : (i += 1) {
                        replaceIfMatches(&monster, Vec2{ .x = i, .y = j }, t, big, w, h);
                    }
                }
            }
            if (false) {
                print("bigmap: \n", .{});
                var j: usize = 0;
                while (j < h) : (j += 1) {
                    print("{}\n", .{big[j * w .. (j + 1) * w]});
                }
            }
        }
        var nb_rocks: usize = 0;
        for (big) |it| {
            if (it == '#') nb_rocks += 1;
        }
        break :ans nb_rocks;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2020/input_day20.txt", run);
