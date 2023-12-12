const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub const main = tools.defaultMain("2023/day10.txt", run);
const Map = tools.Map(u8, 150, 150, false);
const Vec2 = tools.Vec2;

pub fn run(text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena_alloc = std.heap.ArenaAllocator.init(allocator);
    defer arena_alloc.deinit();
    const arena = arena_alloc.allocator();
    _ = arena;

    var map: Map = .{ .default_tile = '.' };
    map.initFromText(text);
    const start = map.find('S') orelse unreachable;

    // corrige le 'S' pour éviter de se compliqer la vie après (surtout part 2)
    const start_pipe: u8 = pipe: {
        const right = map.get(start + Vec2{ 1, 0 });
        const left = map.get(start + Vec2{ -1, 0 });
        const down = map.get(start + Vec2{ 0, 1 });
        const up = map.get(start + Vec2{ 0, -1 });

        const conn_up = if (up) |t| std.mem.indexOfScalar(u8, "|7F", t) != null else false;
        const conn_left = if (left) |t| std.mem.indexOfScalar(u8, "-FL", t) != null else false;
        const conn_down = if (down) |t| std.mem.indexOfScalar(u8, "|JL", t) != null else false;
        const conn_right = if (right) |t| std.mem.indexOfScalar(u8, "-7J", t) != null else false;
        assert(@as(u8, 0) + @intFromBool(conn_up) + @intFromBool(conn_left) + @intFromBool(conn_down) + @intFromBool(conn_right) == 2);

        if (conn_up and conn_left) break :pipe 'J';
        if (conn_up and conn_right) break :pipe 'L';
        if (conn_down and conn_left) break :pipe '7';
        if (conn_down and conn_right) break :pipe 'F';
        unreachable;
    };
    map.set(start, start_pipe);

    // calcule le tuyau, en propageant la distance depuis le start
    const MapDist = tools.Map(u16, 150, 150, false);
    var pipeloop: MapDist = .{ .default_tile = 0xFFFF };
    {
        pipeloop.set(start, 0);

        var agenda_buf: [2]Vec2 = undefined; // il y a les deux directions à parcourir depuis le départ, mais après c'est linéaire il n'y a jamais de backtracking
        var agenda = std.ArrayListUnmanaged(Vec2).initBuffer(&agenda_buf);
        agenda.appendAssumeCapacity(start);

        while (agenda.items.len > 0) {
            const p = agenda.pop();
            const t0 = map.at(p);
            const d = pipeloop.at(p);

            const neib = .{
                p + Vec2{ 1, 0 },
                p + Vec2{ -1, 0 },
                p + Vec2{ 0, 1 },
                p + Vec2{ 0, -1 },
            };
            const connect_to = .{
                "-J7",
                "-LF",
                "|LJ",
                "|7F",
            };
            const connect_from = .{
                "-LF",
                "-J7",
                "|7F",
                "|LJ",
            };
            var dbg_conn_count: u32 = 0;
            inline for (neib, connect_to, connect_from) |p1, to, from| {
                if (map.get(p1)) |t1| {
                    const connected = std.mem.indexOfScalar(u8, from, t0) != null and std.mem.indexOfScalar(u8, to, t1) != null;
                    if (connected) {
                        assert(d + 1 < 0xFFFF);
                        const d1 = pipeloop.get(p1) orelse 0xFFFF;
                        if (d1 > d + 1) {
                            pipeloop.set(p1, d + 1);
                            agenda.appendAssumeCapacity(p1);
                            dbg_conn_count += 1;
                        }
                    }
                }
            }
            assert(dbg_conn_count <= 2);
        }
    }

    // part1 : on a déjà calculé les distances dans pipeloop
    const ans1 = ans: {
        var maxdist: u32 = 0;
        var it = pipeloop.iter(null);
        while (it.next()) |d| {
            if (d != 0xFFFF)
                maxdist = @max(maxdist, d);
        }
        break :ans maxdist;
    };

    // part2: on rasterize, et on compte la partié à chaque fois qu'on croise un tuyau vertical.
    //  piège:
    //        ┃
    //  ---- ┍┙ <- croisement     ┍━┑  <- PAS un croisement vertical
    //       ┃      vertical      ┃ ┃
    //
    const ans2 = ans: {
        var p0 = pipeloop.bbox.min;
        var sum: u32 = 0;
        while (p0[1] <= pipeloop.bbox.max[1]) : (p0 += .{ 0, 1 }) {
            var in = false;
            var on_pipe: enum { off, down, up } = .off; // quand on a rencontré le tyuau il venait depuis où?
            var p = p0;
            while (p[0] <= pipeloop.bbox.max[0]) : (p += .{ 1, 0 }) {
                const is_part_of_loop = pipeloop.at(p) != 0xFFFF;
                if (!is_part_of_loop) {
                    sum += @intFromBool(in);
                    continue;
                }

                switch (map.at(p)) {
                    else => unreachable,
                    '|' => {
                        assert(on_pipe == .off);
                        in = !in;
                    },
                    '-' => assert(on_pipe != .off),
                    '7' => switch (on_pipe) {
                        .off => unreachable,
                        .down => {
                            on_pipe = .off;
                            in = !in;
                        },
                        .up => on_pipe = .off,
                    },
                    'J' => switch (on_pipe) {
                        .off => unreachable,
                        .up => {
                            on_pipe = .off;
                            in = !in;
                        },
                        .down => on_pipe = .off,
                    },
                    'F' => switch (on_pipe) {
                        .down, .up => unreachable,
                        .off => {
                            on_pipe = .down;
                            in = !in;
                        },
                    },
                    'L' => switch (on_pipe) {
                        .down, .up => unreachable,
                        .off => {
                            on_pipe = .up;
                            in = !in;
                        },
                    },
                }
            }
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
        \\.....
        \\.S-7.
        \\.|.|.
        \\.L-J.
        \\.....
    , std.testing.allocator);
    defer std.testing.allocator.free(res1[0]);
    defer std.testing.allocator.free(res1[1]);
    try std.testing.expectEqualStrings("4", res1[0]);
    try std.testing.expectEqualStrings("1", res1[1]);

    const res2 = try run(
        \\-L|F7
        \\7S-7|
        \\L|7||
        \\-L-J|
        \\L|-JF
    , std.testing.allocator);
    defer std.testing.allocator.free(res2[0]);
    defer std.testing.allocator.free(res2[1]);
    try std.testing.expectEqualStrings("4", res2[0]);
    try std.testing.expectEqualStrings("1", res2[1]);

    const res3 = try run(
        \\7-F7-
        \\.FJ|7
        \\SJLL7
        \\|F--J
        \\LJ.LJ
    , std.testing.allocator);
    defer std.testing.allocator.free(res3[0]);
    defer std.testing.allocator.free(res3[1]);
    try std.testing.expectEqualStrings("8", res3[0]);
    try std.testing.expectEqualStrings("1", res3[1]);

    const res4 = try run(
        \\...........
        \\.S-------7.
        \\.|F-----7|.
        \\.||.....||.
        \\.||.....||.
        \\.|L-7.F-J|.
        \\.|..|.|..|.
        \\.L--J.L--J.
        \\...........
    , std.testing.allocator);
    defer std.testing.allocator.free(res4[0]);
    defer std.testing.allocator.free(res4[1]);
    try std.testing.expectEqualStrings("23", res4[0]);
    try std.testing.expectEqualStrings("4", res4[1]);

    const res5 = try run(
        \\..........
        \\.S------7.
        \\.|F----7|.
        \\.||....||.
        \\.||....||.
        \\.|L-7F-J|.
        \\.|..||..|.
        \\.L--JL--J.
        \\..........
    , std.testing.allocator);
    defer std.testing.allocator.free(res5[0]);
    defer std.testing.allocator.free(res5[1]);
    try std.testing.expectEqualStrings("22", res5[0]);
    try std.testing.expectEqualStrings("4", res5[1]);

    const res6 = try run(
        \\.F----7F7F7F7F-7....
        \\.|F--7||||||||FJ....
        \\.||.FJ||||||||L7....
        \\FJL7L7LJLJ||LJ.L-7..
        \\L--J.L7...LJS7F-7L7.
        \\....F-J..F7FJ|L7L7L7
        \\....L7.F7||L7|.L7L7|
        \\.....|FJLJ|FJ|F7|.LJ
        \\....FJL-7.||.||||...
        \\....L---J.LJ.LJLJ...
    , std.testing.allocator);
    defer std.testing.allocator.free(res6[0]);
    defer std.testing.allocator.free(res6[1]);
    try std.testing.expectEqualStrings("70", res6[0]);
    try std.testing.expectEqualStrings("8", res6[1]);

    const res7 = try run(
        \\FF7FSF7F7F7F7F7F---7
        \\L|LJ||||||||||||F--J
        \\FL-7LJLJ||||||LJL-77
        \\F--JF--7||LJLJ7F7FJ-
        \\L---JF-JLJ.||-FJLJJ7
        \\|F|F-JF---7F7-L7L|7|
        \\|FFJF7L7F-JF7|JL---7
        \\7-L-JL7||F7|L7F-7F7|
        \\L.L7LFJ|||||FJL7||LJ
        \\L7JLJL-JLJLJL--JLJ.L
    , std.testing.allocator);
    defer std.testing.allocator.free(res7[0]);
    defer std.testing.allocator.free(res7[1]);
    try std.testing.expectEqualStrings("80", res7[0]);
    try std.testing.expectEqualStrings("10", res7[1]);
}
