const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub const main = tools.defaultMain("2023/day04.txt", run);

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena_alloc = std.heap.ArenaAllocator.init(allocator);
    defer arena_alloc.deinit();
    const arena = arena_alloc.allocator();

    const cards = blk: {
        var list = std.ArrayList(u8).init(arena);
        defer list.deinit();

        var it = std.mem.tokenize(u8, input, "\n\r\t");
        while (it.next()) |line| {
            const card = tools.match_pattern("Card {}: {} | {}", line) orelse continue;
            const card_num: u32 = @intCast(card[0].imm);
            const winning_nums = card[1].lit;
            const my_nums = card[2].lit;

            assert(card_num == list.items.len + 1);

            var winning: u100 = 0;
            var it2 = std.mem.tokenize(u8, winning_nums, " \n\r\t");
            while (it2.next()) |num| {
                const v = std.fmt.parseInt(u7, num, 10) catch unreachable;
                winning |= @as(u100, 1) << v;
            }

            var mine: u100 = 0;
            it2 = std.mem.tokenize(u8, my_nums, " \n\r\t");
            while (it2.next()) |num| {
                const v = std.fmt.parseInt(u7, num, 10) catch unreachable;
                mine |= @as(u100, 1) << v;
            }

            const count = @popCount(mine & winning);
            try list.append(count);
        }
        break :blk try list.toOwnedSlice();
    };

    const ans1 = ans: {
        var sum: usize = 0;
        for (cards) |count| {
            if (count > 0) sum += @as(usize, 1) << @as(u4, @intCast(count - 1));
        }
        break :ans sum;
    };

    const ans2 = ans: {
        const counts = try arena.alloc(u32, cards.len);
        @memset(counts, 1);
        for (cards, counts, 0..) |wins, count, i| {
            for (counts[i + 1 .. i + 1 + wins]) |*it|
                it.* += count;
        }
        var sum: usize = 0;
        for (counts) |c| sum += c;
        break :ans sum;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

test {
    const res = try run(
        \\Card 1: 41 48 83 86 17 | 83 86  6 31 17  9 48 53
        \\Card 2: 13 32 20 16 61 | 61 30 68 82 17 32 24 19
        \\Card 3:  1 21 53 59 44 | 69 82 63 72 16 21 14  1
        \\Card 4: 41 92 73 84 69 | 59 84 76 51 58  5 54 83
        \\Card 5: 87 83 26 28 32 | 88 30 70 12 93 22 82 36
        \\Card 6: 31 18 13 56 72 | 74 77 10 23 35 67 36 11
    , std.testing.allocator);
    defer std.testing.allocator.free(res[0]);
    defer std.testing.allocator.free(res[1]);
    try std.testing.expectEqualStrings("13", res[0]);
    try std.testing.expectEqualStrings("30", res[1]);
}
