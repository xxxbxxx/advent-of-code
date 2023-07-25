const std = @import("std");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

fn findoradd(cities: [][]const u8, nb: *u32, name: []const u8) u32 {
    var i: u32 = 0;
    while (i < nb.*) : (i += 1) {
        const c = cities[i];
        if (std.mem.eql(u8, c, name))
            return i;
    }
    cities[nb.*] = name;
    nb.* += 1;
    return nb.* - 1;
}

fn swap(a: *u32, b: *u32) void {
    const t = a.*;
    a.* = b.*;
    b.* = t;
}
pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day9.txt", limit);

    const maxcities = 10;
    var cities: [maxcities][]const u8 = undefined;
    var nb_cities: u32 = 0;
    var links: [maxcities * maxcities]?u32 = [1]?u32{null} ** (maxcities * maxcities);
    var totdist: u32 = 0;

    var it = std.mem.split(u8, text, "\n");
    while (it.next()) |line_full| {
        const line = std.mem.trim(u8, line_full, " \n\r\t");
        if (line.len < 2)
            continue;
        const sep1 = std.mem.indexOf(u8, line, " to ");
        const sep2 = std.mem.indexOf(u8, line, " = ");
        const name1 = line[0..sep1.?];
        const name2 = line[sep1.? + 4 .. sep2.?];
        const distance_str = line[sep2.? + 3 ..];

        const distance = std.fmt.parseInt(u32, distance_str, 10) catch unreachable;
        const city1 = findoradd(&cities, &nb_cities, name1);
        const city2 = findoradd(&cities, &nb_cities, name2);

        links[city1 + maxcities * city2] = distance;
        links[city2 + maxcities * city1] = distance;
        totdist += distance;
    }

    var permutations_mem: [maxcities]u32 = undefined;
    const perm = permutations_mem[0..nb_cities];
    var permuts: usize = 1;
    for (perm, 0..) |p, i| {
        permuts *= (i + 1);
    }

    var mindist: u32 = totdist;
    var maxdist: u32 = 0;
    var j: u32 = 0;
    while (j < permuts) : (j += 1) {
        for (perm, 0..) |*p, i| {
            p.* = @as(u32, @intCast(i));
        }
        var mod = nb_cities;
        var k = j;
        for (perm, 0..) |*p, i| {
            swap(p, &perm[i + k % mod]);
            k /= mod;
            mod -= 1;
        }

        var dist: ?u32 = 0;
        var prev = perm[0];
        trace("{}", cities[prev]);
        for (perm[1..]) |p| {
            const link = links[prev * maxcities + p];
            trace(" -> {}", cities[p]);
            if (link) |l| {
                dist.? += l;
            } else {
                dist = null;
                break;
            }
            prev = p;
        }
        trace(": {}\n", dist);
        if (dist) |d| {
            if (d < mindist)
                mindist = d;
            if (d > maxdist)
                maxdist = d;
        }
    }

    const out = std.io.getStdOut().writer();
    try out.print("min {}, max {}, tot {} (for {} permutations)\n", mindist, maxdist, totdist, permuts);

    //    return error.SolutionNotFound;
}
