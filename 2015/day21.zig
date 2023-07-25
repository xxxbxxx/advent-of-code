const std = @import("std");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

const Object = struct {
    cost: i32,
    damage: i32,
    armor: i32,
};

const Carac = struct {
    points: i32,
    damage: i32,
    armor: i32,
};
fn playfight(boss: Carac, player: Carac, objects: []Object) bool {
    var b = boss;
    var p = player;
    for (objects) |o| {
        p.damage += o.damage;
        p.armor += o.armor;
    }
    while (b.points > 0 and p.points > 0) {
        {
            var dmg = p.damage - b.armor;
            if (dmg <= 0)
                dmg = 1;
            b.points -= dmg;
            if (b.points <= 0)
                break;
        }
        {
            var dmg = b.damage - p.armor;
            if (dmg <= 0)
                dmg = 1;
            p.points -= dmg;
            if (p.points <= 0)
                break;
        }
    }
    return p.points > 0;
}

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const boss = Carac{ .points = 103, .damage = 9, .armor = 2 };

    const player = Carac{ .points = 100, .damage = 0, .armor = 0 };

    const weapons = [_]Object{
        .{ .cost = 8, .damage = 4, .armor = 0 },
        .{ .cost = 10, .damage = 5, .armor = 0 },
        .{ .cost = 25, .damage = 6, .armor = 0 },
        .{ .cost = 40, .damage = 7, .armor = 0 },
        .{ .cost = 74, .damage = 8, .armor = 0 },
    };
    const armors = [_]Object{
        .{ .cost = 0, .damage = 0, .armor = 0 },
        .{ .cost = 13, .damage = 0, .armor = 1 },
        .{ .cost = 31, .damage = 0, .armor = 2 },
        .{ .cost = 53, .damage = 0, .armor = 3 },
        .{ .cost = 75, .damage = 0, .armor = 4 },
        .{ .cost = 102, .damage = 0, .armor = 5 },
    };
    const rings = [_]Object{
        .{ .cost = 0, .damage = 0, .armor = 0 },
        .{ .cost = 0, .damage = 0, .armor = 0 },
        .{ .cost = 25, .damage = 1, .armor = 0 },
        .{ .cost = 50, .damage = 2, .armor = 0 },
        .{ .cost = 100, .damage = 3, .armor = 0 },
        .{ .cost = 20, .damage = 0, .armor = 1 },
        .{ .cost = 40, .damage = 0, .armor = 2 },
        .{ .cost = 80, .damage = 0, .armor = 3 },
    };

    var bestcost: i32 = 0;
    var objects: [4]Object = undefined;
    for (weapons) |w| {
        objects[0] = w;
        for (armors) |a| {
            objects[1] = a;
            for (rings, 0..) |r1, i| {
                objects[2] = r1;
                for (rings[i + 1 ..]) |r2| {
                    objects[3] = r2;
                    const victory = playfight(boss, player, &objects);
                    const cost = w.cost + a.cost + r1.cost + r2.cost;
                    trace("combi {}, cost={} victory={}\n", objects, cost, victory);
                    if (!victory and cost > bestcost) {
                        bestcost = cost;
                    }
                }
            }
        }
    }

    const out = std.io.getStdOut().writer();
    try out.print("ans = {}\n", bestcost);

    //    return error.SolutionNotFound;
}
