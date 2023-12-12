const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub const main = tools.defaultMain("2023/day12.txt", run);

const String = []const u8;

pub fn run(text: String, allocator: std.mem.Allocator) ![2]String {
    var arena_alloc = std.heap.ArenaAllocator.init(allocator);
    defer arena_alloc.deinit();
    const arena = arena_alloc.allocator();

    const patterns, const groups = blk: {
        var pats = std.ArrayList(String).init(arena);
        defer pats.deinit();
        var grps = std.ArrayList([]const u8).init(arena);
        defer grps.deinit();

        var it = std.mem.tokenize(u8, text, "\n\r\t");
        while (it.next()) |line| {
            var it2 = std.mem.tokenize(u8, line, ", ");
            const pat = it2.next().?;
            var group = std.ArrayList(u8).init(arena);
            defer group.deinit();
            while (it2.next()) |num| {
                try group.append(try std.fmt.parseInt(u8, num, 10));
            }
            try grps.append(try group.toOwnedSlice());
            try pats.append(pat);
        }

        break :blk .{ try pats.toOwnedSlice(), try grps.toOwnedSlice() };
    };

    const ans1 = ans: {
        var sum: u64 = 0;
        for (patterns, groups) |p, g| {
            const c = matches1(p, g, null);
            //std.debug.print("{s} {any}: {} \n", .{p,g,c});
            sum += c;
        }
        break :ans sum;
    };

    const ans2 = ans: {
        var sum: u64 = 0;
        for (patterns, groups) |p, g| {
            const p5 = try allocator.alloc(u8, p.len * 5 + 4);
            defer allocator.free(p5);
            const g5 = try allocator.alloc(u8, g.len * 5);
            defer allocator.free(g5);
            for (0..5) |i| {
                @memcpy(p5[i * (p.len + 1) .. i * (p.len + 1) + p.len], p);
                if (i < 4) p5[i * (p.len + 1) + p.len] = '?';
                @memcpy(g5[i * g.len .. (i + 1) * g.len], g);
            }
            sum += matches2(allocator, p5, g5);
        }
        break :ans sum;
    };

    return [_]String{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

fn matches1(pat: String, grp: []const u8, cur_grp: ?u8) u64 {
    if (pat.len == 0) return @intFromBool(grp.len == 0 and (cur_grp orelse 0) == 0);

    switch (pat[pat.len - 1]) {
        else => unreachable,
        '.' => {
            if (cur_grp) |g| {
                if (g != 0) return 0;
            }
            return matches1(pat[0 .. pat.len - 1], grp, null); // consume '.'
        },
        '#' => {
            if (cur_grp) |g| {
                if (g == 0) return 0;
                return matches1(pat[0 .. pat.len - 1], grp, g - 1); // consume '#'
            }
            if (grp.len == 0) return 0;
            return matches1(pat[0 .. pat.len - 1], grp[0 .. grp.len - 1], grp[grp.len - 1] - 1); // consume '#'
        },
        '?' => {
            if (cur_grp) |g| {
                if (g == 0) return matches1(pat[0 .. pat.len - 1], grp, null); // consume '.'
                return matches1(pat[0 .. pat.len - 1], grp, g - 1); // consume '#'
            }
            if (grp.len == 0) return matches1(pat[0 .. pat.len - 1], grp, null); // consume '.'

            const count_dot = matches1(pat[0 .. pat.len - 1], grp, null); // consume '.'
            const count_hash = matches1(pat[0 .. pat.len - 1], grp[0 .. grp.len - 1], grp[grp.len - 1] - 1); // consume '#'
            return count_hash + count_dot;
        },
    }
    unreachable;
}

fn matches2(allocator: std.mem.Allocator, pat0: String, grp0: []const u8) u64 {
    const Key = struct {
        // pas besoin de copier: c'est des slices dans pat0/grp0
        String,
        []const u8,
    };
    const HashMapCtx = struct {
        pub fn hash(_: @This(), k: Key) u64 {
            return std.hash_map.hashString(k[0]) ^ std.hash_map.hashString(k[1]);
        }
        pub fn eql(_: @This(), k1: Key, k2: Key) bool {
            return std.hash_map.eqlString(k1[0], k2[0]) and std.hash_map.eqlString(k1[1], k2[1]);
        }
    };

    const Searcher = struct {
        memo: std.HashMap(Key, u64, HashMapCtx, 80) = undefined,

        fn matches(self: *@This(), pat: String, grp: []const u8, nb_needed: u32, nb_avail: u32, cur_grp: ?u8) u64 {
            if (pat.len == 0) return @intFromBool(grp.len == 0 and (cur_grp orelse 0) == 0);
            if (nb_needed > nb_avail) return 0;

            switch (pat[pat.len - 1]) {
                else => unreachable,
                '.' => {
                    if (cur_grp) |g| {
                        if (g != 0) return 0;
                    }
                    return self.matches(pat[0 .. pat.len - 1], grp, nb_needed, nb_avail, null);
                },
                '#' => {
                    if (cur_grp) |g| {
                        if (g == 0) return 0;
                        return self.matches(pat[0 .. pat.len - 1], grp, nb_needed - 1, nb_avail - 1, g - 1);
                    }
                    if (grp.len == 0) return 0;
                    return self.matches(pat[0 .. pat.len - 1], grp[0 .. grp.len - 1], nb_needed - 1, nb_avail - 1, grp[grp.len - 1] - 1);
                },
                '?' => {
                    if (cur_grp) |g| {
                        if (g == 0) return self.matches(pat[0 .. pat.len - 1], grp, nb_needed, nb_avail, null);
                        return self.matches(pat[0 .. pat.len - 1], grp, nb_needed - 1, nb_avail - 1, g - 1);
                    }
                    if (grp.len == 0) return self.matches(pat[0 .. pat.len - 1], grp, nb_needed, nb_avail, null);

                    if (self.memo.get(.{ pat, grp })) |count| {
                        return count;
                    } else {
                        const count_dot = self.matches(pat[0 .. pat.len - 1], grp, nb_needed, nb_avail, null);
                        const count_hash = self.matches(pat[0 .. pat.len - 1], grp[0 .. grp.len - 1], nb_needed - 1, nb_avail - 1, grp[grp.len - 1] - 1);
                        self.memo.put(.{ pat, grp }, count_hash + count_dot) catch unreachable;
                        return count_hash + count_dot;
                    }
                },
            }
            unreachable;
        }
    };

    var search: Searcher = .{
        .memo = std.HashMap(Key, u64, HashMapCtx, 80).init(allocator),
    };
    defer search.memo.deinit();

    const nb_needed = sum: {
        var s: u32 = 0;
        for (grp0) |g| s += g;
        break :sum s;
    };
    const nb_avail = sum: {
        var s: u32 = 0;
        for (pat0) |c| s += @intFromBool(c != '.');
        break :sum s;
    };

    return search.matches(pat0, grp0, nb_needed, nb_avail, null);
}

test {
    const res1 = try run(
        \\???.### 1,1,3
        \\.??..??...?##. 1,1,3
        \\?#?#?#?#?#?#?#? 1,3,1,6
        \\????.#...#... 4,1,1
        \\????.######..#####. 1,6,5
        \\?###???????? 3,2,1
    , std.testing.allocator);
    defer std.testing.allocator.free(res1[0]);
    defer std.testing.allocator.free(res1[1]);
    try std.testing.expectEqualStrings("21", res1[0]);
    try std.testing.expectEqualStrings("525152", res1[1]);
}
