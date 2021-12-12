const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub const main = tools.defaultMain("2021/day04.txt", run);

pub fn run(input: []const u8, gpa: std.mem.Allocator) tools.RunError![2][]const u8 {
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();
    const allocator = arena.allocator();

    const Grid = [25]u8;
    var grid_list: []Grid = undefined;
    var number_list: []u8 = undefined;
    {
        var it = std.mem.tokenize(u8, input, "\n\r");
        if (it.next()) |line| { // first line
            var list = std.ArrayList(u8).init(allocator);

            var it_num = std.mem.split(u8, line, ",");
            while (it_num.next()) |txt| {
                const n = try std.fmt.parseInt(u8, txt, 10);
                assert(std.mem.indexOfScalar(u8, list.items, n) == null); // pas de répétitions!
                try list.append(n);
            }

            number_list = list.items;
            //std.debug.print("numbers={d}\n", .{number_list});
        }

        var grids = std.ArrayList(Grid).init(allocator);
        var cur_grid: Grid = undefined;
        var i: u32 = 0;
        while (it.next()) |line| {
            var it_num = std.mem.tokenize(u8, line, " \t\n\r");
            while (it_num.next()) |txt| {
                cur_grid[i] = try std.fmt.parseInt(u8, txt, 10);
                i += 1;
                if (i % 25 == 0) {
                    try grids.append(cur_grid);
                    i = 0;
                }
            }
        }
        grid_list = grids.items;
        //std.debug.print("numbers={} grids={}\n", .{ number_list.len, grid_list.len });
    }

    const answer = ans: {
        const State = struct {
            sum: u32, // somme des nombres cochés
            lines: [5]u8, // combien de cases cochées sur la ligne
            columns: [5]u8, // combien de cases cochées sur la colonne
        };
        const states = try allocator.alloc(State, grid_list.len);
        defer allocator.free(states);
        std.mem.set(State, states, .{ .sum = 0, .lines = [5]u8{ 0, 0, 0, 0, 0 }, .columns = [5]u8{ 0, 0, 0, 0, 0 } });

        var active_grids = try allocator.alloc(u32, grid_list.len);
        defer allocator.free(active_grids);
        for (active_grids) |*idx, i| idx.* = @intCast(u32, i);

        var ans1: ?u32 = null;

        for (number_list) |n| {
            var j: i32 = 0;
            while (j < active_grids.len) : (j += 1) {
                const i = active_grids[@intCast(usize, j)];
                const g = grid_list[i];

                if (std.mem.indexOfScalar(u8, &g, n)) |idx| {
                    const s = &states[i];
                    s.sum += n;
                    s.lines[idx / 5] += 1;
                    s.columns[idx % 5] += 1;
                    if (s.lines[idx / 5] == 5 or s.columns[idx % 5] == 5) { // Quine!
                        var total: u32 = 0;
                        for (g) |sq| total += sq;
                        const v = (total - s.sum) * n;
                        if (ans1 == null)
                            ans1 = v;
                        if (active_grids.len == 1) {
                            const ans2 = v;
                            break :ans .{ ans1.?, ans2 };
                        }

                        // écarte la grille
                        active_grids[@intCast(usize, j)] = active_grids[active_grids.len - 1];
                        active_grids.len -= 1;
                        j -= 1;
                    }
                }
            }
        }
        unreachable;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(gpa, "{}", .{answer[0]}),
        try std.fmt.allocPrint(gpa, "{}", .{answer[1]}),
    };
}

test {
    const res = try run(
        \\7,4,9,5,11,17,23,2,0,14,21,24,10,16,13,6,15,25,12,22,18,20,8,19,3,26,1
        \\
        \\22 13 17 11  0
        \\ 8  2 23  4 24
        \\21  9 14 16  7
        \\ 6 10  3 18  5
        \\ 1 12 20 15 19
        \\
        \\ 3 15  0  2 22
        \\ 9 18 13 17  5
        \\19  8  7 25 23
        \\20 11 10 24  4
        \\14 21 16 12  6
        \\
        \\14 21 17 24  4
        \\10 16 15  9 19
        \\18  8 23 26 20
        \\22 11 13  6  5
        \\ 2  0 12  3  7
    , std.testing.allocator);
    defer std.testing.allocator.free(res[0]);
    defer std.testing.allocator.free(res[1]);
    try std.testing.expectEqualStrings("4512", res[0]);
    try std.testing.expectEqualStrings("1924", res[1]);
}
