const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

fn collapse(input: []u8, tmp: []u8) usize {
    const bufs = [_][]u8{ input, tmp };
    var pingpong: u32 = 0;
    var len = input.len;

    var changed = true;
    while (changed) {
        const in = bufs[pingpong][0..len];
        const out = bufs[1 - pingpong];
        pingpong = 1 - pingpong;

        len = 0;
        changed = false;
        var prev: u8 = '.';
        for (in) |c| {
            if (prev == '.') {
                prev = c;
            } else if (c == (prev + 'A') - 'a' or c == (prev + 'a') - 'A') {
                changed = true;
                prev = '.';
            } else {
                out[len] = prev;
                len += 1;
                prev = c;
            }
        }
        if (prev != '.') {
            out[len] = prev;
            len += 1;
        }
    }

    return len;
}

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {

    // part1
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const ans1 = ans: {
        const bufs = [_][]u8{ try arena.allocator().alloc(u8, input.len), try arena.allocator().alloc(u8, input.len) };
        @memcpy(bufs[0], input);
        const len = collapse(bufs[0], bufs[1]);
        break :ans len;
    };

    // part2
    const ans2 = ans: {
        const bufs = [_][]u8{ try arena.allocator().alloc(u8, input.len), try arena.allocator().alloc(u8, input.len) };

        var bestLen = input.len;
        for ("abcdefghijklmnopqrstuvwxyz") |letter| {
            const buf = bufs[0];
            var l: usize = 0;
            for (input) |c| {
                if (c == (letter + 'A') - 'a' or c == letter)
                    continue;
                buf[l] = c;
                l += 1;
            }

            const newLen = collapse(buf[0..l], bufs[1]);
            if (newLen < bestLen)
                bestLen = newLen;
        }
        break :ans bestLen;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2018/input_day05.txt", run);
