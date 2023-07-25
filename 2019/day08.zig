const std = @import("std");
const tools = @import("tools");

const with_trace = false;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    const Layer = [25 * 6]u8;
    var all_layers: [500]Layer = undefined;

    const layers = blk: {
        var ipix: u32 = 0;
        var ilayer: u32 = 0;
        for (input) |c| {
            if (c < '0' or c > '9')
                continue;
            all_layers[ilayer][ipix] = c;
            ipix += 1;
            if (ipix >= @typeInfo(Layer).Array.len) {
                ipix = 0;
                ilayer += 1;
            }
        }
        assert(ipix == 0);
        break :blk all_layers[0..ilayer];
    };

    var best_zeroes: u32 = 99999;
    var best_result: u32 = undefined;
    for (layers) |layer| {
        var digits = [1]u32{0} ** 10;
        for (layer) |pix| {
            digits[pix - '0'] += 1;
        }
        if (digits[0] < best_zeroes) {
            best_zeroes = digits[0];
            best_result = digits[1] * digits[2];
        }
    }

    var composite: Layer = undefined;
    for (&composite, 0..) |*pix, i| {
        for (layers, 0..) |_, l| {
            switch (layers[layers.len - 1 - l][i]) {
                '0' => pix.* = ' ',
                '1' => pix.* = '*',
                '2' => continue,
                else => unreachable,
            }
        }
    }

    trace("layers = {} , minzero = {}, res = {}\n", .{ layers.len, best_zeroes, best_result });

    var buf: [4096]u8 = undefined;
    var len: usize = 0;
    var row: u32 = 0;
    while (row < 6) : (row += 1) {
        tools.fmt_bufAppend(&buf, &len, "{s}\n", .{composite[row * 25 .. (row + 1) * 25]});
    }

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{best_result}),
        try std.fmt.allocPrint(allocator, "{s}", .{buf[0..len]}),
    };
}

pub const main = tools.defaultMain("2019/day08.txt", run);
