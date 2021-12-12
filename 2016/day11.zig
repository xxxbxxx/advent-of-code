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

    const num = 7;
    const State = struct {
        elevator: u32,
        objects: [4][num * 2]bool,

        fn is_consistent(s: *const @This()) bool {
            {
                var i: u32 = 0;
                while (i < num) : (i += 1) {
                    var countm: u32 = 0;
                    var countg: u32 = 0;
                    for (s.objects) |floor| {
                        if (floor[0 + i]) countm += 1;
                        if (floor[num + i]) countg += 1;
                    }
                    if (countm != 1 or countg != 1)
                        return false;
                }
            }
            return true;
        }
        fn is_valid(s: *const @This()) bool {
            assert(s.is_consistent());
            for (s.objects) |floor| {
                var i: u32 = 0;
                while (i < num) : (i += 1) {
                    const haschip = floor[0 + i];
                    const hasgen = floor[num + i];
                    if (!haschip or hasgen)
                        continue; // safe.
                    var j: u32 = 0;
                    while (j < num) : (j += 1) {
                        if (j == i)
                            continue;
                        if (floor[num + j])
                            return false; // unshiled + other generator
                    }
                }
            }
            return true;
        }

        fn is_done(s: *const @This()) bool {
            for (s.objects[0]) |o| {
                if (!o) return false;
            }
            return true;
        }

        fn tracefloors(s: *const @This()) void {
            for (s.objects) |floor, i| {
                trace("F{} ", .{i});
                if (i == s.elevator) {
                    trace("E  ", .{});
                } else {
                    trace("   ", .{});
                }
                for (floor) |o| {
                    const char: u8 = if (o) '*' else '.';
                    trace("{c} ", .{char});
                }
                trace("\n", .{});
            }
        }

        fn floorsum(s: *const @This()) u32 {
            var sum: usize = 0;
            for (s.objects) |floor, i| {
                for (floor) |o| {
                    if (o) sum += i;
                }
            }
            return @intCast(u32, sum);
        }
    };

    const initial_state = State{
        .elevator = 3,
        .objects = .{
            //            .{ false, false, false, false },
            //            .{ false, false, false, true },
            //            .{ false, false, true, false },
            //            .{ true, true, false, false },
            //M: thu   plu    str    pro    rut    ele    dil |G: thu   plu    str    pro    rut    ele    dil
            .{ false, false, false, false, false, false, false, false, false, false, false, false, false, false },
            .{ false, false, false, true, true, false, false, false, false, false, true, true, false, false },
            .{ false, true, true, false, false, false, false, false, false, false, false, false, false, false },
            .{ true, false, false, false, false, true, true, true, true, true, false, false, true, true },
        },
    };
    assert(initial_state.is_valid());

    const BFS = tools.BestFirstSearch(State, void);
    var searcher = BFS.init(allocator);
    defer searcher.deinit();

    try searcher.insert(BFS.Node{
        .rating = 0,
        .steps = 0,
        .state = initial_state,
        .trace = {},
    });

    var trace_dep: usize = 999999;
    var best: u32 = 999999;
    while (searcher.pop()) |node| {
        if (node.state.floorsum() < trace_dep) {
            trace_dep = node.state.floorsum();
            trace("examining (floorsum={}, agenda={}, visisted={})\n", .{ trace_dep, searcher.agenda.items.len, searcher.visited.count() });
            node.state.tracefloors();
        }

        if (node.state.is_done()) {
            try stdout.print("go solution. steps={}, elevator={}, agenda={}, visisted={}\n", .{ node.steps, node.state.elevator, searcher.agenda.items.len, searcher.visited.count() });
            if (node.steps < best) {
                best = node.steps;
            }
            continue;
        }
        if (node.steps >= best)
            continue;

        var next = BFS.Node{
            .rating = node.rating + 1,
            .steps = node.steps + 1,
            .state = undefined,
            .trace = {},
        };
        const s = &node.state;
        for ([2]bool{ true, false }) |goup| {
            if (goup and s.elevator == 0) continue;
            if (!goup and s.elevator == 3) continue;
            const ns = &next.state;
            ns.elevator = if (goup) s.elevator - 1 else s.elevator + 1;

            const floor = s.objects[s.elevator];
            for (floor) |has1, obj1| {
                if (!has1)
                    continue;
                ns.objects = s.objects;
                assert(ns.is_valid());
                ns.objects[s.elevator][obj1] = false;
                ns.objects[ns.elevator][obj1] = true;
                if (ns.is_valid()) {
                    //trace("...inserting solo {}\n", .{obj1});
                    next.rating = @intCast(i32, next.steps + 3 * ns.floorsum());
                    try searcher.insert(next);
                }

                for (floor[obj1 + 1 ..]) |has2, index2| {
                    if (!has2)
                        continue;
                    const obj2 = obj1 + 1 + index2;
                    assert(ns.is_consistent());
                    ns.objects[s.elevator][obj2] = false;
                    defer ns.objects[s.elevator][obj2] = true;
                    ns.objects[ns.elevator][obj2] = true;
                    defer ns.objects[ns.elevator][obj2] = false;
                    if (ns.is_valid()) {
                        //trace("...inserting pair {},{}\n", .{ obj1, obj2 });
                        next.rating = @intCast(i32, next.steps + 3 * ns.floorsum());
                        try searcher.insert(next);
                    }
                }
            }
        }
    }

    //    try stdout.print("outputs[{}, {}, {}] = {}\n", .{ outputs[0], outputs[1], outputs[2], outputs[0] * outputs[1] * outputs[2] });
}
