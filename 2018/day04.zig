const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {

    //[1518-07-10 23:54] Guard #3167 begins shift
    //[1518-04-15 00:20] falls asleep
    //[1518-09-30 00:49] wakes up
    const Shift = struct {
        guardId: ?u32,
        tomorrowGuardId: ?u32,
        state: [60]bool,
    };
    var shifts = [1]?Shift{null} ** (31 * 12);
    var largestGuardId: ?u32 = null;
    {
        var it = std.mem.tokenize(u8, input, "\n\r");
        while (it.next()) |line| {
            var time: []const u8 = undefined;
            var awake: bool = undefined;
            var guardId: ?u32 = null;
            if (tools.match_pattern("[{}] wakes up", line)) |fields| {
                time = fields[0].lit;
                awake = true;
            } else if (tools.match_pattern("[{}] falls asleep", line)) |fields| {
                time = fields[0].lit;
                awake = false;
            } else if (tools.match_pattern("[{}] Guard #{} begins shift", line)) |fields| {
                time = fields[0].lit;
                guardId = @intCast(u32, fields[1].imm);
            } else {
                std.debug.print("could not parse '{s}'\n", .{line});
                return error.UnsupportedInput;
            }

            const fields = tools.match_pattern("1518-{}-{} {}:{}", time) orelse unreachable;
            const month = @intCast(u32, fields[0].imm);
            const day = @intCast(u32, fields[1].imm);
            const hour = @intCast(u32, fields[2].imm);
            const minutes = @intCast(u32, fields[3].imm);

            // std.debug.print("shift: guard={}  day={}-{} mn={}\n", .{ guardId.?, month, day, minutes });

            if (shifts[month * 31 + day] == null) { // new day?
                shifts[month * 31 + day] = Shift{ .guardId = null, .state = [_]bool{true} ** 60, .tomorrowGuardId = null };
            }
            const shift = &shifts[month * 31 + day].?;

            if (guardId) |id| {
                if (largestGuardId == null or largestGuardId.? < guardId.?)
                    largestGuardId = guardId;
                if (hour > 12) {
                    assert(shift.tomorrowGuardId == null);
                    shift.tomorrowGuardId = id;
                } else {
                    assert(shift.guardId == null);
                    shift.guardId = id;
                }
            } else {
                // suppose que les données sont cohérentes (ie commence reveillé et de ne reveille pas deux fois de suite, mais desordonéees)
                var i = minutes;
                while (i < 60) : (i += 1) {
                    shift.state[i] = !shift.state[i];
                }
            }
        }

        // ajustement: met les guardes arrivés en avance sur les bons jours
        var lastGuardId: ?u32 = null;
        for (shifts) |_, i| {
            if (shifts[i]) |*s| {
                if (s.guardId == null) {
                    s.guardId = lastGuardId;
                }
                if (s.tomorrowGuardId != null) {
                    lastGuardId = s.tomorrowGuardId;
                    s.tomorrowGuardId = null;
                } else {
                    lastGuardId = s.guardId;
                }
                assert(lastGuardId != null);
            }
        }
    }

    // part1
    const ans1 = ans: {
        const guardIdMostAsleep = mostasleep: {
            const sleepTimes = try allocator.alloc(u32, largestGuardId.? + 1);
            defer allocator.free(sleepTimes);
            std.mem.set(u32, sleepTimes, 0);
            for (shifts) |shift| {
                if (shift) |s| {
                    for (s.state) |awake| {
                        if (!awake)
                            sleepTimes[s.guardId.?] += 1;
                    }
                }
            }

            var id: usize = undefined;
            var longuest: u32 = 0;
            for (sleepTimes) |time, i| {
                if (time > longuest) {
                    longuest = time;
                    id = i;
                }
            }
            assert(longuest > 0);
            break :mostasleep id;
        };

        const minuteMostAsleep = mostasleep: {
            var counts = [1]u32{0} ** 60;
            for (shifts) |shift| {
                if (shift == null or shift.?.guardId.? != guardIdMostAsleep)
                    continue;
                for (shift.?.state) |awake, i| {
                    if (!awake) counts[i] += 1;
                }
            }

            var best: usize = undefined;
            var best_count: u32 = 0;
            for (counts) |c, i| {
                if (c > best_count) {
                    best_count = c;
                    best = i;
                }
            }
            assert(best_count > 0);
            break :mostasleep best;
        };
        break :ans guardIdMostAsleep * minuteMostAsleep;
    };

    // part2
    //var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    //defer arena.deinit();
    const ans2 = ans: {
        const sleepMinutes = try allocator.alloc([60]u16, (largestGuardId.? + 1));
        defer allocator.free(sleepMinutes);
        std.mem.set([60]u16, sleepMinutes, [1]u16{0} ** 60);

        for (shifts) |shift| {
            if (shift) |s| {
                for (s.state) |awake, i| {
                    if (!awake) {
                        sleepMinutes[s.guardId.?][i] += 1;
                    }
                }
            }
        }

        var bestGuardId: usize = undefined;
        var bestMinute: usize = undefined;
        var bestNum: u16 = 0;
        for (sleepMinutes) |sm, guardId| {
            for (sm) |num, minute| {
                if (num > bestNum) {
                    bestNum = num;
                    bestGuardId = guardId;
                    bestMinute = minute;
                }
            }
        }

        break :ans bestMinute * bestGuardId;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2018/input_day04.txt", run);
