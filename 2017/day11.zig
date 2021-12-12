const std = @import("std");
const tools = @import("tools");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

fn abs(a: i32) i32 {
    return if (a > 0) a else -a;
}
fn min(a: i32, b: i32) i32 {
    return if (a > b) b else a;
}
fn max(a: i32, b: i32) i32 {
    return if (a > b) a else b;
}

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().writer();
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day11.txt", limit);
    defer allocator.free(text);

    const Dir = enum {
        n,
        nw,
        sw,
        s,
        se,
        ne,
    };
    const dirnames = [_]struct {
        d: Dir,
        str: []const u8,
    }{
        .{ .d = .n, .str = "n" },
        .{ .d = .nw, .str = "nw" },
        .{ .d = .sw, .str = "sw" },
        .{ .d = .s, .str = "s" },
        .{ .d = .se, .str = "se" },
        .{ .d = .ne, .str = "ne" },
    };

    var x: i32 = 0;
    var y: i32 = 0;
    var z: i32 = 0;
    var maxd: i32 = 0;
    var it = std.mem.tokenize(u8, text, ",\n");
    while (it.next()) |dir| {
        const d = for (dirnames) |dn| {
            if (std.mem.eql(u8, dir, dn.str))
                break dn.d;
        } else unreachable;

        switch (d) {
            .n => {
                x += 0;
                y += 1;
                z -= 1;
            },
            .nw => {
                x -= 1;
                y += 1;
                z -= 0;
            },
            .sw => {
                x -= 1;
                y += 0;
                z += 1;
            },
            .s => {
                x += 0;
                y -= 1;
                z += 1;
            },
            .se => {
                x += 1;
                y -= 1;
                z -= 0;
            },
            .ne => {
                x += 1;
                y += 0;
                z -= 1;
            },
        }
        assert(x + y + z == 0);
        const dist = max(abs(x), max(abs(y), abs(z)));
        if (dist > maxd) maxd = dist;
    }

    try stdout.print("dist={}+{}+{} = {}\n, maxd={}\n", .{
        x,                                y,    z,
        max(abs(x), max(abs(y), abs(z))), maxd,
    });
}
