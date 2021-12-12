const std = @import("std");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

const maxpackets = 32;
const Result = struct {
    qe: u64,
    s0: u32,
    progress: u32,
    targetsize: u32,
};
fn dfs(packets: []const u8, groups: [3][]const u8, best: *Result) void {
    var order: [3]u8 = undefined;
    var qe: u64 = 1;
    {
        for (groups[0]) |p| {
            qe *= @intCast(u64, p);
        }

        var m = [3]u32{ 0, 0, 0 };
        for (groups) |g, i| {
            for (g) |p| {
                m[i] += p;
            }
        }
        var mleft: u32 = 0;
        for (packets) |p| {
            mleft += p;
        }

        if (m[0] > m[1]) {
            if (m[1] > m[2]) {
                order = [3]u8{ 2, 1, 0 };
            } else if (m[0] > m[2]) {
                order = [3]u8{ 1, 2, 0 };
            } else {
                order = [3]u8{ 1, 0, 2 };
            }
        } else {
            if (m[0] > m[2]) {
                order = [3]u8{ 2, 0, 1 };
            } else if (m[1] > m[2]) {
                order = [3]u8{ 0, 2, 1 };
            } else {
                order = [3]u8{ 0, 1, 2 };
            }
        }

        const delta = (best.targetsize - m[order[1]]) + (best.targetsize - m[order[0]]);
        if (m[order[2]] > best.targetsize or delta > mleft) {
            if (best.progress > delta) {
                best.progress = delta;
                trace("progress: delta={} left={}\n", delta, mleft);
                for (groups) |g, i| {
                    trace("  group{} = [", i);
                    for (g) |p| {
                        trace("{}, ", p);
                    }
                    trace("] = {}\n", m[i]);
                }
            }
            return;
        }

        if (m[1] > m[2]) {
            order = [3]u8{ 0, 2, 1 };
        } else {
            order = [3]u8{ 0, 1, 2 };
        }
    }

    if (packets.len == 0) {
        var s0 = @intCast(u32, groups[0].len);
        if (s0 < best.s0 or (s0 == best.s0 and qe < best.qe)) {
            best.qe = qe;
            best.s0 = s0;
            best.progress = 999999999;
            trace("new best: {}\n", best.*);
            for (groups) |g, i| {
                trace("  group{} = [", i);
                for (g) |p| {
                    trace("{}, ", p);
                }
                trace("]\n");
            }
        }
    } else {
        var storage: [maxpackets]u8 = undefined;
        const newpackets = storage[0 .. packets.len - 1];

        for (packets) |p, i| {
            std.mem.copy(u8, newpackets[0..i], packets[0..i]);
            std.mem.copy(u8, newpackets[i..], packets[i + 1 ..]);

            if (groups[0].len > best.s0)
                break;
            if (groups[0].len == best.s0 and qe >= best.qe)
                break;

            for (order) |j| {
                const g = groups[j];
                if (j == 0 and g.len >= best.s0)
                    continue;

                var newgroups: [3][]const u8 = undefined;
                for (newgroups) |*ng, k| {
                    if (k == j) {
                        const newgroup = storage[packets.len .. packets.len + g.len + 1];
                        std.mem.copy(u8, newgroup, g);
                        newgroup[g.len] = p;
                        ng.* = newgroup;
                    } else {
                        ng.* = groups[k];
                    }
                }
                dfs(newpackets, newgroups, best);
            }
        }
    }
}
pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    //    const limit = 1 * 1024 * 1024 * 1024;
    //    const text = try std.fs.cwd().readFileAlloc(allocator, "day24.txt", limit);

    //const packets = [_]u8{1,2,3,4,5,7,8,9,10,11};
    //const packets = [_]u8{11,10,9,8,7,5,4,3,2,1};
    const packets = [_]u8{ 113, 109, 107, 103, 101, 97, 89, 83, 79, 73, 71, 67, 61, 59, 53, 47, 43, 41, 37, 31, 23, 19, 17, 13, 11, 7, 3, 2, 1 };
    const totalmass = blk: {
        var m: u32 = 0;
        for (packets) |p| {
            m += p;
        }
        break :blk m;
    };
    assert(totalmass % 3 == 0);

    const emptygroup = [0]u8{};
    const groups = [3][]const u8{
        &emptygroup,
        &emptygroup,
        &emptygroup,
    };

    var res = Result{ .qe = 99999999999999, .s0 = 7, .progress = 999999, .targetsize = totalmass / 3 };
    dfs(&packets, groups, &res);

    const out = std.io.getStdOut().writer();
    try out.print("res: {} \n", res);

    //    return error.SolutionNotFound;
}
