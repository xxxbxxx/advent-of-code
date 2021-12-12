const std = @import("std");
const tools = @import("tools");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().writer();
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const Generator = struct {
        init: u64,
        mul: u64,
        mod: u64,
        criteria: u64,
    };
    const genA = Generator{ .init = 289, .mul = 16807, .mod = 2147483647, .criteria = 4 };
    const genB = Generator{ .init = 629, .mul = 48271, .mod = 2147483647, .criteria = 8 };

    var stateA = genA.init;
    var stateB = genB.init;
    var run: usize = 0;
    var coincidences: usize = 0;
    while (run < 5000000) : (run += 1) {
        if ((stateA & 0xFFFF) == (stateB & 0xFFFF)) {
            coincidences += 1;
        }

        while (true) {
            stateA = (stateA * genA.mul) % genA.mod;
            if (stateA % genA.criteria == 0) break;
        }
        while (true) {
            stateB = (stateB * genB.mul) % genB.mod;
            if (stateB % genB.criteria == 0) break;
        }
    }

    try stdout.print("coincidences={}\n", .{coincidences});
}
