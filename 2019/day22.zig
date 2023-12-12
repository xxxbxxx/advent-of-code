const std = @import("std");
const tools = @import("tools");

const with_trace = true;
const with_dissassemble = false;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

pub fn run(input: []const u8, allocator: std.mem.Allocator) tools.RunError![2][]const u8 {
    const AffineFunc = tools.ModArith(i48).AffineFunc;

    const part1 = ans1: {
        const cardmax = 10006;

        // identité
        //    indexof(card) -> card
        // stack:
        //    indexof(card) -> cardmax-card
        // cut n:
        //    indexof(card) -> (card-n)  % (cardmax+1)
        // deal inc:
        //    indexof(card) -> (card*inc) % (cardmax+1)
        // -> et on compose.  ça donne une fonction affine  modulo m ?
        //    indexof(x) ->  (a*x+b) % (cardmax+1)

        const m = (cardmax + 1);
        var shuffle = AffineFunc{ .a = 1, .b = 0 };

        var it = std.mem.tokenize(u8, input, "\n");
        while (it.next()) |line| {
            const step = blk: {
                if (tools.match_pattern("deal with increment {}", line)) |vals| {
                    const inc: i32 = @intCast(vals[0].imm);
                    break :blk AffineFunc{ .a = inc, .b = 0 };
                } else if (tools.match_pattern("cut {}", line)) |vals| {
                    const amount: i32 = @intCast(vals[0].imm);
                    break :blk AffineFunc{ .a = 1, .b = -amount };
                } else if (tools.match_pattern("deal into new stack", line)) |_| {
                    break :blk AffineFunc{ .a = -1, .b = -1 };
                } else {
                    trace("skipping '{s}'\n", .{line});
                    break :blk AffineFunc{ .a = 1, .b = 0 };
                }
            };
            shuffle = AffineFunc.compose(step, shuffle, m);
        }

        //var idx: T = 0;
        //while (idx <= cardmax) : (idx += 1) {
        //    trace("indexof({}) -> {}\n", .{ idx, f.eval(idx) });
        //}

        //const g = f.invert(m);
        //trace("cardat({}) -> {}\n", .{ 4703, g.eval(4703) });

        break :ans1 shuffle.eval(2019, m);
    };

    const part2 = ans2: {
        const cardmax = 119315717514047 - 1;

        const m = (cardmax + 1);
        var shuffle = AffineFunc{ .a = 1, .b = 0 };

        var it = std.mem.tokenize(u8, input, "\n");
        while (it.next()) |line| {
            const step = blk: {
                if (tools.match_pattern("deal with increment {}", line)) |vals| {
                    const inc: i32 = @intCast(vals[0].imm);
                    break :blk AffineFunc{ .a = inc, .b = 0 };
                } else if (tools.match_pattern("cut {}", line)) |vals| {
                    const amount: i32 = @intCast(vals[0].imm);
                    break :blk AffineFunc{ .a = 1, .b = -amount };
                } else if (tools.match_pattern("deal into new stack", line)) |_| {
                    break :blk AffineFunc{ .a = -1, .b = -1 };
                } else {
                    trace("skipping '{s}'\n", .{line});
                    break :blk AffineFunc{ .a = 1, .b = 0 };
                }
            };
            shuffle = AffineFunc.compose(step, shuffle, m);
        }

        const manyshuffle = AffineFunc.autocompose(shuffle, 101741582076661, m);
        const invshuffle = AffineFunc.invert(manyshuffle, m);
        break :ans2 invshuffle.eval(2020, m);
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{part1}),
        try std.fmt.allocPrint(allocator, "{}", .{part2}),
    };
}

pub const main = tools.defaultMain("2019/day22.txt", run);
