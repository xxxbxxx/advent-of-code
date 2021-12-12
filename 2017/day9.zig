const std = @import("std");
const tools = @import("tools");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

fn regIndex(name: []const u8) u32 {
    var num: u32 = 0;
    for (name) |c| {
        num = (num * 27) + c - 'a';
    }
    return num;
}
pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().writer();
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day9.txt", limit);
    defer allocator.free(text);

    var sum: u32 = 0;
    var garbagecollec: u32 = 0;
    var depth: u32 = 0;
    var ingarbage = false;
    var skipnext = false;
    for (text) |c| {
        if (ingarbage) {
            if (skipnext) {
                skipnext = false;
            } else if (c == '!') {
                skipnext = true;
            } else if (c == '>') {
                ingarbage = false;
            } else {
                garbagecollec += 1;
            }
        } else {
            if (c == '{') {
                depth += 1;
                sum += depth;
            } else if (c == '}') {
                depth -= 1;
            } else if (c == '<') {
                ingarbage = true;
            }
        }
    }

    try stdout.print("score={}, garbage={}\n", .{ sum, garbagecollec });
}
