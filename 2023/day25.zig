const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub const main = tools.defaultMain("2023/day25.txt", run);

const Link = struct {
    a: u16,
    b: u16,
};
const Node = struct {
    links: []u16 = &.{},
};

pub fn run(text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena_alloc = std.heap.ArenaAllocator.init(allocator);
    defer arena_alloc.deinit();
    const arena = arena_alloc.allocator();
    const names, const nodes, const links = input: {
        var _nodes = std.StringArrayHashMap(Node).init(arena);
        var _links = std.AutoArrayHashMap(Link, void).init(arena);

        var it = std.mem.tokenize(u8, text, "\n\r\t");
        while (it.next()) |line| {
            if (tools.match_pattern("{}: {}", line)) |vals| {
                try _nodes.ensureUnusedCapacity(10); // pour que n0 ne soit pas invalidé quand on rajoute les n1..
                const n0 = try _nodes.getOrPut(vals[0].lit);
                if (!n0.found_existing) n0.value_ptr.* = .{};
                var it2 = std.mem.tokenize(u8, vals[1].lit, " ");
                while (it2.next()) |name| {
                    const n1 = try _nodes.getOrPut(name);
                    if (!n1.found_existing) n1.value_ptr.* = .{};
                    const link = Link{ .a = @intCast(@min(n1.index, n0.index)), .b = @intCast(@max(n1.index, n0.index)) };
                    const l = try _links.getOrPutValue(link, {});
                    //std.debug.print("add {s}-{s}: {} {} {}\n", .{ vals[0].lit, name, n0.index, n1.index, l.index});
                    n0.value_ptr.links = try appendIfNotFound(u16, arena, n0.value_ptr.links, @intCast(l.index));
                    n1.value_ptr.links = try appendIfNotFound(u16, arena, n1.value_ptr.links, @intCast(l.index));
                }
            } else unreachable;
        }
        break :input .{ _nodes.keys(), _nodes.values(), _links.keys() };
    };

    const ans1 = ans: {
        const counters = try allocator.alloc(u32, links.len);
        defer allocator.free(counters);
        {
            @memset(counters, 0);
            const visited = try allocator.alloc(bool, nodes.len);
            defer allocator.free(visited);
            var agenda = std.ArrayList(u16).init(allocator);
            defer agenda.deinit();
            for (nodes, 0..) |_, start| {
                try agenda.insert(0, @intCast(start));
                @memset(visited, false);
                visited[start] = true;
                while (agenda.popOrNull()) |n| {
                    for (nodes[n].links) |l| {
                        const other = if (links[l].a == n) links[l].b else links[l].a;
                        if (!visited[other]) {
                            visited[other] = true;
                            try agenda.insert(0, @intCast(other));
                            counters[l] += 1;
                        }
                    }
                }
            }
        }

        const order = try allocator.alloc(u16, links.len);
        defer allocator.free(order);
        for (order, 0..) |*it, i| it.* = @intCast(i);
        const Local = struct {
            fn greaterThan(ctx: []const u32, a: u16, b: u16) bool {
                return ctx[a] > ctx[b];
            }
        };
        std.mem.sortUnstable(u16, order, counters, Local.greaterThan);

        if (false) {
            for (order) |i| {
                std.debug.print("{s}-{s}: {}\n", .{ names[links[i].a], names[links[i].b], counters[i] });
            }
        }

        var links_to_cut: [3]u16 = undefined;
        for (order, 0..) |l0, idx0| {
            for (order[idx0 + 1 ..], 0..) |l1, idx1| {
                for (order[idx0 + 1 ..][idx1 + 1 ..]) |l2| {
                    links_to_cut = .{ l0, l1, l2 };
                    const cluster_sizes = try findClusters(arena, allocator, nodes, links, &links_to_cut);
                    assert(cluster_sizes.len >= 1 and cluster_sizes.len <= 2);
                    //std.debug.print("cluster sizes: {any} for cut={any}\n", .{ cluster_sizes,links_to_cut });
                    if (cluster_sizes.len == 2) {
                        break :ans @as(u64, cluster_sizes[0]) * cluster_sizes[1];
                    }
                }
            }
        }
        unreachable;
    };

    const ans2 = "GRATIS";

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{s}", .{ans2}),
    };
}

fn findClusters(arena: std.mem.Allocator, allocator: std.mem.Allocator, nodes: []const Node, links: []const Link, links_to_cut: []const u16) ![]const u16 {
    const labels = try allocator.alloc(u16, nodes.len);
    defer allocator.free(labels);
    const counts = try allocator.alloc(u16, nodes.len);
    defer allocator.free(counts);
    for (labels, 0..) |*it, i| it.* = @intCast(i);
    @memset(counts, 1);

    for (0..links.len) |_| {
        for (links, 0..) |l, i| {
            if (std.mem.indexOfScalar(u16, links_to_cut, @intCast(i)) != null) continue;
            const min = @min(labels[l.a], labels[l.b]);
            const max = @max(labels[l.a], labels[l.b]);
            if (min == max) continue;
            labels[l.a] = min;
            labels[l.b] = min;
            counts[min] += counts[max];
            counts[max] = 0;
        }
    }

    var cluster_sizes = std.ArrayList(u16).init(arena);
    defer cluster_sizes.deinit();
    for (counts) |c| {
        if (c > 0) try cluster_sizes.append(c);
    }

    return cluster_sizes.toOwnedSlice();
}

fn appendIfNotFound(comptime T: type, allocator: std.mem.Allocator, list: []T, elem: T) ![]T {
    if (std.mem.indexOfScalar(T, list, elem) != null)
        return list;
    const new = try allocator.realloc(list, list.len + 1);
    new[list.len] = elem;
    return new;
}

test {
    const res1 = try run(
        \\jqt: rhn xhk nvd
        \\rsh: frs pzl lsr
        \\xhk: hfx
        \\cmg: qnr nvd lhk bvb
        \\rhn: xhk bvb hfx
        \\bvb: xhk hfx
        \\pzl: lsr hfx nvd
        \\qnr: nvd
        \\ntq: jqt hfx bvb xhk
        \\nvd: lhk
        \\lsr: lhk
        \\rzs: qnr cmg lsr rsh
        \\frs: qnr lhk lsr
    , std.testing.allocator);
    defer std.testing.allocator.free(res1[0]);
    defer std.testing.allocator.free(res1[1]);
    try std.testing.expectEqualStrings("54", res1[0]);
    try std.testing.expectEqualStrings("GRATIS", res1[1]);
}
