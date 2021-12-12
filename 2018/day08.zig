const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

fn sum1(mem: []const u8, node_idx: usize) struct { sum: usize, size: usize } {
    const child_count = mem[node_idx + 0];
    const data_count = mem[node_idx + 1];
    var sum: usize = 0;
    var idx = node_idx + 2;

    var child_index: usize = 0;
    while (child_index < child_count) : (child_index += 1) {
        const r = sum1(mem, idx);
        idx += r.size;
        sum += r.sum;
    }

    for (mem[idx .. idx + data_count]) |it| {
        sum += it;
    }

    return .{ .sum = sum, .size = (idx + data_count) - node_idx };
}

fn sum2(mem: []const u8, node_idx: usize) struct { sum: usize, size: usize } {
    const child_count = mem[node_idx + 0];
    const data_count = mem[node_idx + 1];

    var idx = node_idx + 2;
    var sum: usize = 0;
    if (child_count > 0) {
        var child_sums = [_]usize{0} ** 12;

        var child_index: usize = 0;
        while (child_index < child_count) : (child_index += 1) {
            const r = sum2(mem, idx);
            idx += r.size;
            child_sums[child_index] = r.sum;
        }

        for (mem[idx .. idx + data_count]) |it| {
            if (it > 0 and it <= child_count)
                sum += child_sums[it - 1];
        }
    } else {
        for (mem[idx .. idx + data_count]) |it| {
            sum += it;
        }
    }
    return .{ .sum = sum, .size = (idx + data_count) - node_idx };
}

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var mem = std.ArrayList(u8).init(allocator);
    defer mem.deinit();

    {
        var it = std.mem.tokenize(u8, input, " \t\n\r");
        while (it.next()) |val| {
            try mem.append(try std.fmt.parseInt(u8, val, 0));
        }
    }

    // part1
    const ans1 = sum1(mem.items, 0).sum;

    // part2
    const ans2 = sum2(mem.items, 0).sum;

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2018/input_day08.txt", run);
