const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    const list = try allocator.alloc(i32, input.len / 4);
    defer allocator.free(list);
    var len: usize = 0;
    {
        var it = std.mem.tokenize(u8, input, ", \n\r\t");
        while (it.next()) |line| {
            const val = try std.fmt.parseInt(i32, line, 10);
            list[len] = val;
            len += 1;
        }
    }

    const ans1 = ans: {
        for (list[0 .. len - 1]) |n1, idx1| {
            for (list[idx1 + 1 .. len]) |n2| {
                if (n1 + n2 == 2020) break :ans n1 * n2;
            }
        }
        unreachable;
    };

    const ans2 = ans: {
        for (list[0 .. len - 2]) |n1, idx1| {
            for (list[idx1 + 1 .. len - 1]) |n2, idx2| {
                if (n1 + n2 >= 2020) continue;
                for (list[idx1 + 1 + idx2 + 1 .. len]) |n3| {
                    if (n1 + n2 + n3 == 2020) break :ans n1 * n2 * n3;
                }
            }
        }
        unreachable;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2020/input_day01.txt", run);
