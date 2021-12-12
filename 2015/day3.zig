const std = @import("std");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

fn min3(a: anytype, b: anytype, c: anytype) u32 {
    if (a < b) {
        return if (a < c) a else c;
    } else {
        return if (b < c) b else c;
    }
}

const Vec2 = struct {
    x: u32,
    y: u32,
};
pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day3.txt", limit);

    const grid_size = 20000;
    var grid = try allocator.alloc(bool, grid_size * grid_size);
    defer allocator.free(grid);

    var pos = [1]Vec2{.{ .x = grid_size / 2, .y = grid_size / 2 }} ** 2;
    {
        const p = pos[0];
        grid[p.x + p.y * grid_size] = true;
    }
    var turn: u32 = 0;
    for (text) |c| {
        const p = &pos[turn];
        turn = 1 - turn;
        switch (c) {
            '^' => p.y -= 1,
            'v' => p.y += 1,
            '<' => p.x -= 1,
            '>' => p.x += 1,
            else => unreachable,
        }
        grid[p.x + p.y * grid_size] = true;
    }

    var houses: u32 = 0;
    for (grid) |g| {
        if (g)
            houses += 1;
    }
    const out = std.io.getStdOut().writer();
    try out.print("houess={} \n", houses);

    //    return error.SolutionNotFound;
}
