const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

const Vec2 = tools.Vec2;

pub fn run(input_text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const param: struct {
        depth: u32,
        target: Vec2,
    } = param: {
        var depth: ?u32 = null;
        var target: ?Vec2 = null;

        var it = std.mem.tokenize(u8, input_text, "\n\r");
        while (it.next()) |line| {
            if (tools.match_pattern("depth: {}", line)) |fields| {
                depth = @intCast(u32, fields[0].imm);
            } else if (tools.match_pattern("target: {},{}", line)) |fields| {
                target = Vec2{ .x = @intCast(i32, fields[0].imm), .y = @intCast(i32, fields[1].imm) };
            } else unreachable;
        }
        break :param .{ .depth = depth.?, .target = target.? };
    };

    var map = tools.Map(u16, 512, 2048, false){ .default_tile = 0 };
    {
        var p = Vec2{ .x = 0, .y = 0 };
        while (p.y <= 2000) : (p.y += 1) {
            p.x = 0;
            while (p.x <= 500) : (p.x += 1) {
                const geo_idx: i32 = blk: {
                    if (p.y == 0) break :blk p.x * 16807;
                    if (p.x == 0) break :blk p.y * 48271;
                    if (p.eq(param.target)) break :blk 0;
                    break :blk @intCast(i32, map.at(p.add(Vec2{ .x = -1, .y = 0 }))) * @intCast(i32, map.at(p.add(Vec2{ .x = 0, .y = -1 })));
                };
                const level = (@intCast(u32, geo_idx) + param.depth) % 20183;
                map.set(p, @intCast(u16, level));
            }
        }
    }

    const ans1 = ans: {
        var sum: i32 = 0;
        var it = map.iter(tools.BBox{ .min = Vec2{ .x = 0, .y = 0 }, .max = param.target });
        while (it.next()) |region| {
            sum += region % 3;
        }
        // std.debug.print("checksum: {}\n", .{sum});
        break :ans sum;
    };

    const ans2 = ans: {
        const Tool = enum { neither, climbing_gear, torch };
        const State = struct { p: Vec2, tool: Tool };
        const BFS = tools.BestFirstSearch(State, void);
        var bfs = BFS.init(allocator);
        defer bfs.deinit();

        const init_state = State{ .p = Vec2{ .x = 0, .y = 0 }, .tool = .torch };
        try bfs.insert(BFS.Node{ .state = init_state, .cost = 0, .rating = 0, .trace = {} });

        var best_steps: u32 = 2000;
        while (bfs.pop()) |cur| {
            if (Vec2.eq(cur.state.p, param.target) and cur.state.tool == .torch) { // goal!
                if (best_steps >= cur.cost) {
                    // std.debug.print("new best: {}, agendalen:{}\n", .{ cur.cost, bfs.agenda.count() });
                    best_steps = cur.cost;
                }
                continue;
            }

            if (cur.cost + 7 < best_steps) {
                var next = cur;
                const region = map.at(cur.state.p) % 3;
                const allowed_tools = switch (region) {
                    //rocky
                    0 => &[_]Tool{ .climbing_gear, .torch },
                    //wet
                    1 => &[_]Tool{ .climbing_gear, .neither },
                    //narrow
                    2 => &[_]Tool{ .torch, .neither },
                    else => unreachable,
                };
                for (allowed_tools) |tool| {
                    if (tool != cur.state.tool) {
                        next.state.tool = tool;
                        next.state.p = cur.state.p;
                        next.cost = cur.cost + 7;
                        next.rating = @intCast(i32, Vec2.dist(next.state.p, param.target) * 1 + next.cost);
                        try bfs.insert(next);
                    }
                }
            }

            if (cur.cost + 1 < best_steps) {
                var next = cur;
                for (Vec2.cardinal_dirs) |dir| {
                    const next_p = cur.state.p.add(dir);
                    if (next_p.x < 0 or next_p.y < 0) continue;
                    const next_region = (map.get(next_p) orelse continue) % 3;
                    const allowed_tools = switch (next_region) {
                        //rocky
                        0 => &[_]Tool{ .climbing_gear, .torch },
                        //wet
                        1 => &[_]Tool{ .climbing_gear, .neither },
                        //narrow
                        2 => &[_]Tool{ .torch, .neither },
                        else => unreachable,
                    };
                    if (std.mem.indexOfScalar(Tool, allowed_tools, cur.state.tool) == null) continue;
                    next.state.tool = cur.state.tool;
                    next.state.p = next_p;
                    next.cost = cur.cost + 1;
                    next.rating = @intCast(i32, Vec2.dist(next.state.p, param.target) * 1 + next.cost);
                    try bfs.insert(next);
                }
            }
        }
        break :ans best_steps; // 2559 too high
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2018/input_day22.txt", run);
