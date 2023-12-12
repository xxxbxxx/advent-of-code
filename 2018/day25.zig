const std = @import("std");
const assert = std.debug.assert;
const print = std.debug.print;
const tools = @import("tools");

const Vec4 = [4]i8;
fn dist(a: Vec4, b: Vec4) u32 {
    var d: u32 = 0;
    for (a, 0..) |_, i| {
        d += @abs(@as(i31, a[i]) - b[i]);
    }
    return d;
}

pub fn run(input_text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const param: struct {
        points: []const Vec4,
    } = param: {
        var points = std.ArrayList(Vec4).init(arena.allocator());
        var it = std.mem.tokenize(u8, input_text, "\n\r");
        while (it.next()) |line| {
            if (tools.match_pattern("{},{},{},{}", line)) |fields| {
                try points.append(Vec4{
                    @as(i8, @intCast(fields[0].imm)),
                    @as(i8, @intCast(fields[1].imm)),
                    @as(i8, @intCast(fields[2].imm)),
                    @as(i8, @intCast(fields[3].imm)),
                });
            } else unreachable;
        }
        break :param .{ .points = points.items };
    };

    const ans1 = ans: {
        const Tag = u16;
        const cluster_tag = try allocator.alloc(Tag, param.points.len);
        defer allocator.free(cluster_tag);
        var connected = std.ArrayList(Tag).init(arena.allocator());
        defer connected.deinit();
        var next_tag: Tag = 0;
        for (param.points, 0..) |p, i| {
            try connected.resize(0);
            if (i >= 1) {
                for (param.points[0 .. i - 1], 0..) |o, j| {
                    const d = dist(p, o);
                    if (d <= 3) {
                        const t = cluster_tag[j];
                        if (std.mem.indexOfScalar(Tag, connected.items, t) == null)
                            try connected.append(t);
                    }
                }
            }

            if (connected.items.len == 0) {
                try connected.append(next_tag);
                next_tag += 1;
            }
            const t = connected.items[0];
            cluster_tag[i] = t;

            for (cluster_tag[0..i]) |*tag| {
                if (std.mem.indexOfScalar(Tag, connected.items, tag.*) != null)
                    tag.* = t;
            }
        }

        const unique = &connected;
        try unique.resize(0);
        for (cluster_tag) |t| {
            if (std.mem.indexOfScalar(Tag, unique.items, t) == null)
                try unique.append(t);
        }

        break :ans unique.items.len;
    };

    const ans2 = ans: {
        break :ans "gratis";
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{s}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2018/input_day25.txt", run);
