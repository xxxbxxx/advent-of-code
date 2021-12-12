const std = @import("std");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

const maxpackets = 29;
const Result = struct {
    qe: u64,
    s0: u32,
};

const Candidate = struct {
    rem0: u16,
    rem1: u16,
    rem2: u16,
    qe: u64,
    packets: u8,
    groups: [4]u8,
    storage: [maxpackets]u8 = undefined,
    next: usize = undefined,
};
const Agenda = struct {
    pool: [100000]Candidate,
    count: usize,
    first: usize,
    free: usize,
    const none: usize = 0xFFFFFFFF;
};

fn is_better(a: Candidate, b: Candidate) bool {
    if (a.rem0 < b.rem0)
        return true;
    if (a.rem0 > b.rem0)
        return false;
    if (a.groups[0] < b.groups[0])
        return true;
    if (a.groups[0] > b.groups[0])
        return true;
    if (a.qe < b.qe)
        return true;
    if (a.qe > b.qe)
        return false;

    if (a.rem1 < b.rem1)
        return true;
    if (a.rem1 > b.rem1)
        return false;
    if (a.rem2 < b.rem2)
        return true;
    if (a.rem2 > b.rem2)
        return false;
    return false;
}

fn agenda_insert(a: *Agenda, candidate: Candidate) void {
    var place = &a.first;
    while (place.* != Agenda.none and is_better(a.pool[place.*], candidate)) {
        place = &a.pool[place.*].next;
    }

    const newidx = a.free;
    const new = &a.pool[newidx];
    a.free = new.next;

    new.* = candidate;
    new.next = place.*;
    place.* = newidx;

    a.count += 1;
}

fn agenda_pop(a: *Agenda) ?Candidate {
    if (a.first == Agenda.none)
        return null;
    const idx = a.first;
    const c = a.pool[idx];
    a.first = a.pool[idx].next;
    a.pool[idx].next = a.free;
    a.free = idx;
    a.count -= 1;
    return c;
}

fn agenda_init(a: *Agenda) void {
    for (a.pool) |*it, i| {
        it.next = i + 1;
    }
    a.pool[a.pool.len - 1].next = Agenda.none;
    a.first = Agenda.none;
    a.free = 0;
    a.count = 0;
}

fn bfs(a: *Agenda, curbest: *Result) void {
    var bestrem0: u16 = 9999;
    var bestrem1: u16 = 9999;
    var bestrem2: u16 = 9999;
    var iter: u32 = 0;

    while (agenda_pop(a)) |candidate| {
        const rem0 = candidate.rem0;
        const rem1 = candidate.rem1;
        const rem2 = candidate.rem2;
        const qe = candidate.qe;
        const packets = candidate.storage[0..candidate.packets];
        const groups = [4][]const u8{
            candidate.storage[candidate.packets .. candidate.packets + candidate.groups[0]],
            candidate.storage[candidate.packets + candidate.groups[0] .. candidate.packets + candidate.groups[0] + candidate.groups[1]],
            candidate.storage[candidate.packets + candidate.groups[0] + candidate.groups[1] .. candidate.packets + candidate.groups[0] + candidate.groups[1] + candidate.groups[2]],
            candidate.storage[candidate.packets + candidate.groups[0] + candidate.groups[1] + candidate.groups[2] .. candidate.packets + candidate.groups[0] + candidate.groups[1] + candidate.groups[2] + candidate.groups[3]],
        };

        {
            var s0 = @intCast(u32, groups[0].len);
            if (s0 > curbest.s0 or (s0 == curbest.s0 and qe >= curbest.qe))
                continue;
        }

        iter += 1;
        if (rem0 < bestrem0 or rem1 < bestrem1 or rem2 < bestrem2) {
            bestrem0 = rem0;
            bestrem1 = rem1;
            bestrem2 = rem2;
            trace("progress.. rems={},{},{}, qe={} agenda={}, iter={}\n", rem0, rem1, rem2, qe, a.count, iter);
            trace("cur candidate:\n");
            for (groups) |g, i| {
                trace("  group{} = [", i);
                for (g) |p| {
                    trace("{}, ", p);
                }
                trace("]\n");
            }
        }

        var newcandidate: Candidate = undefined;

        if (rem0 > 0) {
            const g = groups[0];
            if (g.len >= curbest.s0)
                continue;

            for (packets) |p, i| {
                if (p > rem0)
                    continue;

                newcandidate.rem0 = rem0 - p;
                newcandidate.rem1 = rem1;
                newcandidate.rem2 = rem2;
                newcandidate.qe = qe * p;
                newcandidate.packets = candidate.packets - 1;
                newcandidate.groups[0] = candidate.groups[0] + 1;
                newcandidate.groups[1] = candidate.groups[1];
                newcandidate.groups[2] = candidate.groups[2];
                newcandidate.groups[3] = candidate.groups[3];

                const newpackets = newcandidate.storage[0..newcandidate.packets];
                std.mem.copy(u8, newpackets[0..i], packets[0..i]);
                std.mem.copy(u8, newpackets[i..], packets[i + 1 ..]);

                const newgroups = [4][]u8{
                    newcandidate.storage[newcandidate.packets .. newcandidate.packets + newcandidate.groups[0]],
                    newcandidate.storage[newcandidate.packets + newcandidate.groups[0] .. newcandidate.packets + newcandidate.groups[0] + newcandidate.groups[1]],
                    newcandidate.storage[newcandidate.packets + newcandidate.groups[0] + newcandidate.groups[1] .. newcandidate.packets + newcandidate.groups[0] + newcandidate.groups[1] + newcandidate.groups[2]],
                    newcandidate.storage[newcandidate.packets + newcandidate.groups[0] + newcandidate.groups[1] + newcandidate.groups[2] .. newcandidate.packets + newcandidate.groups[0] + newcandidate.groups[1] + newcandidate.groups[2] + newcandidate.groups[3]],
                };
                std.mem.copy(u8, newgroups[0][1 .. g.len + 1], g);
                newgroups[0][0] = p;

                std.mem.copy(u8, newgroups[1], groups[1]);
                std.mem.copy(u8, newgroups[2], groups[2]);
                std.mem.copy(u8, newgroups[3], groups[3]);

                agenda_insert(a, newcandidate);
            }
            continue;
        }

        if (rem1 > 0) {
            const g = groups[1];
            for (packets) |p, i| {
                if (p > rem1)
                    continue;

                newcandidate.rem0 = rem0;
                newcandidate.rem1 = rem1 - p;
                newcandidate.rem2 = rem2;
                newcandidate.qe = qe;
                newcandidate.packets = candidate.packets - 1;
                newcandidate.groups[0] = candidate.groups[0];
                newcandidate.groups[1] = candidate.groups[1] + 1;
                newcandidate.groups[2] = candidate.groups[2];
                newcandidate.groups[3] = candidate.groups[3];

                const newpackets = newcandidate.storage[0..newcandidate.packets];
                std.mem.copy(u8, newpackets[0..i], packets[0..i]);
                std.mem.copy(u8, newpackets[i..], packets[i + 1 ..]);

                const newgroups = [4][]u8{
                    newcandidate.storage[newcandidate.packets .. newcandidate.packets + newcandidate.groups[0]],
                    newcandidate.storage[newcandidate.packets + newcandidate.groups[0] .. newcandidate.packets + newcandidate.groups[0] + newcandidate.groups[1]],
                    newcandidate.storage[newcandidate.packets + newcandidate.groups[0] + newcandidate.groups[1] .. newcandidate.packets + newcandidate.groups[0] + newcandidate.groups[1] + newcandidate.groups[2]],
                    newcandidate.storage[newcandidate.packets + newcandidate.groups[0] + newcandidate.groups[1] + newcandidate.groups[2] .. newcandidate.packets + newcandidate.groups[0] + newcandidate.groups[1] + newcandidate.groups[2] + newcandidate.groups[3]],
                };
                std.mem.copy(u8, newgroups[0], groups[0]);

                std.mem.copy(u8, newgroups[1][1 .. g.len + 1], g);
                newgroups[1][0] = p;

                std.mem.copy(u8, newgroups[2], groups[2]);
                std.mem.copy(u8, newgroups[3], groups[3]);

                agenda_insert(a, newcandidate);
            }
            continue;
        }

        if (rem2 > 0) {
            const g = groups[2];
            for (packets) |p, i| {
                if (p > rem2)
                    continue;

                newcandidate.rem0 = rem0;
                newcandidate.rem1 = rem1;
                newcandidate.rem2 = rem2 - p;
                newcandidate.qe = qe;
                newcandidate.packets = candidate.packets - 1;
                newcandidate.groups[0] = candidate.groups[0];
                newcandidate.groups[1] = candidate.groups[1];
                newcandidate.groups[2] = candidate.groups[2] + 1;
                newcandidate.groups[3] = candidate.groups[3];

                const newpackets = newcandidate.storage[0..newcandidate.packets];
                std.mem.copy(u8, newpackets[0..i], packets[0..i]);
                std.mem.copy(u8, newpackets[i..], packets[i + 1 ..]);

                const newgroups = [4][]u8{
                    newcandidate.storage[newcandidate.packets .. newcandidate.packets + newcandidate.groups[0]],
                    newcandidate.storage[newcandidate.packets + newcandidate.groups[0] .. newcandidate.packets + newcandidate.groups[0] + newcandidate.groups[1]],
                    newcandidate.storage[newcandidate.packets + newcandidate.groups[0] + newcandidate.groups[1] .. newcandidate.packets + newcandidate.groups[0] + newcandidate.groups[1] + newcandidate.groups[2]],
                    newcandidate.storage[newcandidate.packets + newcandidate.groups[0] + newcandidate.groups[1] + newcandidate.groups[2] .. newcandidate.packets + newcandidate.groups[0] + newcandidate.groups[1] + newcandidate.groups[2] + newcandidate.groups[3]],
                };
                std.mem.copy(u8, newgroups[0], groups[0]);
                std.mem.copy(u8, newgroups[1], groups[1]);

                std.mem.copy(u8, newgroups[2][1 .. g.len + 1], g);
                newgroups[2][0] = p;

                std.mem.copy(u8, newgroups[3], groups[3]);

                agenda_insert(a, newcandidate);
            }
            continue;
        }
        {
            const newgroups = [4][]const u8{ groups[0], groups[1], groups[2], packets };
            var m = [4]u32{ 0, 0, 0, 0 };
            for (newgroups) |g, i| {
                for (g) |p| {
                    m[i] += p;
                }
            }
            assert(m[0] == m[1] and m[0] == m[2] and m[0] == m[3]);

            var s0 = @intCast(u32, newgroups[0].len);
            if (s0 < curbest.s0 or (s0 == curbest.s0 and qe < curbest.qe)) {
                curbest.qe = qe;
                curbest.s0 = s0;
                trace("new best: {}\n", curbest.*);
                for (newgroups) |g, i| {
                    trace("  group{} = [", i);
                    for (g) |p| {
                        trace("{}, ", p);
                    }
                    trace("]\n");
                }
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
        var m: u16 = 0;
        for (packets) |p| {
            m += p;
        }
        break :blk m;
    };
    assert(totalmass % 3 == 0 and totalmass % 4 == 0);
    const targetmass = comptime totalmass / 4;

    var agenda = try allocator.create(Agenda);
    agenda_init(agenda);

    const c0 = Candidate{
        .rem0 = targetmass,
        .rem1 = targetmass,
        .rem2 = targetmass,
        .qe = 1,
        .packets = @intCast(u8, packets.len),
        .groups = [4]u8{ 0, 0, 0, 0 },
        .storage = packets,
    };
    agenda_insert(agenda, c0);

    var res = Result{ .qe = 99999999999999, .s0 = 99 };
    bfs(agenda, &res);

    const out = std.io.getStdOut().writer();
    try out.print("res: {} \n", res);

    //    return error.SolutionNotFound;
}
