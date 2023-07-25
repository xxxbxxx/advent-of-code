const std = @import("std");
const tools = @import("tools");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

fn add(p: usize, d: isize) usize {
    return @as(usize, @intCast(@as(isize, @intCast(p)) + d));
}

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().writer();
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day19.txt", limit);
    defer allocator.free(text);

    var stride: usize = 0;
    var height: usize = 0;
    var width: usize = 0;
    {
        var it = std.mem.split(u8, text, "\n");
        while (it.next()) |line| {
            if (width == 0) {
                width = line.len;
            }
            assert(width == line.len);

            if (stride == 0) {
                stride = @intFromPtr(line.ptr) - @intFromPtr(text.ptr);
            }
            assert(line.ptr == text.ptr + height * stride);

            height += 1;

            assert(line[0] == ' ' and line[line.len - 1] == ' '); // guardband
        }

        trace("Map size= {}x{}.\n", .{ width, height });
    }
    const map = text[0 .. stride * height - 1];

    const up: u2 = 0;
    const left: u2 = 1;
    const down: u2 = 2;
    const right: u2 = 3;
    const moves = [_]isize{ -@as(isize, @intCast(stride)), -1, @as(isize, @intCast(stride)), 1 };

    const start_dir = down;
    var start_pos: usize = 0;
    {
        start_pos = std.mem.indexOfScalar(u8, map, '|') orelse unreachable;
        trace("Start={}\n", .{start_pos});
    }

    var letters: [64]u8 = undefined;
    var len: usize = 0;
    var steps: usize = 0;
    var pos = start_pos;
    var dir = start_dir;
    while (true) {
        pos = add(pos, moves[dir]);
        steps += 1;
        const m = map[pos];
        switch (m) {
            ' ' => break, // reachead the end
            '-', '|' => continue,
            'A'...'Z' => {
                letters[len] = m;
                len += 1;
                continue;
            },
            '+' => {
                const dir_l = dir +% 1;
                const dir_r = dir +% 3;
                if (map[add(pos, moves[dir_l])] != ' ') {
                    dir = dir_l;
                } else if (map[add(pos, moves[dir_r])] != ' ') {
                    dir = dir_r;
                } else {
                    unreachable;
                }
                continue;
            },
            else => unreachable,
        }
    }

    try stdout.print("letters={}, steps={}\n", .{ letters[0..len], steps });
}
