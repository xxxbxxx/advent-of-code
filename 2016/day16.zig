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

    const disclen = 35651584;
    var disc = try allocator.alloc(u1, disclen * 2);
    defer allocator.free(disc);

    var len: usize = 17;
    @memcpy(disc[0..len], &[_]u1{ 0, 1, 1, 1, 1, 0, 1, 0, 1, 1, 0, 0, 1, 0, 0, 1, 1 });

    // fill the disc
    {
        while (len < disclen) {
            @memcpy(disc[len + 1 .. len + len + 1], disc[0..len]);
            std.mem.reverse(u1, disc[len + 1 .. len + len + 1]);
            for (disc[len + 1 .. len + len + 1]) |*d| {
                d.* = d.* ^ 1;
            }
            disc[len] = 0;
            len = len + len + 1;
        }

        //try stdout.print("disc=", .{});
        //for (disc[0..len]) |d| {
        //    try stdout.print("{}", .{d});
        //}
        //try stdout.print("\n", .{});
    }

    // reduce checksum
    {
        len = disclen;
        while (len % 2 == 0) {
            len = len / 2;
            for (disc[0..len], 0..) |*d, i| {
                d.* = 1 ^ (disc[i * 2 + 0] ^ disc[i * 2 + 1]);
            }
        }

        try stdout.print("checksum=", .{});
        for (disc[0..len]) |d| {
            try stdout.print("{}", .{d});
        }
        try stdout.print("\n", .{});
    }
}
