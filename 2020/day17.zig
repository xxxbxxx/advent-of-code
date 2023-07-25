const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

const Vec2 = tools.Vec2;

pub fn run(input_text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const param: struct {
        stride: usize,
        width: usize,
        height: usize,
        map: []const u8,
    } = blk: {
        const width = std.mem.indexOfScalar(u8, input_text, '\n').?;
        const stride = width + 1;
        const height = (input_text.len + 1) / (width + 1);

        // std.debug.print("{}\n", .{input});
        break :blk .{
            .stride = stride,
            .width = width,
            .height = height,
            .map = input_text,
        };
    };

    const ans1 = ans: {
        const dim1 = 24;
        const dim2 = dim1 * dim1;
        const center_offset = (dim1 / 2) * dim2 + (dim1 / 2) * dim1 + (dim1 / 2);
        const cube = try allocator.alloc(u8, dim2 * dim1);
        defer allocator.free(cube);
        @memset(cube, '.');
        for (param.map, 0..) |v, i| {
            const y = i / param.stride;
            const x = i % param.stride;
            if (x > param.width or y > param.height) continue;

            const x0 = @as(i32, @intCast(x)) - @as(i32, @intCast(param.width / 2));
            const y0 = @as(i32, @intCast(y)) - @as(i32, @intCast(param.height / 2));

            cube[@intCast(center_offset + y0 * dim1 + x0)] = v;
        }
        const neighbours = comptime blk: {
            var o: [26]isize = undefined;
            var nb: usize = 0;
            var z: isize = -1;
            while (z <= 1) : (z += 1) {
                var y: isize = -1;
                while (y <= 1) : (y += 1) {
                    var x: isize = -1;
                    while (x <= 1) : (x += 1) {
                        if (x == 0 and y == 0 and z == 0) continue;
                        o[nb] = dim2 * z + dim1 * y + x;
                        nb += 1;
                    }
                }
            }
            break :blk o;
        };

        // avec deux plans d'espace supplémentaire pour que ça wrappe et eviter les frontieres
        const cube2 = try allocator.alloc(u8, dim2 * dim1 + dim2 * 2 + dim1 * 2 + 2);
        defer allocator.free(cube2);
        @memset(cube2, '.');
        const padding = dim2 + dim1 + 1;

        var gen: usize = 0;
        while (gen < 6) : (gen += 1) {
            std.mem.copy(u8, cube2[padding .. padding + cube.len], cube);
            for (cube, 0..) |*v, i| {
                var n: usize = 0;
                inline for (neighbours) |o| {
                    if (cube2[@intCast(@as(isize, @intCast(padding + i)) + o)] == '#') n += 1;
                }

                if (v.* == '#') {
                    v.* = if (n == 2 or n == 3) '#' else '.';
                } else {
                    v.* = if (n == 3) '#' else '.';
                }
            }
        }

        var count: usize = 0;
        for (cube) |v| {
            if (v == '#') count += 1;
        }
        break :ans count;
    };

    const ans2 = ans: {
        const dim1 = 22;
        const dim2 = dim1 * dim1;
        const dim3 = dim2 * dim1;
        const center_offset = (dim1 / 2) * dim3 + (dim1 / 2) * dim2 + (dim1 / 2) * dim1 + (dim1 / 2) * 1;
        const cube = try allocator.alloc(u8, dim3 * dim1);
        defer allocator.free(cube);
        @memset(cube, '.');
        for (param.map, 0..) |v, i| {
            const y = i / param.stride;
            const x = i % param.stride;
            if (x > param.width or y > param.height) continue;

            const x0 = @as(i32, @intCast(x)) - @as(i32, @intCast(param.width / 2));
            const y0 = @as(i32, @intCast(y)) - @as(i32, @intCast(param.height / 2));

            cube[@intCast(center_offset + y0 * dim1 + x0)] = v;
        }
        const neighbours = comptime blk: {
            var o: [80]isize = undefined;
            var nb: usize = 0;
            var w: isize = -1;
            while (w <= 1) : (w += 1) {
                var z: isize = -1;
                while (z <= 1) : (z += 1) {
                    var y: isize = -1;
                    while (y <= 1) : (y += 1) {
                        var x: isize = -1;
                        while (x <= 1) : (x += 1) {
                            if (x == 0 and y == 0 and z == 0 and w == 0) continue;
                            o[nb] = dim3 * w + dim2 * z + dim1 * y + x;
                            nb += 1;
                        }
                    }
                }
            }
            break :blk o;
        };

        // avec deux hyper-plans d'espace supplémentaire pour que ça wrappe et eviter les frontieres
        const cube2 = try allocator.alloc(u8, dim2 * dim2 + dim3 * 2 + dim2 * 2 + dim1 * 2 + 2);
        defer allocator.free(cube2);
        @memset(cube2, '.');
        const padding = dim3 + dim2 + dim1 + 1;

        var gen: usize = 0;
        while (gen < 6) : (gen += 1) {
            std.mem.copy(u8, cube2[padding .. padding + cube.len], cube);
            for (cube, 0..) |*v, i| {
                var n: usize = 0;
                inline for (neighbours) |o| {
                    if (cube2[@intCast(@as(isize, @intCast(padding + i)) + o)] == '#') n += 1;
                }

                if (v.* == '#') {
                    v.* = if (n == 2 or n == 3) '#' else '.';
                } else {
                    v.* = if (n == 3) '#' else '.';
                }
            }
        }

        var count: usize = 0;
        for (cube) |v| {
            if (v == '#') count += 1;
        }
        break :ans count;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2020/input_day17.txt", run);
