const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub const main = tools.defaultMain("2021/day05.txt", run);

const Tile = @Vector(2, u2); // [0] only axis aligned, [1] all
//const Tile = @Vector(2, u8); // 'u2' fails with stage2.
const Map = tools.Map(Tile, 1000, 1000, false);
const Vec2 = tools.Vec2;

fn rasterize(map: *Map, a: Vec2, b: Vec2) void {
    const delta = tools.Vec.clamp(b - a, Vec2{ -1, -1 }, Vec2{ 1, 1 });
    const is_diag = @reduce(.And, delta != Vec2{ 0, 0 });
    const inc = Tile{ @boolToInt(!is_diag), 1 };
    var p = a;
    while (@reduce(.Or, p != b + delta)) : (p += delta) {
        const prev = map.get(p) orelse Tile{ 0, 0 };
        map.set(p, prev +| inc);
    }
}

pub fn run(input: []const u8, gpa: std.mem.Allocator) tools.RunError![2][]const u8 {
    var map = Map{ .default_tile = Tile{ 0, 0 } };
    {
        //var buf: [1000]u8 = undefined;
        //const Local = struct {
        //    pub fn toChar(t: Tile) u8 {
        //        const val = t[1];
        //        return if (val == 0) '.' else (@intCast(u8, val) + '0');
        //    }
        //};

        var it = std.mem.tokenize(u8, input, "\n\r");
        while (it.next()) |line| {
            if (tools.match_pattern("{},{} -> {},{}", line)) |val| {
                const a = Vec2{ @intCast(i32, val[0].imm), @intCast(i32, val[1].imm) };
                const b = Vec2{ @intCast(i32, val[2].imm), @intCast(i32, val[3].imm) };
                rasterize(&map, a, b);
            } else {
                std.debug.print("skipping {s}\n", .{line});
            }
            //std.debug.print("trace {s}:\n{s}\n", .{line, map.printToBuf(&buf, .{ .tileToCharFn = Local.toChar })});
        }

        //std.debug.print("map:\n{s}\n", .{map.printToBuf(&buf, .{ .tileToCharFn = Local.toChar })});
    }

    const ans = ans: {
        var count = @Vector(2, u32){ 0, 0 };
        var it = map.iter(null);
        while (it.next()) |v| count += @as(@Vector(2, u32), @bitCast(@Vector(2, u1), v > Tile{ 1, 1 })); // aka @boolToInt()
        break :ans count;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(gpa, "{}", .{ans[0]}),
        try std.fmt.allocPrint(gpa, "{}", .{ans[1]}),
    };
}

test {
    const res = try run(
        \\0,9 -> 5,9
        \\8,0 -> 0,8
        \\9,4 -> 3,4
        \\2,2 -> 2,1
        \\7,0 -> 7,4
        \\6,4 -> 2,0
        \\0,9 -> 2,9
        \\3,4 -> 1,4
        \\0,0 -> 8,8
        \\5,5 -> 8,2
    , std.testing.allocator);
    defer std.testing.allocator.free(res[0]);
    defer std.testing.allocator.free(res[1]);
    try std.testing.expectEqualStrings("5", res[0]);
    try std.testing.expectEqualStrings("12", res[1]);
}
