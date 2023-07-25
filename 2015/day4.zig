const std = @import("std");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const md5 = std.crypto.Md5.init();

    const key = "ckczppom";

    var buf: [100]u8 = undefined;
    var hash: [std.crypto.Md5.digest_length]u8 = undefined;
    var hexhash: [std.crypto.Md5.digest_length * 2]u8 = undefined;

    var answer: u32 = 1;
    while (true) {
        const input = std.fmt.bufPrint(&buf, "ckczppom{}", answer) catch unreachable;
        std.crypto.Md5.hash(input, &hash);
        if (hash[0] == 0 and hash[1] == 0 and hash[2] == 0)
            break;
        answer += 1;
    }

    for (hash, 0..) |h, i| {
        _ = std.fmt.bufPrint(hexhash[i * 2 ..], "{x:0>2}", h) catch unreachable;
    }
    const out = std.io.getStdOut().writer();
    try out.print("answer={} -> {}\n", answer, hexhash);

    //    return error.SolutionNotFound;
}
