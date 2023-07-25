const std = @import("std");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

const Interraction = struct {
    name: []const u8,
    nextname: []const u8,
    cost: i32,
};

fn parse_line(line: []const u8) Interraction {
    //"{name} would {gain|lose} {val} happiness units by sitting next to {nextname}."
    var slice = line;
    var sep = std.mem.indexOf(u8, slice, " would ");
    const name = slice[0..sep.?];
    slice = slice[sep.? + 7 ..];

    sep = std.mem.indexOf(u8, slice, " ");
    const sign = slice[0..sep.?];
    slice = slice[sep.? + 1 ..];

    sep = std.mem.indexOf(u8, slice, " happiness units by sitting next to ");
    const number = slice[0..sep.?];
    slice = slice[sep.? + 36 ..];

    sep = std.mem.indexOf(u8, slice, ".");
    const nextname = slice[0..sep.?];

    var val = std.fmt.parseInt(i32, number, 10) catch unreachable;
    if (std.mem.eql(u8, sign, "lose"))
        val = -val;

    return Interraction{ .name = name, .nextname = nextname, .cost = val };
}

fn findoradd(table: [][]const u8, nb: *u32, name: []const u8) u32 {
    var i: u32 = 0;
    while (i < nb.*) : (i += 1) {
        const c = table[i];
        if (std.mem.eql(u8, c, name))
            return i;
    }
    table[nb.*] = name;
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
    const text = try std.fs.cwd().readFileAlloc(allocator, "day13.txt", limit);

    const maxpeople = 10;
    var people: [maxpeople][]const u8 = undefined;
    var popu: u32 = 0;
    var links: [maxpeople * maxpeople]?i32 = [1]?i32{null} ** (maxpeople * maxpeople);

    var it = std.mem.tokenize(u8, text, "\n");
    while (it.next()) |line| {
        const inter = parse_line(line);
        //trace("{}\n", inter);
        const n1 = findoradd(&people, &popu, inter.name);
        const n2 = findoradd(&people, &popu, inter.nextname);
        links[n1 * maxpeople + n2] = inter.cost;
    }

    if (true) {
        const me = findoradd(&people, &popu, "me");
        var i: u32 = 0;
        while (i < popu - 1) : (i += 1) {
            links[me * maxpeople + i] = 0;
            links[i * maxpeople + me] = 0;
        }
    }

    var permutations_mem: [maxpeople]u32 = undefined;
    const perm = permutations_mem[0..popu];
    var permuts: usize = 1;
    for (perm, 0..) |p, i| {
        permuts *= (i + 1);
    }

    var best_total: i32 = 0;
    var j: u32 = 0;
    while (j < permuts) : (j += 1) {
        for (perm, 0..) |*p, i| {
            p.* = @as(u32, @intCast(i));
        }
        var mod = popu;
        var k = j;
        for (perm, 0..) |*p, i| {
            swap(p, &perm[i + k % mod]);
            k /= mod;
            mod -= 1;
        }

        var total: i32 = 0;
        for (perm, 0..) |p, i| {
            const n = if (i + 1 < perm.len) perm[i + 1] else perm[0];
            const link = links[p * maxpeople + n];
            const revlink = links[n * maxpeople + p];
            if (link) |l| {
                total += l;
            } else {
                unreachable;
            }
            if (revlink) |l| {
                total += l;
            } else {
                unreachable;
            }
        }
        if (total > best_total)
            best_total = total;
    }
    const out = std.io.getStdOut().writer();
    try out.print("pass = {}\n", best_total);

    //    return error.SolutionNotFound;
}
