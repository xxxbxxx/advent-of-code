const std = @import("std");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

const gsize = 100;
const Grid = [gsize * gsize]u1;

fn readgrid(g: Grid, x: i32, y: i32) u32 {
    if (x < 0 or x >= gsize) return 0;
    if (y < 0 or y >= gsize) return 0;
    return g[@intCast(usize, y * gsize + x)];
}
fn compute_next(init: Grid) Grid {
    var g: Grid = undefined;
    var y: i32 = 0;
    while (y < gsize) : (y += 1) {
        var x: i32 = 0;
        while (x < gsize) : (x += 1) {
            const neib: u32 = readgrid(init, x - 1, y - 1) + readgrid(init, x, y - 1) + readgrid(init, x + 1, y - 1) + readgrid(init, x - 1, y) + readgrid(init, x + 1, y) + readgrid(init, x - 1, y + 1) + readgrid(init, x, y + 1) + readgrid(init, x + 1, y + 1);
            const wason = readgrid(init, x, y) != 0;
            g[@intCast(usize, y * gsize + x)] = if ((wason and (neib == 2 or neib == 3)) or (!wason and neib == 3)) 1 else 0;
        }
    }
    g[@intCast(usize, 0 * gsize + 0)] = 1;
    g[@intCast(usize, (gsize - 1) * gsize + 0)] = 1;
    g[@intCast(usize, (gsize - 1) * gsize + (gsize - 1))] = 1;
    g[@intCast(usize, 0 * gsize + (gsize - 1))] = 1;
    return g;
}

fn parse_line(line: []const u8) ?u32 {
    const trimmed = std.mem.trim(u8, line, " \n\r\t");
    if (trimmed.len == 0)
        return null;

    return std.fmt.parseInt(u32, trimmed, 10) catch unreachable;
}

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day18.txt", limit);

    const init_grid = blk: {
        var g: Grid = undefined;
        var i: u32 = 0;
        for (text) |c| {
            switch (c) {
                '#' => {
                    g[i] = 1;
                    i += 1;
                },
                '.' => {
                    g[i] = 0;
                    i += 1;
                },
                else => continue,
            }
        }
        break :blk g;
    };

    var steps: [100]Grid = undefined;
    for (steps) |s, i| {
        s = compute_next(if (i == 0) init_grid else steps[i - 1]);
    }

    var nlights: u32 = 0;
    for (steps[99]) |l| {
        if (l != 0) nlights += 1;
    }

    const out = std.io.getStdOut().writer();
    try out.print("ans = {}\n", nlights);

    //    return error.SolutionNotFound;
}
