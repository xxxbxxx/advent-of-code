const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

fn PackedBoolsArray(comptime size: usize) type {
    return struct {
        words: [(size + 63) / 64]u64,
        fn setAll(self: *@This(), val: bool) void {
            @memset(std.mem.asBytes(&self.words), if (val) @as(u8, 0xFF) else @as(u8, 0x00));
        }
        fn get(self: *@This(), index: usize) bool {
            const word = self.words[index / 64];
            const bit: u6 = @intCast(index % 64);
            return word & (@as(u64, 1) << bit) != 0;
        }
        fn set(self: *@This(), index: usize, val: bool) void {
            const word = &self.words[index / 64];
            const bit: u6 = @intCast(index % 64);
            if (val) {
                word.* |= (@as(u64, 1) << bit);
            } else {
                word.* &= ~(@as(u64, 1) << bit);
            }
        }
    };
}

pub fn run(input_text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    _ = input_text;
    const ans1 = ans: {
        var last_turn_of = [_]?u16{null} ** 5000;
        var last_spoken: u16 = undefined;
        var turn: u16 = undefined;
        for ([_]u16{ 0, 3, 1, 6, 7, 5 }, 0..) |n, i| {
            turn = @intCast(i + 1);
            if (i > 0) {
                last_turn_of[last_spoken] = turn - 1;
            }
            last_spoken = n;
        }

        while (turn < 2020) : (turn += 1) {
            //std.debug.print("lastpoken({}): {}\n", .{ last_spoken, last_turn_of[last_spoken] });
            const next =
                if (last_turn_of[last_spoken]) |prev_turn|
                turn - prev_turn
            else
                0;
            last_turn_of[last_spoken] = turn;
            last_spoken = next;
            //std.debug.print("turn {}: {}\n", .{ turn + 1, last_spoken });
        }
        break :ans last_spoken;
    };

    const ans2 = ans: {
        // ça marche tranquille en bourrinant. pour voir, tenté avec une std.AutoArrayHashMap(u32, u32), mais c'est plus lent (beaucoup en debug) et pas vraiement moins gros.
        //  (remplissage de last_turn_of = 3611683/30000000)
        const last_turn_of = try allocator.alloc(u32, 30000000); // 0 unseen, else turn
        defer allocator.free(last_turn_of);
        @memset(last_turn_of, 0);
        const valid_vals = try allocator.create(PackedBoolsArray(30000000));
        defer allocator.destroy(valid_vals);
        valid_vals.setAll(false);

        var last_spoken: u32 = undefined;
        var turn: u32 = undefined;
        for ([_]u32{ 0, 3, 1, 6, 7, 5 }, 0..) |n, i| {
            turn = @intCast(i + 1);
            if (i > 0) {
                last_turn_of[last_spoken] = (turn - 1);
                valid_vals.set(last_spoken, true);
            }
            last_spoken = n;
        }

        while (turn < 30000000) : (turn += 1) {
            //std.debug.print("lastpoken({}): {}\n", .{ last_spoken, last_turn_of[last_spoken] });
            if (last_spoken < 4096) { // bootstaper ça pour eviter le test ci-dessous dans la boucle?
                const next = turn - last_turn_of[last_spoken];
                last_turn_of[last_spoken] = turn;
                last_spoken = if (next != turn) next else 0;
            } else if (valid_vals.get(last_spoken)) {
                const next = turn - last_turn_of[last_spoken];
                last_turn_of[last_spoken] = turn;
                last_spoken = next;
            } else {
                const next = 0;
                valid_vals.set(last_spoken, true);
                last_turn_of[last_spoken] = turn;
                last_spoken = next;
            }
            //std.debug.print("turn {}: {}\n", .{ turn + 1, last_spoken });
        }
        break :ans last_spoken;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2020/input_day14.txt", run);
