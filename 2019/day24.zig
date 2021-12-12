const std = @import("std");
const tools = @import("tools");

const with_trace = false;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

//const Grid = @Vector(25, u1);       // marche pas vraiment vu les operations qu'on veut faire..
//const Grid = u25;                   // marche pas vraiment, pénible pour accéder aux bits..
const Grid = std.StaticBitSet(25);

const null_grid = Grid{ .mask = 0 };

fn trace_grid(header: []const u8, g: Grid) void {
    trace("{s}", .{header});
    var i: u32 = 0;
    while (i < 25) : (i += 1) {
        const c: u8 = if (g.isSet(i)) '#' else '.';
        if (i % 5 == 4) {
            trace("{c}\n", .{c});
        } else {
            trace("{c}", .{c});
        }
    }
}

const neibourgh_masks_part1: [25]Grid = blk: {
    @setEvalBranchQuota(4000);
    var neib = [1]Grid{null_grid} ** 25;
    for (neib) |*grid, i| {
        var j: u32 = 0;
        while (j < 25) : (j += 1) {
            grid.setValue(j, //
                (@boolToInt((i / 5) == (j / 5)) & (@boolToInt(i == j + 1) | @boolToInt(j == i + 1))) // same line
            | (@boolToInt(i == j + 5) | @boolToInt(j == i + 5)) != 0); // same column
        }
    }
    break :blk neib;
};

const neibourgh_masks_part2: [25][3]Grid = blk: {
    const NeighbourSquare = struct {
        l: i8, // relative grid layer
        i: u8, // sq index in the grid
    };
    const table = [5 * 5][8]?NeighbourSquare{
        [8]?NeighbourSquare{ .{ .l = 0, .i = 1 }, .{ .l = 0, .i = 5 }, .{ .l = -1, .i = 7 }, .{ .l = -1, .i = 11 }, null, null, null, null },
        [8]?NeighbourSquare{ .{ .l = 0, .i = 0 }, .{ .l = 0, .i = 2 }, .{ .l = 0, .i = 6 }, .{ .l = -1, .i = 7 }, null, null, null, null },
        [8]?NeighbourSquare{ .{ .l = 0, .i = 1 }, .{ .l = 0, .i = 3 }, .{ .l = 0, .i = 7 }, .{ .l = -1, .i = 7 }, null, null, null, null },
        [8]?NeighbourSquare{ .{ .l = 0, .i = 2 }, .{ .l = 0, .i = 4 }, .{ .l = 0, .i = 8 }, .{ .l = -1, .i = 7 }, null, null, null, null },
        [8]?NeighbourSquare{ .{ .l = 0, .i = 3 }, .{ .l = 0, .i = 9 }, .{ .l = -1, .i = 7 }, .{ .l = -1, .i = 13 }, null, null, null, null },

        [8]?NeighbourSquare{ .{ .l = 0, .i = 0 }, .{ .l = 0, .i = 6 }, .{ .l = 0, .i = 10 }, .{ .l = -1, .i = 11 }, null, null, null, null },
        [8]?NeighbourSquare{ .{ .l = 0, .i = 1 }, .{ .l = 0, .i = 5 }, .{ .l = 0, .i = 7 }, .{ .l = 0, .i = 11 }, null, null, null, null },
        [8]?NeighbourSquare{ .{ .l = 0, .i = 2 }, .{ .l = 0, .i = 6 }, .{ .l = 0, .i = 8 }, .{ .l = 1, .i = 0 }, .{ .l = 1, .i = 1 }, .{ .l = 1, .i = 2 }, .{ .l = 1, .i = 3 }, .{ .l = 1, .i = 4 } },
        [8]?NeighbourSquare{ .{ .l = 0, .i = 3 }, .{ .l = 0, .i = 7 }, .{ .l = 0, .i = 9 }, .{ .l = 0, .i = 13 }, null, null, null, null },
        [8]?NeighbourSquare{ .{ .l = 0, .i = 4 }, .{ .l = 0, .i = 8 }, .{ .l = 0, .i = 14 }, .{ .l = -1, .i = 13 }, null, null, null, null },

        [8]?NeighbourSquare{ .{ .l = 0, .i = 5 }, .{ .l = 0, .i = 11 }, .{ .l = 0, .i = 15 }, .{ .l = -1, .i = 11 }, null, null, null, null },
        [8]?NeighbourSquare{ .{ .l = 0, .i = 6 }, .{ .l = 0, .i = 10 }, .{ .l = 0, .i = 16 }, .{ .l = 1, .i = 0 }, .{ .l = 1, .i = 5 }, .{ .l = 1, .i = 10 }, .{ .l = 1, .i = 15 }, .{ .l = 1, .i = 20 } },
        [8]?NeighbourSquare{ null, null, null, null, null, null, null, null },
        [8]?NeighbourSquare{ .{ .l = 0, .i = 8 }, .{ .l = 0, .i = 14 }, .{ .l = 0, .i = 18 }, .{ .l = 1, .i = 4 }, .{ .l = 1, .i = 9 }, .{ .l = 1, .i = 14 }, .{ .l = 1, .i = 19 }, .{ .l = 1, .i = 24 } },
        [8]?NeighbourSquare{ .{ .l = 0, .i = 9 }, .{ .l = 0, .i = 13 }, .{ .l = 0, .i = 19 }, .{ .l = -1, .i = 13 }, null, null, null, null },

        [8]?NeighbourSquare{ .{ .l = 0, .i = 10 }, .{ .l = 0, .i = 16 }, .{ .l = 0, .i = 20 }, .{ .l = -1, .i = 11 }, null, null, null, null },
        [8]?NeighbourSquare{ .{ .l = 0, .i = 11 }, .{ .l = 0, .i = 15 }, .{ .l = 0, .i = 17 }, .{ .l = 0, .i = 21 }, null, null, null, null },
        [8]?NeighbourSquare{ .{ .l = 0, .i = 22 }, .{ .l = 0, .i = 16 }, .{ .l = 0, .i = 18 }, .{ .l = 1, .i = 20 }, .{ .l = 1, .i = 21 }, .{ .l = 1, .i = 22 }, .{ .l = 1, .i = 23 }, .{ .l = 1, .i = 24 } },
        [8]?NeighbourSquare{ .{ .l = 0, .i = 13 }, .{ .l = 0, .i = 17 }, .{ .l = 0, .i = 19 }, .{ .l = 0, .i = 23 }, null, null, null, null },
        [8]?NeighbourSquare{ .{ .l = 0, .i = 14 }, .{ .l = 0, .i = 18 }, .{ .l = 0, .i = 24 }, .{ .l = -1, .i = 13 }, null, null, null, null },

        [8]?NeighbourSquare{ .{ .l = 0, .i = 21 }, .{ .l = 0, .i = 15 }, .{ .l = -1, .i = 17 }, .{ .l = -1, .i = 11 }, null, null, null, null },
        [8]?NeighbourSquare{ .{ .l = 0, .i = 20 }, .{ .l = 0, .i = 22 }, .{ .l = 0, .i = 16 }, .{ .l = -1, .i = 17 }, null, null, null, null },
        [8]?NeighbourSquare{ .{ .l = 0, .i = 21 }, .{ .l = 0, .i = 23 }, .{ .l = 0, .i = 17 }, .{ .l = -1, .i = 17 }, null, null, null, null },
        [8]?NeighbourSquare{ .{ .l = 0, .i = 22 }, .{ .l = 0, .i = 24 }, .{ .l = 0, .i = 18 }, .{ .l = -1, .i = 17 }, null, null, null, null },
        [8]?NeighbourSquare{ .{ .l = 0, .i = 23 }, .{ .l = 0, .i = 19 }, .{ .l = -1, .i = 17 }, .{ .l = -1, .i = 13 }, null, null, null, null },
    };

    //@setEvalBranchQuota(4000);
    var neib = [1][3]Grid{[3]Grid{ null_grid, null_grid, null_grid }} ** 25;
    for (neib) |*layers, i| {
        for (table[i]) |maybe_square| {
            if (maybe_square) |sq| layers[1 + sq.l].set(sq.i);
        }
    }
    break :blk neib;
};

pub fn run(_: []const u8, allocator: std.mem.Allocator) tools.RunError![2][]const u8 {
    const text =
        \\ ..###
        \\ .####
        \\ ...#.
        \\ .#..#
        \\ #.###
    ;

    //const text =
    //    \\ ....#
    //    \\ #..#.
    //    \\ #..##
    //    \\ ..#..
    //    \\ #....
    //;

    const start_grid = comptime blk: {
        var g = null_grid;
        var i: u32 = 0;
        for (text) |c| {
            if (c == '.' or c == '#') {
                if (c == '#') g.set(i);
                i += 1;
            }
        }
        assert(i == 5 * 5);
        break :blk g;
    };

    const ans1 = ans: {
        const Visited = std.StaticBitSet(1 << 25); // 4Mo
        var visited = Visited.initEmpty();

        const neibourgh_masks = neibourgh_masks_part1;
        for (neibourgh_masks) |g| trace_grid("neibourgh_mask:\n", g);

        trace_grid("start_grid:\n", start_grid);
        var cur = start_grid;

        while (true) {
            const biodiversity = @intCast(usize, cur.mask) & 0b11111_11111_11111_11111_11111; // zig bug  u25->usize garbage bits
            if (visited.isSet(biodiversity)) {
                break :ans biodiversity;
            }
            visited.set(biodiversity);

            const next = step: {
                var new: Grid = undefined;
                var i: u32 = 0;
                while (i < 25) : (i += 1) {
                    //const count = @reduce(.Add, @as(@Vector(25, u4), cur & neibourgh_masks[i]));        // pfff.  TODO u25 + popcount...
                    const count = @popCount(u25, cur.mask & neibourgh_masks[i].mask);
                    if (cur.isSet(i)) {
                        new.setValue(i, (count == 1));
                    } else {
                        new.setValue(i, (count == 2 or count == 1));
                    }
                }
                break :step new;
            };
            cur = next;
        }
        unreachable;
    };

    const ans2 = ans: {
        const masks = neibourgh_masks_part2;

        var world = [1]Grid{null_grid} ** 300;
        world[world.len / 2] = start_grid;

        // ultime layer: zero padding
        // penultième layer: canari
        assert(world[0].mask == 0 and world[1].mask == 0 and world[world.len - 1].mask == 0 and world[world.len - 2].mask == 0);

        var minutes: u32 = 0;
        while (minutes < 200) : (minutes += 1) {
            const next = step: {
                var new: [world.len]Grid = undefined;
                new[0] = null_grid;
                new[world.len - 1] = null_grid;
                std.mem.set(Grid, &new, null_grid); // zig bug work-around (u25 vs padding bits for u32)
                for (new[1 .. world.len - 1]) |*layer, idx| {
                    var i: u32 = 0;
                    while (i < 25) : (i += 1) {
                        const count = 0 //
                        + @popCount(u25, world[(idx + 1) - 1].mask & masks[i][0].mask) //
                        + @popCount(u25, world[(idx + 1) + 0].mask & masks[i][1].mask) //
                        + @popCount(u25, world[(idx + 1) + 1].mask & masks[i][2].mask);

                        if (world[(idx + 1) + 0].isSet(i)) {
                            layer.setValue(i, (count == 1));
                        } else {
                            layer.setValue(i, (count == 2 or count == 1));
                        }
                    }
                }
                break :step new;
            };

            // assert((next[0].mask | next[1].mask | next[world.len - 1].mask | next[world.len - 2].mask) == 0);        // zig bug
            assert(@as(usize, (next[0].mask | next[1].mask | next[world.len - 1].mask | next[world.len - 2].mask)) & 0b11111_11111_11111_11111_11111 == 0);
            world = next;
        }

        var total: usize = 0;
        for (world) |layer| {
            // if (layer.mask != 0) trace_grid("layer :\n", layer);
            total += @popCount(u25, layer.mask);
        }
        break :ans total;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("", run);
