const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var total1: i32 = 0;
    var total2: i32 = 0;

    const visited_len = 1_000_000;
    const visited = try allocator.alloc(bool, visited_len * 2);
    defer allocator.free(visited);
    @memset(visited, false);

    var first = true;
    loop: while (true) {
        var it = std.mem.tokenize(u8, input, ", \n\r\t");
        while (it.next()) |line| {
            const val = try std.fmt.parseInt(i32, line, 10);

            if (first)
                total1 += val;
            total2 += val;

            const idx = @as(usize, @intCast(visited_len + total2));
            if (visited[idx]) {
                assert(!first);
                break :loop;
            }
            visited[idx] = true;
        }
        first = false;
    }

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{total1}),
        try std.fmt.allocPrint(allocator, "{}", .{total2}),
    };
}

pub const main = tools.defaultMain("2018/input_day01.txt", run);
