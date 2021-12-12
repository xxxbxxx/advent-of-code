const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

fn maskOf(bit: usize) u26 {
    return @as(u26, 1) << @intCast(u5, bit);
}

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var table = [_]u26{0} ** 26;
    var allSteps: u26 = 0;
    {
        var it = std.mem.tokenize(u8, input, "\n\r");
        while (it.next()) |line| {
            const fields = tools.match_pattern("Step {} must be finished before step {} can begin.", line) orelse unreachable;
            const in = fields[0].lit[0] - 'A';
            const out = fields[1].lit[0] - 'A';
            table[out] |= maskOf(in);
            allSteps |= maskOf(out) | maskOf(in);
        }
    }

    // part1
    //var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    //defer arena.deinit();
    var buf: [32]u8 = undefined;
    const ans1 = ans: {
        var len: u32 = 0;
        var done: u26 = 0;
        var todo = allSteps;
        while (done != todo) {
            const nextStep = ns: {
                for (table) |deps, s| {
                    if (deps & ~done != 0) continue;
                    if (done & maskOf(s) != 0) continue;
                    if (allSteps & maskOf(s) == 0) continue;
                    break :ns @intCast(u8, s);
                }
                unreachable;
            };
            buf[len] = 'A' + nextStep;
            len += 1;
            done |= maskOf(nextStep);
        }
        break :ans buf[0..len];
    };

    // part2
    const ans2 = ans: {
        var workTodo: [26]u8 = undefined;
        var time: u32 = 0;
        for (workTodo) |*it, step| {
            if (allSteps & maskOf(step) != 0)
                it.* = @intCast(u8, step) + 1 + 60;
        }
        var done: u26 = 0;
        //var buf2: [32]u8 = undefined;
        //var bufLen: usize = 0;

        while (done != allSteps) {
            time += 1;

            // std.debug.print("t={}: ", .{time});
            var idleWorkers: u32 = 5;
            var doneThisStep: u26 = 0;
            for (table) |deps, s| {
                if (deps & ~done != 0) continue;
                if (done & maskOf(s) != 0) continue;
                if (allSteps & maskOf(s) == 0) continue;

                workTodo[s] -= 1;
                if (workTodo[s] == 0) {
                    doneThisStep |= maskOf(s);
                    // buf2[bufLen] = 'A' + @intCast(u8, s);
                    // bufLen += 1;
                }
                // std.debug.print("{c} ({}s), ", .{ @intCast(u8, s) + 'A', workTodo[s] });

                idleWorkers -= 1;
                if (idleWorkers == 0) break;
            }
            done |= doneThisStep;
            // std.debug.print(" => {}\n", .{buf2[0..bufLen]});
        }
        break :ans time;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{s}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2018/input_day07.txt", run);
