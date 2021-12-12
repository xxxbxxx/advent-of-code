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
    const text = try std.fs.cwd().readFileAlloc(allocator, "day7.txt", limit);
    defer allocator.free(text);

    var count: u32 = 0;
    {
        var it = std.mem.tokenize(u8, text, "\n");
        while (it.next()) |line_full| {
            const line = std.mem.trim(u8, line_full, " \n\r\t");
            if (line.len == 0)
                continue;
            var bracket: u32 = 0;
            var BAB: [100][3]u8 = undefined;
            var ABA: [100][3]u8 = undefined;
            var BAB_count: u32 = 0;
            var ABA_count: u32 = 0;
            var queue = [3]u8{ 0, 1, 2 };
            for (line) |c| {
                if (c == '[') {
                    bracket += 1;
                    queue = [3]u8{ 0, 1, 2 };
                } else if (c == ']') {
                    bracket -= 1;
                    queue = [3]u8{ 0, 1, 2 };
                } else {
                    queue[0] = queue[1];
                    queue[1] = queue[2];
                    queue[2] = c;
                    if (queue[0] == queue[2] and queue[1] != queue[0]) {
                        if (bracket > 0) {
                            BAB[BAB_count] = queue;
                            BAB_count += 1;
                        } else {
                            ABA[ABA_count] = queue;
                            ABA_count += 1;
                        }
                    }
                }
            }

            const found = blk: {
                for (BAB[0..BAB_count]) |bab| {
                    for (ABA[0..ABA_count]) |aba| {
                        if (aba[0] == bab[1] and aba[1] == bab[0]) {
                            break :blk true;
                        }
                    }
                }
                break :blk false;
            };
            if (found) {
                trace("ssl={}\n", .{line});
                count += 1;
            }
        }
    }

    try stdout.print("answer='{}'\n", .{count});
}
