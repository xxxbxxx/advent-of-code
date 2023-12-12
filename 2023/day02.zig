const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub const main = tools.defaultMain("2023/day02.txt", run);

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena_alloc = std.heap.ArenaAllocator.init(allocator);
    defer arena_alloc.deinit();
    const arena = arena_alloc.allocator();

    const SubSet = @Vector(3, u8);
    const games = blk: {
        var list = std.ArrayList([]const SubSet).init(arena);
        defer list.deinit();

        var it = std.mem.tokenize(u8, input, "\n\r\t");
        while (it.next()) |line| {
            const game = tools.match_pattern("Game {}: {}", line) orelse continue;
            const game_num: u32 = @intCast(game[0].imm);
            assert(game_num == list.items.len + 1);

            var subsets = std.ArrayList(SubSet).init(arena);
            defer subsets.deinit();
            var subset_it = std.mem.tokenize(u8, game[1].lit, ";");
            while (subset_it.next()) |subset| {
                var rgb: SubSet = .{ 0, 0, 0 };
                var cube_it = std.mem.tokenize(u8, subset, ",");
                while (cube_it.next()) |cube_raw| {
                    const cube = std.mem.trim(u8, cube_raw, " ");
                    if (tools.match_pattern("{} red", cube)) |vals| rgb[0] = @intCast(vals[0].imm);
                    if (tools.match_pattern("{} green", cube)) |vals| rgb[1] = @intCast(vals[0].imm);
                    if (tools.match_pattern("{} blue", cube)) |vals| rgb[2] = @intCast(vals[0].imm);
                }
                try subsets.append(rgb);
            }

            try list.append(try subsets.toOwnedSlice());
        }
        break :blk try list.toOwnedSlice();
    };

    const ans1 = ans: {
        const bag: SubSet = .{ 12, 13, 14 };
        var sum: usize = 0;
        for (games, 1..) |game, num| {
            var possible = true;
            for (game) |subset|
                possible = possible and @reduce(.And, subset <= bag);
            if (possible) sum += num;
        }
        break :ans sum;
    };

    const ans2 = ans: {
        var sum: usize = 0;
        for (games) |game| {
            var min_bag: SubSet = .{ 0, 0, 0 };
            for (game) |subset| min_bag = @max(min_bag, subset);
            const pow = @reduce(.Mul, @as(@Vector(3, u32), min_bag));
            sum += pow;
        }
        break :ans sum;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

test {
    const res = try run(
        \\Game 1: 3 blue, 4 red; 1 red, 2 green, 6 blue; 2 green
        \\Game 2: 1 blue, 2 green; 3 green, 4 blue, 1 red; 1 green, 1 blue
        \\Game 3: 8 green, 6 blue, 20 red; 5 blue, 4 red, 13 green; 5 green, 1 red
        \\Game 4: 1 green, 3 red, 6 blue; 3 green, 6 red; 3 green, 15 blue, 14 red
        \\Game 5: 6 red, 1 blue, 3 green; 2 blue, 1 red, 2 green
    , std.testing.allocator);
    defer std.testing.allocator.free(res[0]);
    defer std.testing.allocator.free(res[1]);
    try std.testing.expectEqualStrings("8", res[0]);
    try std.testing.expectEqualStrings("2286", res[1]);
}
