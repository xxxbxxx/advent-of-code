const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

const SkyMap = tools.Map(u8, 500, 500, true);
const Vec2 = tools.Vec2;

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    const Star = struct { p: Vec2, v: Vec2 };
    var stars = std.ArrayList(Star).init(allocator);
    defer stars.deinit();

    {
        var it = std.mem.tokenize(u8, input, "\n\r");
        while (it.next()) |line| {
            const fields = tools.match_pattern("position=<{}, {}> velocity=<{}, {}>", line) orelse unreachable;
            try stars.append(Star{
                .p = Vec2{ .x = @as(i32, @intCast(fields[0].imm)), .y = @as(i32, @intCast(fields[1].imm)) },
                .v = Vec2{ .x = @as(i32, @intCast(fields[2].imm)), .y = @as(i32, @intCast(fields[3].imm)) },
            });
        }
    }

    // part1
    var mem: [128 * 128]u8 = undefined;
    var seconds: u32 = 0;
    const ans1 = ans: {
        var cur_stars = try allocator.dupe(Star, stars.items);
        defer allocator.free(cur_stars);
        var sky_map: []const u8 = "";
        var sky_size: isize = 999999999;
        while (true) {
            seconds += 1;
            var bbox = tools.BBox.empty;
            for (cur_stars) |*it| {
                it.p = Vec2.add(it.p, it.v);
                bbox.max = Vec2.max(it.p, bbox.max);
                bbox.min = Vec2.min(it.p, bbox.min);
            }
            const size = (try std.math.absInt(bbox.max.x - bbox.min.x)) + (try std.math.absInt(bbox.max.y - bbox.min.y));
            if (sky_size >= size) {
                sky_size = size;
            } else {
                //std.debug.print("bbox={}\n", .{bbox});
                break;
            }
            if (size < 100) {
                var sky = SkyMap{ .default_tile = ' ' };
                sky.fill(' ', bbox);
                for (cur_stars) |it| {
                    sky.set(it.p, '#');
                }
                sky_map = sky.printToBuf(null, bbox, null, &mem);
                // std.debug.print("map=\n{}", .{sky_map});
            }
        }
        break :ans sky_map;
    };

    // part2
    const ans2 = seconds - 1;

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{s}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2018/input_day10.txt", run);
