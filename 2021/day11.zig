const std = @import("std");
const tools = @import("tools");

const with_trace = false;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}
const assert = std.debug.assert;

pub const main = tools.defaultMain("2021/day11.txt", run);

const Vec2 = tools.Vec2;
const Map = tools.Map(u8, 10, 10, false);

pub fn run(input: []const u8, gpa: std.mem.Allocator) tools.RunError![2][]const u8 {
    const init = blk: {
        var map = Map{ .default_tile = 0 };
        var it = std.mem.tokenize(u8, input, "\n");
        var p = Vec2{ 0, 0 };
        while (it.next()) |line| : (p += Vec2{ 0, 1 }) {
            map.setLine(p, std.mem.trim(u8, line, " \t\r\n"));
        }
        break :blk map;
    };
    {
        var buf: [128]u8 = undefined;
        trace("initial: (size={})\n{s}\n", .{ init.bbox.size(), init.printToBuf(&buf, .{}) });
    }

    const ans = ans: {
        var gen: u32 = 1;
        var accu_flashes_to100: u32 = 0;
        var state = init;
        while (true) : (gen += 1) {
            state.fillIncrement(1, init.bbox);

            var flashed = Map{ .default_tile = 0 };
            // do the flashes
            {
                var flashes: u32 = 0;
                flashed.fill(0, init.bbox);
                var dirty = true;
                while (dirty) {
                    dirty = false;
                    var it = state.iter(null);

                    while (it.nextEx()) |t| {
                        if (t.t.* > '9' and flashed.at(t.p) == 0) {
                            dirty = true;
                            flashed.set(t.p, 1);
                            flashes += 1;
                            for (tools.Vec.cardinal8_dirs) |d| {
                                if (state.get(t.p + d)) |n| {
                                    state.set(t.p + d, n +| 1);
                                }
                            }
                        }
                    }
                }
                if (gen <= 100)
                    accu_flashes_to100 += flashes;
                if (flashes == init.bbox.size()) {
                    trace("all flashes at {}\n", .{gen});
                    break;
                }
            }

            // consume energy
            {
                var it = state.iter(null);
                while (it.nextEx()) |t| {
                    if (t.t.* > '9') t.t.* = '0';
                }

                var buf: [128]u8 = undefined;
                trace("gen{}:\n{s}\n", .{ gen, state.printToBuf(&buf, .{}) });
            }
        }
        break :ans [2]u32{ accu_flashes_to100, gen };
    };

    return [_][]const u8{
        try std.fmt.allocPrint(gpa, "{}", .{ans[0]}),
        try std.fmt.allocPrint(gpa, "{}", .{ans[1]}),
    };
}

test {
    const res0 = try run(
        \\11111
        \\19991
        \\19191
        \\19991
        \\11111
    , std.testing.allocator);
    defer std.testing.allocator.free(res0[0]);
    defer std.testing.allocator.free(res0[1]);

    const res = try run(
        \\5483143223
        \\2745854711
        \\5264556173
        \\6141336146
        \\6357385478
        \\4167524645
        \\2176841721
        \\6882881134
        \\4846848554
        \\5283751526
    , std.testing.allocator);
    defer std.testing.allocator.free(res[0]);
    defer std.testing.allocator.free(res[1]);
    try std.testing.expectEqualStrings("1656", res[0]);
    try std.testing.expectEqualStrings("195", res[1]);
}
