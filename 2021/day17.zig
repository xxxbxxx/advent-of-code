const std = @import("std");
const tools = @import("tools");

const with_trace = false;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}
const assert = std.debug.assert;

const Vec2 = tools.Vec2;
const BBox = tools.BBox;

pub const main = tools.defaultMain("2021/day17.txt", run);

fn saturate(x: i32) i32 {
    return @minimum(1, @maximum(-1, x));
}

fn hitsTarget(target: BBox, v_: Vec2) bool {
    assert(v_[0] >= 0);
    var p = Vec2{ 0, 0 };
    var v = v_;
    while (p[0] <= target.max[0] and p[1] >= target.min[1]) {
        if (target.includes(p)) return true;

        p += v;
        const accel = Vec2{ @maximum(-1, -v[0]), -1 };
        v += accel;
    }
    return false;
}

fn computeApex(v: Vec2) i32 {
    const y = v[1];
    if (y <= 0) return 0;
    return @divFloor(y * (y + 1), 2);
}

pub fn run(input: []const u8, gpa: std.mem.Allocator) tools.RunError![2][]const u8 {
    //var arena_alloc = std.heap.ArenaAllocator.init(gpa);
    //defer arena_alloc.deinit();
    //const arena = arena_alloc.allocator();

    const target = blk: {
        if (tools.match_pattern("target area: x={}..{}, y={}..{}", std.mem.trim(u8, input, "\n\r \t"))) |val| {
            break :blk BBox{
                .min = Vec2{ @intCast(i32, val[0].imm), @intCast(i32, val[2].imm) },
                .max = Vec2{ @intCast(i32, val[1].imm), @intCast(i32, val[3].imm) },
            };
        } else {
            return error.UnsupportedInput;
        }
    };

    // les deux axes sont indépendants
    //  x le plus rapide qui touche en un coup: xmax
    //  x le plus lent qui touche: (x0*(x0+1))/2=xmin -> x= (sqrt(1+8*xmin)-1)/2
    //  y le plus direct  qui touche en un coup: ymin
    //  y le plus long..mmm.  quand on reppasse par zero, c'est symétrique de la vitesse de lancement. et donc meme raisonnement, a partir de là, en un coup ymin
    const ans = ans: {
        const fastest_x = target.max[0];
        const slowest_x = (std.math.sqrt(1 + 8 * @intCast(u32, target.min[0])) - 1) / 2;
        trace("valid initial xvels={}..{}\n", .{ slowest_x, fastest_x });
        trace("              yvels={}..{}\n", .{ target.min[1], -target.min[1] });

        var v = Vec2{ slowest_x, 0 };
        var best_apex: i32 = 0;
        var hit_count: i32 = 0;
        while (v[0] <= fastest_x) : (v[0] += 1) {
            v[1] = target.min[1];
            while (v[1] <= -target.min[1]) : (v[1] += 1) {
                const hits = @boolToInt(hitsTarget(target, v));
                hit_count += hits;
                best_apex = @maximum(best_apex, hits * computeApex(v));
            }
        }

        break :ans [2]i32{ best_apex, hit_count };
    };

    return [_][]const u8{
        try std.fmt.allocPrint(gpa, "{}", .{ans[0]}),
        try std.fmt.allocPrint(gpa, "{}", .{ans[1]}),
    };
}

test {
    const res = try run("target area: x=20..30, y=-10..-5", std.testing.allocator);
    defer std.testing.allocator.free(res[0]);
    defer std.testing.allocator.free(res[1]);
    try std.testing.expectEqualStrings("45", res[0]);
    try std.testing.expectEqualStrings("112", res[1]);

    const res2 = try run("target area: x=352..377, y=-49..-30", std.testing.allocator);
    defer std.testing.allocator.free(res2[0]);
    defer std.testing.allocator.free(res2[1]);
    try std.testing.expectEqualStrings("66", res2[0]);
    try std.testing.expectEqualStrings("820", res2[1]);
}
