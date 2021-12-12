const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var occupied_seats = [_]bool{false} ** 1024;
    var max_seatid: u32 = 0;

    //var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    //defer arena.deinit();
    {
        var it = std.mem.tokenize(u8, input, "\n\r");
        while (it.next()) |line| {
            // BFFFBBFRRR
            var row_min: u32 = 0;
            var row_max: u32 = 127;
            for (line[0..7]) |r| {
                const mid = (row_min + row_max) / 2;
                switch (r) {
                    'B' => row_min = mid,
                    'F' => row_max = mid,
                    else => unreachable,
                }
            }

            var col_min: u32 = 0;
            var col_max: u32 = 7;
            for (line[7..10]) |c| {
                const mid = (col_min + col_max) / 2;
                switch (c) {
                    'R' => col_min = mid,
                    'L' => col_max = mid,
                    else => unreachable,
                }
            }
            // std.debug.print("seat {} = {}x{}\n", .{ line, row_max, col_max });

            const seatid = row_max * 8 + col_max;
            assert(!occupied_seats[seatid]);
            occupied_seats[seatid] = true;
            if (seatid > max_seatid)
                max_seatid = seatid;
        }
    }

    // === part 1 ==============
    const ans1 = max_seatid;

    // === part 2 ==============
    const ans2 = for (occupied_seats) |occ, i| {
        if (!occ and i > 1 and occupied_seats[i - 1] and occupied_seats[i + 1])
            break i;
    } else unreachable;

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2020/input_day05.txt", run);
