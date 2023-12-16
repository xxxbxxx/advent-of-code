const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub const main = tools.defaultMain("2023/day15.txt", run);

fn hash(text: []const u8) u8 {
    var h: u8 = 0;
    for (text) |c| h = (h +% c) *% 17;
    return h;
}

pub fn run(text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena_alloc = std.heap.ArenaAllocator.init(allocator);
    defer arena_alloc.deinit();
    const arena = arena_alloc.allocator();
    _ = arena;

    const ans1 = ans: {
        var sum: u32 = 0;
        var it = std.mem.tokenize(u8, text, "\n\r\t,");
        while (it.next()) |segment| {
            sum += hash(segment);
        }
        break :ans sum;
    };

    const ans2 = ans: {
        var boxes: [256]std.StringArrayHashMap(u32) = undefined;
        for (&boxes) |*b| b.* = std.StringArrayHashMap(u32).init(allocator);
        defer for (&boxes) |*b| b.deinit();

        var it = std.mem.tokenize(u8, text, ",\n\r\t");
        while (it.next()) |segment| {
            if (tools.match_pattern("{}-", segment)) |vals| {
                const label = vals[0].lit;
                _ = boxes[hash(label)].orderedRemove(label);
            } else if (tools.match_pattern("{}={}", segment)) |vals| {
                const label = vals[0].lit;
                const focal = vals[1].imm;
                _ = try boxes[hash(label)].fetchPut(label, @intCast(focal));
            } else unreachable;
        }

        var sum: u64 = 0;
        for (&boxes, 1..) |b, i| {
            for (b.values(), 1..) |focal, j| {
                sum += i * j * focal;
            }
        }
        break :ans sum;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

test {
    const res1 = try run(
        \\rn=1,cm-,qp=3,cm=2,qp-,pc=4,ot=9,ab=5,pc-,pc=6,ot=7
    , std.testing.allocator);
    defer std.testing.allocator.free(res1[0]);
    defer std.testing.allocator.free(res1[1]);
    try std.testing.expectEqualStrings("1320", res1[0]);
    try std.testing.expectEqualStrings("145", res1[1]);
}
