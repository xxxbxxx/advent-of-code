const std = @import("std");
const tools = @import("tools");

const with_trace = false;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}
const assert = std.debug.assert;

pub const main = tools.defaultMain("2021/day20.txt", run);

const Map = tools.Map(u8, 256, 256, true);
const Vec2 = tools.Vec2;

pub fn run(input: []const u8, gpa: std.mem.Allocator) tools.RunError![2][]const u8 {
    //    var arena_alloc = std.heap.ArenaAllocator.init(gpa);
    //    defer arena_alloc.deinit();
    //    const arena = arena_alloc.allocator();

    var map = Map{ .default_tile = '.' };

    var it0 = std.mem.tokenize(u8, input, "\n");
    const dico = it0.next().?;
    assert(dico.len == 512);
    // assert(dico[0] == '.'); ahahahahaahahah
    assert(dico[0] == '.' or dico[511] == '.');

    var p = Vec2{ -50, -50 };
    while (it0.next()) |line| : (p += Vec2{ 0, 1 }) {
        map.setLine(p, line);
    }

    const ans = ans: {
        if (with_trace) {
            var buf: [15000]u8 = undefined;
            trace("gen {}:\n{s}", .{ 0, map.printToBuf(&buf, .{}) });
        }

        var map2 = Map{ .default_tile = '.' };
        const flipflop = [_]*Map{ &map, &map2 };

        var population: [50]u32 = undefined;

        for (&population, 0..) |*pop, gen| {
            const cur = flipflop[gen % 2];
            const next = flipflop[1 - gen % 2];
            next.bbox = tools.BBox.empty;
            cur.default_tile = if (gen % 2 == 0) '.' else dico[0];
            next.default_tile = if (1 - gen % 2 == 0) '.' else dico[0];

            // extend bbox:
            cur.set(cur.bbox.min + Vec2{ -1, -1 }, cur.default_tile);
            cur.set(cur.bbox.max + Vec2{ 1, 1 }, cur.default_tile);

            var it = cur.iter(null);
            var popcount: u32 = 0;
            while (it.nextEx()) |sq| {
                const key = 0 //
                | @as(u9, @intFromBool((sq.up_left orelse cur.default_tile) != '.')) << 8 //
                | @as(u9, @intFromBool((sq.up orelse cur.default_tile) != '.')) << 7 //
                | @as(u9, @intFromBool((sq.up_right orelse cur.default_tile) != '.')) << 6 //
                //
                | @as(u9, @intFromBool((sq.left orelse cur.default_tile) != '.')) << 5 //
                | @as(u9, @intFromBool(sq.t.* != '.')) << 4 //
                | @as(u9, @intFromBool((sq.right orelse cur.default_tile) != '.')) << 3 //
                //
                | @as(u9, @intFromBool((sq.down_left orelse cur.default_tile) != '.')) << 2 //
                | @as(u9, @intFromBool((sq.down orelse cur.default_tile) != '.')) << 1 //
                | @as(u9, @intFromBool((sq.down_right orelse cur.default_tile) != '.')) << 0 //
                ;

                next.set(sq.p, dico[key]);
                popcount += @intFromBool(dico[key] != '.');
            }

            if (gen % 2 == 1) {
                pop.* = popcount;
            } else {
                // undef, infinite.
            }
            if (with_trace) {
                var buf: [100000]u8 = undefined;
                trace("gen {}:\n{s}", .{ gen + 1, next.printToBuf(&buf, .{}) });
            }
        }
        break :ans [2]u32{ population[1], population[49] };
    };

    return [_][]const u8{
        try std.fmt.allocPrint(gpa, "{}", .{ans[0]}),
        try std.fmt.allocPrint(gpa, "{}", .{ans[1]}),
    };
}

test {
    {
        const res = try run(
            \\..#.#..#####.#.#.#.###.##.....###.##.#..###.####..#####..#....#..#..##..###..######.###...####..#..#####..##..#.#####...##.#.#..#.##..#.#......#.###.######.###.####...#.##.##..#..#..#####.....#.#....###..#.##......#.....#..#..#..##..#...##.######.####.####.#.#...#.......#..#.#.#...####.##.#......#..#...##.#.##..#...##.#.##..###.#......#.#.......#.#.#.####.###.##...#.....####.#..#..#.##.#....##..#.####....##...##..#...#......#.#.......#.......##..####..#...#.#.#...##..#.#..###..#####........#..####......#..#
            \\
            \\#..#.
            \\#....
            \\##..#
            \\..#..
            \\..###
        , std.testing.allocator);
        defer std.testing.allocator.free(res[0]);
        defer std.testing.allocator.free(res[1]);
        try std.testing.expectEqualStrings("35", res[0]);
        try std.testing.expectEqualStrings("3351", res[1]);
    }

    {
        const res = try run(
            \\#.#.##..#..#..###.#.#....#.########.#.##.#..#.###..###.##.#.##.#.#.....#..##.#.#..###.###.######..#.#..#######.#..#....####..###.####.###.#.#######.#...#...#.##.###..###..##.#.#.###........##.#.....#.##.#.####...#...#.#..###.#.#...#....#...####..#.########.#...#.####.#####..#.#.###......#.##...###..##..#.#..#....#..###.#.##.....##.#####..##.####.#.###....##.###...#.##....##.#..#.#..#..#.##...#.##..#####.####.#.##...##...##...#.##.#.#.####..##...#.....#......#.#......#..###..#..##..##.###..#####..#..##.#..#.
            \\
            \\#..#.
            \\#....
            \\##..#
            \\..#..
            \\..###
        , std.testing.allocator);
        defer std.testing.allocator.free(res[0]);
        defer std.testing.allocator.free(res[1]);
        try std.testing.expectEqualStrings("37", res[0]);
        try std.testing.expectEqualStrings("4953", res[1]);
    }

    { // conway's game of life:
        const res = try run(
            \\.......#...#.##....#.###.######....#.##..##.#....######.###.#......#.##..##.#....######.###.#....##.#...#.......###.#...#..........#.##..##.#....######.###.#....##.#...#.......###.#...#........##.#...#.......###.#...#.......#...............#..................#.##..##.#....######.###.#....##.#...#.......###.#...#........##.#...#.......###.#...#.......#...............#................##.#...#.......###.#...#.......#...............#...............#...............#...............................................
            \\
            \\#..#.
            \\#....
            \\##..#
            \\..#..
            \\..###
        , std.testing.allocator);
        defer std.testing.allocator.free(res[0]);
        defer std.testing.allocator.free(res[1]);
        try std.testing.expectEqualStrings("11", res[0]);
        try std.testing.expectEqualStrings("114", res[1]);
    }
}
