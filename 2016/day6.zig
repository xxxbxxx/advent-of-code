const std = @import("std");

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
    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day6.txt", limit);
    defer allocator.free(text);

    var counts: [8][26]u16 = [1][26]u16{[1]u16{0} ** 26} ** 8;
    {
        var it = std.mem.tokenize(u8, text, "\n");
        while (it.next()) |line_full| {
            const line = std.mem.trim(u8, line_full, " \n\r\t");
            if (line.len == 0)
                continue;
            for (line, 0..) |c, i| {
                counts[i][c - 'a'] += 1;
            }
        }
    }

    var word: [8]u8 = undefined;
    for (counts, 0..) |col, i| {
        var best: u32 = 999;
        for (col, 0..) |count, c| {
            //trace("'{c}'={}\n", .{ @intCast(u8, c) + 'a', count });
            if (count > 0 and count < best) {
                best = count;
                word[i] = @as(u8, @intCast(c)) + 'a';
            }
        }
    }

    try stdout.print("answer='{}'\n", .{&word});

    //    return error.SolutionNotFound;
}
