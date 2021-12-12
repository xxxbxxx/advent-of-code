const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

const Vec2 = tools.Vec2;
const Map = tools.Map(u8, 1000, 2000, false);

pub fn run(input_text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var map = Map{ .default_tile = '.' };
    map.fill('.', null);

    {
        var it = std.mem.tokenize(u8, input_text, "\n\r");
        while (it.next()) |line| {
            if (tools.match_pattern("x={}, y={}..{}", line)) |fields| {
                const x = @intCast(i32, fields[0].imm);
                const ymin = @intCast(i32, fields[1].imm);
                const ymax = @intCast(i32, fields[2].imm);
                var p = Vec2{ .x = x, .y = ymin };
                while (p.y <= ymax) : (p.y += 1) {
                    map.set(p, '#');
                }
            } else if (tools.match_pattern("y={}, x={}..{}", line)) |fields| {
                const y = @intCast(i32, fields[0].imm);
                const xmin = @intCast(i32, fields[1].imm);
                const xmax = @intCast(i32, fields[2].imm);
                var p = Vec2{ .x = xmin, .y = y };
                while (p.x <= xmax) : (p.x += 1) {
                    map.set(p, '#');
                }
            }
        }
        map.bbox.min.x -= 1;
        map.bbox.max.x += 1;
    }

    const ans1 = ans: {
        const bbox = map.bbox;
        const source = Vec2{ .x = 500, .y = 0 };
        map.set(source, 'v');
        var dirty_bbox: tools.BBox = bbox;
        dirty_bbox.min = Vec2.min(source, dirty_bbox.min);
        dirty_bbox.max = Vec2.max(source, dirty_bbox.max);

        while (true) {
            var it = map.iter(dirty_bbox);
            dirty_bbox = tools.BBox.empty;
            while (it.nextEx()) |sq| {
                var t = sq.t.*;
                const up = if (sq.up) |x| x else '.';
                const right = if (sq.right) |x| x else '.';
                const left = if (sq.left) |x| x else '.';
                const down_right = if (sq.down_right) |x| x else '.';
                const down = if (sq.down) |x| x else '.';
                const down_left = if (sq.down_left) |x| x else '.';
                const ground_left = (down == '#' or down == '~') and (down_left == '#' or down_left == '~');
                const ground_right = (down == '#' or down == '~') and (down_right == '#' or down_right == '~');
                switch (t) {
                    '#' => continue,
                    '~' => continue,
                    '.' => {
                        if (up == 'v') t = 'v';
                        if (right == 'v' and ground_right) t = 'v';
                        if (left == 'v' and ground_left) t = 'v';
                        if (right == 'v' and down_right == '#') t = 'v';
                        if (left == 'v' and down_left == '#') t = 'v';
                        if (right == '<' and (down_right == '#' or down_right == '~')) t = 'v';
                        if (left == '>' and (down_left == '#' or down_left == '~')) t = 'v';
                    },
                    'v' => {
                        if (right == 'v' and left == '#') t = '>';
                        if (left == 'v' and right == '#') t = '<';
                        if (right == '#' and left == '#' and ground_left and ground_right) t = '~';
                        if (left == '>') t = '>';
                        if (right == '<') t = '<';
                    },
                    '>' => {
                        if (right == '<') t = '~';
                        if (right == '#') t = '~';
                        if (right == '~') t = '~';
                    },
                    '<' => {
                        if (left == '>') t = '~';
                        if (left == '#') t = '~';
                        if (left == '~') t = '~';
                    },
                    else => unreachable,
                }
                if (sq.t.* != t) {
                    sq.t.* = t;
                    dirty_bbox.min = Vec2.min(sq.p, dirty_bbox.min);
                    dirty_bbox.max = Vec2.max(sq.p, dirty_bbox.max);
                }
            }

            if (Vec2.eq(dirty_bbox.min, tools.BBox.empty.min)) {
                var water_bbox = tools.BBox.empty;
                var water: u32 = 0;
                var it2 = map.iter(bbox);
                while (it2.nextEx()) |sq| {
                    switch (sq.t.*) {
                        '~', '>', '<', 'v' => {
                            water_bbox.min = Vec2.min(sq.p, water_bbox.min);
                            water_bbox.max = Vec2.max(sq.p, water_bbox.max);
                            water += 1;
                        },
                        else => {},
                    }
                }
                if (false) {
                    var buf: [2000 * 1000]u8 = undefined;
                    std.debug.print("{}\n", .{map.printToBuf(null, water_bbox, null, &buf)});
                }

                break :ans water;
            }

            dirty_bbox.min.x -= 1;
            dirty_bbox.max.x += 1;
            dirty_bbox.min.y -= 1;
            dirty_bbox.max.y += 1;

            if (false) {
                const water = blk: {
                    var w: u32 = 0;
                    var it2 = map.iter(bbox);
                    while (it2.next()) |sq| {
                        switch (sq) {
                            '~', '>', '<', 'v' => w += 1,
                            else => {},
                        }
                    }
                    break :blk w;
                };

                var buf: [300 * 300]u8 = undefined;
                std.debug.print("{}\n", .{map.printToBuf(null, dirty_bbox, null, &buf)});

                std.debug.print("water = {}\n", .{water});
            }
        }
        unreachable;
    };

    const ans2 = ans: {
        const water = blk: {
            var w: u32 = 0;
            var it2 = map.iter(null);
            while (it2.next()) |sq| {
                switch (sq) {
                    '~' => w += 1,
                    else => {},
                }
            }
            break :blk w;
        };
        break :ans water;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2018/input_day17.txt", run);
