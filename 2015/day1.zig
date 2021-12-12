const std = @import("std");

const with_trace = false;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day1.txt", limit);

    var floor: i32 = 0;
    for (text) |c, i| {
        if (c == '(') floor += 1;
        if (c == ')') floor -= 1;
        if (floor == -1) {
            const out = std.io.getStdOut().writer();
            try out.print("{}\n", i + 1);
            break;
        }
    }
    const out = std.io.getStdOut().writer();
    try out.print("{}\n", floor);

    //    return error.SolutionNotFound;
}
