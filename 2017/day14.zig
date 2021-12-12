const std = @import("std");
const tools = @import("tools");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

fn reverseCircular(list: []u8, index: usize, len: usize) void {
    var i: u32 = 0;
    const mod = list.len;
    while (i < len / 2) : (i += 1) {
        const t = list[(index + i) % mod];
        list[(index + i) % mod] = list[(index + ((len - 1) - i)) % mod];
        list[(index + ((len - 1) - i)) % mod] = t;
    }
}

fn knotHash(str: []const u8) u128 {
    const mod = 256;
    var list = comptime blk: {
        var l: [mod]u8 = undefined;
        for (l) |*e, i| {
            e.* = @intCast(u8, i);
        }
        break :blk l;
    };

    var skip: u32 = 0;
    var cursor: u32 = 0;
    var round: u32 = 0;
    while (round < 64) : (round += 1) {
        for (str) |l| {
            reverseCircular(&list, cursor, l);
            cursor = (cursor + l + skip) % mod;
            skip += 1;
        }
        for ([_]u8{ 17, 31, 73, 47, 23 }) |l| {
            reverseCircular(&list, cursor, l);
            cursor = (cursor + l + skip) % mod;
            skip += 1;
        }
    }

    var hash: u128 = 0;
    var accu: u8 = 0;
    for (list) |l, i| {
        accu ^= l;
        if ((i + 1) % 16 == 0) {
            hash |= @intCast(u128, accu) << @intCast(u7, ((i / 16) * 8));
            accu = 0;
        }
    }

    return hash;
}

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().writer();
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const prefix = "jzgqcdpd";

    //@setEvalBranchQuota(500000);   -> explose en comptime.
    //const onescount = comptime blk: {
    //    var bitcount: u32 = 0;
    //    var row: u32 = 0;
    //    while (row < 128) : (row += 1) {
    //        var buf: [12]u8 = undefined;
    //        const str = std.fmt.bufPrint(&buf, prefix ++ "-{}", .{row}) catch unreachable;
    //        const hash = knotHash(str);
    //        bitcount += @popCount(u128, hash);
    //    }
    //    break :blk bitcount;
    //};

    var disk: [128 * 128]u16 = undefined;
    var sectors: u16 = 0;
    {
        var row: u32 = 0;
        while (row < 128) : (row += 1) {
            var buf: [12]u8 = undefined;
            const str = std.fmt.bufPrint(&buf, prefix ++ "-{}", .{row}) catch unreachable;
            const hash = knotHash(str);

            var bit: u8 = 0;
            while (bit < 128) : (bit += 1) {
                const filled = (hash & (@as(u128, 1) << @intCast(u7, bit))) != 0;
                if (filled) {
                    sectors += 1;
                    disk[row * 128 + bit] = sectors;
                } else {
                    disk[row * 128 + bit] = 0;
                }
            }
        }
    }

    var dirty = true;
    while (dirty) {
        dirty = false;
        var row: u32 = 0;
        while (row < 128) : (row += 1) {
            var col: u32 = 0;
            while (col < 128) : (col += 1) {
                const d00 = &disk[(row + 0) * 128 + (col + 0)];
                if (row < 127) {
                    const d10 = &disk[(row + 1) * 128 + (col + 0)];
                    if (d00.* != 0 and d10.* != 0 and d00.* != d10.*) {
                        const min = if (d00.* < d10.*) d00.* else d10.*;
                        d00.* = min;
                        d10.* = min;
                        dirty = true;
                    }
                }
                if (col < 127) {
                    const d01 = &disk[(row + 0) * 128 + (col + 1)];
                    if (d00.* != 0 and d01.* != 0 and d00.* != d01.*) {
                        const min = if (d00.* < d01.*) d00.* else d01.*;
                        d00.* = min;
                        d01.* = min;
                        dirty = true;
                    }
                }
            }
        }
    }

    var regions = blk: {
        var used = [1]bool{false} ** (128 * 128);
        var total: u32 = 0;
        for (disk) |d| {
            if (d == 0) continue;
            if (used[d]) continue;
            total += 1;
            used[d] = true;
        }
        break :blk total;
    };

    try stdout.print("sectors={} regions={}\n", .{ sectors, regions });
}
