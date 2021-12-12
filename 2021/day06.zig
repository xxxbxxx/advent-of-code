const std = @import("std");
const tools = @import("tools");

const with_trace = false;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}
const assert = std.debug.assert;

pub const main = tools.defaultMain("2021/day06.txt", run);

pub fn run(input: []const u8, gpa: std.mem.Allocator) tools.RunError![2][]const u8 {
    // var arena = std.heap.ArenaAllocator.init(gpa);
    //defer arena.deinit();
    //const allocator = arena.allocator();

    const LanternFishList = std.ArrayList(u4);
    var list0 = LanternFishList.init(gpa);
    defer list0.deinit();
    {
        try list0.ensureTotalCapacity(input.len / 2);
        var it = std.mem.tokenize(u8, input, ", \t\n\r");
        while (it.next()) |num| {
            try list0.append(try std.fmt.parseInt(u4, num, 10));
        }
    }

    // descendants = f([generation][age])
    const descendants = blk: {
        var _descendants: [257][9]u64 = undefined;
        std.mem.set(u64, &_descendants[0], 1);
        var gen: u32 = 1;
        while (gen <= 256) : (gen += 1) {
            for (_descendants[gen]) |*pop, age| {
                pop.* = switch (age) {
                    0 => _descendants[gen - 1][6] + _descendants[gen - 1][8],
                    else => _descendants[gen - 1][age - 1],
                };
            }
        }
        break :blk _descendants;
    };

    const ans = ans: {
        var list1 = LanternFishList.init(gpa);
        defer list1.deinit();
        var list2 = LanternFishList.init(gpa);
        defer list2.deinit();
        try list1.appendSlice(list0.items);

        const pinpong = [2]*LanternFishList{ &list1, &list2 };
        var gen: u32 = 0;
        while (gen < 80) : (gen += 1) {
            const cur = pinpong[gen % 2];
            const next = pinpong[1 - gen % 2];

            {
                var total: u64 = 0;
                for (list0.items) |it| {
                    total += descendants[gen][it];
                }
                assert(total == cur.items.len);
            }

            next.clearRetainingCapacity();
            for (cur.items) |it| {
                switch (it) {
                    0 => {
                        try next.append(6);
                        try next.append(8);
                    },
                    else => {
                        try next.append(it - 1);
                    },
                }
            }
            // trace("gen #{} : {} [", .{gen,next.items.len} );
            // for (next.items) |it| {
            //     trace("{},", .{it});
            // }
            // trace("]\n", .{});
        }
        break :ans pinpong[gen % 2].items.len;
    };

    const ans2 = ans: {
        var total: u64 = 0;
        for (list0.items) |it| {
            total += descendants[256][it];
        }
        break :ans total;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(gpa, "{}", .{ans}),
        try std.fmt.allocPrint(gpa, "{}", .{ans2}),
    };
}

test {
    const res = try run("3,4,3,1,2", std.testing.allocator);
    defer std.testing.allocator.free(res[0]);
    defer std.testing.allocator.free(res[1]);
    try std.testing.expectEqualStrings("5934", res[0]);
    try std.testing.expectEqualStrings("26984457539", res[1]);
}
