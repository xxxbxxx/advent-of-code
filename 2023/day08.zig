const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub const main = tools.defaultMain("2023/day08.txt", run);

pub fn run(text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena_alloc = std.heap.ArenaAllocator.init(allocator);
    defer arena_alloc.deinit();
    const arena = arena_alloc.allocator();

    const instructions, const map, const start1, const goal1, const starts2, const goals2 = blk: {
        var nodes = std.StringArrayHashMap([2][]const u8).init(arena);
        defer nodes.deinit();

        var it = std.mem.tokenize(u8, text, "\n\r\t");
        const raw_insns = it.next().?;
        while (it.next()) |line| {
            const node = tools.match_pattern("{} = ({}, {})", line) orelse continue;
            try nodes.put(node[0].lit, .{ node[1].lit, node[2].lit });
        }

        var start_list = std.ArrayList(u32).init(arena);
        defer start_list.deinit();
        var goal_list = std.ArrayList(u32).init(arena);
        defer goal_list.deinit();

        const node_list = try arena.alloc([2]u32, nodes.count());
        var it2 = nodes.iterator();
        while (it2.next()) |n| {
            const node = n.key_ptr.*;
            const node_idx = it2.index - 1;
            node_list[node_idx] = .{ @intCast(nodes.getIndex(n.value_ptr.*[0]).?), @intCast(nodes.getIndex(n.value_ptr.*[1]).?) };
            if (node[2] == 'A') try start_list.append(node_idx);
            if (node[2] == 'Z') try goal_list.append(node_idx);
        }

        const insns = try arena.alloc(u8, raw_insns.len);
        for (raw_insns, insns) |raw, *i| {
            i.* = switch (raw) {
                'L' => 0,
                'R' => 1,
                else => unreachable,
            };
        }

        break :blk .{
            insns,
            node_list,
            nodes.getIndex("AAA").?,
            nodes.getIndex("ZZZ").?,
            try start_list.toOwnedSlice(),
            try goal_list.toOwnedSlice(),
        };
    };

    const ans1 = ans: {
        var steps: u32 = 0;
        var cur = start1;
        loop: while (true) {
            for (instructions) |insn| {
                cur = map[cur][insn];
                steps += 1;
                if (cur == goal1) break :loop;
            }
        }
        break :ans steps;
    };

    const ans2 = ans: {
        const periods = try arena.alloc(u32, starts2.len);
        for (periods, starts2) |*period, start| {
            var steps: u32 = 0;
            var cur = start;
            const steps_to_loop = loop: while (true) {
                for (instructions) |insn| {
                    cur = map[cur][insn];
                    steps += 1;
                    if (std.mem.indexOfScalar(u32, goals2, cur)) |_| break :loop steps;
                }
            } else unreachable;

            if (starts2.len == 1) {
                period.* = steps_to_loop;
                continue;
            }

            const goal = cur;
            steps = 0;
            const loop_period = loop: while (true) {
                for (instructions) |insn| {
                    cur = map[cur][insn];
                    steps += 1;
                    if (std.mem.indexOfScalar(u32, goals2, cur)) |_| break :loop steps;
                }
            } else unreachable;

            assert(goal == cur and steps_to_loop == loop_period); // nice...
            period.* = loop_period;
        }

        var res: u64 = 1;
        for (periods) |p|
            res = tools.ppcm(res, p);
        break :ans res;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

test {
    const res1 = try run(
        \\RL
        \\
        \\AAA = (BBB, CCC)
        \\BBB = (DDD, EEE)
        \\CCC = (ZZZ, GGG)
        \\DDD = (DDD, DDD)
        \\EEE = (EEE, EEE)
        \\GGG = (GGG, GGG)
        \\ZZZ = (ZZZ, ZZZ)
    , std.testing.allocator);
    defer std.testing.allocator.free(res1[0]);
    defer std.testing.allocator.free(res1[1]);
    try std.testing.expectEqualStrings("2", res1[0]);
    try std.testing.expectEqualStrings("2", res1[1]);

    const res2 = try run(
        \\LLR
        \\
        \\AAA = (BBB, BBB)
        \\BBB = (AAA, ZZZ)
        \\ZZZ = (ZZZ, ZZZ)
    , std.testing.allocator);
    defer std.testing.allocator.free(res2[0]);
    defer std.testing.allocator.free(res2[1]);
    try std.testing.expectEqualStrings("6", res2[0]);
    try std.testing.expectEqualStrings("6", res2[1]);

    const res3 = try run(
        \\LR
        \\
        \\AAA = (11B, XXX)
        \\11B = (XXX, ZZZ)
        \\ZZZ = (11B, XXX)
        \\22A = (22B, XXX)
        \\22B = (22C, 22C)
        \\22C = (22Z, 22Z)
        \\22Z = (22B, 22B)
        \\XXX = (XXX, XXX)
    , std.testing.allocator);
    defer std.testing.allocator.free(res3[0]);
    defer std.testing.allocator.free(res3[1]);
    try std.testing.expectEqualStrings("2", res3[0]);
    try std.testing.expectEqualStrings("6", res3[1]);
}
