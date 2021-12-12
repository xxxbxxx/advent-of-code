const std = @import("std");

const with_trace = false;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

const Vec3 = [3]i32;
fn abs(x: i32) u32 {
    return if (x >= 0) @intCast(u32, x) else @intCast(u32, -x);
}
fn length(d: Vec3) u32 {
    return abs(d[0]) + abs(d[1]) + abs(d[2]);
}

fn pgcd(_a: u64, _b: u64) u64 {
    var a = _a;
    var b = _b;
    while (b != 0) {
        var t = b;
        b = a % b;
        a = t;
    }
    return a;
}

fn ppcm(a: u64, b: u64) u64 {
    return (a * b) / pgcd(a, b);
}

const Body = struct {
    pos: Vec3,
    vel: Vec3,
    energy: u32,
};

const Axis = struct {
    pos: [4]i32,
    vel: [4]i32,
};

const Hash = std.AutoHashMap(Axis, void);

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    _ = input;
    const initial_state = [_]Body{
        .{
            .pos = .{ -7, -1, 6 },
            .vel = .{ 0, 0, 0 },
            .energy = 0,
        },
        .{
            .pos = .{ 6, -9, -9 },
            .vel = .{ 0, 0, 0 },
            .energy = 0,
        },
        .{
            .pos = .{ -12, 2, -7 },
            .vel = .{ 0, 0, 0 },
            .energy = 0,
        },
        .{
            .pos = .{ 4, -17, -12 },
            .vel = .{ 0, 0, 0 },
            .energy = 0,
        },
    };

    const part1_steps = 1000;

    var center = Vec3{ 0, 0, 0 };
    {
        var total: u32 = 0;
        for (initial_state) |it| {
            for (center) |*p, j| {
                p.* += it.pos[j];
            }
            total += length(it.pos) * length(it.vel);
        }
        trace("start: {}, {}\n", .{ total, center });
    }

    var tables = [_]Hash{ Hash.init(allocator), Hash.init(allocator), Hash.init(allocator) };
    defer {
        for (tables) |*t| {
            t.deinit();
        }
    }
    {
        for (center) |_, a| {
            const axis = Axis{
                .pos = .{ initial_state[0].pos[a], initial_state[1].pos[a], initial_state[2].pos[a], initial_state[3].pos[a] },
                .vel = .{ initial_state[0].vel[a], initial_state[1].vel[a], initial_state[2].vel[a], initial_state[3].vel[a] },
            };
            _ = try tables[a].put(axis, .{});
        }
    }
    var axis_repeat = [3]?u32{ null, null, null };

    var total_energy_at_1000: u32 = 0;
    var cur = initial_state;
    var next: [4]Body = undefined;
    var step: u32 = 1;
    while (axis_repeat[0] == null or axis_repeat[1] == null or axis_repeat[2] == null) : (step += 1) {
        var total: u32 = 0;
        for (next) |*this, i| {
            const pos = cur[i].pos;
            var vel = cur[i].vel;
            for (cur) |other| {
                for (vel) |*v, j| {
                    if (other.pos[j] > pos[j]) v.* += 1;
                    if (other.pos[j] < pos[j]) v.* -= 1;
                }
            }
            for (this.pos) |*p, j| {
                p.* = pos[j] + vel[j];
            }
            this.vel = vel;
            this.energy = length(this.pos) * length(this.vel);
            total += this.energy;
        }

        if (step == part1_steps) {
            total_energy_at_1000 = total;
        }

        for (axis_repeat) |*axr, a| {
            if (axr.*) |_|
                continue;
            const axis = Axis{
                .pos = .{ next[0].pos[a], next[1].pos[a], next[2].pos[a], next[3].pos[a] },
                .vel = .{ next[0].vel[a], next[1].vel[a], next[2].vel[a], next[3].vel[a] },
            };
            if (try tables[a].fetchPut(axis, .{})) |_| {
                axr.* = step;
                trace("REPEAT{} step n°{}  {},{},{},{}\n", .{ a, step, next[0].pos[a], next[1].pos[a], next[2].pos[a], next[3].pos[a] }); // next[0]
            }
        }

        cur = next;
    }

    const rpt_x = @as(u64, axis_repeat[0].?);
    const rpt_y = @as(u64, axis_repeat[1].?);
    const rpt_z = @as(u64, axis_repeat[2].?);
    trace("repeats:  {},{},{}\n", .{ rpt_x, rpt_y, rpt_z });
    const ppcm1 = ppcm(rpt_x, rpt_y);
    const ppcm2 = ppcm(ppcm1, rpt_z);

    trace("repeat ppcm={} -> {}\n", .{ ppcm1, ppcm2 });

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{total_energy_at_1000}),
        try std.fmt.allocPrint(allocator, "{}", .{ppcm2}),
    };
}

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const ans = try run("", allocator);
    defer allocator.free(ans[0]);
    defer allocator.free(ans[1]);

    try stdout.print("PART 1: {s}\nPART 2: {s}\n", .{ ans[0], ans[1] });
}
