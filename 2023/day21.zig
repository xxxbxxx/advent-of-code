const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub const main = tools.defaultMain("2023/day21.txt", run);
const Map = tools.Map(u8, 2048, 2048, true);
const Vec2 = tools.Vec2;

const debug = false;

fn computeReachableTiles(allocator: std.mem.Allocator, map: *const Map, comptime infinite_tiling: bool, start: Vec2, nb_steps: u32) !u32 {
    // optimisation: pour éviter l'explosion combinatoire, on sait que si on a visité un endroit, on peut y revenir à volonté en deux pas. (retour + aller)
    // donc pas la peine de revisiter les cases pour savoir qu'on peu les atteindre avec le nombre exact de pas, on fait un floodfill.

    if (infinite_tiling) {
        assert(map.bbox.min[0] == 0 and map.bbox.min[1] == 0);
    }

    const Entry = struct {
        p: Vec2,
        steps_todo: u32,
        fn order(_: void, a: @This(), b: @This()) std.math.Order {
            return std.math.order(b.steps_todo, a.steps_todo); // bfs
        }
    };

    var visited = std.AutoHashMap(Vec2, if (debug) u8 else void).init(allocator); // TODO: un tableau 2D (Map), on caonnait la borne sup de la taille nb_steps*nb_steps*4
    defer visited.deinit();
    var agenda = std.PriorityQueue(Entry, void, Entry.order).init(allocator, {});
    defer agenda.deinit();

    try agenda.add(.{ .p = start, .steps_todo = nb_steps });
    var count: u32 = 0;
    while (agenda.removeOrNull()) |it| {
        const ns = it.steps_todo - 1;
        for (tools.Vec.cardinal4_dirs) |dir| {
            const p = it.p + dir;
            if (infinite_tiling) {
                if (map.at(@mod(p, map.bbox.max + Vec2{ 1, 1 })) == '#')
                    continue;
            } else {
                if (!map.bbox.includes(p))
                    continue;
                if (map.at(p) == '#')
                    continue;
            }
            const visit = try visited.getOrPut(p);
            if (visit.found_existing) {
                if (debug) assert(visit.value_ptr.* % 2 == ns % 2);
                continue;
            }
            if (debug) visit.value_ptr.* = @intCast(ns);

            if (ns % 2 == 0)
                count += 1; // on compte au fur et à mesure, en se basant sur le fait que n'importe quel endroit visité reste bon pour le nombre de pas voulu si on fait un aller retour.
            if (ns >= 1)
                try agenda.add(.{ .p = p, .steps_todo = ns });
        }
    }

    // debug:
    if (debug) {
        var dbgmap: Map = map.*;
        var it = visited.iterator();
        var cnt: u32 = 0;
        while (it.next()) |entry| {
            cnt += @intFromBool(entry.value_ptr.* % 2 == 0);
            if (entry.value_ptr.* % 2 == 0)
                dbgmap.set(entry.key_ptr.*, '0' + entry.value_ptr.*);
        }
        dbgmap.set(start, 'S');
        assert(cnt == count);
        var buf: [100000]u8 = undefined;
        std.debug.print("after {} steps, starting from {} reached {} tiles:\n{s}\n", .{ nb_steps, start, cnt, dbgmap.printToBuf(&buf, .{}) });
    }

    return count;
}

pub fn run(text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena_alloc = std.heap.ArenaAllocator.init(allocator);
    defer arena_alloc.deinit();
    const arena = arena_alloc.allocator();
    _ = arena;

    var map: Map = .{ .default_tile = '.' };
    map.initFromText(text);
    const center = map.bbox.max / Vec2{ 2, 2 };
    assert(map.at(center) == 'S');
    const is_example = (map.bbox.max[0] < 15);

    const ans1 = ans: {
        const nb_steps: u32 = if (is_example) 6 else 64;
        break :ans try computeReachableTiles(allocator, &map, false, center, nb_steps);
    };

    const ans2 = ans: {
        const target_steps: u32 = if (is_example) 5000 else 26501365; // 26501365 = size*19093 + size/2 (pour aller au bord)	size = 131   (+ louche: diamant dans l'input + les lignes horiz et verticales sans obstacles)
        var map_steps: [2]Map = .{ .{ .default_tile = '.' }, .{ .default_tile = '.' } };
        map_steps[0].set(center, 'S');
        const size: u32 = @intCast(map.bbox.max[0] + 1);
        const period = size * 2; // à cause de la taille imparire, un coup on rentre dans le bloc avec un nombre de pas pair, un coup impair.  en faisant *2 pour la période, ça rend tout ça pair.
        const offset = target_steps % period;

        var history: [4]i32 = .{ 0, 0, 0, 0 };
        var steps = offset;
        while (steps <= target_steps) : (steps += period) {
            const tiles = try computeReachableTiles(allocator, &map, true, center, steps);
            history[0..3].* = history[1..4].*;
            history[3] = @intCast(tiles);
            const deriv_1 = .{ history[1] - history[0], history[2] - history[1], history[3] - history[2] };
            const deriv_2 = .{ deriv_1[1] - deriv_1[0], deriv_1[2] - deriv_1[1] };
            const deriv_3 = deriv_2[1] - deriv_2[0];

            //std.debug.print("steps= {}, tiles={}, 1ère dérivée={}, 2ème dérivée={}, 3ème dérivée ={}\n", .{ steps, tiles, deriv_1, deriv_2, deriv_3 });

            if (deriv_3 == 0) {
                // bon... à cause des données en input qui ont plein d'espace vide autour du bord, ça finit par se stabiliser et être juste quadratique.
                break;
            }
        }

        {
            // f(x) = computeReachableTiles(..., x)
            // f(x) = ax²+bx+c
            // f'(x) = 2ax+b
            // f''(x) = 2a
            // f'''(x) = 0

            const d: f64 = @floatFromInt(period);

            const x0: f64 = @floatFromInt(steps - 3 * period);

            const deriv_1 = .{ @as(f64, @floatFromInt(history[1] - history[0])) / d, @as(f64, @floatFromInt(history[2] - history[1])) / d };
            const deriv_2 = (deriv_1[1] - deriv_1[0]) / d;

            const a = deriv_2 / 2;
            const b = deriv_1[0] - a * (2 * x0 + d);
            const c = @as(f64, @floatFromInt(history[0])) - (a * x0 + b) * x0;
            //std.debug.print("a={}, b={}, c={}\n", .{ a, b, c });

            inline for (.{ steps - 3 * period, steps - 2 * period, steps - 1 * period, steps - 0 * period }, 0..) |xx, i| {
                const x: f64 = @floatFromInt(xx);
                assert(history[i] == @as(i64, @intFromFloat(@round(a * x * x + b * x + c))));
            }

            const x_target: f64 = @floatFromInt(target_steps);
            break :ans @as(i64, @intFromFloat(@round(a * x_target * x_target + b * x_target + c)));
        }

        // tests qui n'ont pas abouti en regardant pas à pas plutot que en sautant periode par période
        //  et en essayant de distinguer le nouveau périmètre qui cahnge et le centre invariant
        //  peut-être qu'il aurait faire plus d'itérations: je pense que ça devrait aussi être périodique quand ça se stabilise, mais j'ai jamais tout à fait réussi.

        //        var progression = try allocator.alloc(struct { quotient: u32 = 0, reste: u32 = 0 }, period * 4);
        //        defer allocator.free(progression);
        //        @memset(progression, .{});
        //        const base_steps: u32 = @intCast(period * 24);
        //        var base_count: u32 = 0;

        //        {
        //            var total: u32 = 1;
        //            base_count = 1;
        //            {
        //                std.debug.print("\n## step {}:", .{base_steps});
        //                for (1..base_steps + 1) |rr| {
        //                    var tip_counts: [4]u32 = .{0,0,0,0};
        //                    var edge_counts: [4]u32 = .{0,0,0,0};
        //                    var tip_total: [4]u32 = .{0,0,0,0};
        //                    var edge_total: [4]u32 = .{0,0,0,0};
        //                    const r: i32 = @intCast(rr);
        //                    for (0..rr) |ss| {
        //                        const s: i32 = @intCast(ss);
        //                        inline for (.{
        //                            center + Vec2{ 0, r } + Vec2{ s, -s },
        //                            center + Vec2{ r, 0 } + Vec2{ -s, -s },
        //                            center + Vec2{ 0, -r } + Vec2{ -s, s },
        //                            center + Vec2{ -r, 0 } + Vec2{ s, s },
        //                        }, 0..) |p, side| {
        //                            const is_tip = s < size / 2 or s >= rr - size / 2;
        //                            if (is_tip) {
        //                                tip_counts[side] += @intFromBool((map_steps[base_steps % 2].get(p) orelse '.') == 'S');
        //                                tip_total[side] += 1;
        //                            } else {
        //                                edge_counts[side] += @intFromBool((map_steps[base_steps % 2].get(p) orelse '.') == 'S');
        //                                edge_total[side] += 1;
        //                            }
        //                        }
        //                    }
        //
        //                    var perimeter: u32 = 0;
        //                    for (0..4) |side| {
        //                        base_count += tip_counts[side] + edge_counts[side];
        //                        total += tip_total[side] + edge_total[side];
        //                        perimeter += tip_total[side] + edge_total[side];
        //                        //std.debug.print("r={:3}: permiter={}/{}\n", .{rr, permiter_counts, perimter_total});
        //                    }
        //                    assert(perimeter == (4 * rr));
        //
        //                    {
        //                        const blocks: u64 = if (rr < size / 2) 0 else ((rr - size / 2) / size);
        //                        if (blocks * size + size / 2 == rr)
        //                            std.debug.print("\n", .{});
        //                        std.debug.print("(r={:3}: ", .{rr});
        //                        for (0..4) |side| {
        //                            const quotient: u32 = @intCast(if (blocks == 0) 0 else edge_counts[side] / blocks);
        //                            const reste: u32 = @intCast(edge_counts[side] - quotient * blocks);
        //                            assert(reste <= size);
        //                            std.debug.print("{:2}*{}+{}, ", .{ blocks, quotient, reste });
        //                            progression[rr % progression.len] = .{ .quotient = quotient, .reste = reste };
        //                        }
        //                        std.debug.print("), ", .{});
        //                    }
        //                }
        //            }
        //        }
        //        std.debug.print("\n\n", .{});
        //        std.debug.print("base_count={}, progression={any}\n", .{ base_count, progression[0..period] });
        //        std.debug.print("progression2={any}\n", .{progression[period..][0..period]});
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

test {
    const res1 = try run(
        \\...........
        \\.....###.#.
        \\.###.##..#.
        \\..#.#...#..
        \\....#.#....
        \\.##..S####.
        \\.##..#...#.
        \\.......##..
        \\.##.#.####.
        \\.##..##.##.
        \\...........
    , std.testing.allocator);
    defer std.testing.allocator.free(res1[0]);
    defer std.testing.allocator.free(res1[1]);
    try std.testing.expectEqualStrings("16", res1[0]); // 6 steps
    try std.testing.expectEqualStrings("16733044", res1[1]); // 5000 steps
}
