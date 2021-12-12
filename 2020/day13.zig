const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

const BigInt = u50;

fn pgcd(val1: BigInt, val2: BigInt) BigInt {
    var a = if (val1 > val2) val1 else val2;
    var b = if (val1 > val2) val2 else val1;
    while (b != 0) {
        const r = a % b;
        a = b;
        b = r;
    }
    return a;
}

fn ppcm(val1: BigInt, val2: BigInt) BigInt {
    var div = pgcd(val1, val2);
    var num = val1 * val2;
    return num / div;
}

fn coincidence(period1: BigInt, offset1: BigInt, period2: BigInt, offset2: BigInt) BigInt {
    assert(period1 != 0 and period2 != 0);
    var a: BigInt = offset1;
    var b: BigInt = 0;
    while (b != a + offset2) {
        if (b > a + offset2) a += period1;
        if (b < a + offset2) {
            const ceil = ((period2 - 1) + ((a + offset2) - b)) / period2;
            b += period2 * ceil;
        }
    }
    //std.debug.print("XXXX a={}, b={}, p1={}, p2={}, offset2={}\n", .{ a, b, period1, period2, offset2 });
    return a;
}

pub fn run(_: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    const time = 1000511;
    const input_text = "29,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,37,x,x,x,x,x,409,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,17,13,19,x,x,x,23,x,x,x,x,x,x,x,353,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,41";
    //const input_text = "1789,37,47,1889";
    const Bus = struct { period: u32, gap: u32 };
    var mem_buses: [50]Bus = undefined;
    const buses: []const Bus = blk: {
        var nb: usize = 0;
        var it = std.mem.tokenize(u8, input_text, ",\n\r");
        var i: u32 = 0;
        while (it.next()) |field| : (i += 1) {
            const b = std.fmt.parseInt(u32, field, 10) catch continue;
            mem_buses[nb] = .{ .period = b, .gap = i };
            nb += 1;
        }
        break :blk mem_buses[0..nb];
    };

    const ans1 = ans: {
        var best_gap: u32 = 99999;
        var best_bus: u32 = 0;
        for (buses) |b| {
            const gap = (b.period - (time % b.period)) % b.period;
            if (gap < best_gap) {
                best_gap = gap;
                best_bus = b.period;
            }
            //std.debug.print("bus {} -> {}\n", .{ b, b - earliest % b });
        }
        break :ans best_bus * best_gap;
    };

    const ans2 = ans: {
        var group_period: BigInt = buses[0].period;
        var group_offset: BigInt = 0;
        for (buses[1..]) |b| {
            group_offset = coincidence(group_period, group_offset, b.period, b.gap);
            group_period = ppcm(group_period, b.period);
        }
        break :ans group_offset;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2020/input_day12.txt", run);
