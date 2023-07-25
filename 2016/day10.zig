const std = @import("std");
const tools = @import("tools");

const with_trace = false;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day10.txt", limit);
    defer allocator.free(text);

    const Dest = union(enum) {
        output: u32,
        bot: u32,
    };
    const Bot = struct {
        val: [2]?u32 = [2]?u32{ null, null },
        low: ?Dest = null,
        hi: ?Dest = null,
    };

    var bots = [1]Bot{.{}} ** 250;
    var bot_count: u32 = 0;
    {
        var it = std.mem.tokenize(u8, text, "\n");
        while (it.next()) |line| {
            const parse = tools.match_pattern;
            if (parse("value {} goes to bot {}", line)) |vals| {
                trace("value-{}  -> bot{}\n", .{ vals[0], vals[1] });
                const bot = &bots[vals[1]];
                if (bot.val[0] == null) {
                    bot.val[0] = vals[0];
                } else {
                    assert(bot.val[1] == null);
                    bot.val[1] = vals[0];
                }
            } else if (parse("bot {} gives low to bot {} and high to bot {}", line)) |vals| {
                trace("bot{} -> bot{},bot{}\n", .{ vals[0], vals[1], vals[2] });
                const bot = &bots[vals[0]];
                assert(bot.low == null and bot.hi == null);
                bot.low = .{ .bot = vals[1] };
                bot.hi = .{ .bot = vals[2] };
            } else if (parse("bot {} gives low to output {} and high to bot {}", line)) |vals| {
                trace("bot{} -> out{},bot{}\n", .{ vals[0], vals[1], vals[2] });
                const bot = &bots[vals[0]];
                assert(bot.low == null and bot.hi == null);
                bot.low = .{ .output = vals[1] };
                bot.hi = .{ .bot = vals[2] };
            } else if (parse("bot {} gives low to output {} and high to output {}", line)) |vals| {
                trace("bot{} -> out{},out{}\n", .{ vals[0], vals[1], vals[2] });
                const bot = &bots[vals[0]];
                assert(bot.low == null and bot.hi == null);
                bot.low = .{ .output = vals[1] };
                bot.hi = .{ .output = vals[2] };
            } else if (parse("bot {} gives low to bot {} and high to output {}", line)) |vals| {
                trace("bot{} -> bot{},bot{}\n", .{ vals[0], vals[1], vals[2] });
                const bot = &bots[vals[0]];
                assert(bot.low == null and bot.hi == null);
                bot.low = .{ .bot = vals[1] };
                bot.hi = .{ .output = vals[2] };
            } else {
                trace("can't parse: '{}'", .{line});
                unreachable;
            }
        }
    }

    var outputs: [1000]u32 = undefined;
    var changed = true;
    while (changed) {
        changed = false;
        for (bots, 0..) |*bot, ibot| {
            if (bot.val[0]) |v0| {
                if (bot.val[1]) |v1| {
                    changed = true;
                    assert(bot.low != null and bot.hi != null);
                    const vlow = if (v0 < v1) v0 else v1;
                    const vhi = if (v0 >= v1) v0 else v1;
                    if (vlow == 17 and vhi == 61)
                        try stdout.print("bot n°{} is doing the compare\n", .{ibot});

                    switch (bot.low.?) {
                        .output => |o| {
                            trace("bot n°{} puts val-{} to output{}\n", .{ ibot, vlow, o });
                            outputs[o] = vlow;
                        },
                        .bot => |b| {
                            trace("bot n°{} gives val-{} to bot n°{}\n", .{ ibot, vlow, b });
                            const to = &bots[b];
                            if (to.val[0] == null) {
                                to.val[0] = vlow;
                            } else {
                                assert(to.val[1] == null);
                                to.val[1] = vlow;
                            }
                        },
                    }
                    bot.val[0] = null;
                    switch (bot.hi.?) {
                        .output => |o| {
                            trace("bot n°{} puts val-{} to output{}\n", .{ ibot, vhi, o });
                            outputs[o] = vhi;
                        },
                        .bot => |b| {
                            trace("bot n°{} gives val-{} to bot n°{}\n", .{ ibot, vhi, b });
                            const to = &bots[b];
                            if (to.val[0] == null) {
                                to.val[0] = vhi;
                            } else {
                                assert(to.val[1] == null);
                                to.val[1] = vhi;
                            }
                        },
                    }
                    bot.val[1] = null;
                }
            }
        }
    }

    try stdout.print("outputs[{}, {}, {}] = {}\n", .{ outputs[0], outputs[1], outputs[2], outputs[0] * outputs[1] * outputs[2] });
}
