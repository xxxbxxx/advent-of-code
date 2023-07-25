const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

const Vec2 = tools.Vec2;

pub fn run(input_text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    const param: struct {
        stride: usize,
        width: usize,
        height: usize,
        map: []const u8,
    } = blk: {
        const width = std.mem.indexOfScalar(u8, input_text, '\n').?;
        const stride = width + 2 + 1;
        const height = (input_text.len + 1) / (width + 1);
        const input = try allocator.alloc(u8, (height + 2) * stride);
        errdefer allocator.free(input);

        @memset(input[0 .. width + 2], '.');
        @memset(input[(height + 1) * stride .. ((height + 1) * stride) + width + 2], '.');
        input[width + 2] = '\n';
        input[((height + 1) * stride) + width + 2] = '\n';

        var y: usize = 1;
        var it = std.mem.tokenize(u8, input_text, "\n\r");
        while (it.next()) |line| {
            std.mem.copy(u8, input[y * stride + 1 .. y * stride + 1 + width], line[0..width]);
            input[y * stride + 0] = '.';
            input[y * stride + width + 1] = '.';
            input[y * stride + width + 2] = '\n';
            y += 1;
        }

        // std.debug.print("{}\n", .{input});
        break :blk .{
            .stride = stride,
            .width = width,
            .height = height,
            .map = input,
        };
    };
    defer allocator.free(param.map);

    const ans1 = ans: {
        const buf1 = try allocator.dupe(u8, param.map);
        defer allocator.free(buf1);
        const buf2 = try allocator.dupe(u8, param.map);
        defer allocator.free(buf2);
        const bufs = [2][]u8{ buf1, buf2 };
        var curbuf: u32 = 0;
        var prev_count: u32 = 0;
        while (true) {
            const prev = bufs[curbuf];
            const next = bufs[1 - curbuf];
            var next_count: u32 = 0;
            var p = Vec2{ .x = 1, .y = 1 };
            while (p.y <= param.height) : (p.y += 1) {
                p.x = 1;
                while (p.x <= param.width) : (p.x += 1) {
                    const nb_neihb = blk: {
                        var count: u32 = 0;
                        const neighbours = [_]Vec2{
                            .{ .x = -1, .y = -1 }, .{ .x = -1, .y = 0 }, .{ .x = -1, .y = 1 },
                            .{ .x = 0, .y = -1 },  .{ .x = 0, .y = 1 },  .{ .x = 1, .y = -1 },
                            .{ .x = 1, .y = 0 },   .{ .x = 1, .y = 1 },
                        };
                        inline for (neighbours) |o| {
                            const n = p.add(o);
                            if (prev[@as(usize, @intCast(n.y)) * param.stride + @as(usize, @intCast(n.x))] == '#')
                                count += 1;
                        }
                        break :blk count;
                    };
                    const curseat = prev[@as(usize, @intCast(p.y)) * param.stride + @as(usize, @intCast(p.x))];
                    const nextseat = &next[@as(usize, @intCast(p.y)) * param.stride + @as(usize, @intCast(p.x))];
                    if (curseat == 'L' and nb_neihb == 0) {
                        nextseat.* = '#';
                    } else if (curseat == '#' and nb_neihb >= 4) {
                        nextseat.* = 'L';
                    } else {
                        nextseat.* = curseat;
                    }
                    if (nextseat.* == '#') next_count += 1;
                }
            }
            // std.debug.print("seats={}:\n{}\n", .{ next_count, next });
            if (prev_count == next_count) break :ans next_count;

            prev_count = next_count;
            curbuf = 1 - curbuf;
        }
        unreachable;
    };

    const ans2 = ans: {
        const buf1 = try allocator.dupe(u8, param.map);
        defer allocator.free(buf1);
        const buf2 = try allocator.dupe(u8, param.map);
        defer allocator.free(buf2);
        const bufs = [2][]u8{ buf1, buf2 };
        var curbuf: u32 = 0;
        var prev_count: u32 = 0;
        while (true) {
            const prev = bufs[curbuf];
            const next = bufs[1 - curbuf];
            var next_count: u32 = 0;
            var p = Vec2{ .x = 1, .y = 1 };
            while (p.y <= param.height) : (p.y += 1) {
                p.x = 1;
                while (p.x <= param.width) : (p.x += 1) {
                    const nb_neihb = blk: {
                        const neighbours = [_]Vec2{
                            .{ .x = -1, .y = -1 }, .{ .x = -1, .y = 0 }, .{ .x = -1, .y = 1 },
                            .{ .x = 0, .y = -1 },  .{ .x = 0, .y = 1 },  .{ .x = 1, .y = -1 },
                            .{ .x = 1, .y = 0 },   .{ .x = 1, .y = 1 },
                        };

                        var d: i32 = 0;
                        var count: u32 = 0;
                        var done: @Vector(8, u1) = [1]u1{0} ** 8;
                        while (@reduce(.And, done) == 0) {
                            d += 1;
                            inline for (neighbours, 0..) |o, i| {
                                const n = p.add(Vec2{ .x = o.x * d, .y = o.y * d });
                                if (n.x < 1 or n.y < 1 or n.x > param.width or n.y > param.height) {
                                    done[i] = 1;
                                } else if (done[i] != 0) {
                                    const seat = prev[@as(usize, @intCast(n.y)) * param.stride + @as(usize, @intCast(n.x))];
                                    if (seat == '#') {
                                        count += 1;
                                        done[i] = 1;
                                    } else if (seat == 'L') {
                                        done[i] = 1;
                                    }
                                }
                            }
                        }
                        break :blk count;
                    };
                    const idx = @as(usize, @intCast(p.y)) * param.stride + @as(usize, @intCast(p.x));
                    const curseat = prev[idx];
                    const nextseat = &next[idx];
                    if (curseat == 'L' and nb_neihb == 0) {
                        nextseat.* = '#';
                    } else if (curseat == '#' and nb_neihb >= 5) {
                        nextseat.* = 'L';
                    } else {
                        nextseat.* = curseat;
                    }
                    if (nextseat.* == '#') next_count += 1;
                    //if (curbuf == 1 and nextseat.* != '.') nextseat.* = '0' + @intCast(u8, count);
                }
            }
            //std.debug.print("seats={}:\n{}\n", .{ next_count, next });
            if (prev_count == next_count) break :ans next_count;

            prev_count = next_count;
            curbuf = 1 - curbuf;
        }
        unreachable;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2020/input_day11.txt", run);
