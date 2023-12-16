const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");
const tracy = tools.tracy;

const RunFn = *const fn (input: []const u8, allocator: std.mem.Allocator) tools.RunError![2][]const u8;

// @import(name);  -> marche pas. doit être un "string litteral"

const alldays = [_]struct { runFn: RunFn, input: []const u8 }{
    .{ .runFn = &@import("day01.zig").run, .input = @embedFile("day01.txt") },
    .{ .runFn = &@import("day02.zig").run, .input = @embedFile("day02.txt") },
    .{ .runFn = &@import("day03.zig").run, .input = @embedFile("day03.txt") },
    .{ .runFn = &@import("day04.zig").run, .input = @embedFile("day04.txt") },
    .{ .runFn = &@import("day05.zig").run, .input = @embedFile("day05.txt") },
    .{ .runFn = &@import("day06.zig").run, .input = @embedFile("day06.txt") },
    .{ .runFn = &@import("day07.zig").run, .input = @embedFile("day07.txt") },
    .{ .runFn = &@import("day08.zig").run, .input = @embedFile("day08.txt") },
    .{ .runFn = &@import("day09.zig").run, .input = @embedFile("day09.txt") },
    .{ .runFn = &@import("day10.zig").run, .input = @embedFile("day10.txt") },
    .{ .runFn = &@import("day11.zig").run, .input = @embedFile("day11.txt") },
    .{ .runFn = &@import("day12.zig").run, .input = @embedFile("day12.txt") },
    .{ .runFn = &@import("day13.zig").run, .input = @embedFile("day13.txt") },
    .{ .runFn = &@import("day14.zig").run, .input = @embedFile("day14.txt") },
    .{ .runFn = &@import("day15.zig").run, .input = @embedFile("day15.txt") },
    .{ .runFn = &@import("day16.zig").run, .input = @embedFile("day16.txt") },
    //.{ .runFn = &@import("day17.zig").run, .input = @embedFile("day17.txt") },
    //.{ .runFn = &@import("day18.zig").run, .input = @embedFile("day18.txt") },
    //.{ .runFn = &@import("day19.zig").run, .input = @embedFile("day19.txt") },
    //.{ .runFn = &@import("day20.zig").run, .input = @embedFile("day20.txt") },
    //.{ .runFn = &@import("day21.zig").run, .input = @embedFile("day21.txt") },
    //.{ .runFn = &@import("day22.zig").run, .input = @embedFile("day22.txt") },
    //.{ .runFn = &@import("day23.zig").run, .input = @embedFile("day23.txt") },
    //.{ .runFn = &@import("day24.zig").run, .input = @embedFile("day24.txt") },
    //.{ .runFn = &@import("day25.zig").run, .input = @embedFile("day25.txt") },
};

test {
    _ = @import("day01.zig");
    _ = @import("day02.zig");
    _ = @import("day03.zig");
    _ = @import("day04.zig");
    _ = @import("day05.zig");
    _ = @import("day06.zig");
    _ = @import("day07.zig");
    _ = @import("day08.zig");
    _ = @import("day09.zig");
    _ = @import("day10.zig");
    _ = @import("day11.zig");
    _ = @import("day12.zig");
    _ = @import("day13.zig");
    _ = @import("day14.zig");
    _ = @import("day15.zig");
    _ = @import("day16.zig");
    //_ = @import("day17.zig");
    //_ = @import("day18.zig");
    //_ = @import("day19.zig");
    //_ = @import("day20.zig");
    //_ = @import("day21.zig");
    //_ = @import("day22.zig");
    //_ = @import("day23.zig");
    //_ = @import("day24.zig");
    //_ = @import("day25.zig");
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    for (alldays, 0..) |it, day| {
        var buf: [50]u8 = undefined;
        const day_name = try std.fmt.bufPrintZ(&buf, "Day {d:0>2}", .{day + 1});
        const zone = tracy.traceEx(@src(), .{ .name = day_name });
        defer zone.end();

        const answer = try it.runFn(it.input, allocator);
        defer allocator.free(answer[0]);
        defer allocator.free(answer[1]);

        try stdout.print("{s}:\n", .{day_name});
        for (answer, 0..) |ans, i| {
            const multiline = (std.mem.indexOfScalar(u8, ans, '\n') != null);
            if (multiline) {
                try stdout.print("\tPART {d}:\n{s}", .{ i + 1, ans });
            } else {
                try stdout.print("\tPART {d}: {s}\n", .{ i + 1, ans });
            }
        }
    }
}
