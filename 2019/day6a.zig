const std = @import("std");

const Planet = struct {
    parent: []const u8,
    childs: u32 = 0,
};

const Hash = std.StringHashMap(Planet);

pub fn main() anyerror!void {
    const allocator = &std.heap.ArenaAllocator.init(std.heap.page_allocator).allocator;

    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "problem6.txt", limit);

    var table = Hash.init(allocator);
    defer table.deinit();
    _ = try table.put("COM", Planet{ .parent = "" });

    {
        var it = std.mem.split(u8, text, "\n");
        while (it.next()) |line| {
            const l = std.fmt.trim(line);
            if (l.len == 0) continue;
            const sep = std.mem.indexOf(u8, l, ")");
            if (sep) |s| {
                const parent = l[0..s];
                const cur = l[s + 1 ..];
                const entry = table.get(cur);
                if (entry) |_| {
                    return error.DuplicateEntry;
                }
                _ = try table.put(cur, Planet{ .parent = parent });
            } else {
                std.debug.print("while reading '{}'\n", .{line});
                return error.ParseError;
            }
        }
    }

    {
        var total: u32 = 0;
        var it = table.iterator();
        while (it.next()) |cur| {
            var next = cur.value.parent;
            while (next.len > 0) {
                const planet = table.get(next);
                if (planet) |p| {
                    p.value.childs += 1;
                    next = p.value.parent;
                } else {
                    std.debug.print("while examining '{}'\n", .{cur});
                    return error.UnknowParentPlanet;
                }
            }
        }
    }

    {
        var total: u32 = 0;
        var it = table.iterator();
        while (it.next()) |planet| {
            total += planet.value.childs;
        }
        const out = std.io.getStdOut().writer();
        try out.print("{}\n", .{total});
    }
    //    return error.SolutionNotFound;
}
