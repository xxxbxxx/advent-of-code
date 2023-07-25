const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

const Tile = struct {
    dist: u16,
    tag: u8,

    fn tile2char(t: @This()) u8 {
        if (t.tag == 0) {
            return '.';
        } else if (t.tag == 1) {
            return '#';
        } else if (t.dist == 0) {
            return 'A' + (t.tag - 2);
        } else {
            return 'a' + (t.tag - 2);
        }
    }
};
const Vec2 = tools.Vec2;
const Map = tools.Map(Tile, 2000, 2000, true);

fn abs(x: i32) u32 {
    return if (x >= 0) @as(u32, @intCast(x)) else @as(u32, @intCast(-x));
}

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    const map = try allocator.create(Map);
    defer allocator.destroy(map);
    map.default_tile = Tile{ .tag = 0, .dist = 0 };
    map.bbox = tools.BBox.empty;
    map.fill(Tile{ .tag = 0, .dist = 0 }, null);
    const coordList = try allocator.alloc(Vec2, 1000);
    defer allocator.free(coordList);
    var coordCount: usize = 0;

    {
        var tag: u8 = 2;
        var it = std.mem.tokenize(u8, input, "\n\r");
        while (it.next()) |line| {
            const fields = tools.match_pattern("{}, {}", line) orelse unreachable;
            const pos = Vec2{ .x = @as(i32, @intCast(fields[0].imm)), .y = @as(i32, @intCast(fields[1].imm)) };
            coordList[coordCount] = pos;
            coordCount += 1;
            map.set(pos, Tile{ .tag = tag, .dist = 0 });
            tag += 1;
        }
        map.bbox.min = map.bbox.min.add(Vec2{ .x = -2, .y = -2 });
        map.bbox.max = map.bbox.max.add(Vec2{ .x = 2, .y = 2 });

        //var buf: [50000]u8 = undefined;
        //std.debug.print("amp=\n{}\n", .{map.printToBuf(null, null, Tile.tile2char, &buf)});
    }

    // update distance map
    {
        var changed = true;
        while (changed) {
            changed = false;

            var it = map.iter(null);
            while (it.nextEx()) |tn| {
                var d: u16 = 65534;
                var tag: u8 = 0;
                for (tn.neib) |neib| {
                    if (neib) |n| {
                        if (n.tag != 0) {
                            if (n.dist + 1 < d) {
                                d = n.dist + 1;
                                tag = n.tag;
                            } else if (n.dist + 1 == d and tag != n.tag) {
                                tag = 1; // equidistant
                            }
                        }
                    }
                }

                if (tag != 0 and tn.t.dist > d or (tn.t.dist == d and tn.t.tag != tag) or tn.t.tag == 0) {
                    tn.t.tag = tag;
                    tn.t.dist = d;
                    changed = true;
                }
            }
        }
        //var buf: [50000]u8 = undefined;
        //std.debug.print("amp=\n{}\n", .{map.printToBuf(null, null, Tile.tile2char, &buf)});
    }

    // part1
    //var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    //defer arena.deinit();
    const ans1 = ans: {
        // bon je pense que tout ce qui est sur le bord exterieur va se propager à l'infini (en ligne droite ça sera toujours plus court)
        var infiniteTags = [_]bool{false} ** 100;
        {
            var x = map.bbox.min.x;
            while (x <= map.bbox.max.x) : (x += 1) {
                infiniteTags[map.at(Vec2{ .x = x, .y = map.bbox.min.y }).tag] = true;
                infiniteTags[map.at(Vec2{ .x = x, .y = map.bbox.max.y }).tag] = true;
            }
            var y = map.bbox.min.y;
            while (y <= map.bbox.max.y) : (y += 1) {
                infiniteTags[map.at(Vec2{ .x = map.bbox.min.x, .y = y }).tag] = true;
                infiniteTags[map.at(Vec2{ .x = map.bbox.max.x, .y = y }).tag] = true;
            }
        }

        var counts = [_]u32{0} ** 100;
        var bestCount: u32 = 0;
        var bestTag: u8 = 0;
        var it = map.iter(null);
        while (it.next()) |t| {
            if (t.tag > 1 and !infiniteTags[t.tag]) {
                counts[t.tag] += 1;
                if (counts[t.tag] > bestCount) {
                    bestCount = counts[t.tag];
                    bestTag = t.tag;
                }
            }
        }
        break :ans bestCount;
    };

    // part2
    const ans2 = ans: {
        const coords = coordList[0..coordCount];
        var count: u32 = 0;
        var y = map.bbox.min.y;
        while (y <= map.bbox.max.y) : (y += 1) {
            var x = map.bbox.min.x;
            while (x <= map.bbox.max.x) : (x += 1) {
                var d: u32 = 0;
                for (coords) |c| {
                    d += abs(c.x - x) + abs(c.y - y);
                }
                if (d < 10000) count += 1;
            }
        }
        break :ans count;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2018/input_day06.txt", run);
