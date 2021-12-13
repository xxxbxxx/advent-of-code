const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

const RunFn = fn (input: []const u8, allocator: std.mem.Allocator) tools.RunError![2][]const u8;

// @import(name);  -> marche pas. doit être un "string litteral"

const alldays = [_]struct { runFn: RunFn, input: []const u8 }{
    .{ .runFn = @import("day01.zig").run, .input = @embedFile("day01.txt") },
    .{ .runFn = @import("day02.zig").run, .input = @embedFile("day02.txt") },
    .{ .runFn = @import("day03.zig").run, .input = @embedFile("day03.txt") },
    .{ .runFn = @import("day04.zig").run, .input = @embedFile("day04.txt") },
    .{ .runFn = @import("day05.zig").run, .input = @embedFile("day05.txt") },
    .{ .runFn = @import("day06.zig").run, .input = @embedFile("day06.txt") },
    .{ .runFn = @import("day07.zig").run, .input = @embedFile("day07.txt") },
    .{ .runFn = @import("day08.zig").run, .input = @embedFile("day08.txt") },
    .{ .runFn = @import("day09.zig").run, .input = @embedFile("day09.txt") },
    .{ .runFn = @import("day10.zig").run, .input = @embedFile("day10.txt") },
    .{ .runFn = @import("day11.zig").run, .input = @embedFile("day11.txt") },
    .{ .runFn = @import("day12.zig").run, .input = @embedFile("day12.txt") },
    .{ .runFn = @import("day13.zig").run, .input = @embedFile("day13.txt") },
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
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    for (alldays) |it, day| {
        const answer = try it.runFn(it.input, allocator);
        defer allocator.free(answer[0]);
        defer allocator.free(answer[1]);

        try stdout.print("Day {d:0>2}:\n", .{day + 1});
        for (answer) |ans, i| {
            const multiline = (std.mem.indexOfScalar(u8, ans, '\n') != null);
            if (multiline) {
                try stdout.print("\tPART {d}:\n{s}", .{ i + 1, ans });
            } else {
                try stdout.print("\tPART {d}: {s}\n", .{ i + 1, ans });
            }
        }
    }
}
