const std = @import("std");

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

    const Disc = struct {
        offset: u32,
        period: u32,
    };
    //  const discs = [_]Disc{ .{ .offset = 4, .period = 5 }, .{ .offset = 1, .period = 2 } };
    const discs = [_]Disc{
        .{ .offset = 1, .period = 17 },
        .{ .offset = 0, .period = 7 },
        .{ .offset = 2, .period = 19 },
        .{ .offset = 0, .period = 5 },
        .{ .offset = 0, .period = 3 },
        .{ .offset = 5, .period = 13 },
        .{ .offset = 0, .period = 11 },
    };

    var time: u32 = 0;
    while (true) : (time += 1) {
        var t = time;
        const ok = blk: {
            for (discs) |d| {
                t += 1;
                const phase = (t + d.offset) % d.period;
                if (phase != 0)
                    break :blk false;
            }
            break :blk true;
        };

        if (ok)
            break;
    }

    try stdout.print("first match= {}\n", .{time});
}
