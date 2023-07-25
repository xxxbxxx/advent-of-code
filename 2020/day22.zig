const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

const Card = u8;
const Deck = tools.CircularBuffer(Card);

fn playGame(hands: [2][]const Card, variant: enum { classic, recursive }, allocator: std.mem.Allocator) std.mem.Allocator.Error![2]u32 {
    var previous = std.AutoHashMap([2]u32, void).init(allocator);
    defer previous.deinit();
    try previous.ensureTotalCapacity(150);

    var scores: [2]struct { prod: u32, sum: u16, count: u16 } = .{ .{ .prod = 0, .sum = 0, .count = 0 }, .{ .prod = 0, .sum = 0, .count = 0 } };
    var decks = [2]Deck{ Deck.init(allocator), Deck.init(allocator) };
    defer decks[1].deinit();
    defer decks[0].deinit();
    try decks[0].reserve(hands[0].len);
    try decks[1].reserve(hands[1].len);

    //std.debug.print("New game: \n", .{});
    for (hands, 0..) |cards, player| {
        //std.debug.print("player= ", .{});
        for (cards, 0..) |c, i| {
            // std.debug.print("{},", .{c});
            try decks[player].pushTail(c);
            scores[player].prod += @intCast(c * (cards.len - i));
            scores[player].sum += @intCast(c);
            scores[player].count += 1;
        }
        //std.debug.print("\n", .{});
    }

    while (true) {
        // doublon?
        if (try previous.fetchPut([2]u32{ scores[0].prod, scores[1].prod }, {})) |_| {
            return [2]u32{ 1, 0 }; // player1 wins
        }

        const c1 = if (decks[0].pop()) |c| c else break;
        const c2 = if (decks[1].pop()) |c| c else break;
        // std.debug.print("playing {} vs {}\n", .{ c1, c2 });

        const cards = [2]Card{ c1, c2 };
        for (cards, 0..) |c, player| {
            scores[player].prod -= c * scores[player].count;
            scores[player].sum -= c;
            scores[player].count -= 1;
        }

        const play1_wins = win: {
            if (variant == .recursive and c1 <= scores[0].count and c2 <= scores[1].count) {
                var sub_cards: [2][52]Card = undefined;
                for (cards, 0..) |card, player| {
                    var it = decks[player].iter();
                    var nb: u32 = 0;
                    while (it.next()) |c| {
                        sub_cards[player][nb] = c;
                        nb += 1;
                        if (nb >= card) break;
                    }
                }
                const sub_scores = try playGame(.{ sub_cards[0][0..c1], sub_cards[1][0..c2] }, .recursive, allocator);
                break :win sub_scores[0] > sub_scores[1];
            } else {
                break :win c1 > c2;
            }
        };
        if (play1_wins) {
            try decks[0].pushTail(c1);
            try decks[0].pushTail(c2);
            scores[0].prod += scores[0].sum * 2 + c1 * 2 + c2;
            scores[0].sum += c1 + c2;
            scores[0].count += 2;
        } else {
            try decks[1].pushTail(c2);
            try decks[1].pushTail(c1);
            scores[1].prod += scores[1].sum * 2 + c2 * 2 + c1;
            scores[1].sum += c2 + c1;
            scores[1].count += 2;
        }
    }
    return [_]u32{ scores[0].prod, scores[1].prod };
}

pub fn run(input_text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const param: struct {
        hands: [2][]const Card,
    } = param: {
        var cards: [2][52]Card = undefined;
        var nb: [2]usize = .{ 0, 0 };
        var player: ?usize = null;
        var it = std.mem.tokenize(u8, input_text, "\n\r");
        while (it.next()) |line| {
            if (tools.match_pattern("Player {}:", line)) |fields| {
                player = @as(u2, @intCast(fields[0].imm)) - 1;
            } else {
                cards[player.?][nb[player.?]] = try std.fmt.parseInt(Card, line, 10);
                nb[player.?] += 1;
            }
        }

        // std.debug.print("got {} + {} cards\n", .{ nb[0], nb[1] });
        break :param .{
            .hands = .{ cards[0][0..nb[0]], cards[1][0..nb[1]] },
        };
    };

    const ans1 = ans: {
        const scores = try playGame(param.hands, .classic, allocator);
        break :ans scores[0] + scores[1];
    };

    const ans2 = ans: {
        const scores = try playGame(param.hands, .recursive, allocator);
        break :ans scores[0] + scores[1];
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2020/input_day22.txt", run);
