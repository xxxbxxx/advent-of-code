const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub fn run(input_text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    _ = input_text;
    // part1 (buggué car fait tout les karts en un coup et donc ils pourraient se croiser sans crasher "effet tunnel"  -> mais ça passe)
    const ans1 = ans: {
        const desired_nb_scores = 260321;
        var scores: [256 * 1024]u4 = undefined;
        scores[0] = 3;
        scores[1] = 7;
        var nb_scores: usize = 2;
        var elf1: usize = 0;
        var elf2: usize = 1;
        while (nb_scores < desired_nb_scores + 10) {
            const new: u5 = @as(u5, @intCast(scores[elf1])) + scores[elf2];
            if (new >= 10) {
                scores[nb_scores] = @as(u4, @intCast(new / 10));
                nb_scores += 1;
            }
            scores[nb_scores] = @as(u4, @intCast(new % 10));
            nb_scores += 1;

            elf1 = (elf1 + scores[elf1] + 1) % nb_scores;
            elf2 = (elf2 + scores[elf2] + 1) % nb_scores;
        }

        var ans: u64 = 0;
        for (scores[desired_nb_scores .. desired_nb_scores + 10]) |s| {
            ans = ans * 10 + s;
        }
        break :ans ans;
    };

    // part2
    const ans2 = ans: {
        const desired_final_digits = [_]u4{ 2, 6, 0, 3, 2, 1 };
        const scores = try allocator.alloc(u4, 128 * 1024 * 1024);
        defer allocator.free(scores);
        scores[0] = 3;
        scores[1] = 7;
        var nb_scores: usize = 2;
        var elf1: usize = 0;
        var elf2: usize = 1;
        while (!std.mem.endsWith(u4, scores[0..nb_scores], &desired_final_digits) and !std.mem.endsWith(u4, scores[0 .. nb_scores - 1], &desired_final_digits)) {
            const new: u5 = @as(u5, @intCast(scores[elf1])) + scores[elf2];
            if (new >= 10) {
                scores[nb_scores] = @as(u4, @intCast(new / 10));
                nb_scores += 1; // /!\ le piège est ici!  la sequence peut être un cran avant la fin...
            }
            scores[nb_scores] = @as(u4, @intCast(new % 10));
            nb_scores += 1;

            elf1 = (elf1 + scores[elf1] + 1) % nb_scores;
            elf2 = (elf2 + scores[elf2] + 1) % nb_scores;
        }

        if (std.mem.endsWith(u4, scores[0 .. nb_scores - 1], &desired_final_digits)) {
            break :ans (nb_scores - 1) - desired_final_digits.len;
        } else {
            break :ans nb_scores - desired_final_digits.len;
        }
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2018/input_day13.txt", run);
