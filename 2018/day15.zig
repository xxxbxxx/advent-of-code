const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

const Vec2 = tools.Vec2;
const Map = tools.Map(u8, 32, 32, false);

const Unit = struct {
    const Type = enum { goblin, elf };
    type: Type,
    hit_points: u16 = 200,
    attack: u16 = 3,
    p: Vec2,

    fn lessThan(_: void, lhs: Unit, rhs: Unit) bool {
        return Vec2.lessThan({}, lhs.p, rhs.p);
    }
};

fn compute_dists(cavern: *const Map, units: []const Unit, o: Vec2) Map {
    var m = Map{ .default_tile = 255 };
    m.bbox = cavern.bbox;
    m.fill(255, null);
    var dirty = true;
    while (dirty) {
        dirty = false;
        var it = m.iter(null);
        while (it.nextPos()) |p| {
            const cav = cavern.at(p);

            if (cav == '#') continue;
            if (Vec2.eq(p, o)) {
                if (m.at(p) != 0) {
                    m.set(p, 0);
                    dirty = true;
                }
                continue;
            }
            const blocked = for (units) |u| {
                if (u.hit_points == 0) continue;
                if (u.p.eq(p))
                    break true;
            } else false;
            if (blocked) continue;

            const left = m.at(Vec2{ .x = p.x - 1, .y = p.y });
            const right = m.at(Vec2{ .x = p.x + 1, .y = p.y });
            const up = m.at(Vec2{ .x = p.x, .y = p.y - 1 });
            const down = m.at(Vec2{ .x = p.x, .y = p.y + 1 });

            const old = m.at(p);
            const new = std.math.min(std.math.min(left, right), std.math.min(up, down));
            if (new == 255) continue;
            if (old != new + 1) {
                m.set(p, new + 1);
                dirty = true;
            }
        }
    }
    return m;
}

fn debug_print_state(cavern: *const Map, units: []const Unit) void {
    var m = cavern.*;
    for (units) |u| {
        if (u.hit_points == 0) continue;
        assert(m.at(u.p) == '.');
        m.set(u.p, if (u.type == .elf) 'E' else 'G');
    }

    var buf: [5000]u8 = undefined;
    std.debug.print("{}\n", .{m.printToBuf(null, null, null, &buf)});
}

fn playout(cavern: *const Map, units: []Unit) u32 {
    var round: u32 = 0;
    while (true) {
        std.sort.sort(Unit, units, {}, Unit.lessThan);
        for (units) |*it| {
            if (it.hit_points == 0) continue;
            //            std.debug.print("examining unit @{}...\n", .{it.p});
            const dists = compute_dists(cavern, units, it.p);

            const enemy_type: Unit.Type = if (it.type == .elf) .goblin else .elf;
            var candidates: [16]Vec2 = undefined;
            var best_dist: u32 = 255;
            var best_nb: u32 = 0;
            var no_enemies = true;
            for (units) |other| {
                if (other.hit_points == 0) continue;
                if (other.type != enemy_type) continue;
                //              std.debug.print("...examining adjacent to @{}\n", .{other.p});
                no_enemies = false;

                const p = other.p;
                for (Vec2.cardinal_dirs) |d| {
                    const p0 = Vec2{ .x = p.x + d.x, .y = p.y + d.y };
                    const dist = dists.at(p0);
                    // std.debug.print("..... d={} {}\n", .{ dist, p0 });
                    if (dist == 255) continue;
                    if (dist < best_dist) {
                        best_dist = dist;
                        best_nb = 1;
                        candidates[0] = p0;
                    } else if (dist == best_dist) {
                        candidates[best_nb] = p0;
                        best_nb += 1;
                    }
                }
            }
            if (best_nb == 0) {
                continue; // can't move
            }
            std.sort.sort(Vec2, candidates[0..best_nb], {}, Vec2.lessThan);

            //      std.debug.print("...moving to @{}\n", .{candidates[0]});

            const back_dists = compute_dists(cavern, units, candidates[0]);
            var best_back_dist = back_dists.at(it.p);
            var best_pos = it.p;
            for (Vec2.cardinal_dirs) |d| {
                const p0 = it.p.add(d);
                const back_dist = back_dists.at(p0);
                if (best_back_dist > back_dist) {
                    best_back_dist = back_dist;
                    best_pos = p0;
                }
            }
            it.p = best_pos; // move!
            //    std.debug.print("...via {}\n", .{best_pos});

            // attack?
            var best_target: ?*Unit = null;
            var best_hitpoints: u16 = 255;
            for (Vec2.cardinal_dirs) |d| {
                const p0 = it.p.add(d);
                for (units) |*other| {
                    if (other.hit_points == 0) continue;
                    if (other.type != enemy_type) continue;
                    if (!other.p.eq(p0)) continue;
                    if (other.hit_points < best_hitpoints) {
                        best_hitpoints = other.hit_points;
                        best_target = other;
                    }
                }
            }
            if (best_target) |t| {
                t.hit_points = if (t.hit_points > it.attack) t.hit_points - it.attack else 0;
            }
        }

        var alive = [2]bool{ false, false };
        for (units) |it| {
            if (it.hit_points != 0) alive[@enumToInt(it.type)] = true;
        }
        if (!alive[0] or !alive[1]) {
            return round;
        }
        round += 1;
        // debug_print_state(params.cavern, units);
    }
}

pub fn run(input_text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    const params: struct { cavern: *const Map, units: []const Unit } = blk: {
        const cavern = try allocator.create(Map);
        errdefer allocator.destroy(cavern);
        cavern.bbox = tools.BBox.empty;
        cavern.default_tile = 0;
        const units = try allocator.alloc(Unit, 100);
        errdefer allocator.free(units);

        var nb_units: usize = 0;
        var y: i32 = 0;
        var it = std.mem.tokenize(u8, input_text, "\n\r");
        while (it.next()) |line| {
            for (line) |sq, i| {
                const p = Vec2{ .x = @intCast(i32, i), .y = y };
                switch (sq) {
                    '#' => cavern.set(p, '#'),
                    '.' => cavern.set(p, '.'),
                    'G' => {
                        cavern.set(p, '.');
                        units[nb_units] = Unit{ .p = p, .type = .goblin };
                        nb_units += 1;
                    },
                    'E' => {
                        cavern.set(p, '.');
                        units[nb_units] = Unit{ .p = p, .type = .elf };
                        nb_units += 1;
                    },
                    else => {
                        std.debug.print("unknown unit '{c}'\n", .{sq});
                        return error.UnsupportedInput;
                    },
                }
            }
            y += 1;
        }

        break :blk .{ .cavern = cavern, .units = units[0..nb_units] };
    };
    defer allocator.destroy(params.cavern);
    defer allocator.free(params.units);

    //var buf: [5000]u8 = undefined;
    //std.debug.print("{}\n", .{params.cavern.printToBuf(null, null, null, &buf)});

    // part1
    const ans1 = ans: {
        const units = try allocator.dupe(Unit, params.units);
        defer allocator.free(units);

        const round = playout(params.cavern, units);

        //debug_print_state(params.cavern, units);

        var total: u32 = 0;
        for (units) |it| {
            if (it.hit_points == 0) continue;
            // std.debug.print(" unit hp: {}\n", .{it.hit_points});
            total += it.hit_points;
        }
        //std.debug.print("Total  {}x{}\n", .{ round, total });

        break :ans total * round;
    };

    // part2
    const ans2 = ans: {
        var attack: u16 = 30; // 4
        while (true) : (attack += 1) {
            const units = try allocator.dupe(Unit, params.units);
            defer allocator.free(units);

            var nb_elves: u32 = 0;
            for (units) |*u| {
                if (u.type == .elf) {
                    u.attack = attack;
                    nb_elves += 1;
                }
            }

            const round = playout(params.cavern, units);
            //debug_print_state(params.cavern, units);

            var total: u32 = 0;
            var alive_elves: u32 = 0;
            for (units) |it| {
                if (it.hit_points == 0) continue;
                if (it.type == .elf) {
                    alive_elves += 1;
                }
                //std.debug.print(" unit hp: {}\n", .{it.hit_points});
                total += it.hit_points;
            }
            //std.debug.print("Total  {}x{}\n", .{ round, total });
            if (alive_elves == nb_elves)
                break :ans total * round;
        }
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2018/input_day15.txt", run);
