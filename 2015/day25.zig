const std = @import("std");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var v: u64 = 20151125;
    const mul: u64 = 252533;
    const mod: u64 = 33554393;

    var i: u32 = 0;
    while (i < 10000) : (i += 1) {
        var x: u32 = 0;
        while (x <= i) : (x += 1) {
            var y: u32 = i - x;

            if (y == 3010 - 1 and x == 3019 - 1) { // row , column .
                trace("{}\n", v);
                break;
            }

            v = (v * mul) % mod;
        }
    }

    //    const out = std.io.getStdOut().writer();
    //   try out.print("res: {} \n", res);

    //    return error.SolutionNotFound;
}
