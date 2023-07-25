const std = @import("std");
const tools = @import("tools");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

fn insert(pats: anytype, in: anytype, out: anytype) !void {
    //trace("pattern bits: {} -> {}\n", .{ countones(in), countones(out) });
    const transfos2 = [_][]u8{
        &[_]u8{ 0, 1, 2, 3 }, // ident
        &[_]u8{ 1, 3, 0, 2 }, // rot 90
        &[_]u8{ 3, 2, 1, 0 }, // rot 180
        &[_]u8{ 2, 0, 3, 1 }, // rot 270
        &[_]u8{ 1, 0, 3, 2 }, // flip x
        &[_]u8{ 3, 1, 2, 0 },
        &[_]u8{ 2, 3, 0, 1 },
        &[_]u8{ 0, 2, 1, 3 },
        &[_]u8{ 2, 3, 0, 1 }, // flip y
        &[_]u8{ 0, 2, 1, 3 },
        &[_]u8{ 1, 0, 3, 2 },
        &[_]u8{ 3, 1, 2, 0 },
    };

    const transfos3 = [_][]u8{
        &[_]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8 }, // ident
        &[_]u8{ 2, 5, 8, 1, 4, 7, 0, 3, 6 }, // rot 90
        &[_]u8{ 8, 7, 6, 5, 4, 3, 2, 1, 0 }, // rot 180
        &[_]u8{ 6, 3, 0, 7, 4, 1, 8, 5, 2 }, // rot 270
        &[_]u8{ 2, 1, 0, 5, 4, 3, 8, 7, 6 }, // flip x
        &[_]u8{ 8, 5, 2, 7, 4, 1, 6, 3, 0 },
        &[_]u8{ 6, 7, 8, 3, 4, 5, 0, 1, 2 },
        &[_]u8{ 0, 3, 6, 1, 4, 7, 2, 5, 8 },
        &[_]u8{ 6, 7, 8, 3, 4, 5, 0, 1, 2 }, // flip y
        &[_]u8{ 0, 3, 6, 1, 4, 7, 2, 5, 8 },
        &[_]u8{ 2, 1, 0, 5, 4, 3, 8, 7, 6 },
        &[_]u8{ 8, 5, 2, 7, 4, 1, 6, 3, 0 },
    };

    const trans = if (in.len == 2 * 2) &transfos2 else &transfos3;
    for (trans) |t| {
        var in2 = in;
        for (t, 0..) |to, from| in2[to] = in[from];
        assert(countones(in) == countones(in2));

        if (false) {
            const s = if (in.len == 2 * 2) 2 else 3;
            trace("--- pattern=\n", .{});
            for (in2[0 .. s * s], 0..) |m, i| {
                const c: u8 = if (m == 1) '#' else '.';
                trace("{c}", .{c});
                if (i % s == s - 1)
                    trace("\n", .{});
            }
        }

        if (try pats.put(in2, out)) |prev| {
            assert(std.mem.eql(u1, &prev.value, &out));
        }
    }
}

fn countones(map: anytype) usize {
    var c: usize = 0;
    for (map) |m| c += m;
    return c;
}

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().writer();
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day21.txt", limit);
    defer allocator.free(text);

    var patterns2 = std.AutoHashMap([2 * 2]u1, [3 * 3]u1).init(allocator);
    var patterns3 = std.AutoHashMap([3 * 3]u1, [4 * 4]u1).init(allocator);
    defer patterns2.deinit();
    defer patterns3.deinit();

    {
        var rawpatterns: usize = 0;
        var it = std.mem.split(u8, text, "\n");
        while (it.next()) |line| {
            if (tools.match_pattern("{} => {}", line)) |vals| {
                rawpatterns += 1;
                const in = vals[0].name;
                const out = vals[1].name;
                if (in.len == 2 * 2 + 1 and out.len == 3 * 3 + 2) {
                    const i = [2 * 2]u1{
                        if (in[0 * 3 + 0] == '#') 1 else 0,
                        if (in[0 * 3 + 1] == '#') 1 else 0,
                        if (in[1 * 3 + 0] == '#') 1 else 0,
                        if (in[1 * 3 + 1] == '#') 1 else 0,
                    };
                    const o = [3 * 3]u1{
                        if (out[0 * 4 + 0] == '#') 1 else 0,
                        if (out[0 * 4 + 1] == '#') 1 else 0,
                        if (out[0 * 4 + 2] == '#') 1 else 0,
                        if (out[1 * 4 + 0] == '#') 1 else 0,
                        if (out[1 * 4 + 1] == '#') 1 else 0,
                        if (out[1 * 4 + 2] == '#') 1 else 0,
                        if (out[2 * 4 + 0] == '#') 1 else 0,
                        if (out[2 * 4 + 1] == '#') 1 else 0,
                        if (out[2 * 4 + 2] == '#') 1 else 0,
                    };

                    try insert(&patterns2, i, o);
                } else if (in.len == 3 * 3 + 2 and out.len == 4 * 4 + 3) {
                    const i = [3 * 3]u1{
                        if (in[0 * 4 + 0] == '#') 1 else 0,
                        if (in[0 * 4 + 1] == '#') 1 else 0,
                        if (in[0 * 4 + 2] == '#') 1 else 0,
                        if (in[1 * 4 + 0] == '#') 1 else 0,
                        if (in[1 * 4 + 1] == '#') 1 else 0,
                        if (in[1 * 4 + 2] == '#') 1 else 0,
                        if (in[2 * 4 + 0] == '#') 1 else 0,
                        if (in[2 * 4 + 1] == '#') 1 else 0,
                        if (in[2 * 4 + 2] == '#') 1 else 0,
                    };
                    const o = [4 * 4]u1{
                        if (out[0 * 5 + 0] == '#') 1 else 0,
                        if (out[0 * 5 + 1] == '#') 1 else 0,
                        if (out[0 * 5 + 2] == '#') 1 else 0,
                        if (out[0 * 5 + 3] == '#') 1 else 0,
                        if (out[1 * 5 + 0] == '#') 1 else 0,
                        if (out[1 * 5 + 1] == '#') 1 else 0,
                        if (out[1 * 5 + 2] == '#') 1 else 0,
                        if (out[1 * 5 + 3] == '#') 1 else 0,
                        if (out[2 * 5 + 0] == '#') 1 else 0,
                        if (out[2 * 5 + 1] == '#') 1 else 0,
                        if (out[2 * 5 + 2] == '#') 1 else 0,
                        if (out[2 * 5 + 3] == '#') 1 else 0,
                        if (out[3 * 5 + 0] == '#') 1 else 0,
                        if (out[3 * 5 + 1] == '#') 1 else 0,
                        if (out[3 * 5 + 2] == '#') 1 else 0,
                        if (out[3 * 5 + 3] == '#') 1 else 0,
                    };

                    try insert(&patterns3, i, o);
                } else {
                    unreachable;
                }
            }
        }

        trace("patterns: {} -> {}+{}.\n", .{ rawpatterns, patterns2.count(), patterns3.count() });
    }

    var maps = [2][]u1{ try allocator.alloc(u1, 3000 * 3000), try allocator.alloc(u1, 3000 * 3000) };
    defer for (maps) |m| allocator.free(m);

    var size: u32 = 3;
    std.mem.copy(u1, maps[0][0 .. size * size], &[_]u1{ 0, 1, 0, 0, 0, 1, 1, 1, 1 });

    var iter: u32 = 0;
    while (iter < 18) : (iter += 1) {
        const in = maps[iter % 2][0 .. size * size];
        var check_consummed: usize = 0;
        var check_produced: usize = 0;
        if (size % 2 == 0) {
            const sn = (size / 2) * 3;
            const out = maps[1 - iter % 2][0 .. sn * sn];

            var pat: [2 * 2]u1 = undefined;
            var yp: u32 = 0;
            var yn: u32 = 0;
            while (yp < size) : (yp += 2) {
                var xp: u32 = 0;
                var xn: u32 = 0;
                while (xp < size) : (xp += 2) {
                    pat[0 * 2 + 0] = in[(yp + 0) * size + (xp + 0)];
                    pat[0 * 2 + 1] = in[(yp + 0) * size + (xp + 1)];
                    pat[1 * 2 + 0] = in[(yp + 1) * size + (xp + 0)];
                    pat[1 * 2 + 1] = in[(yp + 1) * size + (xp + 1)];

                    const kv = patterns2.get(pat) orelse unreachable;
                    check_consummed += countones(kv.key);
                    check_produced += countones(kv.value);
                    const new = kv.value;

                    out[(yn + 0) * sn + (xn + 0)] = new[0 * 3 + 0];
                    out[(yn + 0) * sn + (xn + 1)] = new[0 * 3 + 1];
                    out[(yn + 0) * sn + (xn + 2)] = new[0 * 3 + 2];
                    out[(yn + 1) * sn + (xn + 0)] = new[1 * 3 + 0];
                    out[(yn + 1) * sn + (xn + 1)] = new[1 * 3 + 1];
                    out[(yn + 1) * sn + (xn + 2)] = new[1 * 3 + 2];
                    out[(yn + 2) * sn + (xn + 0)] = new[2 * 3 + 0];
                    out[(yn + 2) * sn + (xn + 1)] = new[2 * 3 + 1];
                    out[(yn + 2) * sn + (xn + 2)] = new[2 * 3 + 2];

                    xn += 3;
                }
                yn += 3;
            }
            size = sn;
        } else {
            assert(size % 3 == 0);
            const sn = (size / 3) * 4;
            const out = maps[1 - iter % 2][0 .. sn * sn];

            var pat: [3 * 3]u1 = undefined;
            var yp: u32 = 0;
            var yn: u32 = 0;
            while (yp < size) : (yp += 3) {
                var xp: u32 = 0;
                var xn: u32 = 0;
                while (xp < size) : (xp += 3) {
                    pat[0 * 3 + 0] = in[(yp + 0) * size + (xp + 0)];
                    pat[0 * 3 + 1] = in[(yp + 0) * size + (xp + 1)];
                    pat[0 * 3 + 2] = in[(yp + 0) * size + (xp + 2)];
                    pat[1 * 3 + 0] = in[(yp + 1) * size + (xp + 0)];
                    pat[1 * 3 + 1] = in[(yp + 1) * size + (xp + 1)];
                    pat[1 * 3 + 2] = in[(yp + 1) * size + (xp + 2)];
                    pat[2 * 3 + 0] = in[(yp + 2) * size + (xp + 0)];
                    pat[2 * 3 + 1] = in[(yp + 2) * size + (xp + 1)];
                    pat[2 * 3 + 2] = in[(yp + 2) * size + (xp + 2)];

                    const kv = patterns3.get(pat) orelse unreachable;
                    check_consummed += countones(kv.key);
                    check_produced += countones(kv.value);
                    const new = kv.value;

                    out[(yn + 0) * sn + (xn + 0)] = new[0 * 4 + 0];
                    out[(yn + 0) * sn + (xn + 1)] = new[0 * 4 + 1];
                    out[(yn + 0) * sn + (xn + 2)] = new[0 * 4 + 2];
                    out[(yn + 0) * sn + (xn + 3)] = new[0 * 4 + 3];
                    out[(yn + 1) * sn + (xn + 0)] = new[1 * 4 + 0];
                    out[(yn + 1) * sn + (xn + 1)] = new[1 * 4 + 1];
                    out[(yn + 1) * sn + (xn + 2)] = new[1 * 4 + 2];
                    out[(yn + 1) * sn + (xn + 3)] = new[1 * 4 + 3];
                    out[(yn + 2) * sn + (xn + 0)] = new[2 * 4 + 0];
                    out[(yn + 2) * sn + (xn + 1)] = new[2 * 4 + 1];
                    out[(yn + 2) * sn + (xn + 2)] = new[2 * 4 + 2];
                    out[(yn + 2) * sn + (xn + 3)] = new[2 * 4 + 3];
                    out[(yn + 3) * sn + (xn + 0)] = new[3 * 4 + 0];
                    out[(yn + 3) * sn + (xn + 1)] = new[3 * 4 + 1];
                    out[(yn + 3) * sn + (xn + 2)] = new[3 * 4 + 2];
                    out[(yn + 3) * sn + (xn + 3)] = new[3 * 4 + 3];

                    xn += 4;
                }
                yn += 4;
            }

            size = sn;
        }
        {
            const out = maps[1 - iter % 2][0 .. size * size];
            assert(check_consummed == countones(in));
            assert(check_produced == countones(out));

            trace("--- iter={}: {}\n", .{ iter + 1, countones(out) });
            //for (out) |m, i| {
            //    const c: u8 = if (m == 1) '#' else '.';
            //    trace("{c}", .{c});
            //    if (i % size == size - 1)
            //        trace("\n", .{});
            //}
        }
    }

    const count = countones(maps[iter % 2][0 .. size * size]);

    try stdout.print("steps={}, count={}\n", .{ iter, count });
}
