const std = @import("std");
const tools = @import("tools");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

fn abs(a: i32) u32 {
    return if (a > 0) @intCast(u32, a) else @intCast(u32, -a);
}

const Map = tools.Map(u48, 1000, 1000, true);
const Vec2 = tools.Vec2;

fn sum(grid: *const Map, p: Vec2) u48 {
    var s: u48 = 0;
    var y: i32 = -1;
    while (y <= 1) : (y += 1) {
        var x: i32 = -1;
        while (x <= 1) : (x += 1) {
            s += grid.get(Vec2{ .x = p.x + x, .y = p.y + y }) orelse 0;
        }
    }
    return s;
}

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().writer();
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    //const limit = 1 * 1024 * 1024 * 1024;
    //const text = try std.fs.cwd().readFileAlloc(allocator, "day2.txt", limit);
    //defer allocator.free(text);

    var grid = Map{ .default_tile = 0 };
    std.mem.set(u48, &grid.map, 0);

    var p = Vec2{ .x = 0, .y = 0 };
    var num: u48 = 1;
    grid.set(p, 1);
    var size: i32 = 1;
    p.x += 1;

    const req: u48 = 325489;
    var ans1: ?Vec2 = null;
    var ans2: ?u48 = null;

    while (num < 500000) {
        while (p.y > -size) : (p.y -= 1) {
            num += 1;
            if (num == req) ans1 = p;
            if (ans2 == null) {
                const s = sum(&grid, p);
                grid.set(p, s);
                if (s >= req) ans2 = s;
            }
        }
        while (p.x > -size) : (p.x -= 1) {
            num += 1;
            if (num == req) ans1 = p;
            if (ans2 == null) {
                const s = sum(&grid, p);
                grid.set(p, s);
                if (s >= req) ans2 = s;
            }
        }
        while (p.y < size) : (p.y += 1) {
            num += 1;
            if (num == req) ans1 = p;
            if (ans2 == null) {
                const s = sum(&grid, p);
                grid.set(p, s);
                if (s >= req) ans2 = s;
            }
        }
        while (p.x <= size) : (p.x += 1) {
            num += 1;
            if (num == req) ans1 = p;
            if (ans2 == null) {
                const s = sum(&grid, p);
                grid.set(p, s);
                if (s >= req) ans2 = s;
            }
        }
        size += 1;
    }

    var buf: [5000]u8 = undefined;
    trace("map=\n{}\n", .{grid.printToBuf(p, null, &buf)});

    try stdout.print("ans={}, dist={}, ans2={}\n\n", .{ ans1, abs(ans1.?.x) + abs(ans1.?.y), ans2 });
}
