const std = @import("std");
const tools = @import("tools");

const Planet = struct {
    parent: []const u8,
    childs: u32 = 0,
};

const Hash = std.StringHashMap(Planet);

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var table = Hash.init(allocator);
    defer table.deinit();
    try table.ensureTotalCapacity(@as(u32, @intCast(input.len)) / 7);
    _ = try table.put("COM", Planet{ .parent = "" });

    {
        var it = std.mem.split(u8, input, "\n");
        while (it.next()) |line| {
            const l = std.mem.trim(u8, line, &std.ascii.whitespace);
            if (l.len == 0) continue;
            const sep = std.mem.indexOf(u8, l, ")");
            if (sep) |s| {
                const parent = l[0..s];
                const cur = l[s + 1 ..];
                const entry = table.get(cur);
                if (entry) |_| {
                    return error.UnsupportedInput; // duplicate entry..
                }
                _ = try table.put(cur, Planet{ .parent = parent });
            } else {
                std.debug.print("while reading '{s}'\n", .{line});
                return error.UnsupportedInput;
            }
        }
    }

    const solution1 = sol: {
        var total: usize = 0;
        var it = table.iterator();
        while (it.next()) |planet| {
            var parent = planet.value_ptr.parent;
            while (parent.len > 0) {
                total += 1;
                parent = (table.get(parent) orelse unreachable).parent;
            }
        }
        break :sol total;
    };

    const PlanetList = std.ArrayList([]const u8);
    var santaToCOM = PlanetList.init(allocator);
    defer santaToCOM.deinit();
    try santaToCOM.ensureTotalCapacity(table.count());

    {
        const santa = table.get("SAN").?;
        var cur = santa.parent;
        while (cur.len > 0) {
            try santaToCOM.append(cur);
            cur = table.get(cur).?.parent;
        }
    }

    const solution2 = sol: {
        const me = table.get("YOU").?;
        var steps: u32 = 0;
        var cur = me.parent;
        while (cur.len > 0) {
            const index = blk: {
                var i: u32 = 0;
                for (santaToCOM.items) |planet| {
                    if (std.mem.eql(u8, planet, cur))
                        break :blk i;
                    i += 1;
                }
                break :blk null;
            };

            if (index) |i| {
                break :sol (i + steps);
            } else {
                steps += 1;
                cur = table.get(cur).?.parent;
            }
        }
        break :sol null;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{?}", .{solution1}),
        try std.fmt.allocPrint(allocator, "{?}", .{solution2}),
    };
}

pub const main = tools.defaultMain("2019/day06.txt", run);
