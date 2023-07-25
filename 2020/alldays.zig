const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

const RunFn = *const fn (input: []const u8, allocator: std.mem.Allocator) tools.RunError![2][]const u8;

// it.runFn = @import(name);  -> marche pas. doit être un string litteral

const alldays = [_]struct { runFn: RunFn, input: []const u8 }{
    .{ .runFn = &@import("day01.zig").run, .input = @embedFile("input_day01.txt") },
    .{ .runFn = &@import("day02.zig").run, .input = @embedFile("input_day02.txt") },
    .{ .runFn = &@import("day03.zig").run, .input = @embedFile("input_day03.txt") },
    .{ .runFn = &@import("day04.zig").run, .input = @embedFile("input_day04.txt") },
    .{ .runFn = &@import("day05.zig").run, .input = @embedFile("input_day05.txt") },
    .{ .runFn = &@import("day06.zig").run, .input = @embedFile("input_day06.txt") },
    .{ .runFn = &@import("day07.zig").run, .input = @embedFile("input_day07.txt") },
    .{ .runFn = &@import("day08.zig").run, .input = @embedFile("input_day08.txt") },
    .{ .runFn = &@import("day09.zig").run, .input = @embedFile("input_day09.txt") },
    .{ .runFn = &@import("day10.zig").run, .input = @embedFile("input_day10.txt") },
    .{ .runFn = &@import("day11.zig").run, .input = @embedFile("input_day11.txt") },
    .{ .runFn = &@import("day12.zig").run, .input = @embedFile("input_day12.txt") },
    .{ .runFn = &@import("day13.zig").run, .input = "" },
    .{ .runFn = &@import("day14.zig").run, .input = @embedFile("input_day14.txt") },
    .{ .runFn = &@import("day15.zig").run, .input = "" },
    .{ .runFn = &@import("day16.zig").run, .input = @embedFile("input_day16.txt") },
    .{ .runFn = &@import("day17.zig").run, .input = @embedFile("input_day17.txt") },
    .{ .runFn = &@import("day18.zig").run, .input = @embedFile("input_day18.txt") },
    .{ .runFn = &@import("day19.zig").run, .input = @embedFile("input_day19.txt") },
    .{ .runFn = &@import("day20.zig").run, .input = @embedFile("input_day20.txt") },
    .{ .runFn = &@import("day21.zig").run, .input = @embedFile("input_day21.txt") },
    .{ .runFn = &@import("day22.zig").run, .input = @embedFile("input_day22.txt") },
    .{ .runFn = &@import("day23.zig").run, .input = "156794823" },
    .{ .runFn = &@import("day24.zig").run, .input = @embedFile("input_day24.txt") },
    .{ .runFn = &@import("day25.zig").run, .input = "" },
};

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    for (alldays, 0..) |it, day| {
        const answer = try it.runFn(it.input, allocator);
        defer allocator.free(answer[0]);
        defer allocator.free(answer[1]);

        try stdout.print("Day {d:0>2}:\n", .{day + 1});
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
