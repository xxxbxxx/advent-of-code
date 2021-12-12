const std = @import("std");
const tools = @import("tools");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().writer();
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day7.txt", limit);
    defer allocator.free(text);

    const Node = struct {
        parent: []const u8,
        weight: u32,
        weigth_rec: u32,
        childs: [8][]const u8,
        len: usize,
    };

    var nodes = std.StringHashMap(Node).init(allocator);
    defer nodes.deinit();

    {
        var it = std.mem.split(u8, text, "\n");
        while (it.next()) |line0| {
            const line = std.mem.trim(u8, line0, " \n\t\r");
            if (line.len == 0) continue;

            var node: Node = undefined;
            var it2 = std.mem.tokenize(u8, line, "()->, \t");
            const name = it2.next() orelse unreachable;
            node.weight = std.fmt.parseInt(u32, it2.next() orelse unreachable, 10) catch unreachable;
            node.weigth_rec = node.weight;
            node.len = 0;
            node.parent = "";
            while (it2.next()) |child| {
                node.childs[node.len] = child;
                node.len += 1;
            }

            _ = try nodes.put(name, node);

            trace("node: {} ({}) -> {}\n", .{ name, node.weight, node.len });
        }

        var it3 = nodes.iterator();
        while (it3.next()) |KV| {
            const node = &KV.value;
            const name = KV.key;
            for (node.childs[0..node.len]) |child| {
                const c = nodes.get(child) orelse unreachable;
                c.value.parent = name;
            }
        }

        var it4 = nodes.iterator();
        while (it4.next()) |KV| {
            const node = &KV.value;
            var parent = node;
            while (true) {
                if (parent.parent.len == 0)
                    break;
                const p = nodes.get(parent.parent) orelse unreachable;
                parent = &p.value;
                parent.weigth_rec += node.weight;
            }
        }
    }

    var root = blk: {
        var it = nodes.iterator();
        while (it.next()) |KV| {
            const node = &KV.value;
            const name = KV.key;
            if (node.parent.len == 0)
                break :blk name;
        }
        unreachable;
    };

    try stdout.print("root={}\n", .{root});

    const Local = struct {
        fn find_unbalanced(_nodes: anytype, name: []const u8) void {
            const KV = _nodes.get(name) orelse unreachable;
            const n = &KV.value;
            var wsr: [16]u32 = undefined;
            var ws0: [16]u32 = undefined;
            var unbalanced = false;
            for (n.childs[0..n.len]) |child, i| {
                find_unbalanced(_nodes, child);

                const c = _nodes.get(child) orelse unreachable;
                wsr[i] = c.value.weigth_rec;
                ws0[i] = c.value.weight;
                if (i > 0 and wsr[i] != wsr[0]) {
                    unbalanced = true;
                }
            }

            if (unbalanced) {
                trace("name:{},  ", .{name});
                for (wsr[0..n.len]) |w, i| {
                    trace("{} ({}+...), ", .{ w, ws0[i] });
                }
                trace("\n", .{});
            }
        }
    };
    Local.find_unbalanced(&nodes, root);

    //    return error.SolutionNotFound;
}
