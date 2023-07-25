const std = @import("std");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

fn parse_line(line: []const u8) ?u32 {
    const trimmed = std.mem.trim(u8, line, " \n\r\t");
    if (trimmed.len == 0)
        return null;
    return std.fmt.parseInt(u32, trimmed, 10) catch unreachable;
}

fn pow2(x: usize) u32 {
    return @as(u32, 1) << @as(u5, @intCast(x));
}
pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day17.txt", limit);

    var all_sizes: [10000]u32 = undefined;

    var it = std.mem.tokenize(u8, text, "\n");
    var n: u32 = 0;
    while (it.next()) |line| {
        if (parse_line(line)) |val| {
            all_sizes[n] = val;
            trace("{}\n", all_sizes[n]);
            n += 1;
        }
    }
    const sizes = all_sizes[0..n];
    const combi = pow2(n);

    var ans: u32 = 0;
    var minimum: u32 = 99;
    var c: u32 = 0;
    while (c < combi) : (c += 1) {
        var total: u32 = 0;
        var nb: u32 = 0;
        for (sizes, 0..) |s, i| {
            if (c & pow2(i) != 0) {
                nb += 1;
                total += s;
            }
        }
        if (total == 150) {
            if (nb < minimum) {
                minimum = nb;
                ans = 0;
            }
            if (nb == minimum)
                ans += 1;
        }
    }

    const out = std.io.getStdOut().writer();
    try out.print("ans = {} min = {} combi={}\n", ans, minimum, combi);

    //    return error.SolutionNotFound;
}
