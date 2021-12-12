const std = @import("std");
const tools = @import("tools");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

const Vec2 = tools.Vec2;

fn iswall_at(p: Vec2) bool {
    if (p.x < 0 or p.y < 0) return true;
    const x = @intCast(u32, p.x);
    const y = @intCast(u32, p.y);
    const v = (x * x + 3 * x + 2 * x * y + y + y * y) + 1362;
    const bits = @popCount(u32, v);
    return (bits % 2) == 1;
}

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const limit = 1 * 1024 * 1024 * 1024;
    //const text = try std.fs.cwd().readFileAlloc(allocator, "day12.txt", limit);
    //defer allocator.free(text);

    const BFS = tools.BestFirstSearch(Vec2, void);
    var bfs = BFS.init(allocator);
    try bfs.insert(.{ .steps = 0, .rating = 0, .state = Vec2{ .x = 1, .y = 1 }, .trace = {} });
    while (bfs.pop()) |node| {
        //trace("{}\n", .{node.state});
        if (node.state.x == 31 and node.state.y == 39) {
            try stdout.print("steps = {}\n", .{@as(u32, node.steps)});
            //continue;
        }
        if (node.steps >= 50)
            continue;
        const dirs = [_]Vec2{ .{ .x = 0, .y = -1 }, .{ .x = -1, .y = 0 }, .{ .x = 0, .y = 1 }, .{ .x = 1, .y = 0 } };
        for (dirs) |d| {
            const p = Vec2{ .x = node.state.x + d.x, .y = node.state.y + d.y };
            if (iswall_at(p))
                continue;
            try bfs.insert(.{ .steps = node.steps + 1, .rating = node.rating + 1, .state = p, .trace = {} });
        }
    }
    try stdout.print("a = {}\n", .{bfs.visited.count()});
}
