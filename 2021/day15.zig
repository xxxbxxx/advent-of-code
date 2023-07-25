const std = @import("std");
const tools = @import("tools");

const with_trace = false;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}
const assert = std.debug.assert;

pub const main = tools.defaultMain("2021/day15.txt", run);

fn computeLowestExitLevel(alloc: std.mem.Allocator, width: usize, height: usize, ctx: anytype, comptime getIndividualLevel: fn (self: @TypeOf(ctx), x: u32, y: u32) u8) !u32 {
    const Step = packed struct {
        x: u16,
        y: u16,
        level: u16,
        fn compare(_: void, a: @This(), b: @This()) std.math.Order {
            //return std.math.order(a.level, b.level);  plus lent. bizarre

            // testé avec prio = level + k*((width-x)+(hight-y))  -> moins bien.  Facteur limitant = taille de la queue.
            if (a.level < b.level) return .lt;
            if (a.level > b.level) return .gt;
            //if (a.x < b.x or a.y < b.y) return .gt;
            //if (a.x > b.x or a.y > b.y) return .lt;
            return .eq;
        }
    };
    var queue = std.PriorityDequeue(Step, void, Step.compare).init(alloc, {}); // dequeue way faster than queue
    defer queue.deinit();

    const acculevels = try alloc.alloc(u16, width * height);
    defer alloc.free(acculevels);
    std.mem.set(u16, acculevels, 0x7FFF);
    //var best: u16 = 0x7FFF;  // useless, pas grand chose à élaguer

    // start point
    try queue.add(Step{ .x = 0, .y = 0, .level = 0 });

    while (queue.removeMinOrNull()) |step| {
        //if (step.level >= best) continue;
        const x = step.x;
        const y = step.y;
        const index = x + width * y;
        const this = &acculevels[index];
        if (step.level >= this.*) continue;
        this.* = step.level;

        if (x > 0) {
            const l = step.level + getIndividualLevel(ctx, x - 1, y);
            if (l < acculevels[index - 1]) { // and (l < best)
                acculevels[index - 1] = l + 1; // (+1 to make sure than when the step is popped from the queue it is not ignored)
                try queue.add(Step{ .x = (x - 1), .y = (y + 0), .level = l });
            }
        }
        if (y > 0) {
            const l = step.level + getIndividualLevel(ctx, x, y - 1);
            if (l < acculevels[index - width]) { // and (l < best)
                acculevels[index - width] = l + 1;
                try queue.add(Step{ .x = (x + 0), .y = (y - 1), .level = l });
            }
        }
        if (x + 1 < width) {
            const l = step.level + getIndividualLevel(ctx, x + 1, y);
            if (l < acculevels[index + 1]) { // and (l < best)
                acculevels[index + 1] = l + 1;
                try queue.add(Step{ .x = (x + 1), .y = (y + 0), .level = l });
            }
        }
        if (y + 1 < height) {
            const l = step.level + getIndividualLevel(ctx, x, y + 1);
            if (l < acculevels[index + width]) { // and (l < best)
                acculevels[index + width] = l + 1;
                try queue.add(Step{ .x = (x + 0), .y = (y + 1), .level = l });
            }
        }

        //if (index == width * height - 1) {
        //    // En fait vu qu'on a prio == level, on fait un best-first-search, et donc on sait que tous les levels suivants seront >= best.
        //    // Mais ça ne compense pas le test en plus
        //    break;
        //}
    }

    if (false) {
        var y: u32 = 0;
        while (y < height) : (y += 1) {
            var x: u32 = 0;
            while (x < width) : (x += 1) {
                trace("{d:2} ", .{@min(99, acculevels[x + width * y])});
            }
            trace("\n", .{});
        }
    }

    return acculevels[width * height - 1];
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
        const context: struct {
            risk: []const u8,
            stride: usize,

            fn entryRisk(ctx: *const @This(), x: u32, y: u32) u8 {
                return ctx.risk[x + y * ctx.stride] - '0';
            }
        } = .{ .risk = input, .stride = stride_in };

        break :ans try computeLowestExitLevel(gpa, width, height, &context, @TypeOf(context).entryRisk); // context.entryRisk == "BoundFn"?  comment ça s'utilise?
    };

    const ans2 = ans: {
        const context: struct {
            risk: []const u8,
            stride: usize,
            w: usize,
            h: usize,

            fn entryRisk(ctx: *const @This(), x: u32, y: u32) u8 {
                // nb: hardcoder w,h = 100x100  ne gagne pas tant que ça (15%)
                const x0 = x % ctx.w;
                const y0 = y % ctx.h;
                const dist = (x / ctx.w) + (y / ctx.h);
                const v = ctx.risk[x0 + y0 * ctx.stride] - '0';
                return @intCast(u8, (v + dist - 1) % 9 + 1);
            }
        } = .{ .risk = input, .w = width, .h = height, .stride = stride_in };

        break :ans try computeLowestExitLevel(gpa, 5 * width, 5 * height, &context, @TypeOf(context).entryRisk); // context.entryRisk == "BoundFn"?  comment ça s'utilise?
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
