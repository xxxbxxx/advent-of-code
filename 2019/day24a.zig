const std = @import("std");
const tools = @import("tools");

const with_trace = true;
const with_dissassemble = false;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

const Map = tools.Map(u8, 5, 5, false);
const Vec2 = tools.Vec2;

fn dostep(grid: Map) Map {
    var new = Map{ .default_tile = 0 };
    var p = grid.bbox.min;
    while (p.y <= grid.bbox.max.y) : (p.y += 1) {
        p.x = grid.bbox.min.x;
        while (p.x <= grid.bbox.max.x) : (p.x += 1) {
            const neighbours = [_]Vec2{ Vec2{ .x = -1, .y = 0 }, Vec2{ .x = 1, .y = 0 }, Vec2{ .x = 0, .y = -1 }, Vec2{ .x = 0, .y = 1 } };
            var nbneib: u32 = 0;
            for (neighbours) |n| {
                const g = grid.get(Vec2{ .x = p.x + n.x, .y = p.y + n.y }) orelse '.';
                if (g == '#')
                    nbneib += 1;
            }

            const g = grid.at(p);
            if (g == '#' and nbneib != 1) {
                new.set(p, '.');
            } else if (g == '.' and (nbneib == 1 or nbneib == 2)) {
                new.set(p, '#');
            } else {
                new.set(p, g);
            }
        }
    }
    return new;
}
pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().writer();
    _ = stdout;
    const allocator = &std.heap.ArenaAllocator.init(std.heap.page_allocator).allocator;
    const limit = 1 * 1024 * 1024 * 1024;
    _ = limit;

    const text =
        \\ ..###
        \\ .####
        \\ ...#.
        \\ .#..#
        \\ #.###
    ;

    const text0 =
        \\ ....#
        \\ #..#.
        \\ #..##
        \\ ..#..
        \\ #....
    ;
    _ = text0;

    var grid = Map{ .default_tile = 0 };
    var i: u32 = 0;
    for (text) |c| {
        if (c == '.' or c == '#') {
            const p = Vec2{ .x = @intCast(i % 5), .y = @intCast(i / 5) };
            grid.set(p, c);
            i += 1;
        }
    }

    var buf: [5000]u8 = undefined;
    trace("map= \n{}\n", .{grid.printToBuf(Vec2{ .x = -1, .y = -1 }, null, &buf)});

    var visited = std.AutoHashMap(Map, bool).init(allocator);
    _ = try visited.put(grid, true);

    while (true) {
        grid = dostep(grid);
        trace("map= \n{}\n", .{grid.printToBuf(Vec2{ .x = -1, .y = -1 }, null, &buf)});
        if (try visited.put(grid, true)) |_| {
            trace("repeat!\n", .{});

            const biodiversity = blk: {
                var b: u25 = 0;
                var sq: u32 = 1;
                for (grid.map) |m| {
                    if (m == '#')
                        b += @intCast(sq);
                    sq *= 2;
                }
                break :blk b;
            };
            trace("biodiversity = {}\n", .{biodiversity});
            break;
        }
    }
}
