const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

const Vec3 = struct { x: i32, y: i32, z: i32 };
const zero3 = Vec3{ .x = 0, .y = 0, .z = 0 };
const Bot = struct { p: Vec3, r: u31 };
fn dist(a: Vec3, b: Vec3) u32 {
    return @abs(a.x - b.x) + @abs(a.y - b.y) + @abs(a.z - b.z);
}

fn axisRangeDist(p: i32, min: i32, max: i32) u32 {
    if (p > max) return @as(u32, @intCast(p - max));
    if (p < min) return @as(u32, @intCast(min - p));
    return 0;
}

fn countBots(corner: Vec3, size: u31, bots: []const Bot) u32 {
    const box_min = corner;
    const box_max = Vec3{ .x = corner.x + size - 1, .y = corner.y + size - 1, .z = corner.z + size - 1 };
    var count: u32 = 0;
    for (bots) |b| {
        //const bot_min = Vec3{ .x = b.p.x - b.r, .y = b.p.y - b.r, .z = b.p.z - b.r };
        //const bot_max = Vec3{ .x = b.p.x + b.r, .y = b.p.y + b.r, .z = b.p.z + b.r };
        //if (bbox_min.x > bot_max.x or bbox_max.x < bot_min.x) continue;
        //if (bbox_min.y > bot_max.y or bbox_max.y < bot_min.y) continue;
        //if (bbox_min.z > bot_max.z or bbox_max.z < bot_min.z) continue;

        // cf  "Graphics Gems" AABB intersects with a solid sphere  Jim Arvo
        const d = axisRangeDist(b.p.x, box_min.x, box_max.x) + axisRangeDist(b.p.y, box_min.y, box_max.y) + axisRangeDist(b.p.z, box_min.z, box_max.z);
        if (d <= b.r) count += 1;
    }
    return count;
}

const Cell = struct {
    size: u31,
    corner: Vec3,
    population: u32,

    fn betterThan(_: void, a: @This(), b: @This()) std.math.Order {
        if (a.population > b.population) return .lt;
        if (a.population < b.population) return .gt;
        if (a.size < b.size) return .lt;
        if (a.size > b.size) return .gt;
        if (dist(zero3, a.corner) < dist(zero3, b.corner)) return .lt;
        return .gt;
    }
};

pub fn run(input_text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const param: struct {
        bots: []Bot,
        largest_idx: usize,
    } = param: {
        var bots = std.ArrayList(Bot).init(arena.allocator());
        var large_idx: usize = 0;
        var large_radius: u32 = 0;
        var it = std.mem.tokenize(u8, input_text, "\n\r");
        while (it.next()) |line| {
            if (tools.match_pattern("pos=<{},{},{}>, r={}", line)) |fields| {
                const b = Bot{
                    .p = Vec3{ .x = @as(i32, @intCast(fields[0].imm)), .y = @as(i32, @intCast(fields[1].imm)), .z = @as(i32, @intCast(fields[2].imm)) },
                    .r = @as(u31, @intCast(fields[3].imm)),
                };
                if (b.r > large_radius) {
                    large_radius = b.r;
                    large_idx = bots.items.len;
                }
                try bots.append(b);
            } else unreachable;
        }
        break :param .{ .bots = bots.items, .largest_idx = large_idx };
    };
    //std.debug.print("got {} bots, largest at {}\n", .{ param.bots.len, param.largest_idx });

    const ans1 = ans: {
        var count: usize = 0;
        const center = param.bots[param.largest_idx];
        for (param.bots) |b| {
            const d = dist(b.p, center.p);
            //std.debug.print(" dist= {} b.p={}, center.p={}, r={} \n", .{ d, b.p, center.p, center.r });
            if (d <= center.r) count += 1;
        }
        break :ans count;
    };

    const ans2 = ans: {
        //nb cet algo ne marche pas (bien du tout) si les sphres sont reparties de façon homogène (vu ue du coup il faut tout explorer en parallèle...)
        const global_size = 1024 * 1024 * 256; // à la louche, on pourrait examiner les données pour avoir la bbox précise
        var workqueue = std.PriorityQueue(Cell, void, Cell.betterThan).init(allocator, {});
        defer workqueue.deinit();

        {
            var cell0 = Cell{
                .size = global_size,
                .corner = Vec3{ .x = -global_size / 2, .y = -global_size / 2, .z = -global_size / 2 },
                .population = undefined,
            };
            cell0.population = countBots(cell0.corner, cell0.size, param.bots);
            try workqueue.add(cell0);
        }

        while (workqueue.removeOrNull()) |cell| {
            //std.debug.print("examining {}...\n", .{cell});
            if (cell.size == 1) break :ans dist(zero3, cell.corner);

            const step = (cell.size + 1) / 2;
            var subcell_idx: u32 = 0;
            while (subcell_idx < 8) : (subcell_idx += 1) {
                const x = subcell_idx % 2;
                const y = (subcell_idx / 2) % 2;
                const z = (subcell_idx / 4) % 2;
                const corner = Vec3{ .x = cell.corner.x + @as(i32, @intCast(x * step)), .y = cell.corner.y + @as(i32, @intCast(y * step)), .z = cell.corner.z + @as(i32, @intCast(z * step)) };
                const count = countBots(corner, step, param.bots);
                try workqueue.add(Cell{ .size = step, .corner = corner, .population = count });
            }
        }
        unreachable;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2018/input_day23.txt", run);
