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
    const text = try std.fs.cwd().readFileAlloc(allocator, "day22.txt", limit);
    defer allocator.free(text);

    const Disk = struct {
        x: u8,
        y: u8,
        total: u16,
        used: u16,
    };
    var alldiscs: [2000]Disk = undefined;

    const discs = blk: {
        var len: usize = 0;

        var it = std.mem.tokenize(u8, text, "\n");
        while (it.next()) |line| {
            // "Filesystem              Size  Used  Avail  Use%"
            // "/dev/grid/node-x19-y28   85T   68T    17T   80%"
            const name = line[0..23];
            const size_total = line[23..28];
            const size_used = line[29..34];
            const size_avail = line[35..41];

            const d = &alldiscs[len];
            len += 1;

            if (tools.match_pattern("/dev/grid/node-x{}-y{}", name)) |vals| {
                d.x = @intCast(u8, vals[0].imm);
                d.y = @intCast(u8, vals[1].imm);
            } else {
                unreachable;
            }

            d.total = @intCast(u16, (tools.match_pattern("{}T", size_total) orelse unreachable)[0].imm);
            d.used = @intCast(u16, (tools.match_pattern("{}T", size_used) orelse unreachable)[0].imm);
            const avail = @intCast(u16, (tools.match_pattern("{}T", size_avail) orelse unreachable)[0].imm);
            assert(d.used + avail == d.total);
        }
        break :blk alldiscs[0..len];
    };

    try stdout.print("=== part1 ===========================\n", .{});
    var w: u32 = 0;
    var h: u32 = 0;
    {
        var count: usize = 0;
        for (discs) |d1, i| {
            w = if (w < d1.x) d1.x else w;
            h = if (h < d1.y) d1.y else h;
            for (discs) |d2, j| {
                if (j == i)
                    continue;
                if (d1.used == 0)
                    continue;
                if (d1.used > (d2.total - d2.used))
                    continue;
                count += 1;
            }
        }
        w += 1;
        h += 1;
        try stdout.print("pair count={}, size={}x{}, nbnodes={}\n", .{ count, w, h, discs.len });
    }

    try stdout.print("=== part2 ===========================\n", .{});
    {
        // Je pense qu'il faut observer que en fait tout est plein à >50%, et que donc
        //  les seuls trucs utiles à traquer sont la case vide et les doi. (car on pourra jamais merger deux nodes)
        const Usage = packed struct {
            doi: u1,
            used: u15,
        };
        const Trace = struct {
            usages: [30 * 35]Usage,
            text: [4000]u8,
            len: usize,
        };
        const State = [30 * 35]enum(u2) {
            empty,
            doi,
            movable,
            unmovable,
        };
        const stride = w;
        var map0: [30 * 35]Disk = undefined;
        var cur: State = undefined;
        var trc0: Trace = .{ .text = undefined, .len = 0, .usages = undefined };
        for (discs) |d| {
            const i = stride * @intCast(usize, d.y) + d.x;
            map0[i] = d;
            const doi = (d.y == 0 and d.x == w - 1);
            trc0.usages[i].doi = if (doi) 1 else 0;
            trc0.usages[i].used = @intCast(u15, d.used);
            if (d.used == 0) {
                assert(!doi);
                cur[i] = .empty;
            } else if (d.used > 200) {
                assert(!doi);
                cur[i] = .unmovable;
            } else if (doi) {
                cur[i] = .doi;
            } else {
                cur[i] = .movable;
            }
        }

        const doimoveweight: i32 = 5;

        var dfs = tools.BestFirstSearch(State, Trace).init(allocator);
        defer dfs.deinit();
        try dfs.insert(.{
            .steps = 0,
            .rating = doimoveweight * @intCast(i32, w),
            .state = cur,
            .trace = trc0,
        });

        trace("sizeof(state)=={}\n", .{@sizeOf(State)});

        var depth: u32 = 0;
        var best: ?u32 = null;
        while (dfs.pop()) |node| {
            if (node.state[0 + stride * 0] == .doi) {
                try stdout.print("got the data in {} steps:  {}\n", .{ node.steps, node.trace.text[0..node.trace.len] });
                if (best == null or best.? > node.steps)
                    best = node.steps;
                continue;
            }

            if (best != null and node.steps >= best.?)
                continue;

            if (node.steps > depth) {
                trace("reached depth = {}, with rating {}, visitednodes={}, agendlen={}\n", .{ node.steps, node.rating, dfs.visited.count(), dfs.agenda.items.len });
                depth = node.steps;
                {
                    for (node.state[0 .. w * h]) |s, i| {
                        if (i != 0 and (i % stride) == 0)
                            trace("\n", .{});
                        const char: u8 = switch (s) {
                            .doi => 'x',
                            .empty => '_',
                            .unmovable => '#',
                            .movable => '.',
                        };
                        trace("{c}", .{char});
                    }
                    trace("\n", .{});
                }
            }

            // compute next steps
            var m = node.state;
            var moves: u32 = 0;
            var trc: Trace = node.trace;
            for (m[0 .. w * h]) |*to, i| {
                if (to.* != .empty)
                    continue;
                const used = node.trace.usages[i].used;
                const avail = map0[i].total - used;
                const x = i % stride;
                const y = i / stride;
                assert(x < w and y < h);
                if (x > 0) {
                    const j = i - 1;
                    const from = &m[j];
                    const from_used = node.trace.usages[j].used;
                    const from_doi = node.trace.usages[j].doi != 0;
                    if (from_used > 0 and from_used < avail) {
                        assert(!from_doi or used == 0);
                        const from_bak = from.*;
                        const to_bak = to.*;
                        trc.usages[i] = node.trace.usages[j];
                        trc.usages[j].used = 0;
                        trc.usages[j].doi = 0;
                        to.* = from.*;
                        from.* = .empty;
                        assert(trc.usages[i].used <= map0[i].total);
                        const rating = node.rating + 1 + if (from_doi) doimoveweight else 0;
                        trc.len = node.trace.len;
                        tools.fmt_bufAppend(&trc.text, &trc.len, "{}x{}->{}x{}, ", .{ x - 1, y, x, y });
                        moves += 1;
                        try dfs.insert(.{
                            .steps = node.steps + 1,
                            .rating = rating,
                            .state = m,
                            .trace = trc,
                        });
                        to.* = to_bak;
                        from.* = from_bak;
                        trc.len = node.trace.len;
                        trc.usages[i] = node.trace.usages[i];
                        trc.usages[j] = node.trace.usages[j];
                    }
                }
                if (x < w - 1) {
                    const j = i + 1;
                    const from = &m[j];
                    const from_used = node.trace.usages[j].used;
                    const from_doi = node.trace.usages[j].doi != 0;
                    if (from_used > 0 and from_used < avail) {
                        assert(!from_doi or used == 0);
                        const from_bak = from.*;
                        const to_bak = to.*;
                        trc.usages[i] = node.trace.usages[j];
                        trc.usages[j].used = 0;
                        trc.usages[j].doi = 0;
                        to.* = from.*;
                        from.* = .empty;
                        assert(trc.usages[i].used <= map0[i].total);
                        const rating = node.rating + 1 - if (from_doi) doimoveweight else 0;
                        trc.len = node.trace.len;
                        tools.fmt_bufAppend(&trc.text, &trc.len, "{}x{}->{}x{}, ", .{ x + 1, y, x, y });
                        moves += 1;
                        try dfs.insert(.{
                            .steps = node.steps + 1,
                            .rating = rating,
                            .state = m,
                            .trace = trc,
                        });
                        to.* = to_bak;
                        from.* = from_bak;
                        trc.len = node.trace.len;
                        trc.usages[i] = node.trace.usages[i];
                        trc.usages[j] = node.trace.usages[j];
                    }
                }
                if (y > 0) {
                    const j = i - stride;
                    const from = &m[j];
                    const from_used = node.trace.usages[j].used;
                    const from_doi = node.trace.usages[j].doi != 0;
                    if (from_used > 0 and from_used < avail) {
                        assert(!from_doi or used == 0);
                        const from_bak = from.*;
                        const to_bak = to.*;
                        trc.usages[i] = node.trace.usages[j];
                        trc.usages[j].used = 0;
                        trc.usages[j].doi = 0;
                        to.* = from.*;
                        from.* = .empty;
                        assert(trc.usages[i].used <= map0[i].total);
                        const rating = node.rating + 1 + if (from_doi) doimoveweight else 0;
                        trc.len = node.trace.len;
                        tools.fmt_bufAppend(&trc.text, &trc.len, "{}x{}->{}x{}, ", .{ x, y - 1, x, y });
                        moves += 1;
                        try dfs.insert(.{
                            .steps = node.steps + 1,
                            .rating = rating,
                            .state = m,
                            .trace = trc,
                        });
                        to.* = to_bak;
                        from.* = from_bak;
                        trc.len = node.trace.len;
                        trc.usages[i] = node.trace.usages[i];
                        trc.usages[j] = node.trace.usages[j];
                    }
                }
                if (y < h - 1) {
                    const j = i + stride;
                    const from = &m[j];
                    const from_used = node.trace.usages[j].used;
                    const from_doi = node.trace.usages[j].doi != 0;
                    if (from_used > 0 and from_used < avail) {
                        assert(!from_doi or used == 0);
                        const from_bak = from.*;
                        const to_bak = to.*;
                        trc.usages[i] = node.trace.usages[j];
                        trc.usages[j].used = 0;
                        trc.usages[j].doi = 0;
                        to.* = from.*;
                        from.* = .empty;
                        assert(trc.usages[i].used <= map0[i].total);
                        const rating = node.rating + 1 - if (from_doi) doimoveweight else 0;
                        trc.len = node.trace.len;
                        tools.fmt_bufAppend(&trc.text, &trc.len, "{}x{}->{}x{}, ", .{ x, y + 1, x, y });
                        moves += 1;
                        try dfs.insert(.{
                            .steps = node.steps + 1,
                            .rating = rating,
                            .state = m,
                            .trace = trc,
                        });
                        to.* = to_bak;
                        from.* = from_bak;
                        trc.len = node.trace.len;
                        trc.usages[i] = node.trace.usages[i];
                        trc.usages[j] = node.trace.usages[j];
                    }
                }
            }
            // trace("moves for step : {}\n", .{moves});
        }
    }
}
