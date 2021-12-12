const std = @import("std");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

fn looknsay(in: []const u8, out: *[]u8, storage: []u8) void {
    var cur = storage;
    var prev: u8 = in[0];
    var repeat: u8 = 1;
    for (in[1..]) |c| {
        if (c == prev) {
            repeat += 1;
        } else {
            const slice = std.fmt.bufPrint(cur, "{d}", repeat) catch unreachable; // inutile, c'est toujours 1, 2, ou 3.
            cur[slice.len] = prev;
            cur = cur[slice.len + 1 ..];
            prev = c;
            repeat = 1;
        }
    }
    const slice = std.fmt.bufPrint(cur, "{d}", repeat) catch unreachable;
    cur[slice.len] = prev;
    cur = cur[slice.len + 1 ..];

    out.* = storage[0..(@ptrToInt(cur.ptr) - @ptrToInt(storage.ptr))];
}

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    //  const limit = 1 * 1024 * 1024 * 1024;
    //  const text = try std.fs.cwd().readFileAlloc(allocator, "day9.txt", limit);

    var bufs = [_][]u8{ try allocator.alloc(u8, 100000000), try allocator.alloc(u8, 100000000) };
    var next: []u8 = undefined;
    std.mem.copy(u8, bufs[0], "1113222113");
    var cur = bufs[0][0..10];
    var count: u32 = 0;
    while (count < 50) : (count += 1) {
        looknsay(cur, &next, bufs[1 - (count % 2)]);
        //trace("{}\n", next);
        cur = next;
    }

    const out = std.io.getStdOut().writer();
    try out.print("len {}\n", cur.len);

    //    return error.SolutionNotFound;
}
