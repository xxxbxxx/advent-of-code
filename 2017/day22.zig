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
    const text = try std.fs.cwd().readFileAlloc(allocator, "day22.txt", limit);
    defer allocator.free(text);

    const State = struct {
        const clean = 0;
        const weak = 1;
        const infected = 2;
        const flagged = 3;
    };

    var submap: [1000]u2 = undefined;
    const init = blk: {
        var len: usize = 0;
        var width: usize = 0;
        var it = std.mem.split(u8, text, "\n");
        while (it.next()) |line0| {
            const line = std.mem.trim(u8, line0, " \n\t\r");
            if (line.len == 0) continue;
            width = line.len;
            for (line) |c| {
                submap[len] = if (c == '#') State.infected else State.clean;
                len += 1;
            }
        }
        break :blk .{ submap[0..len], width };
    };

    const stride = 2048;
    const half = stride / 2;
    const center = half * stride + half;

    var map: [stride * stride]u2 = undefined;
    std.mem.set(u2, &map, State.clean);
    if (false) {
        map[center + (-1) * stride + 1] = State.infected;
        map[center + 0 * stride - 1] = State.infected;
    } else {
        const m = init[0];
        const w = init[1];
        const h = m.len / w;
        var offset = center - (w / 2) - stride * (h / 2);
        var i: usize = 0;
        while (i < h) : (i += 1) {
            std.mem.copy(u2, map[offset .. offset + w], m[i * w .. i * w + w]);
            offset += stride;
        }
    }

    var pos: isize = center;
    var dir: u2 = 0;
    const moves = [_]isize{ -stride, 1, stride, -1 };

    var infections: u32 = 0;
    var steps: u32 = 0;
    while (steps < 10000000) : (steps += 1) {
        const m = &map[@intCast(usize, pos)];
        switch (m.*) {
            State.clean => {
                m.* +%= 1;
                dir -%= 1;
            },
            State.weak => {
                m.* +%= 1;
                dir +%= 0;
                infections += 1;
            },
            State.infected => {
                m.* +%= 1;
                dir +%= 1;
            },
            State.flagged => {
                m.* +%= 1;
                dir +%= 2;
            },
        }

        pos += moves[dir];
    }

    try stdout.print("steps={}, infections={}\n", .{ steps, infections });
}
