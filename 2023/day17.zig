const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub const main = tools.defaultMain("2023/day17.txt", run);
const Map = tools.Map(u8, 150, 150, false);
const Vec2 = tools.Vec2;

pub fn run(text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena_alloc = std.heap.ArenaAllocator.init(allocator);
    defer arena_alloc.deinit();
    const arena = arena_alloc.allocator();
    _ = arena;

    var map: Map = .{ .default_tile = '.' };
    map.initFromText(text);
    const goal = map.bbox.max;

    const State = struct {
        p: Vec2,
        dir: Vec2,
        total_loss: u32,
        consecutive: u8,
        fn lessThan(g: Vec2, a: @This(), b: @This()) std.math.Order {
            const da = @reduce(.Add, @abs(g - a.p)) + a.total_loss;
            const db = @reduce(.Add, @abs(g - b.p)) + b.total_loss;
            return std.math.order(da, db);
        }
    };
    var agenda = std.PriorityQueue(State, Vec2, State.lessThan).init(allocator, goal);
    defer agenda.deinit();
    var visited = std.AutoHashMap(struct { Vec2, Vec2, u32 }, u32).init(allocator);
    defer visited.deinit();

    const ans1 = ans: {
        try agenda.add(State{ .p = .{ 0, 0 }, .dir = .{ 1, 0 }, .total_loss = 0, .consecutive = 0 });
        try agenda.add(State{ .p = .{ 0, 0 }, .dir = .{ 0, 1 }, .total_loss = 0, .consecutive = 0 });

        while (agenda.removeOrNull()) |s| {
            if (@reduce(.And, s.p == goal)) break :ans s.total_loss;
            if (visited.get(.{ s.p, s.dir, s.consecutive })) |value| {
                if (value <= s.total_loss) continue;
            }
            try visited.put(.{ s.p, s.dir, s.consecutive }, s.total_loss);

            //std.debug.print("pop state:{}\n", .{s});
            const dir_straight: Vec2 = s.dir;
            const dir_left: Vec2 = .{ -s.dir[1], s.dir[0] };
            const dir_right: Vec2 = .{ s.dir[1], -s.dir[0] };
            inline for (.{ .{ dir_straight, s.consecutive + 1 }, .{ dir_left, 1 }, .{ dir_right, 1 } }) |step| {
                if (step[1] < 4) {
                    const p1 = s.p + step[0];
                    if (map.get(p1)) |loss| {
                        const s1: State = .{ .p = p1, .dir = step[0], .total_loss = s.total_loss + (loss - '0'), .consecutive = step[1] };
                        //std.debug.print("push state:{}\n", .{s1});
                        try agenda.add(s1);
                    }
                }
            }
        }
        unreachable;
    };

    agenda.len = 0;
    visited.clearRetainingCapacity();
    const ans2 = ans: {
        try agenda.add(State{ .p = .{ 0, 0 }, .dir = .{ 1, 0 }, .total_loss = 0, .consecutive = 0 });
        try agenda.add(State{ .p = .{ 0, 0 }, .dir = .{ 0, 1 }, .total_loss = 0, .consecutive = 0 });

        while (agenda.removeOrNull()) |s| {
            if (@reduce(.And, s.p == goal)) {
                if (s.consecutive >= 4) break :ans s.total_loss;
                continue;
            }

            if (visited.get(.{ s.p, s.dir, s.consecutive })) |value| {
                if (value <= s.total_loss) continue;
            }
            try visited.put(.{ s.p, s.dir, s.consecutive }, s.total_loss);

            const dir_straight: Vec2 = s.dir;
            const dir_left: Vec2 = .{ -s.dir[1], s.dir[0] };
            const dir_right: Vec2 = .{ s.dir[1], -s.dir[0] };
            const moves: []const struct { Vec2, u8 } = switch (s.consecutive) {
                0...3 => &.{.{ dir_straight, s.consecutive + 1 }},
                4...9 => &.{ .{ dir_straight, s.consecutive + 1 }, .{ dir_left, 1 }, .{ dir_right, 1 } },
                10 => &.{ .{ dir_left, 1 }, .{ dir_right, 1 } },
                else => unreachable,
            };
            for (moves) |step| {
                const p1 = s.p + step[0];
                if (map.get(p1)) |loss| {
                    const l = s.total_loss + (loss - '0');
                    if (visited.get(.{ p1, step[0], step[1] })) |value| {
                        if (value <= l) continue;
                    }

                    try agenda.add(.{ .p = p1, .dir = step[0], .total_loss = l, .consecutive = step[1] });
                }
            }
        }
        unreachable;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

test {
    const res1 = try run(
        \\2413432311323
        \\3215453535623
        \\3255245654254
        \\3446585845452
        \\4546657867536
        \\1438598798454
        \\4457876987766
        \\3637877979653
        \\4654967986887
        \\4564679986453
        \\1224686865563
        \\2546548887735
        \\4322674655533
    , std.testing.allocator);
    defer std.testing.allocator.free(res1[0]);
    defer std.testing.allocator.free(res1[1]);
    try std.testing.expectEqualStrings("102", res1[0]);
    try std.testing.expectEqualStrings("94", res1[1]);

    const res2 = try run(
        \\111111111111
        \\999999999991
        \\999999999991
        \\999999999991
        \\999999999991
    , std.testing.allocator);
    defer std.testing.allocator.free(res2[0]);
    defer std.testing.allocator.free(res2[1]);
    try std.testing.expectEqualStrings("59", res2[0]);
    try std.testing.expectEqualStrings("71", res2[1]);
}
