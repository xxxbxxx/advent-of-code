const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub const main = tools.defaultMain("2023/day07.txt", run);

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena_alloc = std.heap.ArenaAllocator.init(allocator);
    defer arena_alloc.deinit();
    const arena = arena_alloc.allocator();

    const hands = blk: {
        var list = std.ArrayList(Hand).init(arena);
        defer list.deinit();

        var it = std.mem.tokenize(u8, input, "\n\r\t");
        while (it.next()) |line| {
            const hand = tools.match_pattern("{} {}", line) orelse continue;
            const bid: u32 = @intCast(hand[1].imm);
            try list.append(.{ .cards = line[0..5].*, .bid = bid });
        }
        break :blk try list.toOwnedSlice();
    };

    const ans1 = ans: {
        std.mem.sortUnstable(Hand, hands, {}, Hand.lessThan);
        var sum: u64 = 0;
        for (hands, 1..) |h, i| {
            sum += h.bid * i;
        }
        break :ans sum;
    };

    const ans2 = ans: {
        std.mem.sortUnstable(Hand, hands, {}, Hand.lessThanWithJoker);
        var sum: u64 = 0;
        for (hands, 1..) |h, i| {
            sum += h.bid * i;
        }
        break :ans sum;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

const Hand = struct {
    cards: [5]u8,
    bid: u32,

    fn indexes(hand_cards: [5]u8, order: []const u8) [5]u8 {
        var o: [5]u8 = undefined;
        for (&hand_cards, 0..) |c, i|
            o[i] = @intCast(std.mem.indexOfScalar(u8, order, c).?);
        return o;
    }

    const Kind = enum(u8) { none, onepair, twopair, brelan, full, carre, five };
    fn kind(card_indexes: [5]u8) Kind {
        var counts = [1]u8{0} ** 13;
        for (&card_indexes) |c| counts[c] += 1;
        std.mem.sortUnstable(u8, &counts, {}, std.sort.desc(u8));
        if (counts[0] == 5) return .five;
        if (counts[0] == 4) return .carre;
        if (counts[0] == 3 and counts[1] == 2) return .full;
        if (counts[0] == 3) return .brelan;
        if (counts[0] == 2 and counts[1] == 2) return .twopair;
        if (counts[0] == 2) return .onepair;
        return .none;
    }
    fn lessThan(_: void, lhs: Hand, rhs: Hand) bool {
        const lh_idxs = indexes(lhs.cards, "23456789TJQKA");
        const rh_idxs = indexes(rhs.cards, "23456789TJQKA");
        const lht = kind(lh_idxs);
        const rht = kind(rh_idxs);
        if (@intFromEnum(lht) < @intFromEnum(rht)) return true;
        if (@intFromEnum(lht) > @intFromEnum(rht)) return false;
        for (&lh_idxs, &rh_idxs) |l, r| {
            if (l < r) return true;
            if (l > r) return false;
        }
        unreachable;
    }

    fn kindWithJoker(card_indexes: [5]u8) Kind {
        var counts = [1]u8{0} ** 13;
        for (&card_indexes) |c| counts[c] += 1;
        const jokers = counts[0];
        if (jokers >= 4) return .five;
        if (jokers == 0) return kind(card_indexes);

        counts[0] = 0;
        std.mem.sortUnstable(u8, &counts, {}, std.sort.desc(u8));

        if (counts[0] == 4 and jokers == 1) return .five;
        if (counts[0] == 3 and jokers == 2) return .five;
        if (counts[0] == 3 and jokers == 1) return .carre;
        if (counts[0] == 2 and jokers == 3) return .five;
        if (counts[0] == 2 and jokers == 2) return .carre;
        if (counts[0] == 2 and counts[1] == 2 and jokers == 1) return .full;
        if (counts[0] == 2 and jokers == 1) return .brelan;
        if (counts[0] == 1 and jokers == 3) return .carre;
        if (counts[0] == 1 and jokers == 2) return .brelan;
        if (counts[0] == 1 and jokers == 1) return .onepair;
        unreachable;
    }

    fn lessThanWithJoker(_: void, lhs: Hand, rhs: Hand) bool {
        const lh_idxs = indexes(lhs.cards, "J23456789TQKA");
        const rh_idxs = indexes(rhs.cards, "J23456789TQKA");
        const lht = kindWithJoker(lh_idxs);
        const rht = kindWithJoker(rh_idxs);
        if (@intFromEnum(lht) < @intFromEnum(rht)) return true;
        if (@intFromEnum(lht) > @intFromEnum(rht)) return false;
        for (&lh_idxs, &rh_idxs) |l, r| {
            if (l < r) return true;
            if (l > r) return false;
        }
        unreachable;
    }
};

test {
    const res = try run(
        \\32T3K 765
        \\T55J5 684
        \\KK677 28
        \\KTJJT 220
        \\QQQJA 483
    , std.testing.allocator);
    defer std.testing.allocator.free(res[0]);
    defer std.testing.allocator.free(res[1]);
    try std.testing.expectEqualStrings("6440", res[0]);
    try std.testing.expectEqualStrings("5905", res[1]);
}
