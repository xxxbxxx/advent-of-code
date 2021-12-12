const std = @import("std");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

fn min3(a: anytype, b: anytype, c: anytype) u32 {
    if (a < b) {
        return if (a < c) a else c;
    } else {
        return if (b < c) b else c;
    }
}

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day2.txt", limit);

    var paper: u32 = 0;
    var ribbon: u32 = 0;
    var it = std.mem.split(u8, text, "\n");
    while (it.next()) |line| {
        if (line.len == 0)
            continue;
        var dim = std.mem.split(u8, line, "x");
        var dims = [_]u32{ 0, 0, 0 };
        var i: u32 = 0;
        while (dim.next()) |d| {
            const trimmed = std.mem.trim(u8, d, " \n\r\t");
            dims[i] = try std.fmt.parseInt(u32, trimmed, 10);
            i += 1;
        }
        const l = dims[0];
        const w = dims[1];
        const h = dims[2];

        const volume = w * l * h;

        const face1 = l * w;
        const face2 = l * h;
        const face3 = w * h;
        const smallface = min3(face1, face2, face3);

        const perimeter1 = 2 * (l + w);
        const perimeter2 = 2 * (l + h);
        const perimeter3 = 2 * (w + h);
        const smallperimeter = min3(perimeter1, perimeter2, perimeter3);

        paper += 2 * (face1 + face2 + face3) + smallface;
        ribbon += smallperimeter + volume;

        trace("box: {}x{}x{}  paper={}+{}  ribbon={}+{}\n", l, w, h, 2 * (face1 + face2 + face3), smallface, smallperimeter, volume);
    }

    const out = std.io.getStdOut().writer();
    try out.print("paper={} ribbon={}\n", paper, ribbon);

    //    return error.SolutionNotFound;
}
