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

    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day13.txt", limit);
    defer allocator.free(text);

    var scanners = [1]u32{0} ** 100;

    var it = std.mem.split(u8, text, "\n");
    while (it.next()) |line0| {
        const line = std.mem.trim(u8, line0, " \n\t\r");
        if (line.len == 0) continue;

        var it2 = std.mem.tokenize(u8, line, ": \t");
        const layer = std.fmt.parseInt(u32, it2.next() orelse unreachable, 10) catch unreachable;
        const range = std.fmt.parseInt(u32, it2.next() orelse unreachable, 10) catch unreachable;
        assert(scanners[layer] == 0);
        scanners[layer] = range;
    }

    var severity: u64 = 0;
    for (scanners) |range, depth| {
        const t = depth;
        if (false and with_trace) {
            trace("t={} ------------\n", .{t});
            for (scanners) |r2, d2| {
                if (r2 == 0) continue;
                const step = t % ((r2 - 1) * 2);
                const cur = if (step >= r2) ((r2 - 1) * 2) - step else step;
                trace("scanner n°{} at {}\n", .{ d2, cur });
            }
        }

        if (range == 0)
            continue;
        const step = t % ((range - 1) * 2);
        const cur = if (step >= range) ((range - 1) * 2) - step else step;
        if (cur == 0) {
            trace("hit: {},{},{}\n", .{ t, depth, range });
            severity += range * depth;
        }
    }
    try stdout.print("severity={}\n", .{severity});

    var delay: u32 = 0;
    const min_delay = outer: while (true) : (delay += 1) {
        for (scanners) |range, depth| {
            const t = delay + depth;
            if (range == 0)
                continue;
            const step = t % ((range - 1) * 2);
            const cur = if (step >= range) ((range - 1) * 2) - step else step;
            if (cur == 0) {
                // detected.
                continue :outer;
            }
        } else {
            // not detected
            break :outer delay;
        }
    } else {
        unreachable;
    };
    try stdout.print("mindelay={}\n", .{min_delay});
}
