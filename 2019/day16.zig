const std = @import("std");
const tools = @import("tools");

const with_trace = false;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var input_alloc: []u4 = try allocator.alloc(u4, input.len);
    defer allocator.free(input_alloc);

    const input_signal = blk: {
        var len: u32 = 0;
        for (std.mem.trim(u8, input, " \n\r\t")) |c| {
            input_alloc[len] = @intCast(c - '0');
            len += 1;
        }
        break :blk input_alloc[0..len];
    };

    var answer1: [8]u8 = undefined;
    {
        const signals = [2][]u4{ try allocator.alloc(u4, input_signal.len), try allocator.alloc(u4, input_signal.len) };
        defer {
            for (signals) |s| {
                allocator.free(s);
            }
        }
        std.mem.copy(u4, signals[0], input_signal);

        var phase: u32 = 0;
        while (phase < 100) : (phase += 1) {
            const in: []const u4 = signals[phase % 2];
            const out: []u4 = signals[1 - (phase % 2)];

            for (out, 0..) |*sample_out, index_out| {
                var sum: i32 = 0;
                for (in, 0..) |sample_in, index_in| {
                    const pattern_values = [_]i32{ 0, 1, 0, -1 };
                    const index_pattern = ((index_in + 1) / (index_out + 1)) % 4;
                    const pattern = pattern_values[index_pattern];
                    trace("{}*{}, ", .{ sample_in, pattern });
                    sum += @as(i32, sample_in) * pattern;
                }
                trace("{}\n", .{sum});
                sample_out.* = @intCast(if (sum >= 0) @as(u32, @intCast(sum)) % 10 else @as(u32, @intCast(-sum)) % 10);
            }

            for (out, 0..) |sample_out, i| {
                if (i >= answer1.len) break;
                answer1[i] = '0' + @as(u8, @intCast(sample_out));
            }
        }
    }

    var answer2: [8]u8 = undefined;
    {
        const repeats = 10000;

        const signals = [2][]u4{ try allocator.alloc(u4, input_signal.len * repeats), try allocator.alloc(u4, input_signal.len * repeats) };
        defer {
            for (signals) |s| {
                allocator.free(s);
            }
        }
        var repeat: u32 = 0;
        while (repeat < repeats) : (repeat += 1) {
            std.mem.copy(u4, signals[0][repeat * input_signal.len .. (repeat + 1) * input_signal.len], input_signal);
        }

        const offset = 5976277;
        assert(offset > signals[0].len / 2); // du coup, le pattern se resume à que des uns.. super. c'est naze.

        var phase: u32 = 0;
        while (phase < 100) : (phase += 1) {
            const in: []const u4 = signals[phase % 2];
            const out: []u4 = signals[1 - (phase % 2)];

            var sum: i32 = 0;
            var index_out: usize = out.len - 1;
            while (index_out >= offset) : (index_out -= 1) {
                const sample_in = in[index_out];
                const pattern = 1;
                sum += @as(i32, sample_in) * pattern;
                out[index_out] = @as(u4, @intCast(if (sum >= 0) @as(u32, @intCast(sum)) % 10 else @as(u32, @intCast(-sum)) % 10));
            }

            for (out[offset .. offset + 8], 0..) |sample_out, i| {
                if (i >= answer2.len) break;
                answer2[i] = '0' + @as(u8, @intCast(sample_out));
            }
        }
    }

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{s}", .{answer2}),
        try std.fmt.allocPrint(allocator, "{s}", .{answer1}),
    };
}

pub const main = tools.defaultMain("2019/day16.txt", run);
