const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

fn modpow(base: u64, exp: u64, m: u64) u64 {
    var result: u64 = 1;
    var e = exp;
    var b = base;
    while (e > 0) {
        if ((e & 1) != 0) result = (result * b) % m;
        e = e / 2;
        b = (b * b) % m;
    }

    return result;
}

fn crypt(subj: u32, loopsz: u32) u32 {
    if (true) {
        return @intCast(modpow(subj, loopsz, 20201227));
    } else {
        var val: u64 = 1;
        var i: u32 = 0;
        while (i < loopsz) : (i += 1) {
            val *= subj;
            val %= 20201227;
        }
        //std.debug.print("subj:{}, loop:{} = {}\n", .{ subj, loopsz, val });
        assert(val == modpow(subj, loopsz, 20201227));
        return @intCast(val);
    }
}

pub fn run(input_text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    _ = input_text;
    //const card_pubkey = 5764801;
    //const door_pubkey = 17807724;
    const card_pubkey = 8458505;
    const door_pubkey = 16050997;

    //if (false) { // implem bête et directe de l'énoncé
    //    const subj = 7;
    //
    //    const card_loopsz = blk: {
    //        var loopsz: u32 = 1;
    //        while (true) : (loopsz += 1) {
    //            if (crypt(subj, loopsz) == card_pubkey) break :blk loopsz;
    //        }
    //    };
    //    const door_loopsz = blk: {
    //        var loopsz: u32 = 1;
    //        while (true) : (loopsz += 1) {
    //            if (crypt(subj, loopsz) == door_pubkey) break :blk loopsz;
    //        }
    //    };
    //
    //    const ans = crypt(door_pubkey, card_loopsz);
    //}

    const ans1 = ans: {
        if (false) { // pas plus rapide, car les mul + mod sont pas fait en vectoriel, mais il y a le packing / depacking des vecteur en plus..
            const u64x2 = @Vector(2, u64);
            var pair: u64x2 = .{ 1, 1 };
            const mul: u64x2 = .{ 7, card_pubkey };
            const mod: u64x2 = .{ 20201227, 20201227 };
            while (true) {
                pair = (pair * mul) % mod;
                if (pair[0] == door_pubkey) break :ans pair[1];
            }
        } else {
            var v0: u64 = 1;
            var v1: u64 = 1;
            while (true) {
                v0 = (v0 * 7) % 20201227;
                v1 = (v1 * card_pubkey) % 20201227;
                if (v0 == door_pubkey) break :ans v1;
            }
        }
    };

    const ans2 = ans: {
        break :ans "gratis!";
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{s}", .{ans2}),
    };
}

pub const main = tools.defaultMain("", run);
