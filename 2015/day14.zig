const std = @import("std");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

const Carac = struct {
    name: []const u8,
    speed: u32,
    duration: u32,
    rest: u32,
};

fn parse_line(line: []const u8) Carac {
    //Rudolph can fly 22 km/s for 8 seconds, but then must rest for 165 seconds.
    var slice = line;
    var sep = std.mem.indexOf(u8, slice, " can fly ");
    const name = slice[0..sep.?];
    slice = slice[sep.? + 9 ..];

    sep = std.mem.indexOf(u8, slice, " km/s for ");
    const speed = slice[0..sep.?];
    slice = slice[sep.? + 10 ..];

    sep = std.mem.indexOf(u8, slice, " seconds, but then must rest for ");
    const duration = slice[0..sep.?];
    slice = slice[sep.? + 33 ..];

    sep = std.mem.indexOf(u8, slice, " seconds.");
    const rest = slice[0..sep.?];

    return Carac{
        .name = name,
        .speed = std.fmt.parseInt(u32, speed, 10) catch unreachable,
        .duration = std.fmt.parseInt(u32, duration, 10) catch unreachable,
        .rest = std.fmt.parseInt(u32, rest, 10) catch unreachable,
    };
}
pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day14.txt", limit);

    const maxpeople = 10;
    var reindeers: [maxpeople]Carac = undefined;
    var popu: u32 = 0;

    var it = std.mem.tokenize(u8, text, "\n");
    while (it.next()) |line| {
        reindeers[popu] = parse_line(line);
        trace("{}\n", reindeers[popu]);
        popu += 1;
    }

    var dist: [maxpeople]u32 = [1]u32{0} ** maxpeople;
    var points: [maxpeople]u32 = [1]u32{0} ** maxpeople;

    var tick: u32 = 0;
    while (tick < 2503) : (tick += 1) {
        var i: u32 = 0;
        var bestdist: u32 = 0;
        while (i < popu) : (i += 1) {
            const c = reindeers[i];
            const sleeping = (tick % (c.duration + c.rest)) >= c.duration;
            if (!sleeping)
                dist[i] += c.speed;
            if (dist[i] > bestdist)
                bestdist = dist[i];
        }
        i = 0;
        while (i < popu) : (i += 1) {
            if (dist[i] == bestdist)
                points[i] += 1;
        }
    }

    var i: u32 = 0;
    while (i < popu) : (i += 1) {
        trace("{} : {} km, {} points\n", reindeers[i].name, dist[i], points[i]);
    }

    const out = std.io.getStdOut().writer();
    try out.print("pass = {}\n", popu);

    //    return error.SolutionNotFound;
}
