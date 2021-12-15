const std = @import("std");
const tools = @import("tools");

const with_trace = false;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}
const assert = std.debug.assert;

pub const main = tools.defaultMain("2021/day14.txt", run);

pub fn run(input: []const u8, gpa: std.mem.Allocator) tools.RunError![2][]const u8 {
    //var arena_alloc = std.heap.ArenaAllocator.init(gpa);
    //defer arena_alloc.deinit();
    //const arena = arena_alloc.allocator();

    const table_base = '@' * 256;
    const table_count = (('Z' + 1) - '@') * 256; //  @,A,..,Z

    var it = std.mem.tokenize(u8, input, "\n");
    const template = it.next().?;

    var rules_table: [table_count]u8 = undefined;
    std.mem.set(u8, &rules_table, 0);
    while (it.next()) |line| {
        if (tools.match_pattern("{} -> {}", line)) |val| {
            const pair = @ptrCast(*align(1) const u16, val[0].lit.ptr).*;
            const insert = val[1].lit;
            rules_table[pair - table_base] = insert[0]; // little endian
        } else {
            std.debug.print("skipping {s}\n", .{line});
        }
    }

    const ans1 = ans: {
        // version bourrin in-extenso
        var bufs = [2][]u8{
            try gpa.alloc(u8, 64 * 1024),
            try gpa.alloc(u8, 64 * 1024),
        };
        defer {
            gpa.free(bufs[0]);
            gpa.free(bufs[1]);
        }
        var state = [2]usize{ template.len, 0 };
        std.mem.copy(u8, bufs[0][0..state[0]], template);

        var gen: u32 = 0;
        while (gen < 10) : (gen += 1) {
            const from = bufs[gen % 2][0..state[gen % 2]];
            const to = bufs[1 - gen % 2];
            var len: usize = 0;
            var i: u32 = 1;
            while (i < from.len) : (i += 1) {
                to[len] = from[i - 1];
                len += 1;
                const pair = @ptrCast(*align(1) const u16, &from[i - 1]).*;
                const insert = rules_table[pair - table_base];
                if (insert != 0) {
                    to[len] = insert;
                    len += 1;
                }
            }
            to[len] = from[from.len - 1];
            len += 1;
            state[1 - gen % 2] = len;

            trace("gen{} :  {s}\n", .{ gen + 1, to[0..len] });
        }

        const final = bufs[gen % 2][0..state[gen % 2]];
        var quantities = [1]u32{0} ** 128;
        for (final) |c| quantities[c] += 1;
        var min: u32 = 0xFFFFFFFF;
        var max: u32 = 0;
        for (quantities) |q| {
            if (q == 0) continue;
            min = @minimum(min, q);
            max = @maximum(max, q);
        }
        break :ans max - min;
    };

    const ans2 = ans: {
        // pour éviter les problèmes avec l'overlap, on considère que des paires: (dont on ne compte que la première lettre pour les stats)
        // NNCB == "NN + NC + CB + B@"
        // on réécrit les règles pour marcher par paires,
        // puis on pourra facilement avoir un compte par type de paires.

        const all_pairs = comptime blk: {
            var p: [26 * 27]u16 = undefined;
            for ("ABCDEFGHIJKLMNOPQRSTUVWXYZ") |letter1, i| {
                for ("ABCDEFGHIJKLMNOPQRSTUVWXYZ@") |letter2, j| {
                    p[i * 27 + j] = @as(u16, letter2) << 8 | letter1;
                }
            }
            break :blk p;
        };

        var rules_as_pairs: [table_count][2]u16 = undefined;
        for (all_pairs) |pair| {
            const insert = rules_table[pair - table_base];
            if (insert != 0) {
                const letter1 = @intCast(u8, pair & 0xFF);
                const letter2 = @intCast(u8, (pair >> 8) & 0xFF);
                rules_as_pairs[pair - table_base][0] = @as(u16, insert) << 8 | letter1;
                rules_as_pairs[pair - table_base][1] = @as(u16, letter2) << 8 | insert;
            } else {
                rules_as_pairs[pair - table_base][0] = pair;
                rules_as_pairs[pair - table_base][1] = 0;
            }
        }

        var pairs_count: [table_count]u64 = undefined;
        std.mem.set(u64, &pairs_count, 0);
        var i: u32 = 0;
        while (i < template.len) : (i += 1) {
            const pair = if (i < template.len - 1) @ptrCast(*align(1) const u16, &template[i]).* else (@as(u16, '@') << 8 | template[i]);
            pairs_count[pair - table_base] += 1;
        }

        var gen: u32 = 0;
        while (gen < 40) : (gen += 1) {
            var count2: [table_count]u64 = undefined;
            std.mem.set(u64, &count2, 0);
            for (all_pairs) |pair| {
                for (rules_as_pairs[pair - table_base]) |out| {
                    if (out != 0) count2[out - table_base] += pairs_count[pair - table_base];
                }
            }
            std.mem.copy(u64, &pairs_count, &count2);
        }

        {
            var quantities = [1]u64{0} ** 128;
            for (all_pairs) |pair| {
                const letter1 = @intCast(u8, pair & 0xFF);
                quantities[letter1] += pairs_count[pair - table_base];
            }
            var min: u64 = 0xFFFFFFFFFFFFFFFF;
            var max: u64 = 0;
            for (quantities) |q| {
                if (q == 0) continue;
                min = @minimum(min, q);
                max = @maximum(max, q);
            }
            break :ans max - min;
        }
    };

    return [_][]const u8{
        try std.fmt.allocPrint(gpa, "{}", .{ans1}),
        try std.fmt.allocPrint(gpa, "{}", .{ans2}),
    };
}

test {
    const res0 = try run(
        \\NNCB
        \\
        \\CH -> B
        \\HH -> N
        \\CB -> H
        \\NH -> C
        \\HB -> C
        \\HC -> B
        \\HN -> C
        \\NN -> C
        \\BH -> H
        \\NC -> B
        \\NB -> B
        \\BN -> B
        \\BB -> N
        \\BC -> B
        \\CC -> N
        \\CN -> C
    , std.testing.allocator);
    defer std.testing.allocator.free(res0[0]);
    defer std.testing.allocator.free(res0[1]);
    try std.testing.expectEqualStrings("1588", res0[0]);
    try std.testing.expectEqualStrings("2188189693529", res0[1]);
}
