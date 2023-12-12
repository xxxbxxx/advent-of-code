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
        @memcpy(m[0..i], molecule[0..i]);
        @memcpy(m[i .. i + rule.to.len], rule.to);
        @memcpy(m[i + rule.to.len ..], molecule[i + rule.from.len ..]);
        return m;
    } else {
        return null;
    }
}

fn compute_reversemutation(molecule: []const u8, rule: Replacement, startindex: *usize, memory: []u8) ?[]const u8 {
    var idx = std.mem.indexOfPos(u8, molecule, startindex.*, rule.to);
    if (idx) |i| {
        startindex.* = i + 1;
        const m = memory[0 .. molecule.len + rule.from.len - rule.to.len];
        @memcpy(m[0..i], molecule[0..i]);
        @memcpy(m[i .. i + rule.from.len], rule.from);
        @memcpy(m[i + rule.from.len ..], molecule[i + rule.to.len ..]);
        return m;
    } else {
        return null;
    }
}

fn dfs(molecule: []const u8, rules: []const Replacement, depth: u32) usize {
    if (molecule.len == 1 and molecule[0] == 'e') {
        trace("whooohho  {}\n", depth);
        return depth;
    }

    var memory: [512]u8 = undefined;
    var min: usize = 9999;
    for (rules) |r| {
        var startindex: usize = 0;
        while (compute_reversemutation(molecule, r, &startindex, &memory)) |m| {
            const d = dfs(m, rules, depth + 1);
            if (d != 9999) {
                trace("after applying {}->{}, {}\n", r.from, r.to, molecule);
                return d;
            }
            min = if (d > min) min else d;
        }
    }
    return min;
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

    // bon en fait en dfs et en prennant le plus gros qui matche ça donne le bon resultat.
    //  mais c'est en fait que c'est pas random, et que c'est le règles d'une grammaire générative.
    var steps: usize = 0;
    steps = dfs(molecule, rules, 0);

    if (false) {
        var sets: [500]std.StringHashMap(bool) = undefined;
        for (sets) |*s| {
            s.* = std.StringHashMap(bool).init(allocator);
        }
        defer {
            for (sets) |*s| {
                s.deinit();
            }
        }

        _ = try sets[0].put(molecule, true);

        var shortest: usize = 9999999;
        while (true) {
            for (rules) |r| {
                var step: u32 = 1;
                while (true) {
                    const set = &sets[step];
                    const prevset = sets[step - 1];
                    if (prevset.count() == 0)
                        break;

                    var prevmolecules = prevset.iterator();
                    while (prevmolecules.next()) |it| {
                        const base = it.key;
                        var startindex: usize = 0;
                        var memory: [512]u8 = undefined;
                        while (compute_reversemutation(base, r, &startindex, &memory)) |m| {
                            if (m.len < shortest) {
                                shortest = m.len;
                            }
                            var dup = false;
                            for (sets[0 .. step + 1]) |s| {
                                if (set.get(m)) |_| {
                                    dup = true;
                                }
                            }
                            if (!dup) {
                                const newmol = try allocator.alloc(u8, m.len);
                                @memcpy(newmol, m);
                                _ = try set.put(newmol, true);
                            }
                        }
                    }
                    step += 1;
                }

                trace("after applying {}->{}, shotest={}\n", r.to, r.from, shortest);
                for (sets) |*s| {
                    const c = s.count();
                    trace("  {}\n", c);
                    if (c == 0)
                        break;
                }
            }
        }
    }
    const out = std.io.getStdOut().writer();
    try out.print("ans = {}\n", steps);

    //    return error.SolutionNotFound;
}
