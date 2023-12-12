const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub const main = tools.defaultMain("2023/day01.txt", run);

const words = [_][]const u8{ "one", "two", "three", "four", "five", "six", "seven", "eight", "nine" };
const digits = [_][]const u8{ "1", "2", "3", "4", "5", "6", "7", "8", "9" };

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    const ans1 = ans: {
        var sum: u32 = 0;
        var it = std.mem.tokenize(u8, input, ", \n\r\t");
        while (it.next()) |line| {
            var x: ?u8 = null;
            var y: ?u8 = null;
            for (line) |c| {
                const digit = switch (c) {
                    '0'...'9' => c - '0',
                    else => continue,
                };
                if (x == null) x = digit;
                y = digit;
            }
            if (x) |v| sum += v * 10;
            if (y) |v| sum += v * 1;
        }
        break :ans sum;
    };

    const ans2 = ans: {
        var sum: usize = 0;
        var it = std.mem.tokenize(u8, input, ", \n\r\t");
        while (it.next()) |line| {
            sum += 10 * x: {
                var i: usize = 0;
                while (i < line.len) : (i += 1) {
                    const eol = line[i..];
                    inline for (.{ &digits, &words }) |set| {
                        for (set, 1..) |v, digit| {
                            if (std.mem.startsWith(u8, eol, v)) {
                                i += v.len - 1;
                                break :x digit;
                            }
                        }
                    }
                }
                unreachable;
            };

            sum += y: {
                var i: usize = line.len;
                while (i > 0) : (i -= 1) {
                    const eol = line[i - 1 ..];
                    inline for (.{ &digits, &words }) |set| {
                        for (set, 1..) |v, digit| {
                            if (std.mem.startsWith(u8, eol, v)) {
                                i += v.len - 1;
                                break :y digit;
                            }
                        }
                    }
                }
                unreachable;
            };
        }
        break :ans sum;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

test {
    const res_a = try run(
        \\1abc2
        \\pqr3stu8vwx
        \\a1b2c3d4e5f
        \\treb7uchet
    , std.testing.allocator);
    defer std.testing.allocator.free(res_a[0]);
    defer std.testing.allocator.free(res_a[1]);
    try std.testing.expectEqualStrings("142", res_a[0]);
    try std.testing.expectEqualStrings("142", res_a[1]);

    const res_b = try run(
        \\two1nine
        \\eightwothree
        \\abcone2threexyz
        \\xtwone3four
        \\4nineeightseven2
        \\zoneight234
        \\7pqrstsixteen
    , std.testing.allocator);
    defer std.testing.allocator.free(res_b[0]);
    defer std.testing.allocator.free(res_b[1]);
    try std.testing.expectEqualStrings("209", res_b[0]);
    try std.testing.expectEqualStrings("281", res_b[1]);
}
