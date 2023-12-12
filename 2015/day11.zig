const std = @import("std");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

fn findpair(s: []const u8) ?usize {
    if (s.len < 2)
        return null;
    var i: usize = 0;
    while (i < s.len - 1) : (i += 1) {
        const prev = if (i > 0) s[i - 1] else 0;
        const pair0 = s[i];
        const pair1 = s[i + 1];
        const next = if (i + 2 < s.len) s[i + 2] else 0;
        if (pair0 == pair1 and pair0 != prev and pair1 != next)
            return i;
    }
    return null;
}

fn is_valid1(s: []const u8) bool {
    var hasbrelan = false;
    var tri = [3]u8{ 0, 0, 0 };
    for (s) |c| {
        tri[0] = tri[1];
        tri[1] = tri[2];
        tri[2] = c;
        if (tri[0] + 1 == tri[1] and tri[1] + 1 == tri[2])
            hasbrelan = true;
    }
    if (!hasbrelan)
        return false;

    var hasforbiden = false;
    for (s) |c| {
        if (c == 'o' or c == 'l' or c == 'i')
            hasforbiden = true;
    }
    if (hasforbiden)
        return false;

    const pair1 = findpair(s);
    if (pair1) |p1| {
        var n = p1 + 2;
        while (true) {
            const pair2 = findpair(s[n..]);
            if (pair2) |p2| {
                if (s[p1] != s[p2])
                    return true;
                n = p2 + 2;
            } else {
                return false;
            }
        }
    } else {
        return false;
    }
}

fn add_one(s: []u8) void {
    var carry: u8 = 1;
    var i: usize = 0;
    while (i < s.len) : (i += 1) {
        const pos = &s[(s.len - 1) - i];
        const c = pos.* + carry;
        if (c > 'z') {
            carry = 1;
            pos.* = 'a';
        } else {
            carry = 0;
            pos.* = c;
        }
    }
}

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    //  const limit = 1 * 1024 * 1024 * 1024;
    //  const text = try std.fs.cwd().readFileAlloc(allocator, "day9.txt", limit);

    var password: [8]u8 = undefined;
    @memcpy(&password, "vzbxkghb");
    add_one(&password);
    while (!is_valid1(&password)) {
        add_one(&password);
    }
    add_one(&password);
    while (!is_valid1(&password)) {
        add_one(&password);
    }

    const out = std.io.getStdOut().writer();
    try out.print("pass = {s}\n", password);

    //    return error.SolutionNotFound;
}
