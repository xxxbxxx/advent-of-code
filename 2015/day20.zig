const std = @import("std");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

fn housespresents(num: u32) u32 {
    var i = num;
    var total: u32 = 0;
    while (i > 0) : (i -= 1) {
        if (num <= i * 50 and num % i == 0)
            total += i;
    }
    return total * 11;
}

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var best: u32 = 1002600;
    var i: u32 = best;
    while (i > 1000) : (i -= 1) {
        var v = housespresents(i);
        if (v >= 36000000) {
            best = i;
            trace("best={}\n", best);
        }
    }

    // bissection: débile! c'est pas monotone...
    // mais bon en repetant, ptet que..
    while (true) {
        var low: u32 = 509999;
        var hi: u32 = best;
        var low_v = housespresents(low);
        var hi_v = housespresents(hi);
        while (low_v < 36000000 and low + 1 < hi) {
            const mid = (low + hi + 1) / 2;
            const mid_v = housespresents(mid);
            trace("[{}]:{} .. [{}]:{} .. [{}]:{}\n", low, low_v, mid, mid_v, hi, hi_v);
            if (mid_v <= 36000000) {
                low = mid;
                low_v = mid_v;
            } else {
                hi = mid;
                hi_v = mid_v;
            }
        }
        best = if (low_v < 36000000) hi else low;
        const out = std.io.getStdOut().writer();
        try out.print("ans = {}\n", best);
    }

    //    return error.SolutionNotFound;
}
