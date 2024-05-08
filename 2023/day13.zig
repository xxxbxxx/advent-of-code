const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub const main = tools.defaultMain("2023/day13.txt", run);

pub fn run(text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena_alloc = std.heap.ArenaAllocator.init(allocator);
    defer arena_alloc.deinit();
    const arena = arena_alloc.allocator();

    const Pattern = struct {
        pat: []const u8,
        width: usize,
        height: usize,
        stride: usize,

        ligne1: ?usize = null,
        col1: ?usize = null,
    };
    const patterns = blk: {
        var pats = std.ArrayList(Pattern).init(arena);
        defer pats.deinit();

        var it = std.mem.tokenizeSequence(u8, text, "\n\n");
        while (it.next()) |p| {
            const pattern = std.mem.trim(u8, p, "\n\r ");
            const linelen = std.mem.indexOfScalar(u8, pattern, '\n').?;
            const linecount = std.mem.count(u8, pattern, "\n");
            try pats.append(.{ .pat = pattern, .width = linelen, .height = linecount + 1, .stride = linelen + 1 });
        }

        break :blk try pats.toOwnedSlice();
    };
    //std.debug.print("c={}, s={}, h={},first=---{s}---\n", .{patterns.len, patterns[1].stride, patterns[1].height, patterns[1].pat});

    const ans1 = ans: {
        var sum: usize = 0;
        patterns: for (patterns) |*pattern| {
            const pat = pattern.pat;
            const width = pattern.width;
            const height = pattern.height;
            const stride = pattern.stride;
            for (1..height) |y| {
                const ok = for (0..y) |i| {
                    const l1 = y - i - 1;
                    const l2 = y + i;
                    if (l2 >= height) break true;
                    if (!std.mem.eql(u8, pat[l1 * stride .. l1 * stride + width], pat[l2 * stride .. l2 * stride + width])) break false;
                } else true;

                if (ok) {
                    pattern.ligne1 = y;
                    sum += y * 100;
                    continue :patterns;
                }
            }
            for (1..width) |x| {
                const ok = for (0..x) |i| {
                    const c1 = x - i - 1;
                    const c2 = x + i;
                    if (c2 >= width) break true;
                    const eql = for (0..height) |y| {
                        if (pat[c1 + stride * y] != pat[c2 + stride * y]) break false;
                    } else true;
                    if (!eql) break false;
                } else true;

                if (ok) {
                    pattern.col1 = x;
                    sum += x;
                    continue :patterns;
                }
            }
        }
        break :ans sum;
    };

    const ans2 = ans: {
        var sum: usize = 0;
        patterns: for (patterns) |pattern| {
            const width = pattern.width;
            const height = pattern.height;
            const stride = pattern.stride;

            for (pattern.pat, 0..) |c, idx| {
                if (c != '#' and c != '.') continue;
                const pat = try allocator.dupe(u8, pattern.pat);
                defer allocator.free(pat);
                pat[idx] = if (c == '#') '.' else '#';
                for (1..height) |y| {
                    if (pattern.ligne1 == y) continue;
                    const ok = for (0..y) |i| {
                        const l1 = y - i - 1;
                        const l2 = y + i;
                        if (l2 >= height) break true;
                        //std.debug.print("{} {}: '{s}'=='{s}'\n", .{l1, l2, pat[l1 * stride .. l1 * stride + width], pat[l2 * stride .. l2 * stride + width]});
                        if (!std.mem.eql(u8, pat[l1 * stride .. l1 * stride + width], pat[l2 * stride .. l2 * stride + width])) break false;
                    } else true;

                    if (ok) {
                        sum += y * 100;
                        continue :patterns;
                    }
                }
                for (1..width) |x| {
                    if (pattern.col1 == x) continue;
                    const ok = for (0..x) |i| {
                        const c1 = x - i - 1;
                        const c2 = x + i;
                        if (c2 >= width) break true;
                        const eql = for (0..height) |y| {
                            if (pat[c1 + stride * y] != pat[c2 + stride * y]) break false;
                        } else true;
                        if (!eql) break false;
                    } else true;

                    if (ok) {
                        sum += x;
                        continue :patterns;
                    }
                }
            } else unreachable;
        }
        break :ans sum;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

test {
    const res1 = try run(
        \\#.##..##.
        \\..#.##.#.
        \\##......#
        \\##......#
        \\..#.##.#.
        \\..##..##.
        \\#.#.##.#.
        \\
        \\#...##..#
        \\#....#..#
        \\..##..###
        \\#####.##.
        \\#####.##.
        \\..##..###
        \\#....#..#
    , std.testing.allocator);
    defer std.testing.allocator.free(res1[0]);
    defer std.testing.allocator.free(res1[1]);
    try std.testing.expectEqualStrings("405", res1[0]);
    try std.testing.expectEqualStrings("400", res1[1]);
}
