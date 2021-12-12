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
    const text = try std.fs.cwd().readFileAlloc(allocator, "day20.txt", limit);
    defer allocator.free(text);

    const Range = struct {
        min: u32,
        max: u32,
    };
    var blacklist: [1000]Range = undefined;
    var len: usize = 0;

    var it = std.mem.tokenize(u8, text, "\n");
    while (it.next()) |line| {
        if (tools.match_pattern("{}-{}", line)) |vals| {
            trace("new RANGE {}/{}\n", .{ vals[0], vals[1] });
            const range0 = Range{ .min = @intCast(u32, vals[0].imm), .max = @intCast(u32, vals[1].imm) };

            const oldlist = blacklist;
            var depth: u32 = 0;
            var cur: ?u32 = null;
            var i: usize = 0;
            var j: ?usize = null;

            while (true) {
                const Edge = struct {
                    v: u32,
                    up: i3,
                };
                const nextedge = blk: {
                    const e = if (cur == null or range0.min > cur.?) Edge{ .v = range0.min, .up = 1 } else if (range0.max > cur.?) Edge{ .v = range0.max, .up = -1 } else null;
                    if (i < len) {
                        const r = oldlist[i];
                        if (cur == null or r.min > cur.?) {
                            if (e == null or e.?.v > r.min) {
                                break :blk Edge{ .v = r.min, .up = 1 };
                            } else if (e != null and e.?.v == r.min) {
                                break :blk Edge{ .v = r.min, .up = 1 + e.?.up };
                            } else {
                                break :blk e;
                            }
                        } else if (r.max > cur.?) {
                            if (e == null or e.?.v > r.max) {
                                i += 1;
                                break :blk Edge{ .v = r.max, .up = -1 };
                            } else if (e != null and e.?.v == r.max) {
                                i += 1;
                                break :blk Edge{ .v = r.min, .up = e.?.up - 1 };
                            } else {
                                break :blk e;
                            }
                        }
                    }
                    break :blk e;
                };

                if (nextedge) |e| {
                    depth = @intCast(u32, @intCast(i32, depth) + e.up);
                    if (e.up > 0 and depth == 1) {
                        if (j == null) {
                            j = 0;
                            blacklist[0].min = e.v;
                        } else if (e.v > blacklist[j.?].max + 1) {
                            j.? += 1;
                            blacklist[j.?].min = e.v;
                        }
                    } else if (e.up < 0 and depth == 0) {
                        blacklist[j.?].max = e.v;
                    }
                    cur = e.v;
                } else {
                    break;
                }
            }
            len = j.? + 1;

            for (blacklist[0..len]) |range| {
                //trace("range = {}\n", .{range});
            }

            var prev: u32 = 0;
            for (blacklist[0..len]) |range| {
                assert(range.min >= prev);
                assert(range.max >= range.min);
                prev = range.max;
            }
        } else {
            trace("skipping {}\n", .{line});
        }
    }

    {
        try stdout.print("====================================\n", .{});
        var allowed: usize = 0;
        var prev: u32 = 0;
        for (blacklist[0..len]) |range| {
            try stdout.print("range = {}\n", .{range});
            allowed += (range.min - prev);
            prev = if (range.max != 0xFFFFFFFF) range.max + 1 else undefined;
        }
        try stdout.print("allowed = {}\n", .{allowed});
    }
}
