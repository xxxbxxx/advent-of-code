const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub const main = tools.defaultMain("2021/day03.txt", run);

fn filter_in_place(initial_list: []u16, mode: enum { least_frequent, most_frequent }) u16 {
    var list = initial_list;
    var bit_index: u4 = 15;
    while (bit_index >= 0) : (bit_index -= 1) {
        const mask = @as(u16, 1) << bit_index;
        var ones: u32 = 0;
        for (list) |l| {
            ones += @boolToInt(l & mask != 0);
        }
        const criteria = switch (mode) {
            .least_frequent => if (ones >= (list.len + 1) / 2 or ones == 0) 0 else mask, //  or ones == 0 : s'il y en a zero, on garde tout
            .most_frequent => if (ones >= (list.len + 1) / 2) mask else 0,
        };

        var i: usize = 0;
        var j: usize = list.len;
        while (i < j) {
            const keep = list[i] & mask == criteria;
            if (keep) {
                i += 1;
            } else {
                j -= 1;
                const t = list[j];
                list[j] = list[i];
                list[i] = t;
            }
        }
        assert(j >= 1);
        list.len = j;
        if (list.len == 1)
            return list[0];
    }

    unreachable;
}

pub fn run(input: []const u8, gpa: std.mem.Allocator) tools.RunError![2][]const u8 {
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();
    const allocator = arena.allocator();

    var number_list: []u16 = undefined;
    var digits_list: []@Vector(16, u1) = undefined; // msb
    {
        const line_count = std.mem.count(u8, input, "\n") + 1;
        const nums = try allocator.alloc(u16, line_count);
        const digs = try allocator.alloc(@Vector(16, u1), line_count);

        var it = std.mem.tokenize(u8, input, "\n\r");
        var l: u32 = 0;
        while (it.next()) |line| : (l += 1) {
            var val = @splat(16, @as(u1, 0));
            var num: u16 = 0;
            for (line) |c, i| {
                val[i] = @boolToInt(c == '1');
                num = (num * 2) | @boolToInt(c == '1');
            }
            nums[l] = num;
            digs[l] = val;
        }
        number_list = nums[0..l];
        digits_list = digs[0..l];
    }

    const ans1 = ans: {
        const zero = @splat(16, @as(u16, 0));
        var counters = zero;
        for (digits_list) |val| {
            counters += @as(@Vector(16, u16), val);
        }

        var gamma: u32 = 0;
        var epsilon: u32 = 0;

        //std.debug.print("line_count={}, counts={}\n", .{ digits_list.len, counters });

        const ones = counters > @splat(16, digits_list.len / 2);
        const width = @reduce(.Add, @as(@Vector(16, u16), @bitCast(@Vector(16, u1), counters > zero)));
        //std.debug.print("width={}, ones={}\n", .{ width, ones });

        for (@as([16]bool, ones)[0..width]) |bit| {
            gamma *= 2;
            epsilon *= 2;
            gamma |= @boolToInt(bit);
            epsilon |= @boolToInt(!bit);
        }
        break :ans epsilon * gamma;
    };

    const ans2 = ans: {
        const co2 = filter_in_place(number_list, .least_frequent);
        const oxygen = filter_in_place(number_list, .most_frequent);
        //std.debug.print("oxygen: {b}, co2: {b}\n", .{oxygen, co2});

        break :ans @as(u32, oxygen) * @as(u32, co2);
    };

    return [_][]const u8{
        try std.fmt.allocPrint(gpa, "{}", .{ans1}),
        try std.fmt.allocPrint(gpa, "{}", .{ans2}),
    };
}

test {
    const res = try run(
        \\00100
        \\11110
        \\10110
        \\10111
        \\10101
        \\01111
        \\00111
        \\11100
        \\10000
        \\11001
        \\00010
        \\01010
    , std.testing.allocator);
    defer std.testing.allocator.free(res[0]);
    defer std.testing.allocator.free(res[1]);
    try std.testing.expectEqualStrings("198", res[0]);
    try std.testing.expectEqualStrings("230", res[1]);
}
