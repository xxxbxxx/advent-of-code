const std = @import("std");
const tools = @import("tools");

const with_trace = true;

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
    const text = try std.fs.cwd().readFileAlloc(allocator, "day16.txt", limit);
    defer allocator.free(text);

    const Move = union(enum) {
        s: u4,
        x: struct {
            a: u4,
            b: u4,
        },
        p: struct {
            a: u8,
            b: u8,
        },
    };
    var dance0: [10000]Move = undefined;
    const dance = blk: {
        var len: usize = 0;
        var it = std.mem.tokenize(u8, text, ", \n\r");
        while (it.next()) |move| {
            if (tools.match_pattern("s{}", move)) |vals| {
                const a = @as(u4, @intCast(vals[0].imm));
                dance0[len] = Move{ .s = a };
                len += 1;
            } else if (tools.match_pattern("x{}/{}", move)) |vals| {
                const a = @as(u4, @intCast(vals[0].imm));
                const b = @as(u4, @intCast(vals[1].imm));
                dance0[len] = Move{ .x = .{ .a = a, .b = b } };
                len += 1;
            } else if (tools.match_pattern("p{}/{}", move)) |vals| {
                const d1 = vals[0].name[0];
                const d2 = vals[1].name[0];
                dance0[len] = Move{ .p = .{ .a = d1, .b = d2 } };
                len += 1;
            } else {
                unreachable;
            }
        }
        break :blk dance0[0..len];
    };
    trace("the dance is {} moves long\n", .{dance.len});

    var dancers: [16]u8 = undefined;
    std.mem.copy(u8, &dancers, "abcdefghijklmnop");

    var positions = [16]u4{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 };
    var positions1 = [16]u4{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 };

    var prevmap = std.AutoHashMap([16]u8, usize).init(arena.allocator());
    _ = try prevmap.put(dancers, 0);

    var round: usize = 1;
    while (round < 1000000000) : (round += 1) {
        for (dance) |m| {
            switch (m) {
                .s => |s| {
                    std.mem.rotate(u8, &dancers, dancers.len - s);

                    {
                        for (positions) |*pos| {
                            pos.* +%= s;
                        }
                    }
                },
                .x => |x| {
                    const a = dancers[x.a];
                    const b = dancers[x.b];
                    dancers[x.b] = a;
                    dancers[x.a] = b;

                    {
                        for (positions) |*p| {
                            if (p.* == x.a) {
                                p.* = x.b;
                            } else if (p.* == x.b) {
                                p.* = x.a;
                            }
                        }
                    }
                },
                .p => |p| {
                    for (dancers) |*d| {
                        if (d.* == p.a) {
                            d.* = p.b;
                        } else if (d.* == p.b) {
                            d.* = p.a;
                        }
                    }

                    {
                        const p1 = positions[p.a - 'a'];
                        const p2 = positions[p.b - 'a'];
                        positions[p.a - 'a'] = p2;
                        positions[p.b - 'a'] = p1;
                    }
                },
            }
            if (round == 1) {
                std.mem.copy(u4, &positions1, &positions);
            }
            assert(dancers[positions['a' - 'a']] == 'a' and dancers[positions['b' - 'a']] == 'b');
        }

        if (false) {
            assert(dancers[positions['a' - 'a']] == 'a' and dancers[positions['b' - 'a']] == 'b');
            trace("postions^{}= [", .{round});
            for (positions) |pos| {
                trace("{}, ", .{pos});
            }
            trace("]\n", .{});
        }

        if (false) {
            var composed = [16]u4{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 };
            var i: usize = 0;
            while (i < round) : (i += 1) {
                for (composed) |*c| {
                    c.* = positions1[c.*];
                }
            }
            trace("composed^{}= [", .{round});
            for (composed) |pos| {
                trace("{}, ", .{pos});
            }
            trace("]\n", .{});

            assert(dancers[composed['a' - 'a']] == 'a' and dancers[composed['b' - 'a']] == 'b');
        }

        if (try prevmap.put(dancers, round)) |kv| {
            const perdiod = round - kv.value;
            trace("period={}\n", .{perdiod});
            if (1000000000 % perdiod == round % perdiod) {
                break;
            }
        }
        trace("order={}\n", .{dancers});
    }

    try stdout.print("order={}\n", .{dancers});
}
