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

    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day1.txt", limit);
    defer allocator.free(text);

    assert(text.len % 2 == 0);
    var sum: u32 = 0;
    for (text, 0..) |c, i| {
        assert(c >= '0' and c <= '9');
        const n = c - '0';
        if (c == text[(i + text.len / 2) % text.len])
            sum += n;
    }
    try stdout.print("sum= {}\n", .{sum});

    //    return error.SolutionNotFound;
}
