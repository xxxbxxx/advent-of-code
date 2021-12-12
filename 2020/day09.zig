const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    const ans1 = ans: {
        var list = [_]u32{0} ** 25;
        var cursor: u32 = 0;
        var count: u32 = 0;
        var it = std.mem.tokenize(u8, input, "\n\r");
        while (it.next()) |line| {
            const val = try std.fmt.parseInt(u32, line, 10);
            if (count < 25) {
                list[count] = val;
                count += 1;
            } else {
                const valid = valid: for (list) |v1, i| {
                    for (list) |v2, j| {
                        if (val == v1 + v2 and i != j) break :valid true;
                    }
                } else false;

                if (!valid) break :ans val;

                list[cursor] = val;
                cursor = (cursor + 1) % 25;
            }
        }
        unreachable;
    };

    const ans2 = ans: {
        var cumul = [_]u32{0} ** 1001;
        var count: u32 = 1;
        var it = std.mem.tokenize(u8, input, "\n\r");
        while (it.next()) |line| {
            const val = try std.fmt.parseInt(u32, line, 10);
            cumul[count] = val + cumul[count - 1];
            count += 1;

            const c2 = cumul[count - 1];
            for (cumul[0 .. count - 1]) |c1, i| {
                if (c2 - c1 == ans1) {
                    const min = cumul[i + 1] - c1;
                    const max = val;
                    break :ans min + max;
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

pub const main = tools.defaultMain("2020/input_day09.txt", run);
