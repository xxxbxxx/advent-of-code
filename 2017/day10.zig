const std = @import("std");
const tools = @import("tools");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

fn regIndex(name: []const u8) u32 {
    var num: u32 = 0;
    for (name) |c| {
        num = (num * 27) + c - 'a';
    }
    return num;
}
pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().writer();
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    //const limit = 1 * 1024 * 1024 * 1024;
    //const text = try std.fs.cwd().readFileAlloc(allocator, "day9.txt", limit);
    //defer allocator.free(text);

    const lengths1 = [_]u32{ 18, 1, 0, 161, 255, 137, 254, 252, 14, 95, 165, 33, 181, 168, 2, 188 };
    //const lengths2 = "AoC 2017" ++ [_]u8{ 17, 31, 73, 47, 23 };
    const lengths2 = "18,1,0,161,255,137,254,252,14,95,165,33,181,168,2,188" ++ [_]u8{ 17, 31, 73, 47, 23 };

    const mod = 256;
    var list = comptime blk: {
        var l: [mod]u8 = undefined;
        for (l, 0..) |*e, i| {
            e.* = @as(u8, @intCast(i));
        }
        break :blk l;
    };

    var skip: u32 = 0;
    var cursor: u32 = 0;
    var round: u32 = 0;
    while (round < 64) : (round += 1) {
        for (lengths2) |l| {
            // reverse list[cursor..cursor+l%mod]
            var i: u32 = 0;
            while (i < l / 2) : (i += 1) {
                const t = list[(cursor + i) % mod];
                list[(cursor + i) % mod] = list[(cursor + ((l - 1) - i)) % mod];
                list[(cursor + ((l - 1) - i)) % mod] = t;
            }

            // cursor %+= l+skip %mod
            cursor = (cursor + l + skip) % mod;

            // skip ++
            skip += 1;
        }
    }

    const hextochar = "0123456789abcdef";
    var hash: [32]u8 = undefined;
    var accu: u8 = 0;
    for (list, 0..) |l, i| {
        accu ^= l;
        if ((i + 1) % 16 == 0) {
            hash[2 * (i / 16) + 0] = hextochar[(accu / 16) % 16];
            hash[2 * (i / 16) + 1] = hextochar[accu % 16];
            accu = 0;
        }
    }

    try stdout.print("list={}, {}, {}, ... -> {}\nhash={}\n", .{ list[0], list[1], list[2], @as(u32, @intCast(list[0])) * @as(u32, @intCast(list[1])), hash });
}
