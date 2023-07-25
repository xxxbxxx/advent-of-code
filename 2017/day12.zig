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

    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day12.txt", limit);
    defer allocator.free(text);

    var process_groups: [2000]u16 = undefined;
    for (process_groups, 0..) |*g, i| {
        g.* = @as(u16, @intCast(i));
    }
    var used_groups: [process_groups.len]bool = undefined;

    var dirty = true;
    while (dirty) {
        dirty = false;
        @memset(&used_groups, false);
        var it = std.mem.split(u8, text, "\n");
        while (it.next()) |line0| {
            const line = std.mem.trim(u8, line0, " \n\t\r");
            if (line.len == 0) continue;

            const min_group = blk: {
                var g: ?u16 = null;
                var it2 = std.mem.tokenize(u8, line, "<->, \t");
                while (it2.next()) |num| {
                    const process = std.fmt.parseInt(u32, num, 10) catch unreachable;
                    if (g == null or g.? > process_groups[process])
                        g = process_groups[process];
                }
                break :blk g.?;
            };

            var it2 = std.mem.tokenize(u8, line, "<->, \t");
            while (it2.next()) |num| {
                const process = std.fmt.parseInt(u32, num, 10) catch unreachable;
                if (process_groups[process] != min_group) {
                    assert(process_groups[process] > min_group);
                    process_groups[process] = min_group;
                    dirty = true;
                }
            }

            used_groups[min_group] = true;
        }
    }

    const group0size = blk: {
        var c: u32 = 0;
        for (process_groups) |g| {
            if (g == 0) c += 1;
        }
        break :blk c;
    };

    const numgroups = blk: {
        var c: u32 = 0;
        for (used_groups) |used| {
            if (used) c += 1;
        }
        break :blk c;
    };

    try stdout.print("group0={}, numgroups={}\n", .{ group0size, numgroups });
}
