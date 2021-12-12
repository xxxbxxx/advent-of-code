const std = @import("std");
const tools = @import("tools");

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var total1: u32 = 0;
    var total2: u32 = 0;

    {
        var it = std.mem.tokenize(u8, input, ", \n\r\t");
        while (it.next()) |line| {
            const val = try std.fmt.parseInt(u32, line, 10);

            total1 += (val / 3) - 2;

            total2 += module: {
                var m: u32 = 0;
                var v = val;
                while (v > 6) {
                    const fuel = (v / 3) - 2;
                    m += fuel;
                    v = fuel;
                }
                break :module m;
            };
        }
    }

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{total1}),
        try std.fmt.allocPrint(allocator, "{}", .{total2}),
    };
}

pub const main = tools.defaultMain("2019/day01.txt", run);
