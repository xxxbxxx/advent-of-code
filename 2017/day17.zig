const std = @import("std");
const tools = @import("tools");

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

    //const limit = 1 * 1024 * 1024 * 1024;
    //const text = try std.fs.cwd().readFileAlloc(allocator, "day16.txt", limit);
    //defer allocator.free(text);

    const steps = 370;

    var circular_buffer = std.ArrayList(u32).init(allocator);
    try circular_buffer.append(0);

    var round: u32 = 1;
    var cursor: usize = 0;
    while (round <= 2017) : (round += 1) {
        assert(circular_buffer.len == round);
        cursor = (cursor + steps) % round + 1;
        if (cursor == circular_buffer.len) {
            try circular_buffer.append(@intCast(u16, round));
        } else {
            try circular_buffer.insert(cursor, @intCast(u16, round));
        }
    }
    try stdout.print("buffer: len={}, elem={}\n", .{ circular_buffer.len, circular_buffer.items[cursor + 1] });

    const zero_idx = std.mem.indexOfScalar(u32, circular_buffer.toSliceConst(), 0) orelse unreachable;
    try stdout.print("&zero={}, zero.next={}\n", .{ zero_idx, circular_buffer.items[zero_idx + 1] });

    var b1 = circular_buffer.items[1];
    while (round < 50000000) : (round += 1) {
        cursor = (cursor + steps) % round + 1;
        if (cursor == 1)
            b1 = round;
    }
    try stdout.print("buf[1]={}\n", .{b1});
}
