const std = @import("std");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

const Attribs = enum {
    children,
    cats,
    samoyeds,
    pomeranians,
    akitas,
    vizslas,
    goldfish,
    trees,
    cars,
    perfumes,

    const asString = comptime blk: {
        var names = [1][]const u8{""} ** @memberCount(Attribs);
        for (names) |*n, i| {
            n.* = @memberName(Attribs, i);
        }
        break :blk names;
    };
};
const Aunt = struct {
    name: []const u8,
    att: [@memberCount(Attribs)]?u32,
};

fn parse_line(line: []const u8) Aunt {
    // Sue 279: perfumes: 9, cars: 8, vizslas: 2
    var aunt = Aunt{ .name = undefined, .att = [1]?u32{null} ** @memberCount(Attribs) };

    var slice = line;
    var sep = std.mem.indexOf(u8, slice, ": ");
    aunt.name = slice[0..sep.?];
    slice = slice[sep.? + 2 ..];

    while (slice.len > 0) {
        sep = std.mem.indexOf(u8, slice, ": ");
        const atrribute = slice[0..sep.?];
        slice = slice[sep.? + 2 ..];

        sep = std.mem.indexOf(u8, slice, ", ");
        const value = if (sep) |s| slice[0..s] else slice;
        slice = if (sep) |s| slice[s + 2 ..] else slice[0..0];

        var found = false;
        for (aunt.att) |*att, i| {
            if (std.mem.eql(u8, atrribute, Attribs.asString[i])) {
                found = true;
                att.* = std.fmt.parseInt(u32, value, 10) catch unreachable;
            }
        }
        assert(found);
    }

    return aunt;
}

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day16.txt", limit);

    var clues: [@memberCount(Attribs)]u32 = undefined;
    clues[@enumToInt(Attribs.children)] = 3;
    clues[@enumToInt(Attribs.cats)] = 7;
    clues[@enumToInt(Attribs.samoyeds)] = 2;
    clues[@enumToInt(Attribs.pomeranians)] = 3;
    clues[@enumToInt(Attribs.akitas)] = 0;
    clues[@enumToInt(Attribs.vizslas)] = 0;
    clues[@enumToInt(Attribs.goldfish)] = 5;
    clues[@enumToInt(Attribs.trees)] = 3;
    clues[@enumToInt(Attribs.cars)] = 2;
    clues[@enumToInt(Attribs.perfumes)] = 1;

    var it = std.mem.tokenize(u8, text, "\n");
    var combi: u32 = 1;
    while (it.next()) |line| {
        const aunt = parse_line(line);

        var ok = true;
        for (aunt.att) |att, i| {
            const e = @intToEnum(Attribs, @intCast(u4, i));
            if (att) |a| {
                ok = ok and switch (e) {
                    .cats, .trees => (a > clues[i]),
                    .pomeranians, .goldfish => (a < clues[i]),
                    else => (a == clues[i]),
                };
            }
        }
        if (ok)
            trace("{}\n", aunt);
    }

    const out = std.io.getStdOut().writer();
    try out.print("pass = {} \n", text.len);

    //    return error.SolutionNotFound;
}
