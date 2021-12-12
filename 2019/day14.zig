const std = @import("std");
const tools = @import("tools");

const with_trace = false;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

const Chemical = []const u8;
const Chemicals = std.ArrayList(Chemical);
const Reaction = struct {
    const Comp = struct {
        chemical: usize,
        quantity: u64,
    };
    reactives: []Comp,
    product: Comp,
};

fn parseChemical(segment: []const u8, chemicals: *Chemicals) !Reaction.Comp {
    var comp: Reaction.Comp = undefined;
    var it = std.mem.tokenize(u8, segment, " ");
    if (it.next()) |q| {
        comp.quantity = try std.fmt.parseInt(u64, q, 10);
    }

    if (it.next()) |name| {
        var found = false;
        for (chemicals.items) |c, i| {
            if (std.mem.eql(u8, c, name)) {
                comp.chemical = i;
                found = true;
                break;
            }
        }
        if (!found) {
            try chemicals.append(name);
            comp.chemical = chemicals.items.len - 1;
        }
    } else {
        unreachable;
    }

    return comp;
}

fn parseline(line: []const u8, chemicals: *Chemicals, reactions: []?Reaction, allocator: std.mem.Allocator) !void {
    const sep = std.mem.indexOf(u8, line, " => ").?;

    var reaction: Reaction = undefined;
    reaction.product = try parseChemical(line[sep + 4 ..], chemicals);

    var reactives_count = blk: {
        var count: u32 = 0;
        var it = std.mem.tokenize(u8, line[0..sep], "\n,");
        while (it.next()) |_| {
            count += 1;
        }
        break :blk count;
    };
    reaction.reactives = try allocator.alloc(Reaction.Comp, reactives_count);
    {
        var i: u32 = 0;
        var it = std.mem.tokenize(u8, line[0..sep], "\n,");
        while (it.next()) |segment| {
            reaction.reactives[i] = try parseChemical(segment, chemicals);
            i += 1;
        }
    }

    assert(reactions[reaction.product.chemical] == null);
    reactions[reaction.product.chemical] = reaction;
}

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var grid = try allocator.alloc(u8, 1000 * 1000);
    defer allocator.free(grid);
    std.mem.set(u8, grid, 0);

    var chemicals = Chemicals.init(arena.allocator());
    var reactions: [1000]?Reaction = [1]?Reaction{null} ** 1000;

    try chemicals.append("ORE");
    try chemicals.append("FUEL");

    {
        var it = std.mem.split(u8, input, "\n");
        while (it.next()) |line_full| {
            const line = std.mem.trim(u8, line_full, " \n\r\t");
            if (line.len == 0)
                continue;
            try parseline(line, &chemicals, &reactions, arena.allocator());
        }
    }
    var reactions_count: u32 = 0;
    for (reactions) |reacmaybe| {
        if (reacmaybe) |reac| {
            reactions_count += 1;
            trace("{}: ", .{chemicals.items[reac.product.chemical]});
            for (reac.reactives) |it| {
                trace("{} {}, ", .{ it.quantity, chemicals.items[it.chemical] });
            }
            trace("\n", .{});
        }
    }
    trace("chemicals={} reactions={} \n", .{ chemicals.items.len, reactions_count });

    var chemicals_to_fuel = try allocator.alloc(u32, chemicals.items.len);
    defer allocator.free(chemicals_to_fuel);
    {
        std.mem.set(u32, chemicals_to_fuel, 0);
        chemicals_to_fuel[1] = 0;
        var changed = true;
        while (changed) {
            changed = false;
            for (reactions) |reacmaybe| {
                if (reacmaybe) |reac| {
                    const d = chemicals_to_fuel[reac.product.chemical] + 1;
                    for (reac.reactives) |r| {
                        if (chemicals_to_fuel[r.chemical] < d) {
                            changed = true;
                            chemicals_to_fuel[r.chemical] = d;
                        }
                    }
                }
            }
        }
        for (chemicals_to_fuel) |d, i| {
            trace("  {}: {}\n", .{ d, chemicals.items[i] });
        }
    }

    const ore_for_one_fuel = part1: {
        const fuel = 1;
        var todo = std.ArrayList(Reaction.Comp).init(allocator);
        defer todo.deinit();
        try todo.append(Reaction.Comp{ .chemical = 1, .quantity = fuel });

        while (todo.items.len > 1 or todo.items[0].chemical != 0) {
            var next_products = try allocator.alloc(u64, chemicals.items.len);
            defer allocator.free(next_products);
            std.mem.set(u64, next_products, 0);
            const smallest_dist = blk: {
                trace("== step: ", .{});
                var dist: u32 = 9999;
                for (todo.items) |product| {
                    trace("{} {}, ", .{ product.quantity, chemicals.items[product.chemical] });

                    const d = chemicals_to_fuel[product.chemical];
                    if (d < dist) dist = d;
                }
                trace("\n", .{});
                break :blk dist;
            };
            for (todo.items) |product| {
                if (chemicals_to_fuel[product.chemical] == smallest_dist and product.chemical != 0) {
                    if (reactions[product.chemical]) |r| {
                        const repeats = ((product.quantity + r.product.quantity - 1) / r.product.quantity);
                        for (r.reactives) |reac| {
                            next_products[reac.chemical] += repeats * reac.quantity;
                        }
                        trace("{} times  [{} {} <- {}]\n", .{ repeats, r.product.quantity, chemicals.items[r.product.chemical], r.reactives });
                    } else {
                        unreachable;
                    }
                } else {
                    next_products[product.chemical] += product.quantity;
                }
            }
            try todo.resize(0);
            for (next_products) |q, c| {
                if (q > 0) {
                    try todo.append(Reaction.Comp{ .chemical = c, .quantity = q });
                }
            }
        }

        trace("ore={} -> fuel:{}\n", .{ todo.items[0].quantity, fuel });
        break :part1 todo.items[0].quantity;
    };

    const fuel = part2: {
        const maxore: u64 = 1000000000000;
        var minfuel: u64 = maxore / ore_for_one_fuel;
        var maxfuel: u64 = 2 * minfuel;
        while (minfuel + 1 < maxfuel) {
            var todo = std.ArrayList(Reaction.Comp).init(allocator);
            defer todo.deinit();

            const fuel = (maxfuel + minfuel) / 2;
            try todo.append(Reaction.Comp{ .chemical = 1, .quantity = fuel });

            while (todo.items.len > 1 or todo.items[0].chemical != 0) {
                var next_products = try allocator.alloc(u64, chemicals.items.len);
                defer allocator.free(next_products);
                std.mem.set(u64, next_products, 0);
                const smallest_dist = blk: {
                    trace("== step: ", .{});
                    var dist: u32 = 9999;
                    for (todo.items) |product| {
                        trace("{} {}, ", .{ product.quantity, chemicals.items[product.chemical] });
                        const d = chemicals_to_fuel[product.chemical];
                        if (d < dist) dist = d;
                    }
                    trace("\n", .{});
                    break :blk dist;
                };
                for (todo.items) |product| {
                    if (chemicals_to_fuel[product.chemical] == smallest_dist and product.chemical != 0) {
                        if (reactions[product.chemical]) |r| {
                            const repeats = ((product.quantity + r.product.quantity - 1) / r.product.quantity);
                            for (r.reactives) |reac| {
                                next_products[reac.chemical] += repeats * reac.quantity;
                            }
                            trace("{} times  [{} {} <- {}]\n", .{ repeats, r.product.quantity, chemicals.items[r.product.chemical], r.reactives });
                        } else {
                            unreachable;
                        }
                    } else {
                        next_products[product.chemical] += product.quantity;
                    }
                }
                try todo.resize(0);
                for (next_products) |q, c| {
                    if (q > 0) {
                        try todo.append(Reaction.Comp{ .chemical = c, .quantity = q });
                    }
                }
            }

            trace("ore={} -> fuel:{}<{}<{} \n", .{ todo.items[0].quantity, minfuel, fuel, maxfuel });
            const over = (todo.items[0].quantity > maxore);
            if (over) {
                maxfuel = fuel;
            } else {
                minfuel = fuel;
            }
        }
        break :part2 minfuel;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ore_for_one_fuel}),
        try std.fmt.allocPrint(allocator, "{}", .{fuel}),
    };
}

pub const main = tools.defaultMain("2019/day14.txt", run);
