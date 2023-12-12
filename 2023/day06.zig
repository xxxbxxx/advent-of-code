const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub const main = tools.defaultMain("2023/day06.txt", run);

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena_alloc = std.heap.ArenaAllocator.init(allocator);
    defer arena_alloc.deinit();
    const arena = arena_alloc.allocator();

    const ans1 = ans: {
        var times = std.ArrayList(u32).init(arena);
        defer times.deinit();
        var dists = std.ArrayList(u32).init(arena);
        defer dists.deinit();

        var it = std.mem.tokenize(u8, input, "\n\r\t");
        while (it.next()) |line| {
            if (tools.match_pattern("Time: {}", line)) |vals| {
                var it2 = std.mem.tokenize(u8, vals[0].lit, " ");
                while (it2.next()) |num| {
                    try times.append(try std.fmt.parseInt(u32, num, 10));
                }
            }
            if (tools.match_pattern("Distance: {}", line)) |vals| {
                var it2 = std.mem.tokenize(u8, vals[0].lit, " ");
                while (it2.next()) |num| {
                    try dists.append(try std.fmt.parseInt(u32, num, 10));
                }
            }
        }

        var prod: usize = 1;
        for (times.items, dists.items) |race_time, race_dist| {
            var count: u32 = 0;
            for (1..race_time) |press_time| {
                const speed = press_time;
                const d = (race_time - press_time) * speed;
                count += @intFromBool(d > race_dist);
            }
            prod *= count;
        }
        break :ans prod;
    };

    const ans2 = ans: {
        const race_time, const race_dist = blk: {
            var t: i64 = 0;
            var d: i64 = 0;
            var it = std.mem.tokenize(u8, input, "\n\r\t");
            while (it.next()) |line| {
                if (tools.match_pattern("Time: {}", line)) |vals| {
                    for (vals[0].lit) |c| {
                        if (c >= '0' and c <= '9')
                            t = t * 10 + (c - '0');
                    }
                }
                if (tools.match_pattern("Distance: {}", line)) |vals| {
                    for (vals[0].lit) |c| {
                        if (c >= '0' and c <= '9')
                            d = d * 10 + (c - '0');
                    }
                }
            }
            break :blk .{ t, d };
        };

        // d = (race_time-press_time)*press_time
        // d > race_dist
        //  racines: -t*t +t*race_time -race_dist
        const det: u64 = @intCast(race_time * race_time - 4 * -1 * -race_dist);
        const r1 = @divTrunc(-race_time - std.math.sqrt(det), 2 * -1); // round up   (c'est des nombres négatifs)
        const r2 = @divTrunc(1 - race_time + std.math.sqrt(det), 2 * -1); // round down (c'est des nombres négatifs)
        const count = r1 - r2;
        break :ans count;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

test {
    const res = try run(
        \\Time:      7  15   30
        \\Distance:  9  40  200
    , std.testing.allocator);
    defer std.testing.allocator.free(res[0]);
    defer std.testing.allocator.free(res[1]);
    try std.testing.expectEqualStrings("288", res[0]);
    try std.testing.expectEqualStrings("71503", res[1]);
}
