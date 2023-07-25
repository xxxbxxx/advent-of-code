const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    const Bag = struct {
        count: u8,
        items: [24]struct { n: u16, col: u16 },
    };
    var colors = std.StringHashMap(u16).init(allocator);
    defer colors.deinit();

    // index by color_id
    var contents: []Bag = undefined;
    var parents: []Bag = undefined;
    {
        var contents_desc = std.ArrayList([]const u8).init(allocator);
        defer contents_desc.deinit();

        // parse all colors:
        {
            var it = std.mem.tokenize(u8, input, "\n\r");
            while (it.next()) |line| {
                const fields = tools.match_pattern("{} bags contain {}.", line) orelse unreachable;
                const color = fields[0].lit;
                const desc = fields[1].lit;

                const color_id = contents_desc.items.len;
                try colors.putNoClobber(color, @intCast(color_id));
                try contents_desc.append(desc);
            }
        }

        // parse all coNTENTS:
        contents = try allocator.alloc(Bag, contents_desc.items.len);
        parents = try allocator.alloc(Bag, contents_desc.items.len);
        errdefer allocator.free(contents);
        errdefer allocator.free(parents);

        @memset(parents, Bag{ .count = 0, .items = undefined });
        for (contents_desc.items, 0..) |desc, color_id| {
            const c = &contents[color_id];
            if (std.mem.eql(u8, desc, "no other bags")) {
                c.* = Bag{ .count = 0, .items = undefined };
            } else {
                c.count = 0;
                var iter = std.mem.tokenize(u8, desc, ",");
                while (iter.next()) |item| {
                    const v = tools.match_pattern("{} {} bag", item) orelse unreachable;
                    const n: u8 = @intCast(v[0].imm);
                    const col = colors.get(v[1].lit) orelse unreachable;

                    c.items[c.count].n = n;
                    c.items[c.count].col = col;
                    c.count += 1;

                    const p = &parents[col];
                    p.items[p.count].n = n;
                    p.items[p.count].col = @intCast(color_id);
                    p.count += 1;
                }
            }
        }
    }
    defer allocator.free(contents);
    defer allocator.free(parents);

    const ans1 = ans: {
        var containers = std.AutoHashMap(u16, void).init(allocator);
        defer containers.deinit();
        var queue = std.ArrayList(u16).init(allocator);
        defer queue.deinit();
        const root_id = colors.get("shiny gold") orelse unreachable;
        try queue.append(root_id);

        while (queue.items.len > 0) {
            const col = queue.pop();
            for (parents[col].items[0..parents[col].count]) |it| {
                const r = try containers.getOrPut(it.col);
                if (!r.found_existing)
                    try queue.append(it.col);
            }
        }
        break :ans containers.count();
    };

    const ans2 = ans: {
        var queue = std.ArrayList(struct { n: u16, col: u16 }).init(allocator);
        defer queue.deinit();
        const root_id = colors.get("shiny gold") orelse unreachable;
        try queue.append(.{ .n = 1, .col = root_id });
        var total: u64 = 0;
        while (queue.items.len > 0) {
            const c = queue.pop();
            total += c.n;
            for (contents[c.col].items[0..contents[c.col].count]) |it| {
                try queue.append(.{ .n = c.n * it.n, .col = it.col });
            }
        }
        break :ans total - 1;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2020/input_day07.txt", run);
