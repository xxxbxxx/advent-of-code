const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var count_with_pairs: usize = 0;
    var count_with_triplets: usize = 0;

    // part1
    {
        var it = std.mem.tokenize(u8, input, ", \n\r\t");
        while (it.next()) |line| {
            var letter_count = [1]u8{0} ** 128;
            for (line) |c| {
                letter_count[c] += 1;
            }

            var has_pair = false;
            var has_triplet = false;
            for (letter_count) |c| {
                has_pair = has_pair or c == 2;
                has_triplet = has_triplet or c == 3;
            }
            if (has_pair) count_with_pairs += 1;
            if (has_triplet) count_with_triplets += 1;
        }
    }

    // part2
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const ans2 = blk: {
        var outer = std.mem.tokenize(u8, input, ", \n\r\t");
        while (outer.next()) |outer_line| {
            var inner = std.mem.tokenize(u8, input, ", \n\r\t");
            while (inner.next()) |inner_line| {
                assert(outer_line.len == inner_line.len);
                var diffs: usize = 0;
                for (outer_line) |outer_letter, i| {
                    if (outer_letter != inner_line[i]) diffs += 1;
                }
                if (diffs == 1) {
                    const common = try arena.allocator().alloc(u8, outer_line.len - 1);
                    var j: usize = 0;
                    for (outer_line) |letter, i| {
                        if (letter == inner_line[i]) {
                            common[j] = letter;
                            j += 1;
                        }
                    }
                    assert(j == common.len);
                    break :blk common;
                }
            }
        }
        unreachable;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{count_with_pairs * count_with_triplets}),
        try std.fmt.allocPrint(allocator, "{s}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2018/input_day02.txt", run);
