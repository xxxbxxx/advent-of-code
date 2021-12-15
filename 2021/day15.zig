const std = @import("std");
const tools = @import("tools");

const with_trace = false;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}
const assert = std.debug.assert;

pub const main = tools.defaultMain("2021/day15.txt", run);

const gutter = 1;
fn propagateRiskLevel(levels: []u32, width: usize, height: usize, ctx: anytype, comptime getIndividualLevel: fn (self: @TypeOf(ctx), x: u32, y: u32) ?u8) void {
    assert(levels.len == (width + gutter * 2) * (height + gutter * 2));

    const stride = width + gutter * 2;
    std.mem.set(u32, levels, 0x0FFFFFFF);

    var dirty = true;
    while (dirty) {
        dirty = false;
        var y: u32 = 0;
        while (y < height) : (y += 1) {
            var x: u32 = 0;
            while (x < width) : (x += 1) {
                const this = &levels[((x + gutter) + 0) + stride * ((y + gutter) + 0)];
                if (getIndividualLevel(ctx, x, y)) |entry_cost| {
                    const r1 = levels[((x + gutter) + 0) + stride * ((y + gutter) - 1)];
                    const r2 = levels[((x + gutter) + 0) + stride * ((y + gutter) + 1)];
                    const r3 = levels[((x + gutter) - 1) + stride * ((y + gutter) + 0)];
                    const r4 = levels[((x + gutter) + 1) + stride * ((y + gutter) + 0)];
                    const r = @minimum(@minimum(r1, r2), @minimum(r3, r4));
                    if (this.* > r + entry_cost) {
                        this.* = r + entry_cost;
                        dirty = true;
                    }
                } else {
                    this.* = 0;
                }
            }
        }
    }
}

pub fn run(input: []const u8, gpa: std.mem.Allocator) tools.RunError![2][]const u8 {
    //var arena_alloc = std.heap.ArenaAllocator.init(gpa);
    //defer arena_alloc.deinit();
    //const arena = arena_alloc.allocator();

    const stride_in = std.mem.indexOfScalar(u8, input, '\n').? + 1;
    const height = (input.len + 1) / stride_in;
    const width = stride_in - 1;
    trace("input: {}x{}\n", .{ width, height });

    const ans1 = ans: {
        const levels_stride = (width + 2);
        var levels = try gpa.alloc(u32, (height + 2) * levels_stride);
        defer gpa.free(levels);

        const context: struct {
            risk: []const u8,
            stride: usize,

            fn entryRisk(ctx: *const @This(), x: u32, y: u32) ?u8 {
                if (x == 0 and y == 0) return null;
                return ctx.risk[x + y * ctx.stride] - '0';
            }
        } = .{ .risk = input, .stride = stride_in };

        propagateRiskLevel(levels, width, height, &context, @TypeOf(context).entryRisk); // context.entryRisk == "BoundFn"?  comment ça s'utilise?

        if (with_trace) {
            var y: u32 = 0;
            while (y < height) : (y += 1) {
                var x: u32 = 0;
                while (x < width) : (x += 1) {
                    trace("{d:2} ", .{@minimum(99, levels[((x + gutter) + 0) + levels_stride * ((y + gutter) + 0)])});
                }
                trace("\n", .{});
            }
        }

        break :ans levels[(width - 1 + gutter) + levels_stride * (height - 1 + gutter)];
    };

    const ans2 = ans: {
        const levels_stride = (5 * width + 2);
        var levels = try gpa.alloc(u32, (5 * height + 2) * levels_stride);
        defer gpa.free(levels);

        const context: struct {
            risk: []const u8,
            stride: usize,
            w: usize,
            h: usize,

            fn entryRisk(ctx: *const @This(), x: u32, y: u32) ?u8 {
                if (x == 0 and y == 0) return null;
                const x0 = x % ctx.w;
                const y0 = y % ctx.h;
                const dist = (x / ctx.w) + (y / ctx.h);
                const v = ctx.risk[x0 + y0 * ctx.stride] - '0';
                return @intCast(u8, (v + dist - 1) % 9 + 1);
            }
        } = .{ .risk = input, .w = width, .h = height, .stride = stride_in };

        propagateRiskLevel(levels, 5 * width, 5 * height, &context, @TypeOf(context).entryRisk); // context.entryRisk == "BoundFn"?  comment ça s'utilise?

        break :ans levels[(5 * width) + levels_stride * (5 * height)];
    };

    return [_][]const u8{
        try std.fmt.allocPrint(gpa, "{}", .{ans1}),
        try std.fmt.allocPrint(gpa, "{}", .{ans2}),
    };
}

test {
    const res0 = try run(
        \\1163751742
        \\1381373672
        \\2136511328
        \\3694931569
        \\7463417111
        \\1319128137
        \\1359912421
        \\3125421639
        \\1293138521
        \\2311944581
    , std.testing.allocator);
    defer std.testing.allocator.free(res0[0]);
    defer std.testing.allocator.free(res0[1]);
    try std.testing.expectEqualStrings("40", res0[0]);
    try std.testing.expectEqualStrings("315", res0[1]);
}
