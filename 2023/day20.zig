const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub const main = tools.defaultMain("2023/day20.txt", run);

const Connection = struct {
    module: u8,
    port: u8,
};
const Module = union(enum) {
    flipflop: struct {
        state: bool,
        conns: []const Connection,
    },
    conjunction: struct {
        inputs: []bool,
        conns: []const Connection,
    },
    broadcaster: struct {
        conns: []const Connection,
    },
    none: void,
};

pub fn run(text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena_alloc = std.heap.ArenaAllocator.init(allocator);
    defer arena_alloc.deinit();
    const arena = arena_alloc.allocator();

    const modules, const names = input: {
        var mods = std.StringArrayHashMap(struct { Module, u8 }).init(allocator);
        defer mods.deinit();
        try mods.put("broadcaster", .{ .{ .none = {} }, 0 }); // at index zero

        var it = std.mem.tokenize(u8, text, "\n\r\t");
        while (it.next()) |line| {
            if (tools.match_pattern("broadcaster -> {}", line)) |vals| {
                var conns = std.ArrayList(Connection).init(arena);
                defer conns.deinit();
                var it2 = std.mem.tokenize(u8, vals[0].lit, ", ");
                while (it2.next()) |name| {
                    const m = try mods.getOrPut(name);
                    if (!m.found_existing) m.value_ptr.* = .{ .{ .none = {} }, 0 };
                    try conns.append(.{ .module = @intCast(m.index), .port = m.value_ptr[1] });
                    m.value_ptr[1] += 1;
                }

                const m = try mods.getOrPut("broadcaster");
                assert(m.found_existing);
                m.value_ptr[0] = .{ .broadcaster = .{ .conns = try conns.toOwnedSlice() } };
            } else if (tools.match_pattern("%{} -> {}", line)) |vals| {
                var conns = std.ArrayList(Connection).init(arena);
                defer conns.deinit();
                var it2 = std.mem.tokenize(u8, vals[1].lit, ", ");
                while (it2.next()) |name| {
                    const m = try mods.getOrPut(name);
                    if (!m.found_existing) m.value_ptr.* = .{ .{ .none = {} }, 0 };
                    try conns.append(.{ .module = @intCast(m.index), .port = m.value_ptr[1] });
                    m.value_ptr[1] += 1;
                }

                const m = try mods.getOrPut(vals[0].lit);
                if (!m.found_existing) m.value_ptr[1] = 0;
                m.value_ptr[0] = .{ .flipflop = .{ .state = false, .conns = try conns.toOwnedSlice() } };
            } else if (tools.match_pattern("&{} -> {}", line)) |vals| {
                var conns = std.ArrayList(Connection).init(arena);
                defer conns.deinit();
                var it2 = std.mem.tokenize(u8, vals[1].lit, ", ");
                while (it2.next()) |name| {
                    const m = try mods.getOrPut(name);
                    if (!m.found_existing) m.value_ptr.* = .{ .{ .none = {} }, 0 };
                    try conns.append(.{ .module = @intCast(m.index), .port = m.value_ptr[1] });
                    m.value_ptr[1] += 1;
                }

                const m = try mods.getOrPut(vals[0].lit);
                if (!m.found_existing) m.value_ptr[1] = 0;
                m.value_ptr[0] = .{ .conjunction = .{ .inputs = &[0]bool{}, .conns = try conns.toOwnedSlice() } };
            } else unreachable;
        }

        const list = try arena.alloc(Module, mods.values().len);
        for (mods.values(), list) |t, *module| {
            module.* = t[0];
            switch (module.*) {
                .none, .flipflop, .broadcaster => {},
                .conjunction => |*m| {
                    m.inputs = try arena.alloc(bool, t[1]);
                },
            }
        }

        var all_names = std.StringArrayHashMap(void).init(arena);
        for (mods.keys()) |k| {
            try all_names.put(k, {});
        }

        break :input .{ list, all_names };
    };

    const ans1 = ans: {
        // clear state
        for (modules) |*module| {
            switch (module.*) {
                .none, .broadcaster => {},
                .flipflop => |*m| {
                    m.state = false;
                },
                .conjunction => |*m| {
                    @memset(m.inputs, false);
                },
            }
        }

        var lo_count: u64 = 0;
        var hi_count: u64 = 0;
        var signals = std.ArrayList(struct { Connection, bool }).init(allocator);
        defer signals.deinit();
        for (0..1000) |_| {
            try signals.append(.{ .{ .module = 0, .port = 0 }, false });
            lo_count += 1;
            while (signals.items.len > 0) {
                const conn, const in = signals.orderedRemove(0);

                const mod = &modules[conn.module];
                const conns, const out = switch (mod.*) {
                    .broadcaster => |*m| .{ m.conns, in },
                    .flipflop => |*m| out: {
                        if (!in) {
                            m.state = !m.state;
                            break :out .{ m.conns, m.state };
                        } else {
                            break :out .{ &[0]Connection{}, false };
                        }
                    },
                    .conjunction => |*m| out: {
                        m.inputs[conn.port] = in;
                        const all = for (m.inputs) |i| {
                            if (!i) break false;
                        } else true;
                        break :out .{ m.conns, !all };
                    },
                    .none => .{ &[0]Connection{}, false },
                };

                for (conns) |c| {
                    try signals.append(.{ c, out });
                }
                if (out) {
                    hi_count += conns.len;
                } else {
                    lo_count += conns.len;
                }
            }
        }

        break :ans hi_count * lo_count;
    };

    const ans2 = ans: {
        // clear state
        for (modules) |*module| {
            switch (module.*) {
                .none, .broadcaster => {},
                .flipflop => |*m| {
                    m.state = false;
                },
                .conjunction => |*m| {
                    @memset(m.inputs, false);
                },
            }
        }

        const module_df = if (names.getIndex("rx")) |module_rx| blk: {
            assert(modules[module_rx] == .none);
            var unique_input: ?usize = null;
            for (modules, 0..) |module, i| {
                const conns = switch (module) {
                    .none => &[0]Connection{},
                    inline else => |m| m.conns,
                };
                for (conns) |c| {
                    if (c.module == module_rx) {
                        assert(unique_input == null);
                        unique_input = i;
                    }
                }
            }
            break :blk unique_input.?;
        } else break :ans 0;
        assert(module_df == names.getIndex("df").?); // c'est comme ça dans mon input...

        const modules_count = names.keys().len;
        const probe_pulses = 10000; // nombre d'appuis pour mesurer et detecter les boucles.
        var pool = try allocator.alloc(u8, modules_count * probe_pulses);
        defer allocator.free(pool);
        const history_counters_to_df = try allocator.alloc([]u8, probe_pulses);
        defer allocator.free(history_counters_to_df);
        for (history_counters_to_df, 0..) |*it, i| it.* = pool[modules_count * i .. modules_count * (1 + i)];

        var signals = std.ArrayList(struct { Connection, bool }).init(allocator);
        defer signals.deinit();
        var pulses: usize = 0;

        while (pulses < probe_pulses) : (pulses += 1) {
            try signals.append(.{ .{ .module = 0, .port = 0 }, false });
            const counters_to_df = history_counters_to_df[pulses];
            @memset(counters_to_df, 0);
            while (signals.items.len > 0) {
                const conn, const in = signals.orderedRemove(0);
                const mod = &modules[conn.module];
                const conns, const out = switch (mod.*) {
                    .broadcaster => |*m| .{ m.conns, in },
                    .flipflop => |*m| out: {
                        if (!in) {
                            m.state = !m.state;
                            break :out .{ m.conns, m.state };
                        } else {
                            break :out .{ &[0]Connection{}, false };
                        }
                    },
                    .conjunction => |*m| out: {
                        m.inputs[conn.port] = in;
                        const all = for (m.inputs) |i| {
                            if (!i) break false;
                        } else true;
                        break :out .{ m.conns, !all };
                    },
                    .none => .{ &[0]Connection{}, false },
                };

                for (conns) |c| {
                    try signals.append(.{ c, out });
                    if (c.module == module_df) {
                        //assert(!out);  bon c'et toujours la même valeur par module, j'ai la flemme de tracker les deux states...
                        counters_to_df[conn.module] += 1;
                    }
                }
            }

            //std.debug.print("pulse n°{} -> to_df={any}\n", .{pulses, counters_to_df});
        }

        // detect cycles
        var total_pulses: u64 = 1;
        next_module: for (0..modules_count) |m| {
            for (1..probe_pulses) |period| {
                next_offset: for (0..period) |offset| {
                    var i = offset;
                    while (i + period < probe_pulses) : (i += 1) {
                        if (history_counters_to_df[i][m] != history_counters_to_df[i + period][m]) continue :next_offset;
                    }
                    // std.debug.print("module n°{}: period={}, offet={}\n", .{m, period, offset});
                    assert(offset == 0); // nice!
                    total_pulses = tools.ppcm(total_pulses, period);

                    continue :next_module;
                }
            } else {
                //std.debug.print("module n°{}: NO CYCLE\n", .{m});
                unreachable;
            }
        }

        break :ans total_pulses;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

test {
    const res1 = try run(
        \\broadcaster -> a, b, c
        \\%a -> b
        \\%b -> c
        \\%c -> inv
        \\&inv -> a
    , std.testing.allocator);
    defer std.testing.allocator.free(res1[0]);
    defer std.testing.allocator.free(res1[1]);
    try std.testing.expectEqualStrings("32000000", res1[0]);
    try std.testing.expectEqualStrings("0", res1[1]);

    const res2 = try run(
        \\%a -> inv, con
        \\broadcaster -> a
        \\&inv -> b
        \\%b -> con
        \\&con -> output
    , std.testing.allocator);
    defer std.testing.allocator.free(res2[0]);
    defer std.testing.allocator.free(res2[1]);
    try std.testing.expectEqualStrings("11687500", res2[0]);
    try std.testing.expectEqualStrings("0", res2[1]);
}
