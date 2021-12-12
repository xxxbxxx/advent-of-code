const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub fn run(input_text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    const ans1 = ans: {
        var mem = try allocator.alloc(u36, 100000);
        defer allocator.free(mem);
        std.mem.set(u36, mem, 0);
        var mask_or: u36 = 0;
        var mask_and: u36 = 0xFFFFFFFFF;
        var it = std.mem.tokenize(u8, input_text, "\n\r");
        while (it.next()) |line| {
            if (tools.match_pattern("mask = {}", line)) |fields| {
                const pattern = fields[0].lit;
                mask_or = 0;
                mask_and = 0xFFFFFFFFF;
                for (pattern) |bit, i| {
                    const mask = @as(u36, 1) << @intCast(u6, 35 - i);
                    switch (bit) {
                        'X' => {},
                        '1' => mask_or |= mask,
                        '0' => mask_and &= ~mask,
                        else => unreachable,
                    }
                }
            } else if (tools.match_pattern("mem[{}] = {}", line)) |fields| {
                const adr = @intCast(usize, fields[0].imm);
                const val = @intCast(u36, fields[1].imm);
                mem[adr] = (val | mask_or) & mask_and;
            } else {
                unreachable;
            }
        }

        var sum: u64 = 0;
        for (mem) |v| {
            sum += v;
        }
        break :ans sum;
    };

    const ans2 = ans: {
        var mem = std.AutoArrayHashMap(u36, u36).init(allocator);
        defer mem.deinit();

        var mask_or: u36 = 0;
        var mask_and: u36 = 0xFFFFFFFFF;
        var mask_muts: [36]u36 = undefined;
        var mask_nb_mut: u6 = 0;

        var it = std.mem.tokenize(u8, input_text, "\n\r");
        while (it.next()) |line| {
            if (tools.match_pattern("mask = {}", line)) |fields| {
                const pattern = fields[0].lit;
                mask_or = 0;
                mask_and = 0xFFFFFFFFF;
                mask_nb_mut = 0;
                for (pattern) |bit, i| {
                    const mask = @as(u36, 1) << @intCast(u6, 35 - i);
                    switch (bit) {
                        'X' => {
                            mask_and &= ~mask;
                            mask_muts[mask_nb_mut] = mask;
                            mask_nb_mut += 1;
                        },
                        '1' => mask_or |= mask,
                        '0' => {},
                        else => unreachable,
                    }
                }
            } else if (tools.match_pattern("mem[{}] = {}", line)) |fields| {
                const adr = @intCast(u36, fields[0].imm);
                const val = @intCast(u36, fields[1].imm);
                const base = (adr | mask_or) & mask_and;
                var i: u36 = 0;
                while (i < (@as(u36, 1) << (mask_nb_mut + 1))) : (i += 1) {
                    var a: u36 = base;
                    for (mask_muts[0..mask_nb_mut]) |mask, j| {
                        const use = ((i & (@as(u32, 1) << @intCast(u5, j))) != 0);
                        if (use) a |= mask;
                    }
                    try mem.put(a, val);
                }
            } else {
                unreachable;
            }
        }

        {
            var sum: u64 = 0;
            var it2 = mem.iterator();
            while (it2.next()) |v| {
                sum += v.value_ptr.*;
            }
            break :ans sum;
        }
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2020/input_day14.txt", run);
