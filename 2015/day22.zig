const std = @import("std");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

const SpellEffect = struct {
    damage: i32 = 0,
    armor: i32 = 0,
    heal: i32 = 0,
    manabonus: i32 = 0,
};

const Spell = struct {
    cost: i32,
    //   effect: i32,
    duration: i32 = 0,
};

const Carac = struct {
    points: i32,
    damage: i32,
    armor: i32,
    mana: i32,
};

const effects = [_]SpellEffect{
    .{ .damage = 4 },
    .{ .damage = 2, .heal = 2 },
    .{ .armor = 7 },
    .{ .damage = 3 },
    .{ .manabonus = 101 },
};

const spells = [_]Spell{
    .{ .cost = 53 },
    .{ .cost = 73 },
    .{ .cost = 113, .duration = 6 },
    .{ .cost = 173, .duration = 6 },
    .{ .cost = 229, .duration = 5 },
};

fn apply_effect(boss: *Carac, player: *Carac, idx: usize) void {
    const e = effects[idx];
    boss.points -= e.damage;
    player.armor += e.armor;
    player.mana += e.manabonus;
    player.points += e.heal;
}

fn playfight_bfs(boss: Carac, player: Carac, active_spells: [5]i32, turn: u32) ?i32 {
    const spaces = "                                                                         ";
    const playerturn = (turn % 2) == 1;
    //  const padding = spaces[0 .. (turn - 1) * 2];

    var b0 = boss;
    var p0 = player;
    var as0 = [5]i32{ 0, 0, active_spells[2], active_spells[3], active_spells[4] };
    //  trace("{}turn={}, spells={},{},{}, player: {},{},{}, boss: {}\n", padding, turn, as0[2], as0[3], as0[4], p0.points, p0.mana, p0.armor, b0.points);

    p0.armor = 0;
    for (as0) |*duration, i| {
        if (duration.* > 0) {
            apply_effect(&b0, &p0, i);
            duration.* -= 1;
        }
    }
    const hardmode = true;
    if (hardmode and playerturn) {
        p0.points -= 1;
    }
    if (p0.points <= 0)
        return null;
    if (b0.points <= 0)
        return 0;

    if (playerturn) {
        var bestcost: ?i32 = null;
        for (spells) |s, i| {
            var b1 = b0;
            var p1 = p0;
            var as1 = [5]i32{ 0, 0, as0[2], as0[3], as0[4] };

            if (s.duration == 0 and s.cost <= p1.mana) {
                //              trace("{}player casts: {}\n", padding, i);
                p1.mana -= s.cost;
                apply_effect(&b1, &p1, i);
                if (b1.points <= 0) {
                    if (bestcost == null or s.cost < bestcost.?)
                        bestcost = s.cost;
                } else {
                    if (playfight_bfs(b1, p1, as1, turn + 1)) |cost| {
                        if (bestcost == null or cost + s.cost < bestcost.?)
                            bestcost = cost + s.cost;
                    }
                }
            } else if (as1[i] == 0 and s.cost <= p1.mana) {
                //              trace("{}player casts: {}\n", padding, i);
                p1.mana -= s.cost;
                as1[i] = s.duration;
                if (playfight_bfs(b1, p1, as1, turn + 1)) |cost| {
                    if (bestcost == null or cost + s.cost < bestcost.?)
                        bestcost = cost + s.cost;
                }
            }
        }
        return bestcost;
    } else {
        var dmg = b0.damage - p0.armor;
        if (dmg <= 0)
            dmg = 1;
        p0.points -= dmg;
        //      trace("{}boss deals {}\n", padding, dmg);
        if (p0.points <= 0)
            return null;
        return playfight_bfs(b0, p0, as0, turn + 1);
    }
}

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const boss = Carac{ .points = 71, .damage = 10, .armor = 0, .mana = 0 };
    const player = Carac{ .points = 50, .damage = 0, .armor = 0, .mana = 500 };
    //const boss = Carac{ .points = 14, .damage = 8, .armor = 0, .mana = 0 };
    //const player = Carac{ .points = 10, .damage = 0, .armor = 0, .mana = 250 };

    const active_spells = [5]i32{ 0, 0, 0, 0, 0 };

    const out = std.io.getStdOut().writer();
    try out.print("ans = {}\n", playfight_bfs(boss, player, active_spells, 1));

    //    return error.SolutionNotFound;
}
