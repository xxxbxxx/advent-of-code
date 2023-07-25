const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub const main = tools.defaultMain("2021/day02.txt", run);

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    const Vec2 = @Vector(2, i32);

    const ans1 = ans: {
        var pos = Vec2{ 0, 0 };
        var it = std.mem.tokenize(u8, input, "\n\r");
        while (it.next()) |line| {
            var delta = Vec2{ 0, 0 };
            if (tools.match_pattern("forward {}", line)) |val| {
                delta[0] = @as(i32, @intCast(val[0].imm));
            } else if (tools.match_pattern("down {}", line)) |val| {
                delta[1] = @as(i32, @intCast(val[0].imm));
            } else if (tools.match_pattern("up {}", line)) |val| {
                delta[1] = @as(i32, @intCast(-val[0].imm));
            } else {
                std.debug.print("skipping {s}\n", .{line});
            }
            pos += delta;
        }
        break :ans @reduce(.Mul, pos);
    };

    const ans2 = ans: {
        var pos = Vec2{ 0, 0 };
        var aim: i32 = 0;
        var it = std.mem.tokenize(u8, input, "\n\r");
        while (it.next()) |line| {
            if (tools.match_pattern("forward {}", line)) |val| {
                const x = @as(i32, @intCast(val[0].imm));
                pos += Vec2{ x, x * aim };
            } else if (tools.match_pattern("down {}", line)) |val| {
                aim += @as(i32, @intCast(val[0].imm));
            } else if (tools.match_pattern("up {}", line)) |val| {
                aim -= @as(i32, @intCast(val[0].imm));
            } else {
                std.debug.print("skipping {s}\n", .{line});
            }
        }
        break :ans @reduce(.Mul, pos);
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

test {
    const res = try run(
        \\forward 5
        \\down 5
        \\forward 8
        \\up 3
        \\down 8
        \\forward 2
    , std.testing.allocator);
    defer std.testing.allocator.free(res[0]);
    defer std.testing.allocator.free(res[1]);
    try std.testing.expectEqualStrings("150", res[0]);
    try std.testing.expectEqualStrings("900", res[1]);
}
