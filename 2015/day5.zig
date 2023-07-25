const std = @import("std");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

fn is_nice1(s: []const u8) bool {
    const voyelles = "aeiou";
    var nbvoy: u32 = 0;
    var hasdouble = false;
    var hasforbidden = false;
    var prev: u8 = 0;
    for (s) |c| {
        for (voyelles) |v| {
            if (c == v) nbvoy += 1;
        }
        if (prev == c) hasdouble = true;
        if (prev == 'a' and c == 'b') hasforbidden = true;
        if (prev == 'c' and c == 'd') hasforbidden = true;
        if (prev == 'p' and c == 'q') hasforbidden = true;
        if (prev == 'x' and c == 'y') hasforbidden = true;
        prev = c;
    }

    return (!hasforbidden and hasdouble and nbvoy >= 3);
}

fn is_nice2(s: []const u8) bool {
    var hasrepeat = false;
    var tri = [3]u8{ 0, 0, 0 };
    for (s) |c| {
        tri[0] = tri[1];
        tri[1] = tri[2];
        tri[2] = c;
        if (tri[0] == tri[2])
            hasrepeat = true;
    }

    var hasrepeatpair = false;
    var pair = [2]u8{ 0, 0 };
    for (s, 0..) |c, i| {
        pair[0] = pair[1];
        pair[1] = c;
        var pair2 = [2]u8{ 1, 1 };
        for (s[i + 1 ..]) |c2| {
            pair2[0] = pair2[1];
            pair2[1] = c2;
            if (pair2[0] == pair[0] and pair2[1] == pair[1])
                hasrepeatpair = true;
        }
    }

    return (hasrepeatpair and hasrepeat);
}

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day5.txt", limit);

    var nb_nice: u32 = 0;
    var it = std.mem.split(u8, text, "\n");
    while (it.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \n\r\t");
        if (is_nice2(trimmed))
            nb_nice += 1;
    }

    const out = std.io.getStdOut().writer();
    try out.print("nices={} \n", nb_nice);

    //    return error.SolutionNotFound;
}
