const std = @import("std");
const tools = @import("tools");

const with_trace = false;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

const Vec3 = struct {
    x: i64,
    y: i64,
    z: i64,
};
const Part = struct {
    p: Vec3,
    v: Vec3,
    a: Vec3,
};

fn add(a: Vec3, b: Vec3) Vec3 {
    return Vec3{
        .x = a.x + b.x,
        .y = a.y + b.y,
        .z = a.z + b.z,
    };
}

fn sgn(a: i64) i2 {
    if (a < 0) return -1;
    if (a > 0) return 1;
    return 0;
}

fn same_sign(a: Vec3, b: Vec3) bool {
    return (sgn(a.x) * sgn(b.x) >= 0 and sgn(a.y) * sgn(b.y) >= 0 and sgn(a.z) * sgn(b.z) >= 0);
}

fn update(p: *Part) void {
    p.v = add(p.v, p.a);
    p.p = add(p.p, p.v);
}

fn is_stabilised(p: *const Part) bool {
    return same_sign(p.p, p.v) and same_sign(p.a, p.v);
}

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().writer();
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day20.txt", limit);
    defer allocator.free(text);

    var parts0: [1000]Part = undefined;
    var len: usize = 0;
    {
        var it = std.mem.split(u8, text, "\n");
        while (it.next()) |line| {
            //const line = std.mem.trim(u8, line0, " \n\t\r");
            //if (line.len == 0) continue;
            if (tools.match_pattern("p=<{},{},{}>, v=<{},{},{}>, a=<{},{},{}>", line)) |vals| {
                const p = &parts0[len];
                p.p = Vec3{ .x = vals[0].imm, .y = vals[1].imm, .z = vals[2].imm };
                p.v = Vec3{ .x = vals[3].imm, .y = vals[4].imm, .z = vals[5].imm };
                p.a = Vec3{ .x = vals[6].imm, .y = vals[7].imm, .z = vals[8].imm };
                len += 1;
            }
        }
    }
    try stdout.print("len={}\n", .{len});

    {
        var parts: [1000]Part = undefined;
        std.mem.copy(Part, parts[0..len], parts0[0..len]);

        var steps: u32 = 0;
        var stabilised = false;
        var closest_i: usize = 0;
        while (!stabilised) {
            steps += 1;
            stabilised = true;
            closest_i = 0;
            var closest_dist: u32 = 1000000000;
            for (parts[0..len]) |*p, i| {
                update(p);
                if (!is_stabilised(p))
                    stabilised = false;

                const d = (p.p.x * sgn(p.p.x) + p.p.y * sgn(p.p.y) + p.p.z * sgn(p.p.z));
                if (d < closest_dist) {
                    closest_dist = @intCast(u32, d);
                    closest_i = i;
                }
            }
            trace("closest_i={}\n", .{closest_i});
        }

        try stdout.print("steps={}, closest_i={}\n", .{ steps, closest_i });
    }

    {
        var parts: [1000]Part = undefined;
        var tmp: [1000]Part = undefined;
        std.mem.copy(Part, parts[0..len], parts0[0..len]);

        var steps: u32 = 0;
        var stabilised = false;
        while (!stabilised) {
            steps += 1;
            stabilised = true;
            var closest_i: usize = 0;
            var closest_dist: u32 = 1000000000;
            for (parts[0..len]) |p, i| {
                tmp[i] = p;
                update(&tmp[i]);
            }

            var l: usize = 0;
            for (tmp[0..len]) |p, i| {
                const collides = for (tmp[0..len]) |q, j| {
                    if (i != j and p.p.x == q.p.x and p.p.y == q.p.y and p.p.z == q.p.z)
                        break true;
                } else false;
                if (!collides) {
                    parts[l] = p;
                    l += 1;

                    if (!is_stabilised(&p))
                        stabilised = false;
                }
            }
            len = l;

            trace("len={}\n", .{len});
        }

        try stdout.print("steps={}, len={}\n", .{ steps, len });
    }
}
