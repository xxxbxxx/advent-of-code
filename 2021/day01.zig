const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub const main = tools.defaultMain("2021/day01.txt", run);

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    const list = try allocator.alloc(i32, input.len / 3);
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
        var nb_inc: usize = 0;
        var prev = list[0];
        for (list[1..len]) |cur| {
            nb_inc += @intFromBool(cur > prev);
            prev = cur;
        }
        break :ans nb_inc;
    };

    const ans2 = ans: {
        var nb_inc: usize = 0;
        var i: usize = 1;
        while (i < len - 2) : (i += 1) {
            //const prev = list[i-1] + list[i] + list[i+1];
            //const cur = list[i] + list[i+1] + list[i+2];
            //nb_inc += @intFromBool(cur > prev);
            nb_inc += @intFromBool(list[i + 2] > list[i - 1]);
        }
        break :ans nb_inc;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

test {
    const res = try run(
        \\199
        \\200
        \\208
        \\210
        \\200
        \\207
        \\240
        \\269
        \\260
        \\263
    , std.testing.allocator);
    defer std.testing.allocator.free(res[0]);
    defer std.testing.allocator.free(res[1]);
    try std.testing.expectEqualStrings("7", res[0]);
    try std.testing.expectEqualStrings("5", res[1]);
}
