const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");
const Vec2 = tools.Vec2;
const Fabric = tools.Map(u8, 1024, 1024, false);

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var fabric = Fabric{ .default_tile = 0 };
    {
        var it = std.mem.tokenize(u8, input, "\n\r");
        while (it.next()) |line| {
            const fields = tools.match_pattern("#{} @ {},{}: {}x{}", line) orelse unreachable;
            //const patchId = fields[0].imm;
            const pos = Vec2{ .x = @as(i32, @intCast(fields[1].imm)), .y = @as(i32, @intCast(fields[2].imm)) };
            const size = Vec2{ .x = @as(i32, @intCast(fields[3].imm)) - 1, .y = @as(i32, @intCast(fields[4].imm)) - 1 };
            const patch = tools.BBox{
                .min = pos,
                .max = Vec2.add(pos, size),
            };
            fabric.fillIncrement(1, patch);
        }
    }

    // part1
    const ans1 = overlaps: {
        var count: usize = 0;
        var it = fabric.iter(null);
        while (it.next()) |tile| {
            if (tile > 1) count += 1;
        }

        break :overlaps count;
    };

    // part2
    //var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    //defer arena.deinit();
    const ans2 = goodpatch: {
        var it = std.mem.tokenize(u8, input, "\n\r");
        while (it.next()) |line| {
            const fields = tools.match_pattern("#{} @ {},{}: {}x{}", line) orelse unreachable;
            const patchId = fields[0].imm;
            const pos = Vec2{ .x = @as(i32, @intCast(fields[1].imm)), .y = @as(i32, @intCast(fields[2].imm)) };
            const size = Vec2{ .x = @as(i32, @intCast(fields[3].imm)) - 1, .y = @as(i32, @intCast(fields[4].imm)) - 1 };
            const patch = tools.BBox{
                .min = pos,
                .max = Vec2.add(pos, size),
            };

            var isbad = false;
            var it2 = fabric.iter(patch);
            while (it2.next()) |tile| {
                assert(tile >= 1);
                if (tile > 1) {
                    isbad = true;
                    break;
                }
            }
            if (!isbad)
                break :goodpatch patchId;
        }
        unreachable;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2018/input_day03.txt", run);
