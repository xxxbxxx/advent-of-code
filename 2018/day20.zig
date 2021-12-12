const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

const Vec2 = tools.Vec2;
const Map = tools.Map(u16, 1000, 1000, true);

fn tileToChar(t: u16) u8 {
    if (t < 10) return '0' + @intCast(u8, t);
    if (t < 36) return @intCast(u8, t - 10) + 'A';
    if (t == 65535) return '.';
    return '?';
}
const Avancement = struct { steps: u16, pos: Vec2 };
fn drawAlt(regex: []const u8, cur: Avancement, i: *u32, map: *Map) Avancement {
    var most = cur;

    assert(regex[i.*] == '(');
    var start = i.* + 1;
    i.* += 1;
    var parens: u32 = 1;
    while (true) : (i.* += 1) {
        const it = regex[i.*];

        if (parens == 1 and (it == '|' or it == ')')) {
            const res = draw(regex[start..i.*], cur, map);
            start = i.* + 1;
            if (res.steps > most.steps) {
                most = res;
            }
        }

        if (it == '(') {
            parens += 1;
        } else if (it == ')') {
            parens -= 1;
            if (parens == 0)
                break;
        }
    }
    assert(regex[i.*] == ')');
    return most;
}

fn draw(regex: []const u8, cur: Avancement, map: *Map) Avancement {
    if (regex.len == 0) return cur;
    var p = cur.pos;
    var s = cur.steps;
    var i: u32 = 0;
    while (i < regex.len) : (i += 1) {
        const it = regex[i];
        switch (it) {
            'N' => {
                p = p.add(Vec2.cardinal_dirs[0]);
                s += 1;
            },
            'W' => {
                p = p.add(Vec2.cardinal_dirs[1]);
                s += 1;
            },
            'E' => {
                p = p.add(Vec2.cardinal_dirs[2]);
                s += 1;
            },
            'S' => {
                p = p.add(Vec2.cardinal_dirs[3]);
                s += 1;
            },
            '(' => {
                const r = drawAlt(regex, .{ .steps = s, .pos = p }, &i, map);
                p = r.pos;
                s = r.steps;
            },
            else => unreachable,
        }
        if (map.get(p)) |cursteps| {
            if (cursteps < s) s = cursteps;
        }
        // std.debug.print("{c} => {},{}\n", .{ it, p, s });
        map.set(p, s);
    }
    //std.debug.print("{}+{} => {}\n", .{ regex, cur, s });
    return Avancement{ .steps = s, .pos = p };
}

pub fn run(input_text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const regex = blk: {
        const begin = if (std.mem.indexOfScalar(u8, input_text, '^')) |idx| idx else return error.UnsupportedInput;
        const end = if (std.mem.indexOfScalar(u8, input_text, '$')) |idx| idx else return error.UnsupportedInput;
        break :blk input_text[begin + 1 .. end];
    };

    const map = try allocator.create(Map);
    defer allocator.destroy(map);
    map.bbox = tools.BBox.empty;
    map.default_tile = 65535;
    map.fill(65535, null);

    const ans1 = ans: {
        map.set(Vec2{ .x = 0, .y = 0 }, 0);
        var result = Avancement{ .pos = Vec2{ .x = 0, .y = 0 }, .steps = 65535 };
        while (true) {
            const r = draw(regex, .{ .pos = Vec2{ .x = 0, .y = 0 }, .steps = 0 }, map);
            if (r.steps == result.steps) break;
            assert(r.steps < result.steps);
            result = r;
        }
        //var buf: [1000]u8 = undefined;
        //std.debug.print("{}\n", .{map.printToBuf(result.pos, null, tileToChar, &buf)});

        break :ans result.steps;
    };

    const ans2 = ans: {
        var it = map.iter(null);
        var count: usize = 0;
        while (it.next()) |d| {
            if (d >= 1000 and d != 65535)
                count += 1;
        }
        break :ans count;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2018/input_day20.txt", run);
