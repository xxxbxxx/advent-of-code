const std = @import("std");
const tools = @import("tools");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const md5 = std.crypto.Md5.init();

    const Vec2 = tools.Vec2;
    const BFS = tools.BestFirstSearch([]const u8, Vec2);
    var bfs = BFS.init(allocator);

    try bfs.insert(.{
        .rating = 0,
        .steps = 0,
        .state = "",
        .trace = Vec2{ .x = 0, .y = 0 },
    });

    var longest: usize = 0;
    var shortestfound = false;
    while (bfs.pop()) |node| {
        const p: Vec2 = node.trace;
        if (p.x == 3 and p.y == 3) {
            if (!shortestfound) {
                shortestfound = true;
                try stdout.print("shortest='{}'\n", .{node.state});
            }
            longest = if (node.state.len > longest) node.state.len else longest;
            continue;
        }

        const doors = blk: {
            var buf: [4096]u8 = undefined;
            var input = std.fmt.bufPrint(&buf, "ulqzkmiv{}", .{node.state}) catch unreachable;
            var hash: [std.crypto.Md5.digest_length]u8 = undefined;
            std.crypto.Md5.hash(input, &hash);

            break :blk [4]bool{
                ((hash[0] >> 4) & 0xF) >= 11,
                ((hash[0] >> 0) & 0xF) >= 11,
                ((hash[1] >> 4) & 0xF) >= 11,
                ((hash[1] >> 0) & 0xF) >= 11,
            };
        };

        for (doors, 0..) |d, i| {
            if (!d)
                continue;
            const dirs = [4]Vec2{ .{ .x = 0, .y = -1 }, .{ .x = 0, .y = 1 }, .{ .x = -1, .y = 0 }, .{ .x = 1, .y = 0 } };
            const letters = [4]u8{ 'U', 'D', 'L', 'R' };

            const p1 = Vec2{ .x = p.x + dirs[i].x, .y = p.y + dirs[i].y };
            if (p1.x < 0 or p1.y < 0 or p1.x > 3 or p1.y > 3)
                continue;

            const seq = try allocator.alloc(u8, node.state.len + 1);
            @memcpy(seq[0 .. seq.len - 1], node.state);
            seq[seq.len - 1] = letters[i];
            try bfs.insert(.{
                .rating = node.rating + 1,
                .steps = node.steps + 1,
                .state = seq,
                .trace = p1,
            });
        }
    }
    try stdout.print("longest={}\n", .{longest});
}
