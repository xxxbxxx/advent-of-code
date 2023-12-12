const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

const Vec2 = tools.Vec2;

pub fn run(input_text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    const ans1 = ans: {
        var p = Vec2{ .x = 0, .y = 0 };
        var d = Vec2{ .x = 1, .y = 0 };
        var it = std.mem.tokenize(u8, input_text, "\n\r");
        while (it.next()) |line| {
            const action = line[0];
            const amount = try std.fmt.parseInt(i32, line[1..], 10);
            //std.debug.print("{c}{}  p={}, d={} .....", .{ action, amount, p, d });
            switch (action) {
                'N' => { // means to move north by the given value.
                    p = p.add(Vec2{ .x = 0, .y = -amount });
                },
                'S' => { // means to move south by the given value.
                    p = p.add(Vec2{ .x = 0, .y = amount });
                },
                'E' => { // means to move east by the given value.
                    p = p.add(Vec2{ .x = amount, .y = 0 });
                },
                'W' => { // means to move west by the given value.
                    p = p.add(Vec2{ .x = -amount, .y = 0 });
                },
                'L' => { // means to turn left the given number of degrees.
                    var rots = @divExact(amount, 90);
                    while (rots > 0) {
                        const new = Vec2{ .x = d.y, .y = -d.x };
                        d = new;
                        rots -= 1;
                    }
                },
                'R' => { // means to turn right the given number of degrees.
                    var rots = @divExact(amount, 90);
                    while (rots > 0) {
                        const new = Vec2{ .x = -d.y, .y = d.x };
                        d = new;
                        rots -= 1;
                    }
                },
                'F' => { // means to move forward by the given value in the direction the ship is currently facing.
                    p = p.add(Vec2{ .x = d.x * amount, .y = d.y * amount });
                },
                else => unreachable,
            }
            //std.debug.print("p={}, d={}\n", .{ p, d });
        }
        break :ans @abs(p.x) + @abs(p.y);
    };

    const ans2 = ans: {
        var p = Vec2{ .x = 0, .y = 0 };
        var d = Vec2{ .x = 10, .y = -1 };
        var it = std.mem.tokenize(u8, input_text, "\n\r");
        while (it.next()) |line| {
            const action = line[0];
            const amount = try std.fmt.parseInt(i32, line[1..], 10);
            //std.debug.print("{c}{}  p={}, d={} .....", .{ action, amount, p, d });
            switch (action) {
                'N' => { // move the waypoint north by the given value.
                    d = d.add(Vec2{ .x = 0, .y = -amount });
                },
                'S' => { // move the waypoint south by the given value.
                    d = d.add(Vec2{ .x = 0, .y = amount });
                },
                'E' => { // move the waypoint east by the given value.
                    d = d.add(Vec2{ .x = amount, .y = 0 });
                },
                'W' => { // move the waypoint west by the given value.
                    d = d.add(Vec2{ .x = -amount, .y = 0 });
                },
                'L' => { // rotate the waypoint around the ship left (counter-clockwise) the given number of degrees.
                    var rots = @divExact(amount, 90);
                    while (rots > 0) {
                        const new = Vec2{ .x = d.y, .y = -d.x };
                        d = new;
                        rots -= 1;
                    }
                },
                'R' => { // rotate the waypoint around the ship right (clockwise) the given number of degrees.
                    var rots = @divExact(amount, 90);
                    while (rots > 0) {
                        const new = Vec2{ .x = -d.y, .y = d.x };
                        d = new;
                        rots -= 1;
                    }
                },
                'F' => { // mmove forward to the waypoint a number of times equal to the given value.
                    p = p.add(Vec2{ .x = d.x * amount, .y = d.y * amount });
                },
                else => unreachable,
            }
            //std.debug.print("p={}, d={}\n", .{ p, d });
        }
        break :ans @abs(p.x) + @abs(p.y);
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2020/input_day12.txt", run);
