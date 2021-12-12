const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

const Vec2 = tools.Vec2;

fn powerOfCell(p: Vec2, SN: u32) i32 {
    const rackId = @intCast(u32, p.x + 10);
    var pow = @intCast(u32, p.y) * rackId;
    pow += SN;
    pow *= rackId;
    pow /= 100;
    pow = pow % 10;

    return @intCast(i32, pow) - 5;
}

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    _ = input;
    const SN = 7403; // GridSerialNumber

    //std.debug.print("test (3,5) 8: {}\n", .{powerOfCell(Vec2{ .x = 3, .y = 5 }, 8)});
    //std.debug.print("test (217,196) 39: {}\n", .{powerOfCell(Vec2{ .x = 217, .y = 196 }, 39)});

    // chaque case = integrale de la surface en haut à gauche
    const powergrid = try allocator.alloc(i32, 301 * 301);
    const stride = 301;
    defer allocator.free(powergrid);
    {
        var p = Vec2{ .x = 0, .y = 0 };
        while (p.y <= 300) : (p.y += 1) {
            p.x = 0;
            while (p.x <= 300) : (p.x += 1) {
                if (p.x == 0 or p.y == 0) {
                    powergrid[@intCast(usize, p.x + stride * p.y)] = 0;
                    continue;
                }
                const p00 = Vec2.add(p, Vec2{ .x = 0, .y = 0 });
                //const p01 = Vec2.add(p, Vec2{ .x = 0, .y = -1 });
                //const p10 = Vec2.add(p, Vec2{ .x = -1, .y = 0 });
                //const p11 = Vec2.add(p, Vec2{ .x = -1, .y = -1 });
                const pow = powerOfCell(p00, SN);
                const acc01 = powergrid[@intCast(usize, (p.x - 1) + stride * (p.y - 0))];
                const acc10 = powergrid[@intCast(usize, (p.x - 0) + stride * (p.y - 1))];
                const acc11 = powergrid[@intCast(usize, (p.x - 1) + stride * (p.y - 1))];
                powergrid[@intCast(usize, p.x + stride * p.y)] = pow + (acc01 + (acc10 - acc11));
            }
        }
    }

    // part1
    const ans1 = ans: {
        var best = Vec2{ .x = 0, .y = 0 };
        var best_pow: i64 = -999999999;
        var p = Vec2{ .x = 1, .y = 1 };
        while (p.y <= 300 - 3) : (p.y += 1) {
            p.x = 1;
            while (p.x <= 300 - 3) : (p.x += 1) {
                const sz = Vec2{ .x = 2, .y = 2 };
                const acc00 = powergrid[@intCast(usize, (p.x - 1) + stride * (p.y - 1))];
                const acc03 = powergrid[@intCast(usize, (p.x - 1) + stride * (p.y + sz.y))];
                const acc30 = powergrid[@intCast(usize, (p.x + sz.x) + stride * (p.y - 1))];
                const acc33 = powergrid[@intCast(usize, (p.x + sz.x) + stride * (p.y + sz.y))];
                const pow = (acc33 - acc03) - (acc30 - acc00);
                if (best_pow < pow) {
                    best_pow = pow;
                    best = p;
                }
            }
        }
        break :ans best;
    };

    // part2
    const ans2 = ans: {
        var best: struct { p: Vec2, sz: i32 } = .{ .p = Vec2{ .x = 0, .y = 0 }, .sz = 0 };
        var best_pow: i64 = -999999999;
        var p = Vec2{ .x = 1, .y = 1 };
        while (p.y <= 300) : (p.y += 1) {
            p.x = 1;
            while (p.x <= 300) : (p.x += 1) {
                var sz: i32 = 0;
                while (sz <= (300 - p.x) and sz <= (300 - p.y)) : (sz += 1) {
                    const acc00 = powergrid[@intCast(usize, (p.x - 1) + stride * (p.y - 1))];
                    const acc03 = powergrid[@intCast(usize, (p.x - 1) + stride * (p.y + sz))];
                    const acc30 = powergrid[@intCast(usize, (p.x + sz) + stride * (p.y - 1))];
                    const acc33 = powergrid[@intCast(usize, (p.x + sz) + stride * (p.y + sz))];
                    const pow = (acc33 - acc03) - (acc30 - acc00);
                    if (best_pow < pow) {
                        best_pow = pow;
                        best = .{ .p = p, .sz = sz + 1 };
                    }
                }
            }
        }
        break :ans best;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2018/input_day10.txt", run);
