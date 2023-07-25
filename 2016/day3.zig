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
    return @as(u3, @intCast(b));
}

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().writer();
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day3.txt", limit);
    defer allocator.free(text);

    var num: u32 = 0;
    var tripple: u32 = 0;
    var lens: [3][3]i32 = .{ .{ 0, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 0 } };
    var it = std.mem.tokenize(u8, text, "\n");
    while (it.next()) |line| {
        var itn = std.mem.tokenize(u8, line, " ");
        lens[0][tripple] = std.fmt.parseInt(i32, itn.next().?, 10) catch unreachable;
        lens[1][tripple] = std.fmt.parseInt(i32, itn.next().?, 10) catch unreachable;
        lens[2][tripple] = std.fmt.parseInt(i32, itn.next().?, 10) catch unreachable;
        tripple += 1;
        if (tripple == 3) {
            tripple = 0;
            for (lens) |l| {
                if ((l[0] + l[1] > l[2]) and (l[0] + l[2] > l[1]) and (l[1] + l[2] > l[0])) {
                    //trace("possib = {},{},{}\n", .{ l1,l2,l3 });
                    num += 1;
                }
            }
        }
    }
    try stdout.print("num={}\n", .{num});

    //    return error.SolutionNotFound;
}
