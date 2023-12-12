const std = @import("std");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

fn matches(line: []const u8, pattern: []const u8, sep: []const u8) ?[2]u32 {
    if (line.len < pattern.len)
        return null;
    if (!std.mem.eql(u8, line[0..pattern.len], pattern))
        return null;

    var it = std.mem.tokenize(u8, line[pattern.len..], sep);
    const v1 = it.next().?;
    const v2 = it.next().?;

    return [_]u32{
        std.fmt.parseInt(u32, v1, 10) catch unreachable,
        std.fmt.parseInt(u32, v2, 10) catch unreachable,
    };
}

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day8.txt", limit);
    defer allocator.free(text);

    const width = 50;
    const height = 6;
    const stride = width + 1;
    var screen = ([1]u8{' '} ** width ++ [1]u8{'\n'}) ** height;
    trace("screen=\n{}\n", .{screen});

    {
        var it = std.mem.tokenize(u8, text, "\n");
        while (it.next()) |line_full| {
            const line = std.mem.trim(u8, line_full, " \n\r\t");
            if (line.len == 0)
                continue;

            if (matches(line, "rect ", " x")) |size| {
                var y: u32 = 0;
                while (y < size[1]) : (y += 1) {
                    @memset(screen[y * stride + 0 .. y * stride + size[0]], '#');
                }
            } else if (matches(line, "rotate row y=", " by")) |rotrow| {
                const y = rotrow[0];
                const r = rotrow[1];
                const row = screen[y * stride + 0 .. y * stride + width];
                var oldrow: [width]u8 = undefined;
                @memcpy(&oldrow, row);
                var x: u32 = 0;
                while (x < width) : (x += 1) {
                    row[x] = oldrow[(x + width - r) % width];
                }
            } else if (matches(line, "rotate column x=", " by")) |rotcol| {
                const x = rotcol[0];
                const r = rotcol[1];
                var oldcol: [height]u8 = undefined;
                var y: u32 = 0;
                while (y < height) : (y += 1) {
                    oldcol[y] = screen[x + y * stride];
                }
                y = 0;
                while (y < height) : (y += 1) {
                    screen[x + y * stride] = oldcol[(y + height - r) % height];
                }
            }

            trace("line={}, screen=\n{}\n", .{ line, screen });
        }
    }

    const count = blk: {
        var c: u32 = 0;
        for (screen) |p| {
            if (p == '#') c += 1;
        }
        break :blk c;
    };

    try stdout.print("answer='{}'\n", .{count});
}
