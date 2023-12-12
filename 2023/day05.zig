const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub const main = tools.defaultMain("2023/day05.txt", run);

const Number = u64;
const maxnum = std.math.maxInt(Number);
const Map = struct {
    const Range = struct {
        from: Number,
        to: Number,
        len: u32,
    };
    ranges: []Range,
};

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena_alloc = std.heap.ArenaAllocator.init(allocator);
    defer arena_alloc.deinit();
    const arena = arena_alloc.allocator();

    const Input = struct {
        seeds: []Number,
        maps: []Map,
    };
    const data = blk: {
        var maps = std.ArrayList(Map).init(arena);
        defer maps.deinit();
        var seeds = std.ArrayList(Number).init(arena);
        defer seeds.deinit();
        var ranges = std.ArrayList(Map.Range).init(arena);
        defer ranges.deinit();

        var it = std.mem.tokenize(u8, input, "\n\r\t");
        while (it.next()) |line| {
            if (tools.match_pattern("seeds: {}", line)) |vals| {
                var it2 = std.mem.tokenize(u8, vals[0].lit, " ");
                while (it2.next()) |num| {
                    try seeds.append(try std.fmt.parseInt(Number, num, 10));
                }
            } else if (tools.match_pattern("{}-to-{} map:", line)) |_| {
                if (ranges.items.len > 0)
                    try maps.append(Map{ .ranges = try ranges.toOwnedSlice() });
                assert(ranges.items.len == 0);
            } else if (tools.match_pattern("{} {} {}", line)) |vals| {
                try ranges.append(.{ .from = @intCast(vals[1].imm), .to = @intCast(vals[0].imm), .len = @intCast(vals[2].imm) });
            }
        }
        if (ranges.items.len > 0)
            try maps.append(Map{ .ranges = try ranges.toOwnedSlice() });
        break :blk Input{ .seeds = try seeds.toOwnedSlice(), .maps = try maps.toOwnedSlice() };
    };

    const ans1 = ans: {
        var low: Number = maxnum;
        for (data.seeds) |seed| {
            var s = seed;
            map: for (data.maps) |map| {
                for (map.ranges) |range| {
                    if (s >= range.from and s < range.from + range.len) {
                        s = range.to + (s - range.from);
                        continue :map;
                    }
                } else s = s;
            }
            low = @min(low, s);
        }
        break :ans low;
    };

    const ans2 = ans: {
        const Range = struct { start: Number, len: Number };
        //const seeds: []const Range = @ptrCast(data.seeds);
        const seeds_ptr: [*]const Range = @ptrCast(data.seeds);
        const seeds: []const Range = seeds_ptr[0..@divExact(data.seeds.len, 2)];
        var low: Number = maxnum;
        for (seeds) |r| {
            const l = propagateRange(r.start, r.len, data.maps, 0);
            low = @min(low, l);
        }

        break :ans low;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

fn propagateRange(start: Number, len: Number, map: []const Map, map_idx: u32) Number {
    assert(len >= 1);
    if (map_idx == map.len) {
        return start;
    }
    for (map[map_idx].ranges) |r| {
        if (r.from > start + len) continue;
        if (r.from + r.len <= start) continue;
        if (start >= r.from and len <= r.len) {
            return propagateRange(start - r.from + r.to, len, map, map_idx + 1);
        }

        const a = @min(start, r.from);
        const b = @max(start, r.from);
        const c = @min(start + len - 1, r.from + r.len - 1);
        const d = @max(start + len - 1, r.from + r.len - 1);
        assert(a <= b and b <= c and c <= d);

        // 3 ranges: [a,b[ [b,c] ]c,d]
        const l1 = if (a >= start and b > a) propagateRange(a, b - a - 1, map, map_idx) else maxnum;
        const l2 = propagateRange(b, c - b + 1, map, map_idx);
        const l3 = if (d <= start + len - 1 and c + 1 < d) propagateRange(c + 1, d - c - 1, map, map_idx) else maxnum;
        return @min(l1, l2, l3);
    } else return propagateRange(start, len, map, map_idx + 1);
}

test {
    const res = try run(
        \\seeds: 79 14 55 13
        \\
        \\seed-to-soil map:
        \\50 98 2
        \\52 50 48
        \\
        \\soil-to-fertilizer map:
        \\0 15 37
        \\37 52 2
        \\39 0 15
        \\
        \\fertilizer-to-water map:
        \\49 53 8
        \\0 11 42
        \\42 0 7
        \\57 7 4
        \\
        \\water-to-light map:
        \\88 18 7
        \\18 25 70
        \\
        \\light-to-temperature map:
        \\45 77 23
        \\81 45 19
        \\68 64 13
        \\
        \\temperature-to-humidity map:
        \\0 69 1
        \\1 0 69
        \\
        \\humidity-to-location map:
        \\60 56 37
        \\56 93 4
    , std.testing.allocator);
    defer std.testing.allocator.free(res[0]);
    defer std.testing.allocator.free(res[1]);
    try std.testing.expectEqualStrings("35", res[0]);
    try std.testing.expectEqualStrings("46", res[1]);
}
