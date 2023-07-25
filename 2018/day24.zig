const std = @import("std");
const assert = std.debug.assert;
const print = std.debug.print;
const tools = @import("tools");

const Property = enum { bludgeoning, radiation, cold, slashing, fire };
const Group = struct {
    unit_count: u16,
    unit_hp: u16,

    weak: []const Property,
    immune: []const Property,

    attack_prop: Property,
    attack_damage: u16,
    initiative: u8,
};

fn computePotentialDamage(att: Group, tgt: Group) u32 {
    if (std.mem.indexOfScalar(Property, tgt.immune, att.attack_prop)) |_| return 0;
    const weak = std.mem.indexOfScalar(Property, tgt.weak, att.attack_prop) != null;
    const dmg = @as(u32, att.attack_damage) * att.unit_count;
    return if (weak) 2 * dmg else dmg;
}

fn betterEffectivePower(_: void, a: Group, b: Group) bool {
    const eff_a = @as(u32, a.attack_damage) * a.unit_count;
    const eff_b = @as(u32, b.attack_damage) * b.unit_count;
    if (eff_a > eff_b) return true;
    if (eff_a < eff_b) return false;
    if (a.initiative > b.initiative) return true;
    if (a.initiative < b.initiative) return false;
    unreachable;
}
fn doOneFight(armies: [2][]Group, allocator: std.mem.Allocator) ![2]u32 {
    //print("-- new fight ---\n", .{});
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const Attack = struct {
        army: u1,
        group: u8,
        initiative: u8,
        target: u8,
        fn betterInitiative(_: void, a: @This(), b: @This()) bool {
            return a.initiative > b.initiative;
        }
    };

    // phase1
    for (armies) |army| {
        std.mem.sort(Group, army, {}, betterEffectivePower);
    }

    var attacks = std.ArrayList(Attack).init(arena.allocator());
    defer attacks.deinit();

    for (armies, 0..) |army, i| {
        var potential_targets = std.ArrayList(?Group).init(arena.allocator());
        defer potential_targets.deinit();
        for (armies[1 - i]) |g| try potential_targets.append(if (g.unit_count > 0) g else null);

        for (army, 0..) |att, j| {
            //   print("army {}, group {}, units: {}\n", .{ i, j, att.unit_count });
            var best_tgt: ?usize = null;
            var best_potential_damage: u32 = 0;
            for (potential_targets.items, 0..) |tgt, k| {
                if (tgt) |t| {
                    const damage = computePotentialDamage(att, t);
                    if (damage > best_potential_damage) {
                        best_potential_damage = damage;
                        best_tgt = k;
                    }
                }
            }
            if (best_tgt) |idx| {
                try attacks.append(Attack{
                    .army = @as(u1, @intCast(i)),
                    .group = @as(u8, @intCast(j)),
                    .initiative = att.initiative,
                    .target = @as(u8, @intCast(idx)),
                });
                potential_targets.items[idx] = null;
            }
        }
    }

    //phase 2
    std.mem.sort(Attack, attacks.items, {}, Attack.betterInitiative);

    for (attacks.items) |attack| {
        const target = &armies[1 - attack.army][attack.target];
        const dmg = computePotentialDamage(armies[attack.army][attack.group], target.*);
        const kills = @as(u16, @intCast(dmg / target.unit_hp));
        //  print("  attack: {}.{} -> {}, does {} damage: kills {} units\n", .{ attack.army, attack.group, attack.target, dmg, kills });

        target.unit_count = if (target.unit_count > kills) target.unit_count - kills else 0;
    }

    var finalcounts = [2]u32{ 0, 0 };
    for (armies, 0..) |army, i| {
        for (army) |group| finalcounts[i] += group.unit_count;
    }

    return finalcounts;
}

pub fn run(input_text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    _ = input_text;
    const param: struct {
        immunesys: []const Group,
        infection: []const Group,
    } = .{
        .immunesys = &[_]Group{
            .{ .unit_count = 889, .unit_hp = 3275, .weak = &[_]Property{ .bludgeoning, .radiation }, .immune = &[_]Property{.cold}, .attack_damage = 36, .attack_prop = .bludgeoning, .initiative = 12 },
            .{ .unit_count = 94, .unit_hp = 1336, .weak = &[_]Property{ .radiation, .cold }, .immune = &[_]Property{}, .attack_damage = 127, .attack_prop = .bludgeoning, .initiative = 7 },
            .{ .unit_count = 1990, .unit_hp = 5438, .weak = &[_]Property{}, .immune = &[_]Property{}, .attack_damage = 25, .attack_prop = .slashing, .initiative = 20 },
            .{ .unit_count = 1211, .unit_hp = 6640, .weak = &[_]Property{}, .immune = &[_]Property{}, .attack_damage = 54, .attack_prop = .fire, .initiative = 19 },
            .{ .unit_count = 3026, .unit_hp = 7938, .weak = &[_]Property{.bludgeoning}, .immune = &[_]Property{.cold}, .attack_damage = 26, .attack_prop = .bludgeoning, .initiative = 16 },
            .{ .unit_count = 6440, .unit_hp = 9654, .weak = &[_]Property{}, .immune = &[_]Property{}, .attack_damage = 14, .attack_prop = .fire, .initiative = 4 },
            .{ .unit_count = 2609, .unit_hp = 8218, .weak = &[_]Property{.bludgeoning}, .immune = &[_]Property{}, .attack_damage = 28, .attack_prop = .cold, .initiative = 3 },
            .{ .unit_count = 3232, .unit_hp = 11865, .weak = &[_]Property{.radiation}, .immune = &[_]Property{}, .attack_damage = 30, .attack_prop = .slashing, .initiative = 14 },
            .{ .unit_count = 2835, .unit_hp = 7220, .weak = &[_]Property{}, .immune = &[_]Property{ .fire, .radiation }, .attack_damage = 18, .attack_prop = .bludgeoning, .initiative = 2 },
            .{ .unit_count = 2570, .unit_hp = 4797, .weak = &[_]Property{.cold}, .immune = &[_]Property{}, .attack_damage = 15, .attack_prop = .radiation, .initiative = 17 },
        },
        .infection = &[_]Group{
            .{ .unit_count = 333, .unit_hp = 44943, .weak = &[_]Property{.bludgeoning}, .immune = &[_]Property{}, .attack_damage = 223, .attack_prop = .slashing, .initiative = 13 },
            .{ .unit_count = 1038, .unit_hp = 10867, .weak = &[_]Property{}, .immune = &[_]Property{ .bludgeoning, .slashing, .fire }, .attack_damage = 16, .attack_prop = .cold, .initiative = 8 },
            .{ .unit_count = 57, .unit_hp = 50892, .weak = &[_]Property{}, .immune = &[_]Property{}, .attack_damage = 1732, .attack_prop = .cold, .initiative = 5 },
            .{ .unit_count = 196, .unit_hp = 36139, .weak = &[_]Property{.cold}, .immune = &[_]Property{}, .attack_damage = 334, .attack_prop = .fire, .initiative = 6 },
            .{ .unit_count = 2886, .unit_hp = 45736, .weak = &[_]Property{.slashing}, .immune = &[_]Property{.cold}, .attack_damage = 25, .attack_prop = .cold, .initiative = 1 },
            .{ .unit_count = 4484, .unit_hp = 37913, .weak = &[_]Property{.bludgeoning}, .immune = &[_]Property{ .fire, .radiation, .slashing }, .attack_damage = 16, .attack_prop = .fire, .initiative = 18 },
            .{ .unit_count = 1852, .unit_hp = 49409, .weak = &[_]Property{.radiation}, .immune = &[_]Property{.bludgeoning}, .attack_damage = 52, .attack_prop = .radiation, .initiative = 9 },
            .{ .unit_count = 3049, .unit_hp = 18862, .weak = &[_]Property{.radiation}, .immune = &[_]Property{}, .attack_damage = 12, .attack_prop = .fire, .initiative = 10 },
            .{ .unit_count = 1186, .unit_hp = 23898, .weak = &[_]Property{}, .immune = &[_]Property{.fire}, .attack_damage = 34, .attack_prop = .bludgeoning, .initiative = 15 },
            .{ .unit_count = 6003, .unit_hp = 12593, .weak = &[_]Property{}, .immune = &[_]Property{}, .attack_damage = 2, .attack_prop = .cold, .initiative = 11 },
        },
    };

    const param_example: struct {
        immunesys: []const Group,
        infection: []const Group,
    } = .{
        .immunesys = &[_]Group{
            .{ .unit_count = 17, .unit_hp = 5390, .weak = &[_]Property{ .bludgeoning, .radiation }, .immune = &[_]Property{}, .attack_damage = 4507, .attack_prop = .fire, .initiative = 2 },
            .{ .unit_count = 989, .unit_hp = 1274, .weak = &[_]Property{ .bludgeoning, .slashing }, .immune = &[_]Property{}, .attack_damage = 25, .attack_prop = .slashing, .initiative = 3 },
        },
        .infection = &[_]Group{
            .{ .unit_count = 801, .unit_hp = 4706, .weak = &[_]Property{.radiation}, .immune = &[_]Property{}, .attack_damage = 116, .attack_prop = .bludgeoning, .initiative = 1 },
            .{ .unit_count = 4485, .unit_hp = 2961, .weak = &[_]Property{ .fire, .cold }, .immune = &[_]Property{.radiation}, .attack_damage = 12, .attack_prop = .slashing, .initiative = 4 },
        },
    };
    _ = param_example;

    const ans1 = ans: { // 18531 toolow
        const armies = [2][]Group{
            try arena.allocator().dupe(Group, param.immunesys),
            try arena.allocator().dupe(Group, param.infection),
        };
        while (true) {
            const units_left = try doOneFight(armies, allocator);
            if (units_left[0] == 0) break :ans units_left[1];
            if (units_left[1] == 0) break :ans units_left[0];
        }
    };

    const ans2 = ans: {
        var bracket_min: u16 = 0;
        var bracket_max: u16 = 50000;
        var immune_left: u32 = undefined;
        while (bracket_min + 1 < bracket_max) {
            const armies = [2][]Group{
                try arena.allocator().dupe(Group, param.immunesys),
                try arena.allocator().dupe(Group, param.infection),
            };
            defer arena.allocator().free(armies[0]);
            defer arena.allocator().free(armies[1]);

            const boost = (bracket_min + bracket_max + 1) / 2;
            for (armies[0]) |*it| it.attack_damage += boost;

            var prev: u32 = 0;
            const units_left = while (true) {
                const res = try doOneFight(armies, allocator);
                if (res[0] == 0 or res[1] == 0) break res;
                if (res[0] + res[1] == prev) break res;
                prev = res[0] + res[1];
            } else unreachable;

            // print("boost: {} -> unitsleft:{} vs {}\n", .{ boost, units_left[0], units_left[1] });
            if (units_left[1] != 0) {
                bracket_min = boost;
            } else {
                immune_left = units_left[0];
                bracket_max = boost;
            }
        }

        break :ans immune_left;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2018/input_day23.txt", run);
