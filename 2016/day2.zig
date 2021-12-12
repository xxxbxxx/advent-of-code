const std = @import("std");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

fn addsat(a: u3, range: u3, d: i32) u3 {
    const b: i32 = @as(i32, a) + d;
    if (b <= 2 - @as(i32, range)) return 2 - range;
    if (b >= 2 + @as(i32, range)) return 2 + range;
    return @intCast(u3, b);
}

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().writer();
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day2.txt", limit);
    defer allocator.free(text);

    const V = struct {
        x: u3,
        y: u3,
    };
    const r = [_]u3{ 0, 1, 2, 1, 0 };
    var p = V{ .x = 0, .y = 2 };
    var it = std.mem.tokenize(u8, text, "\n");
    while (it.next()) |line| {
        for (line) |c| {
            switch (c) {
                'L' => p.x = addsat(p.x, r[p.y], -1),
                'R' => p.x = addsat(p.x, r[p.y], 1),
                'U' => p.y = addsat(p.y, r[p.x], -1),
                'D' => p.y = addsat(p.y, r[p.x], 1),
                else => unreachable,
            }
        }
        try stdout.print("pos= {}  d= {}\n", .{ p, 1 + @as(u32, p.x) + 3 * @as(u32, p.y) });
    }

    //    return error.SolutionNotFound;
}
