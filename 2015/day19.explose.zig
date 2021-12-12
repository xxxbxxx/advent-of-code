const std = @import("std");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

const Replacement = struct {
    from: []const u8,
    to: []const u8,
};

fn parse_line(line: []const u8) ?Replacement {
    // H => HO
    const trimmed = std.mem.trim(u8, line, " \n\r\t");
    var sep = std.mem.indexOf(u8, trimmed, " => ");
    if (sep) |s| {
        return Replacement{ .from = line[0..s], .to = line[s + 4 ..] };
    } else {
        return null;
    }
}

fn compute_mutation(molecule: []const u8, rule: Replacement, startindex: *usize, allocator: std.mem.Allocator) !?[]const u8 {
    var idx = std.mem.indexOfPos(u8, molecule, startindex.*, rule.from);
    if (idx) |i| {
        startindex.* = i + 1;
        const m = try allocator.alloc(u8, molecule.len + rule.to.len - rule.from.len);
        std.mem.copy(u8, m[0..i], molecule[0..i]);
        std.mem.copy(u8, m[i .. i + rule.to.len], rule.to);
        std.mem.copy(u8, m[i + rule.to.len ..], molecule[i + rule.from.len ..]);
        return m;
    } else {
        return null;
    }
}

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day19.txt", limit);
    const molecule = "CRnCaCaCaSiRnBPTiMgArSiRnSiRnMgArSiRnCaFArTiTiBSiThFYCaFArCaCaSiThCaPBSiThSiThCaCaPTiRnPBSiThRnFArArCaCaSiThCaSiThSiRnMgArCaPTiBPRnFArSiThCaSiRnFArBCaSiRnCaPRnFArPMgYCaFArCaPTiTiTiBPBSiThCaPTiBPBSiRnFArBPBSiRnCaFArBPRnSiRnFArRnSiRnBFArCaFArCaCaCaSiThSiThCaCaPBPTiTiRnFArCaPTiBSiAlArPBCaCaCaCaCaSiRnMgArCaSiThFArThCaSiThCaSiRnCaFYCaSiRnFYFArFArCaSiRnFYFArCaSiRnBPMgArSiThPRnFArCaSiRnFArTiRnSiRnFYFArCaSiRnBFArCaSiRnTiMgArSiThCaSiThCaFArPRnFArSiRnFArTiTiTiTiBCaCaSiRnCaCaFYFArSiThCaPTiBPTiBCaSiThSiRnMgArCaF";

    var rules_mem: [1000]Replacement = undefined;
    var rules = rules_mem[0..0];
    {
        var it = std.mem.tokenize(u8, text, "\n");
        while (it.next()) |line| {
            const newrule = parse_line(line);
            if (newrule) |r| {
                trace("rule= {} -> {}\n", r.from, r.to);
                rules = rules_mem[0 .. rules.len + 1];
                rules[rules.len - 1] = r;
            }
        }
    }

    var sets = [_]std.StringHashMap(bool){ std.StringHashMap(bool).init(allocator), std.StringHashMap(bool).init(allocator) };
    defer sets[0].deinit();
    defer sets[1].deinit();
    try sets[0].ensureTotalCapacity(100000);
    try sets[1].ensureTotalCapacity(100000);

    var steps: u32 = 0;
    _ = try sets[0].put("e", true);

    while (true) {
        var minlen: usize = 99999999;
        var maxlen: usize = 0;
        steps += 1;
        const set = &sets[steps % 2];
        set.clear();
        var prevmolecules = sets[1 - steps % 2].iterator();
        while (prevmolecules.next()) |it| {
            const base = it.key;
            for (rules) |r| {
                var startindex: usize = 0;
                while (try compute_mutation(base, r, &startindex, allocator)) |m| {
                    minlen = if (m.len < minlen) m.len else minlen;
                    maxlen = if (m.len > maxlen) m.len else maxlen;
                    _ = try set.put(m, true);
                }
            }
        }

        trace("step{}: {} mutations  {} .. {}\n", steps, set.count(), minlen, maxlen);

        if (set.get(molecule)) |m| {
            break;
        }
    }

    const out = std.io.getStdOut().writer();
    try out.print("ans = {}\n", steps);

    //    return error.SolutionNotFound;
}
