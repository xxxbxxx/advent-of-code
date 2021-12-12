const std = @import("std");
const tools = @import("tools");

const with_trace = false;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    _ = input;
    var counter1: u32 = 0;
    var counter2: u32 = 0;

    var candidate: u32 = 234208;
    while (candidate < 765869) : (candidate += 1) {
        var digits: [6]u8 = undefined;
        var val = candidate;
        digits[5] = @intCast(u8, val % 10);
        val /= 10;
        digits[4] = @intCast(u8, val % 10);
        val /= 10;
        digits[3] = @intCast(u8, val % 10);
        val /= 10;
        digits[2] = @intCast(u8, val % 10);
        val /= 10;
        digits[1] = @intCast(u8, val % 10);
        val /= 10;
        digits[0] = @intCast(u8, val % 10);
        val /= 10;

        // part 1
        {
            var valid = true;
            var pair = false;
            var i: u32 = 1;
            while (i < 6) : (i += 1) {
                valid = valid and (digits[i] >= digits[i - 1]);
                pair = pair or (digits[i] == digits[i - 1]);
            }
            if (valid and pair)
                counter1 += 1;
        }

        // part 2
        {
            var valid = true;
            var pair = false;
            var i: u32 = 1;
            while (i < 6) : (i += 1) {
                valid = valid and (digits[i] >= digits[i - 1]);
                pair = pair or ((i <= 1 or digits[i - 2] != digits[i - 1]) and digits[i] == digits[i - 1] and (i >= 5 or digits[i + 1] != digits[i]));
            }
            if (valid and pair)
                counter2 += 1;
        }
    }

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{counter1}),
        try std.fmt.allocPrint(allocator, "{}", .{counter2}),
    };
}

pub const main = tools.defaultMain("2019/day03.txt", run);
