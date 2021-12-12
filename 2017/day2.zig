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
    const text = try std.fs.cwd().readFileAlloc(allocator, "day2.txt", limit);
    defer allocator.free(text);

    var sum1: u32 = 0;
    var sum2: u32 = 0;
    var it = std.mem.split(u8, text, "\n");
    while (it.next()) |line| {
        var linevals: [100]u32 = undefined;
        var len: u32 = 0;
        var min: ?u32 = null;
        var max: ?u32 = null;
        var it2 = std.mem.tokenize(u8, std.mem.trim(u8, line, " \n\t\r"), " \t");
        while (it2.next()) |field| {
            const val = try std.fmt.parseInt(u32, field, 10);
            linevals[len] = val;
            len += 1;
            min = if (min == null or val < min.?) val else min;
            max = if (max == null or val > max.?) val else max;
        }
        if (len == 0) continue;
        if (max != null and min != null)
            sum1 += (max.? - min.?);
        sum2 += blk: {
            for (linevals[0..len]) |v1, i| {
                for (linevals[0..len]) |v2, j| {
                    if (i != j and v2 % v1 == 0)
                        break :blk v2 / v1;
                }
            }
            unreachable;
        };
    }
    try stdout.print("sum_minmax={}\nsumdiv={}\n", .{ sum1, sum2 });

    //    return error.SolutionNotFound;
}
