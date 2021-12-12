const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

var cache = [_]?u64{null} ** 256;
fn count(adapters: []u1) u64 {
    if (adapters.len == 0) return 1;
    if (cache[adapters.len]) |v| return v;

    var c: u64 = 0;
    if (adapters.len >= 3 and adapters[2] != 0) c += count(adapters[3..]);
    if (adapters.len >= 2 and adapters[1] != 0) c += count(adapters[2..]);
    if (adapters.len >= 1 and adapters[0] != 0) c += count(adapters[1..]);

    cache[adapters.len] = c;
    return c;
}

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    //var adapters_list: [100]u32 = undefined;
    //var nb_adapters: u32 = 0;
    var adapters = [_]u1{0} ** 256;
    var device: u32 = 0;
    {
        var it = std.mem.tokenize(u8, input, "\n\r");
        while (it.next()) |line| {
            const v = try std.fmt.parseInt(u32, line, 10);
            assert(adapters[v] == 0);
            adapters[v] = 1;
            // adapters_list[nb_adapters] = v;
            // nb_adapters += 1;
            if (v > device) device = v;
        }
        device += 3;
        adapters[device] = 1;
    }

    const ans1 = ans: {
        var gaps = [_]u32{ 0, 0, 0 };
        var it: u32 = 1;
        var g: u32 = 0;
        while (it <= device) : (it += 1) {
            if (adapters[it] != 0) {
                gaps[g] += 1;
                // std.debug.print("adap[{}] +{} / gaps:{}, {}, {}\n", .{ it, g, gaps[0], gaps[1], gaps[2] });
                g = 0;
            } else {
                g += 1;
            }
        }
        break :ans gaps[0] * gaps[2];
    };

    const ans2 = count(adapters[1 .. device + 1]);

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2020/input_day10.txt", run);
