const std = @import("std");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

const Ingredient = struct {
    name: []const u8,
    capacity: i32,
    durability: i32,
    flavor: i32,
    texture: i32,
    calories: i32,
};

fn parse_line(line: []const u8) Ingredient {
    //Butterscotch: capacity -1, durability -2, flavor 6, texture 3, calories 8
    var slice = line;
    var sep = std.mem.indexOf(u8, slice, ": capacity ");
    const name = slice[0..sep.?];
    slice = slice[sep.? + 11 ..];

    sep = std.mem.indexOf(u8, slice, ", durability ");
    const capac = slice[0..sep.?];
    slice = slice[sep.? + 13 ..];

    sep = std.mem.indexOf(u8, slice, ", flavor ");
    const durab = slice[0..sep.?];
    slice = slice[sep.? + 9 ..];

    sep = std.mem.indexOf(u8, slice, ", texture ");
    const flav = slice[0..sep.?];
    slice = slice[sep.? + 10 ..];

    sep = std.mem.indexOf(u8, slice, ", calories ");
    const tex = slice[0..sep.?];
    const cal = slice[sep.? + 11 ..];

    return Ingredient{
        .name = name,
        .capacity = std.fmt.parseInt(i32, capac, 10) catch unreachable,
        .durability = std.fmt.parseInt(i32, durab, 10) catch unreachable,
        .flavor = std.fmt.parseInt(i32, flav, 10) catch unreachable,
        .texture = std.fmt.parseInt(i32, tex, 10) catch unreachable,
        .calories = std.fmt.parseInt(i32, cal, 10) catch unreachable,
    };
}
pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day15.txt", limit);

    const maxelem = 20;
    var ingred: [maxelem]Ingredient = undefined;
    var popu: u32 = 0;

    var it = std.mem.tokenize(u8, text, "\n");
    var combi: u32 = 1;
    while (it.next()) |line| {
        ingred[popu] = parse_line(line);
        trace("{}\n", ingred[popu]);
        popu += 1;
        combi *= 100;
    }

    var best: i32 = 0;
    var c: u32 = 0;
    while (c < combi) : (c += 1) {
        var recipe: [maxelem]i32 = undefined;
        var rem = c;
        var tot: i32 = 0;
        for (recipe[0..popu]) |*r| {
            r.* = @intCast(i32, rem % 100);
            rem = rem / 100;
            tot += r.*;
            if (tot > 100)
                break;
        }
        if (tot != 100)
            continue;

        var capacity: i32 = 0;
        var durability: i32 = 0;
        var flavor: i32 = 0;
        var texture: i32 = 0;
        var calories: i32 = 0;
        for (recipe[0..popu]) |r, i| {
            const ing = ingred[i];
            capacity += ing.capacity * r;
            durability += ing.durability * r;
            flavor += ing.flavor * r;
            texture += ing.texture * r;
            calories += ing.calories * r;
        }
        if (calories != 500)
            continue;

        if (capacity < 0) capacity = 0;
        if (durability < 0) durability = 0;
        if (flavor < 0) flavor = 0;
        if (texture < 0) texture = 0;
        const score = capacity * durability * flavor * texture;
        //trace("{} -> {} {} {} {} -> {}\n", recipe[0..popu], capacity, durability, flavor, texture, score);

        if (score > best) best = score;
    }

    const out = std.io.getStdOut().writer();
    try out.print("pass = {} (FROM {} combis)\n", best, combi);

    //    return error.SolutionNotFound;
}
