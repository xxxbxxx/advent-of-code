const std = @import("std");
const tools = @import("tools");

const with_trace = true;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}
const assert = std.debug.assert;

pub const main = tools.defaultMain("2021/day13.txt", run);

const Vec2 = tools.Vec2;
fn sortAndremoveDups(list: []Vec2) []Vec2 {
    std.sort.sort(Vec2, list, {}, tools.Vec.lessThan);

    var i: u32 = 1;
    var j: u32 = 0;
    while (i < list.len) : (i += 1) {
        if (@reduce(.Or, list[i] != list[j])) {
            j += 1;
            list[j] = list[i];
        }
    }
    return list[0 .. j + 1];
}

pub fn run(input: []const u8, gpa: std.mem.Allocator) tools.RunError![2][]const u8 {
    //var arena_alloc = std.heap.ArenaAllocator.init(gpa);
    //defer arena_alloc.deinit();
    //const arena = arena_alloc.allocator();

    var dot_list = std.ArrayList(Vec2).init(gpa);
    defer dot_list.deinit();
    var first_fold: ?[]Vec2 = null;
    defer if (first_fold) |l| gpa.free(l);

    var it = std.mem.tokenize(u8, input, "\n");
    while (it.next()) |line| {
        if (tools.match_pattern("{},{}", line)) |val| {
            const v = Vec2{
                @intCast(i32, val[0].imm),
                @intCast(i32, val[1].imm),
            };
            try dot_list.append(v);
        } else if (tools.match_pattern("fold along x={}", line)) |val| {
            const x = @intCast(i32, val[0].imm);
            for (dot_list.items) |*v| {
                if (v.*[0] > x)
                    v.* = Vec2{ 2 * x, 0 } + Vec2{ -1, 1 } * v.*;
            }
            if (first_fold == null) first_fold = try gpa.dupe(Vec2, dot_list.items);
        } else if (tools.match_pattern("fold along y={}", line)) |val| {
            const y = @intCast(i32, val[0].imm);
            for (dot_list.items) |*v| {
                if (v.*[1] > y)
                    v.* = Vec2{ 0, 2 * y } + Vec2{ 1, -1 } * v.*;
            }
            if (first_fold == null) first_fold = try gpa.dupe(Vec2, dot_list.items);
        } else {
            std.debug.print("skipping {s}\n", .{line});
        }
    }

    const ans1 = ans: {
        const l = sortAndremoveDups(first_fold.?);
        break :ans l.len;
    };

    var buf: [4096]u8 = undefined;
    const ans2 = ans: {
        const dots = sortAndremoveDups(dot_list.items);
        const max = max: {
            var m = Vec2{ 0, 0 };
            for (dots) |v| m = @max(m, v);
            break :max m;
        };

        var dot_idx: u32 = 0;
        var buf_idx: u32 = 0;
        var p = Vec2{ 0, 0 };
        while (p[1] <= max[1]) : (p += Vec2{ 0, 1 }) {
            p[0] = 0;
            while (p[0] <= max[0]) : (p += Vec2{ 1, 0 }) {
                if (dot_idx < dots.len and @reduce(.And, p == dots[dot_idx])) {
                    buf[buf_idx] = '#';
                    dot_idx += 1;
                } else {
                    buf[buf_idx] = ' ';
                }
                buf_idx += 1;
            }
            buf[buf_idx] = '\n';
            buf_idx += 1;
        }
        break :ans buf[0..buf_idx];
    };

    return [_][]const u8{
        try std.fmt.allocPrint(gpa, "{}", .{ans1}),
        try std.fmt.allocPrint(gpa, "{s}", .{ans2}),
    };
}

test {
    const res0 = try run(
        \\6,10
        \\0,14
        \\9,10
        \\0,3
        \\10,4
        \\4,11
        \\6,0
        \\6,12
        \\4,1
        \\0,13
        \\10,12
        \\3,4
        \\3,0
        \\8,4
        \\1,10
        \\2,14
        \\8,10
        \\9,0
        \\
        \\fold along y=7
        \\fold along x=5
    , std.testing.allocator);
    defer std.testing.allocator.free(res0[0]);
    defer std.testing.allocator.free(res0[1]);
    try std.testing.expectEqualStrings("17", res0[0]);
    try std.testing.expectEqualStrings(
        \\#####
        \\#   #
        \\#   #
        \\#   #
        \\#####
        \\
    , res0[1]);
}
