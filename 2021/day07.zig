const std = @import("std");
const tools = @import("tools");

const with_trace = false;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}
const assert = std.debug.assert;

pub const main = tools.defaultMain("2021/day07.txt", run);

fn fuelCost_part1(dist: u32) u32 {
    return dist;
}

fn fuelCost_part2(dist: u32) u32 {
    return dist * (dist + 1) / 2;
}

fn computeTotalFuel(list: []i16, t: i16, fuelcostFn: fn (u32) u32) u64 {
    var total: u64 = 0;
    for (list) |p| {
        total += fuelcostFn(@intCast(u32, std.math.absInt(t - p) catch unreachable));
    }
    return total;
}

fn findBest(list: []i16, fuelcostFn: fn (u32) u32) u64 {
    var pos_left: i16 = 0; //std.mem.min(i16, list);
    var pos_right: i16 = 10000; //std.mem.max(i16, list);
    var eval_left = computeTotalFuel(list, pos_left, fuelcostFn);
    var eval_right = computeTotalFuel(list, pos_right, fuelcostFn);
    trace("left={} -> {}\n", .{ pos_left, eval_left });
    trace("right={} -> {}\n", .{ pos_right, eval_right });

    //var p = pos_left;
    //while (p < pos_right) : (p += 1) {
    //    const eval = computeTotalFuel(list, p, fuelcostFn);
    //    trace("pos={} eval={}\n", .{ p, eval });
    //    if (eval_left > eval) eval_left = eval;
    //}

    // fontions en V : on est soit sur la partie \  soit sur la partie /...
    while (pos_left < pos_right) {
        var mid = @divFloor(pos_left + pos_right, 2);
        const eval0 = computeTotalFuel(list, mid, fuelcostFn);
        const eval1 = computeTotalFuel(list, mid + 1, fuelcostFn);
        trace("[{}...{}]:  {} -> {},{}\n", .{ pos_left, pos_right, mid, eval0, eval1 });

        if (eval0 > eval1) { // dans la moitié décroisante
            pos_left = mid + 1;
            eval_left = eval1;
        } else { // dans la moitié croisante
            pos_right = mid;
            eval_right = eval0;
        }
    }
    assert(eval_left == eval_right);
    return eval_left;
}

pub fn run(input: []const u8, gpa: std.mem.Allocator) tools.RunError![2][]const u8 {
    var list0 = std.ArrayList(i16).init(gpa);
    defer list0.deinit();
    {
        try list0.ensureTotalCapacity(input.len / 2);
        var it = std.mem.tokenize(u8, input, ", \t\n\r");
        while (it.next()) |num| {
            try list0.append(try std.fmt.parseInt(i16, num, 10));
        }
    }

    const ans1 = findBest(list0.items, fuelCost_part1);
    const ans2 = findBest(list0.items, fuelCost_part2);

    // bonus:
    if (list0.items[0] > 1000) {
        var cpu = tools.IntCode_Computer{
            .name = "decoder",
            .memory = try gpa.alloc(tools.IntCode_Computer.Data, 10000),
        };
        defer gpa.free(cpu.memory);
        const image = try gpa.alloc(tools.IntCode_Computer.Data, list0.items.len);
        defer gpa.free(image);
        for (image) |*m, i| {
            m.* = list0.items[i];
        }
        cpu.boot(image);
        _ = async cpu.run();
        while (!cpu.is_halted()) {
            switch (cpu.io_mode) {
                .input => unreachable,
                .output => trace("{c}", .{@intCast(u8, cpu.io_port)}), // "Ceci n'est pas une intcode program"
            }
            resume cpu.io_runframe;
        }
    }

    return [_][]const u8{
        try std.fmt.allocPrint(gpa, "{}", .{ans1}),
        try std.fmt.allocPrint(gpa, "{}", .{ans2}),
    };
}

test {
    const res = try run("16,1,2,0,4,2,7,1,2,14", std.testing.allocator);
    defer std.testing.allocator.free(res[0]);
    defer std.testing.allocator.free(res[1]);
    try std.testing.expectEqualStrings("37", res[0]);
    try std.testing.expectEqualStrings("168", res[1]);
}
