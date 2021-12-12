const std = @import("std");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

fn compute_uncompressed_len(text: []const u8) usize {
    var out: usize = 0;
    var in: usize = 0;
    while (in < text.len) : (in += 1) {
        const c = text[in];
        if (c == '(') {
            const end = blk: {
                var e = in;
                while (e < text.len) : (e += 1) {
                    if (text[e] == ')') break :blk e;
                }
                unreachable;
            };
            const x = blk: {
                var e = in;
                while (e < text.len) : (e += 1) {
                    if (text[e] == 'x') break :blk e;
                }
                unreachable;
            };

            const pattern_start = end + 1;
            const pattern_len = std.fmt.parseInt(u32, text[in + 1 .. x], 10) catch unreachable;
            const pattern_repeat = std.fmt.parseInt(u32, text[x + 1 .. end], 10) catch unreachable;

            out += pattern_repeat * compute_uncompressed_len(text[pattern_start .. pattern_start + pattern_len]);
            in = end + pattern_len;
        } else {
            if (c != ' ' and c != '\t' and c != '\n') {
                out += 1;
            }
        }
    }
    return out;
}

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day9.txt", limit);
    defer allocator.free(text);

    const count = compute_uncompressed_len(text);

    try stdout.print("answer='{}'\n", .{count});
}
