const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

const Vec2 = tools.Vec2;

pub fn run(input_text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const Food = struct { ing: []const u16, alg: []const u16 };
    const param: struct {
        allergens: [][]const u8,
        ingredients: [][]const u8,
        foods: []Food,
    } = param: {
        var allergens_hash = std.StringHashMap(u16).init(allocator);
        defer allergens_hash.deinit();
        var ingredients_hash = std.StringHashMap(u16).init(allocator);
        defer ingredients_hash.deinit();
        var allergens = std.ArrayList([]const u8).init(arena.allocator());
        var ingredients = std.ArrayList([]const u8).init(arena.allocator());
        var foods = std.ArrayList(Food).init(arena.allocator());

        var it = std.mem.tokenize(u8, input_text, "\n\r");
        while (it.next()) |line| {
            if (tools.match_pattern("{} (contains {})", line)) |fields| {
                var ings: [100]u16 = undefined;
                var nb_ing: u32 = 0;
                {
                    var it2 = std.mem.tokenize(u8, fields[0].lit, " ,");
                    while (it2.next()) |word| {
                        const ingredient_idx = blk: {
                            const kv = try ingredients_hash.getOrPut(word);
                            if (kv.found_existing)
                                break :blk kv.value_ptr.*;

                            kv.value_ptr.* = @intCast(u16, ingredients.items.len);
                            try ingredients.append(word);
                            break :blk kv.value_ptr.*;
                        };
                        ings[nb_ing] = ingredient_idx;
                        nb_ing += 1;
                    }
                }

                var algs: [100]u16 = undefined;
                var nb_alg: u32 = 0;
                {
                    var it2 = std.mem.tokenize(u8, fields[1].lit, " ,");
                    while (it2.next()) |word| {
                        const allergen_idx = blk: {
                            const kv = try allergens_hash.getOrPut(word);
                            if (kv.found_existing)
                                break :blk kv.value_ptr.*;

                            kv.value_ptr.* = @intCast(u16, allergens.items.len);
                            try allergens.append(word);
                            break :blk kv.value_ptr.*;
                        };
                        algs[nb_alg] = allergen_idx;
                        nb_alg += 1;
                    }
                }

                try foods.append(Food{
                    .ing = try arena.allocator().dupe(u16, ings[0..nb_ing]),
                    .alg = try arena.allocator().dupe(u16, algs[0..nb_alg]),
                });
            } else {
                std.debug.print("parse error: '{s}'\n", .{line});
                return error.UnsupportedInput;
            }
        }

        // std.debug.print("got {} ingredients, {} allergens, {} foods\n", .{ ingredients.items.len, allergens.items.len, foods.items.len });
        break :param .{
            .allergens = allergens.items,
            .ingredients = ingredients.items,
            .foods = foods.items,
        };
    };

    var inert_ings = std.ArrayList(u16).init(allocator);
    defer inert_ings.deinit();
    const ans1 = ans: {
        var total: u32 = 0;
        next_ing: for (param.ingredients) |_, i| {
            for (param.allergens) |_, a| {
                const can_contain_allegen = for (param.foods) |f| {
                    const has_allergen = std.mem.indexOfScalar(u16, f.alg, @intCast(u16, a)) != null;
                    if (!has_allergen) continue;
                    const in_food = std.mem.indexOfScalar(u16, f.ing, @intCast(u16, i)) != null;
                    if (!in_food) break false;
                } else true;
                if (can_contain_allegen) continue :next_ing;
            }

            try inert_ings.append(@intCast(u16, i));

            var nb: u32 = 0;
            for (param.foods) |f| {
                for (f.ing) |x| {
                    if (x == i) nb += 1;
                }
            }
            total += nb;

            // std.debug.print("ingredient '{}' ({}): no allergens. appears {} times\n", .{ ingredient, i, nb });
        }
        break :ans total;
    };

    const ans2 = ans: {
        // const matrix = try allocator.alloc(bool, param.ingredients.len * param.allergens.len);  -> mauviase approche ... mehhh
        assert(param.allergens.len == param.ingredients.len - inert_ings.items.len);
        const active_ingredients = try allocator.alloc(u16, param.allergens.len);
        defer allocator.free(active_ingredients);
        var idx: u32 = 0;
        for (param.ingredients) |_, i| {
            if (std.mem.indexOfScalar(u16, inert_ings.items, @intCast(u16, i))) |_| continue;
            active_ingredients[idx] = @intCast(u16, i);
            idx += 1;
        }

        var buf: [50]u16 = undefined;
        var it = tools.generate_permutations(u16, active_ingredients);
        next_perm: while (it.next(&buf)) |perm| {
            for (perm) |i, a| {
                const possible = for (param.foods) |f| {
                    const has_allergen = std.mem.indexOfScalar(u16, f.alg, @intCast(u16, a)) != null;
                    if (!has_allergen) continue;
                    const in_food = std.mem.indexOfScalar(u16, f.ing, @intCast(u16, i)) != null;
                    if (!in_food) break false;
                } else true;
                if (!possible) continue :next_perm;
            }

            // bingo!
            const Pair = struct {
                ing: []const u8,
                alg: []const u8,
                fn lessThan(_: void, lhs: @This(), rhs: @This()) bool {
                    return std.mem.lessThan(u8, lhs.alg, rhs.alg);
                }
            };

            var result: [32]Pair = undefined;
            for (perm) |i, a| {
                result[a] = .{
                    .ing = param.ingredients[i],
                    .alg = param.allergens[a],
                };
            }
            std.sort.sort(Pair, result[0..perm.len], {}, Pair.lessThan);

            const result_text = try arena.allocator().alloc(u8, 500);
            var len: usize = 0;
            for (result[0..perm.len]) |r, index| {
                std.mem.copy(u8, result_text[len .. len + r.ing.len], r.ing);
                len += r.ing.len;
                if (index < perm.len - 1) {
                    result_text[len] = ',';
                    len += 1;
                }
            }
            break :ans result_text[0..len];
        }
        unreachable;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{s}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2020/input_day21.txt", run);
