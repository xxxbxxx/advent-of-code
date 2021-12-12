const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

const Vec2 = struct { x: usize, y: usize };

const Map = struct {
    tiles: []const u8,
    width: usize,
    height: usize,
    stride: usize,
};

fn countTrees(map: Map, step: Vec2) usize {
    var p = Vec2{ .x = 0, .y = 0 };
    assert(map.tiles[p.x + map.stride * p.y] == '.');
    var trees: usize = 0;
    while (p.y < map.height) {
        switch (map.tiles[p.x + map.stride * p.y]) {
            '#' => trees += 1,
            '.' => {},
            else => unreachable,
        }

        p.x = (p.x + step.x) % map.width;
        p.y = (p.y + step.y);
    }
    return trees;
}

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {

    // parse map:
    const line_len = std.mem.indexOfScalar(u8, input, '\n') orelse return error.UnsupportedInput;
    const map = Map{
        .tiles = input,
        .width = line_len,
        .stride = 1 + line_len,
        .height = (input.len + 1) / (line_len + 1),
    };

    // part1
    const ans1 = countTrees(map, Vec2{ .x = 3, .y = 1 });

    const ans2 = countTrees(map, Vec2{ .x = 1, .y = 1 }) * countTrees(map, Vec2{ .x = 3, .y = 1 }) * countTrees(map, Vec2{ .x = 5, .y = 1 }) * countTrees(map, Vec2{ .x = 7, .y = 1 }) * countTrees(map, Vec2{ .x = 1, .y = 2 });

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2020/input_day03.txt", run);
