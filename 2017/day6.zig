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

    //const limit = 1 * 1024 * 1024 * 1024;
    //const text = try std.fs.cwd().readFileAlloc(allocator, "day5.txt", limit);
    //defer allocator.free(text);

    const bank0 = [16]u8{ 10, 3, 15, 10, 5, 15, 5, 15, 9, 2, 5, 8, 5, 2, 3, 6 };

    var bank = bank0;
    var allstates = std.AutoHashMap([16]u8, u32).init(allocator);
    var steps: u32 = 0;
    var looplen: ?u32 = null;
    while (true) {
        const imax = blk: {
            var max: u8 = 0;
            var imax: ?usize = null;
            for (bank) |v, i| {
                if (v > max) {
                    max = v;
                    imax = i;
                }
            }
            break :blk imax.?;
        };
        var m = bank[imax];
        bank[imax] = 0;
        var i = imax;
        while (m > 0) {
            i = (i + 1) % bank.len;
            bank[i] += 1;
            m -= 1;
        }
        steps += 1;

        const res = try allstates.getOrPut(bank);
        if (res.found_existing) {
            looplen = steps - res.kv.value;
            break;
        } else {
            res.kv.value = steps;
        }
    }

    try stdout.print("steps={}, looplen={}\n", .{ steps, looplen });

    //    return error.SolutionNotFound;
}
