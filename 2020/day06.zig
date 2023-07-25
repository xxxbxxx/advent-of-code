const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

fn maskOf(bit: usize) u26 {
    return @as(u26, 1) << @intCast(bit);
}

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {

    //var arena = std.heap.ArenaAllocator.init(allocator);
    //defer arena.deinit();
    var ans1: u32 = 0;
    var ans2: u32 = 0;
    {
        var it1 = std.mem.split(u8, input, "\n\n");
        while (it1.next()) |group| {
            var it2 = std.mem.tokenize(u8, group, " \n\t");
            var group_union: u26 = 0;
            var group_intersection: u26 = ~@as(u26, 0);
            while (it2.next()) |person| {
                var person_letters_mask: u26 = 0;
                for (person) |letter| {
                    person_letters_mask |= if (letter >= 'a' and letter <= 'z') maskOf(letter - 'a') else 0;
                }
                group_union = group_union | person_letters_mask;
                group_intersection = group_intersection & person_letters_mask;
            }
            ans1 += @popCount(group_union);
            ans2 += @popCount(group_intersection);
        }
    }

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2020/input_day06.txt", run);
