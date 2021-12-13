const std = @import("std");
const tools = @import("tools");

const with_trace = true;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}
const assert = std.debug.assert;

pub const main = tools.defaultMain("2021/day12.txt", run);

const Room = struct {
    links: [8]u8 = undefined,
    nb_links: u8 = 0,
    is_large: bool = false,
};
const Maze = struct {
    rooms: []Room,
    names: [][]const u8,
    start: u8,
    end: u8,
};

fn countRoutes(maze: *const Maze, smallroom_visit_bits: u32, cur_idx: u8, bonus_visit_used: bool) @Vector(2, u32) {
    if (cur_idx == maze.end) return .{ @boolToInt(!bonus_visit_used), 1 };

    const room = &maze.rooms[cur_idx];

    if (room.is_large) {
        var total = @Vector(2, u32){ 0, 0 };
        for (room.links[0..room.nb_links]) |ri| {
            total += countRoutes(maze, smallroom_visit_bits, ri, bonus_visit_used);
        }
        return total;
    } else {
        const mask = @as(u32, 1) << @intCast(u5, cur_idx);
        var bonus = bonus_visit_used;
        if (smallroom_visit_bits & mask != 0) {
            if (!bonus_visit_used and cur_idx != maze.start and cur_idx != maze.end) {
                bonus = true;
            } else {
                return .{ 0, 0 };
            }
        }

        var total = @Vector(2, u32){ 0, 0 };
        for (room.links[0..room.nb_links]) |ri| {
            total += countRoutes(maze, (smallroom_visit_bits | mask), ri, bonus);
        }
        return total;
    }
}

pub fn run(input: []const u8, gpa: std.mem.Allocator) tools.RunError![2][]const u8 {
    var arena_alloc = std.heap.ArenaAllocator.init(gpa);
    defer arena_alloc.deinit();
    const arena = arena_alloc.allocator();

    const maze: Maze = blk: {
        var room_names = std.StringArrayHashMap(void).init(arena);
        var rooms = try arena.alloc(Room, 32);
        std.mem.set(Room, rooms, Room{});
        var start: ?u8 = null;
        var end: ?u8 = null;

        var it = std.mem.tokenize(u8, input, "\n");
        while (it.next()) |line| {
            if (tools.match_pattern("{}-{}", line)) |val| {
                const entrya = try room_names.getOrPut(val[0].lit);
                const entryb = try room_names.getOrPut(val[1].lit);
                const ia = @intCast(u8, entrya.index);
                const ib = @intCast(u8, entryb.index);

                const ra = &rooms[ia];
                ra.is_large = (val[0].lit[0] >= 'A' and val[0].lit[0] <= 'Z');
                ra.links[ra.nb_links] = @intCast(u8, ib);
                ra.nb_links += 1;
                if (std.mem.eql(u8, val[0].lit, "start")) start = ia;
                if (std.mem.eql(u8, val[0].lit, "end")) end = ia;

                const rb = &rooms[ib];
                rb.is_large = (val[1].lit[0] >= 'A' and val[1].lit[0] <= 'Z');
                rb.links[rb.nb_links] = @intCast(u8, ia);
                rb.nb_links += 1;
                if (std.mem.eql(u8, val[1].lit, "start")) start = ib;
                if (std.mem.eql(u8, val[1].lit, "end")) end = ib;
            } else {
                std.debug.print("skipping {s}\n", .{line});
            }
        }
        break :blk Maze{
            .rooms = rooms[0..room_names.count()],
            .names = room_names.keys(),
            .start = start.?,
            .end = end.?,
        };
    };

    const ans = countRoutes(&maze, 0, maze.start, false);

    return [_][]const u8{
        try std.fmt.allocPrint(gpa, "{}", .{ans[0]}),
        try std.fmt.allocPrint(gpa, "{}", .{ans[1]}),
    };
}

test {
    const res0 = try run(
        \\start-A
        \\start-b
        \\A-c
        \\A-b
        \\b-d
        \\A-end
        \\b-end
    , std.testing.allocator);
    defer std.testing.allocator.free(res0[0]);
    defer std.testing.allocator.free(res0[1]);
    try std.testing.expectEqualStrings("10", res0[0]);
    try std.testing.expectEqualStrings("36", res0[1]);

    const res1 = try run(
        \\dc-end
        \\HN-start
        \\start-kj
        \\dc-start
        \\dc-HN
        \\LN-dc
        \\HN-end
        \\kj-sa
        \\kj-HN
        \\kj-dc
    , std.testing.allocator);
    defer std.testing.allocator.free(res1[0]);
    defer std.testing.allocator.free(res1[1]);
    try std.testing.expectEqualStrings("19", res1[0]);
    try std.testing.expectEqualStrings("103", res1[1]);

    const res2 = try run(
        \\fs-end
        \\he-DX
        \\fs-he
        \\start-DX
        \\pj-DX
        \\end-zg
        \\zg-sl
        \\zg-pj
        \\pj-he
        \\RW-he
        \\fs-DX
        \\pj-RW
        \\zg-RW
        \\start-pj
        \\he-WI
        \\zg-he
        \\pj-fs
        \\start-RW
    , std.testing.allocator);
    defer std.testing.allocator.free(res2[0]);
    defer std.testing.allocator.free(res2[1]);
    try std.testing.expectEqualStrings("226", res2[0]);
    try std.testing.expectEqualStrings("3509", res2[1]);
}
