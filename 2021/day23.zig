const std = @import("std");
const tools = @import("tools");

const with_trace = false;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}
const assert = std.debug.assert;

pub const main = tools.defaultMain("2021/day23.txt", run);

pub fn run(input: []const u8, gpa: std.mem.Allocator) tools.RunError![2][]const u8 {

    // positions:
    //#############
    //#abcdefghijk#
    //###l#m#n#o###
    //  #p#q#r#s#
    //  #t#u#v#w#
    //  #x#y#z#{#
    //  #########
    const Position = u8;
    const all_positions_1 = [_]Position{ 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's' };
    const all_positions_2 = [_]Position{ 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', '{' };

    const canonical_paths = [_][]const Position{
        "abclptx", "abcdemquy", "abcdefgnrvz", "abcdefghiosw{", // chemins possibles depuis 'a' + retours
        "kjiosw{", "kjihgnrvz", "kjihgfemquy", "kjihgfedclptx", // chemins possibles depuis 'k' + retours
        "xtplcdemquy", "xtplcdefgnrvz", "xtplcdefghiosw{", // chemins possibles depuis 'p' + retours
        "yuqmefgnrvz", "yuqmefghiosw{", // chemins possibles depuis 'q' + retours
        "zvrnghiosw{", // chemins possibles depuis 'r' + retours
    };

    const no_parking_zones: []const Position = "cegi";
    const target_zone = [4][2]Position{
        .{ 'l', 'p' },
        .{ 'm', 'q' },
        .{ 'n', 'r' },
        .{ 'o', 's' },
    };
    const target_zone_2 = [4][4]Position{
        .{ 'l', 'p', 't', 'x' },
        .{ 'm', 'q', 'u', 'y' },
        .{ 'n', 'r', 'v', 'z' },
        .{ 'o', 's', 'w', '{' },
    };

    const paths_matrix = comptime blk: {
        @setEvalBranchQuota(80000);
        var paths: [all_positions_2.len][all_positions_2.len][]const Position = undefined;
        for (all_positions_2) |from, i| {
            assert(from == i + 'a');
            const from_is_rooom = (from >= 'l');

            for (all_positions_2) |to, j| {
                const to_is_rooom = (to >= 'l');

                paths[i][j] = &[0]Position{};
                if (from == to) continue;

                // "in the hallway, it will stay in that spot until it can move into a room"
                if (!to_is_rooom and !from_is_rooom) continue;

                // "never stop on the space immediately outside any room."
                if (std.mem.indexOfScalar(Position, no_parking_zones, from) != null) continue;
                if (std.mem.indexOfScalar(Position, no_parking_zones, to) != null) continue;

                for (canonical_paths) |p| {
                    if (std.mem.indexOfScalar(Position, p, from)) |idx_from| {
                        if (std.mem.indexOfScalar(Position, p[idx_from..], to)) |len_to| {
                            const path = p[idx_from + 1 .. idx_from + len_to + 1];
                            paths[i][j] = path;
                        }
                    }
                    if (std.mem.indexOfScalar(Position, p, to)) |idx_to| {
                        if (std.mem.indexOfScalar(Position, p[idx_to..], from)) |len_from| {
                            const path = p[idx_to .. idx_to + len_from];
                            paths[i][j] = path;
                        }
                    }
                }
            }
        }
        break :blk paths;
    };

    const move_energy_cost = [4]u32{ 1, 10, 100, 1000 };

    const StateBuilder = struct {
        fn State(room_sz: u32) type {
            return struct {
                amphipods: [4][room_sz]Position,
                fn distanceToTarget(s: @This()) u32 {
                    var distance: u32 = 0;
                    for (s.amphipods) |pair, i| {
                        for (pair) |pos| {
                            if (pos == target_zone[i][0] or pos == target_zone[i][1] or pos == target_zone_2[i][2] or pos == target_zone_2[i][3]) continue;
                            const d = @intCast(u32, paths_matrix[pos - 'a'][target_zone[i][0] - 'a'].len);
                            distance += move_energy_cost[i] * d;
                        }
                    }
                    return distance;
                }
                fn isFree(s: @This(), p: Position) bool {
                    for (s.amphipods) |pair| {
                        for (pair) |pos| {
                            if (pos == p) return false;
                        }
                    }
                    return true;
                }
            };
        }
    };

    const State_1 = StateBuilder.State(2);
    const initial_state = blk: {
        var state = State_1{ .amphipods = undefined };
        var pop = [4]u2{ 0, 0, 0, 0 };

        var it = std.mem.tokenize(u8, input, "\n");
        if (tools.match_pattern("#############", it.next().?) == null) return error.UnsupportedInput;
        if (tools.match_pattern("#...........#", it.next().?) == null) return error.UnsupportedInput;
        if (tools.match_pattern("###{}#{}#{}#{}###", it.next().?)) |val| {
            state.amphipods[val[0].lit[0] - 'A'][pop[val[0].lit[0] - 'A']] = target_zone[0][0];
            pop[val[0].lit[0] - 'A'] += 1;
            state.amphipods[val[1].lit[0] - 'A'][pop[val[1].lit[0] - 'A']] = target_zone[1][0];
            pop[val[1].lit[0] - 'A'] += 1;
            state.amphipods[val[2].lit[0] - 'A'][pop[val[2].lit[0] - 'A']] = target_zone[2][0];
            pop[val[2].lit[0] - 'A'] += 1;
            state.amphipods[val[3].lit[0] - 'A'][pop[val[3].lit[0] - 'A']] = target_zone[3][0];
            pop[val[3].lit[0] - 'A'] += 1;
        } else {
            return error.UnsupportedInput;
        }
        if (tools.match_pattern("#{}#{}#{}#{}#", it.next().?)) |val| {
            state.amphipods[val[0].lit[0] - 'A'][pop[val[0].lit[0] - 'A']] = target_zone[0][1];
            pop[val[0].lit[0] - 'A'] += 1;
            state.amphipods[val[1].lit[0] - 'A'][pop[val[1].lit[0] - 'A']] = target_zone[1][1];
            pop[val[1].lit[0] - 'A'] += 1;
            state.amphipods[val[2].lit[0] - 'A'][pop[val[2].lit[0] - 'A']] = target_zone[2][1];
            pop[val[2].lit[0] - 'A'] += 1;
            state.amphipods[val[3].lit[0] - 'A'][pop[val[3].lit[0] - 'A']] = target_zone[3][1];
            pop[val[3].lit[0] - 'A'] += 1;
        } else {
            return error.UnsupportedInput;
        }
        if (tools.match_pattern("#########", it.next().?) == null) return error.UnsupportedInput;
        break :blk state;
    };

    const ans1 = ans: {
        var arena_alloc = std.heap.ArenaAllocator.init(gpa);
        defer arena_alloc.deinit();
        const arena = arena_alloc.allocator(); // for traces

        const Bfs = tools.BestFirstSearch(State_1, []u8);
        var bfs = Bfs.init(gpa);
        defer bfs.deinit();
        try bfs.insert(Bfs.Node{
            .rating = 0,
            .steps = 0,
            .state = initial_state,
            .trace = "",
        });

        var best_dist: u32 = 100000;
        var best_energy: u32 = 100000;
        while (bfs.pop()) |n| {
            if (n.steps >= best_energy) continue;
            if (n.rating > best_energy) continue;

            const d = n.state.distanceToTarget();
            if (d == 0) {
                if (best_energy > n.steps) {
                    best_energy = n.steps;
                    trace("solution: {d} {s}\n", .{ n.steps, n.trace });
                }
                continue;
            }
            if (d < best_dist) {
                best_dist = d;
                trace("best so far...: d={}, e={} {s}\n", .{ d, n.steps, n.trace });
            }

            for (n.state.amphipods) |pair, i| {
                for (pair) |from, j| {
                    for (all_positions_1) |to| {
                        const to_is_room = (to >= 'l');

                        const path = paths_matrix[from - 'a'][to - 'a'];
                        if (path.len == 0) continue;

                        if (to_is_room) {
                            // "never move from the hallway into a room unless that room is their destination room..."
                            // "... and that room contains no amphipods which do not also have that room as their own destination"
                            const ok = good_room: for (target_zone[i]) |zone, room_idx| {
                                if (zone == to) {
                                    for (target_zone[i]) |zone2, room_idx2| {
                                        if (room_idx2 <= room_idx) {
                                            if (!n.state.isFree(zone2)) break :good_room false;
                                        } else {
                                            const is_friend = for (pair) |friend| {
                                                if (friend == zone2) break true;
                                            } else false;
                                            if (!is_friend) break :good_room false;
                                        }
                                    }
                                    break true;
                                }
                            } else false;
                            if (!ok) continue;

                            // // "never move from the hallway into a room unless that room is their destination room..."
                            // if (to != target_zone[i][0] and to != target_zone[i][1]) continue;
                            // // "... and that room contains no amphipods which do not also have that room as their own destination"
                            // if (to == target_zone[i][0] and n.state.isFree(target_zone[i][1])) continue;
                            // if (to == target_zone[i][0] and pair[1 - j] != target_zone[i][1]) continue;
                            // if (to == target_zone[i][1] and !n.state.isFree(target_zone[i][0])) continue;
                        }

                        // moving into an unoccupied open space
                        assert(path[0] == to or path[path.len - 1] == to);
                        const is_free = for (path) |p| {
                            if (!n.state.isFree(p)) break false;
                        } else true;
                        if (!is_free) continue;

                        const new_energy = n.steps + @intCast(u32, path.len * move_energy_cost[i]);
                        if (new_energy >= best_energy) continue;

                        var new = n;
                        new.state.amphipods[i][j] = to;
                        new.steps = new_energy;
                        new.rating = @intCast(i32, new_energy + new.state.distanceToTarget());
                        if (new.rating > best_energy) continue;

                        if (with_trace)
                            new.trace = try std.fmt.allocPrint(arena, "{s},{c}:{c}->{c}", .{ n.trace, @intCast(u8, i + 'A'), from, to });
                        try bfs.insert(new);
                    }
                }
            }
        }
        break :ans best_energy;
    };

    const State_2 = StateBuilder.State(4);
    const initial_state_2 = blk: {
        var state: State_2 = undefined;

        for (initial_state.amphipods) |pair, i| {
            state.amphipods[i][0] = if (pair[0] < 'p') pair[0] else pair[0] + ('x' - 'p');
            state.amphipods[i][1] = if (pair[1] < 'p') pair[1] else pair[1] + ('x' - 'p');
        }

        //  #p#q#r#s#
        //  #t#u#v#w#
        //  #D#C#B#A#
        //  #D#B#A#C#
        state.amphipods[0][2] = 's';
        state.amphipods[0][3] = 'v';
        state.amphipods[1][2] = 'r';
        state.amphipods[1][3] = 'u';
        state.amphipods[2][2] = 'w';
        state.amphipods[2][3] = 'q';
        state.amphipods[3][2] = 'p';
        state.amphipods[3][3] = 't';

        break :blk state;
    };
    trace("init1= {}\n", .{initial_state});
    trace("init2= {}\n", .{initial_state_2});

    const ans2 = ans: {
        var arena_alloc = std.heap.ArenaAllocator.init(gpa);
        defer arena_alloc.deinit();
        const arena = arena_alloc.allocator(); // for traces

        const Bfs = tools.BestFirstSearch(State_2, []u8);
        var bfs = Bfs.init(gpa);
        defer bfs.deinit();
        try bfs.insert(Bfs.Node{
            .rating = 0,
            .steps = 0,
            .state = initial_state_2,
            .trace = "",
        });

        var best_dist: u32 = 100000;
        var best_energy: u32 = 100000;
        while (bfs.pop()) |n| {
            if (n.steps >= best_energy) continue;
            if (n.rating > best_energy) continue;

            const d = n.state.distanceToTarget();
            if (d == 0) {
                if (best_energy > n.steps) {
                    best_energy = n.steps;
                    trace("solution: {d} {s}\n", .{ n.steps, n.trace });
                }
                continue;
            }
            if (d < best_dist) {
                best_dist = d;
                trace("best so far...: d={}, e={} {s}\n", .{ d, n.steps, n.trace });
            }

            for (n.state.amphipods) |pair, i| {
                for (pair) |from, j| {
                    for (all_positions_2) |to| {
                        const to_is_room = (to >= 'l');

                        const path = paths_matrix[from - 'a'][to - 'a'];
                        if (path.len == 0) continue;

                        if (to_is_room) {
                            // "never move from the hallway into a room unless that room is their destination room..."
                            // "... and that room contains no amphipods which do not also have that room as their own destination"
                            const ok = good_room: for (target_zone_2[i]) |zone, room_idx| {
                                if (zone == to) {
                                    for (target_zone_2[i]) |zone2, room_idx2| {
                                        if (room_idx2 <= room_idx) {
                                            if (!n.state.isFree(zone2)) break :good_room false;
                                        } else {
                                            const is_friend = for (pair) |friend| {
                                                if (friend == zone2) break true;
                                            } else false;
                                            if (!is_friend) break :good_room false;
                                        }
                                    }
                                    break true;
                                }
                            } else false;
                            if (!ok) continue;
                        }

                        // moving into an unoccupied open space
                        assert(path[0] == to or path[path.len - 1] == to);
                        const is_free = for (path) |p| {
                            if (!n.state.isFree(p)) break false;
                        } else true;
                        if (!is_free) continue;

                        const new_energy = n.steps + @intCast(u32, path.len * move_energy_cost[i]);
                        if (new_energy >= best_energy) continue;

                        var new = n;
                        new.state.amphipods[i][j] = to;
                        new.steps = new_energy;
                        new.rating = @intCast(i32, new_energy + new.state.distanceToTarget());
                        if (with_trace)
                            new.trace = try std.fmt.allocPrint(arena, "{s},{c}:{c}->{c}", .{ n.trace, @intCast(u8, i + 'A'), from, to });
                        if (new.rating > best_energy) continue;

                        try bfs.insert(new);
                    }
                }
            }
        }
        break :ans best_energy;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(gpa, "{}", .{ans1}),
        try std.fmt.allocPrint(gpa, "{}", .{ans2}),
    };
}

test {
    if (false) {
        const res = try run(
            \\#############
            \\#...........#
            \\###A#B#C#D###
            \\  #A#B#C#D#
            \\  #########
        , std.testing.allocator);
        defer std.testing.allocator.free(res[0]);
        defer std.testing.allocator.free(res[1]);
        try std.testing.expectEqualStrings("0", res[0]);
        try std.testing.expectEqualStrings("0", res[1]);
    }
    if (false) {
        const res = try run(
            \\#############
            \\#...........#
            \\###B#A#C#D###
            \\  #A#B#C#D#
            \\  #########
        , std.testing.allocator);
        defer std.testing.allocator.free(res[0]);
        defer std.testing.allocator.free(res[1]);
        try std.testing.expectEqualStrings("46", res[0]);
        try std.testing.expectEqualStrings("0", res[1]);
    }
    {
        const res = try run(
            \\#############
            \\#...........#
            \\###B#C#B#D###
            \\  #A#D#C#A#
            \\  #########
        , std.testing.allocator);
        defer std.testing.allocator.free(res[0]);
        defer std.testing.allocator.free(res[1]);
        try std.testing.expectEqualStrings("12521", res[0]);
        try std.testing.expectEqualStrings("44169", res[1]);
    }
}
