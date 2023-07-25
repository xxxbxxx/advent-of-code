const std = @import("std");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

const Action = enum {
    toggle,
    on,
    off,
};
const Vec2 = struct {
    x: u32,
    y: u32,
};
const Rect = struct {
    min: Vec2,
    max: Vec2,
};

fn parsevec2(text: []const u8) Vec2 {
    const sepmaybe = std.mem.indexOf(u8, text, ",");
    const sep = sepmaybe.?;
    return Vec2{
        .x = std.fmt.parseInt(u32, text[0..sep], 10) catch unreachable,
        .y = std.fmt.parseInt(u32, text[sep + 1 ..], 10) catch unreachable,
    };
}

fn fill_rect(grid: []bool, action: Action, rect: Rect) void {
    var y = rect.min.y;
    while (y <= rect.max.y) : (y += 1) {
        var x = rect.min.x;
        while (x <= rect.max.x) : (x += 1) {
            const g = &grid[y * 1000 + x];
            switch (action) {
                .on => g.* = true,
                .off => g.* = false,
                .toggle => g.* = !g.*,
            }
        }
    }
}
fn parseline(line: []const u8, action: *Action, rect: *Rect) void {
    const off = "turn off ";
    const on = "turn on ";
    const tog = "toggle ";
    const thgh = " through ";

    var rectstr: []const u8 = undefined;
    if (std.mem.eql(u8, off, line[0..off.len])) {
        action.* = .off;
        rectstr = line[off.len..];
    }
    if (std.mem.eql(u8, on, line[0..on.len])) {
        action.* = .on;
        rectstr = line[on.len..];
    }
    if (std.mem.eql(u8, tog, line[0..tog.len])) {
        action.* = .toggle;
        rectstr = line[tog.len..];
    }

    const sepmaybe = std.mem.indexOf(u8, rectstr, thgh[0..]);
    const sep = sepmaybe.?;
    rect.min = parsevec2(rectstr[0..sep]);
    rect.max = parsevec2(rectstr[sep + thgh.len ..]);
}

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day6.txt", limit);

    var grid = try allocator.alloc(bool, 1000 * 1000);
    @memset(grid, false);

    var it = std.mem.split(u8, text, "\n");
    while (it.next()) |line_full| {
        const line = std.mem.trim(u8, line_full, " \n\r\t");
        if (line.len == 0)
            continue;
        var action: Action = undefined;
        var rect: Rect = undefined;
        parseline(line, &action, &rect);

        fill_rect(grid, action, rect);
    }

    var count: u32 = 0;
    for (grid) |g| {
        if (g) count += 1;
    }
    const out = std.io.getStdOut().writer();
    try out.print("lights={} \n", count);

    //    return error.SolutionNotFound;
}
