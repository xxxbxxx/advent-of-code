const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

// version "generale" pas du tout specialisée pour l'input
//  dans l'input il y a genre 2 repetitions donc genre a(b*)c(d*)  ou un truc comme ça
//  mais du coup c'est un peu lent.  -> memoize et voilà.

const Grammar = struct {
    arena: std.heap.ArenaAllocator,
    rules: []Rule,

    memoize_cache: ?MemoizeCache = null,

    const empty_rule = Grammar.Rule{ .alts = &[0]Grammar.Alternative{}, .min_len = 0 };

    const MemoizeCache = std.AutoHashMap(struct { ptr: usize, len: u8, r: u8 }, bool);

    fn init(alloc: std.mem.Allocator) !Grammar {
        var g = Grammar{
            .arena = std.heap.ArenaAllocator.init(alloc),
            .rules = undefined,
        };

        g.rules = try g.arena.allocator().alloc(Rule, 200);
        @memset(g.rules, empty_rule);

        return g;
    }
    fn deinit(self: *@This()) void {
        if (self.memoize_cache) |*memo|
            memo.deinit();
        self.arena.deinit();
    }

    fn newLit(self: *@This(), lit: []const u8) !Node {
        return Node{ .lit = try self.arena.allocator().dupe(u8, lit) };
    }
    fn newLitJoined(self: *@This(), lit1: []const u8, lit2: []const u8) !Node {
        const lit = self.arena.allocator().alloc(u8, lit1.len + lit2.len);
        std.mem.copy(u8, lit[0..lit1.len], lit1);
        std.mem.copy(u8, lit[lit1.len..], lit2);
        return Node{ .lit = lit };
    }

    fn newRuleLit(self: *@This(), lit: []const u8) !Rule {
        const alts = try self.arena.allocator().alloc(Grammar.Alternative, 1);
        const seq = try self.arena.allocator().alloc(Grammar.Node, 1);
        seq[0] = try self.newLit(lit);
        alts[0].seq = seq;
        return Rule{ .alts = alts, .min_len = @intCast(lit.len) };
    }

    fn newRuleSimple(self: *@This(), sub_rules: []const []const u8) !Rule {
        const alts = try self.arena.allocator().alloc(Grammar.Alternative, sub_rules.len);
        for (sub_rules, 0..) |s, i| {
            const seq = try self.arena.allocator().alloc(Grammar.Node, s.len);
            for (s, 0..) |r, j| {
                seq[j] = Node{ .rule = r };
            }
            alts[i].seq = seq;
        }
        return Rule{ .alts = alts, .min_len = 0 };
    }

    fn debugPrint(self: *const @This()) void {
        std.debug.print("======================================\n", .{});
        for (self.rules, 0..) |r, rule_idx| {
            if (r.alts.len == 0) continue; //empty_rule
            std.debug.print("rule n° {}: (len>={})", .{ rule_idx, r.min_len });
            for (r.alts, 0..) |a, i| {
                if (i > 0) std.debug.print("| ", .{});
                for (a.seq) |node| {
                    std.debug.print("{} ", .{node});
                }
            }
            std.debug.print("\n", .{});
        }
        std.debug.print("======================================\n", .{});
    }

    const Node = union(enum) {
        lit: []const u8,
        rule: u8,
    };
    const Alternative = struct { seq: []Node };
    const Rule = struct { alts: []Alternative, min_len: u8 };
};

fn reduce(grammar: *const Grammar, allocator: std.mem.Allocator) !Grammar {
    var g = try Grammar.init(allocator);
    errdefer g.deinit();
    {
        for (g.rules, 0..) |*r, i| {
            r.alts = try g.arena.allocator().dupe(Grammar.Alternative, grammar.rules[i].alts);
            r.min_len = 0;
            for (r.alts) |*alt| {
                alt.seq = try g.arena.allocator().dupe(Grammar.Node, alt.seq);
            }
        }
    }

    const do_inline = true;
    const do_constprop = true;
    const do_fusing = true;
    const do_distrib = true;
    const do_dce = true;
    const max_pass = ~@as(usize, 0);

    var dirty = true;
    var max_rule = g.rules.len;
    var pass: usize = 0;
    while (dirty and pass < max_pass) : (pass += 1) {
        dirty = false;

        if (false) {
            for (g.rules[0..max_rule], 0..) |r, rule_idx| {
                if (r.alts.len == 0) continue; //empty_rule
                std.debug.print("rule n° {}: ", .{rule_idx});
                for (r.alts, 0..) |a, i| {
                    if (i > 0) std.debug.print("| ", .{});
                    for (a.seq) |node| {
                        std.debug.print("{} ", .{node});
                    }
                }
                std.debug.print("\n", .{});
            }
            std.debug.print("======================================\n", .{});
        }

        next_rule: for (g.rules) |*rule| {
            if (rule.alts.len == 0) continue; // empty_rule

            if (do_inline) { // direct inlining
                if (rule.alts.len == 1 and rule.alts[0].seq.len == 1 and rule.alts[0].seq[0] == .rule) {
                    rule.alts = g.rules[rule.alts[0].seq[0].rule].alts;
                    dirty = true;
                }
            }

            for (rule.alts, 0..) |*alt, alt_idx| {
                if (do_constprop) { // constant prop:
                    next_node: for (alt.seq, 0..) |*node, node_idx| {
                        if (node.* == .rule) {
                            const sub_rule = g.rules[node.rule];
                            assert(sub_rule.alts.len > 0);
                            if (sub_rule.alts.len == 1 and sub_rule.alts[0].seq.len == 1) {
                                node.* = sub_rule.alts[0].seq[0];
                                dirty = true;
                            } else if (sub_rule.alts.len == 1) {
                                const sub_seq = sub_rule.alts[0].seq;
                                const new_seq = try g.arena.allocator().alloc(Grammar.Node, alt.seq.len + sub_seq.len - 1);
                                std.mem.copy(Grammar.Node, new_seq[0..node_idx], alt.seq[0..node_idx]);
                                std.mem.copy(Grammar.Node, new_seq[node_idx .. node_idx + sub_seq.len], sub_seq);
                                std.mem.copy(Grammar.Node, new_seq[node_idx + sub_seq.len ..], alt.seq[node_idx + 1 ..]);
                                alt.seq = new_seq;
                                dirty = true;
                                break :next_node;
                            }
                        }
                    }
                }

                if (do_fusing) { // litteral fusing
                    var i: usize = alt.seq.len - 1;
                    while (i > 0) : (i -= 1) {
                        const lhs = alt.seq[i - 1];
                        const rhs = alt.seq[i];
                        if (lhs == .lit and rhs == .lit) {
                            const new_lit = try g.arena.allocator().alloc(u8, lhs.lit.len + rhs.lit.len);
                            std.mem.copy(u8, new_lit[0..lhs.lit.len], lhs.lit);
                            std.mem.copy(u8, new_lit[lhs.lit.len..], rhs.lit);
                            alt.seq[i - 1] = Grammar.Node{ .lit = new_lit };
                            std.mem.copy(Grammar.Node, alt.seq[i .. alt.seq.len - 1], alt.seq[i + 1 ..]);
                            alt.seq.len -= 1;
                            dirty = true;
                        }
                    }
                }

                if (do_distrib) { // distribution
                    var i: usize = alt.seq.len - 1;
                    while (i > 0) : (i -= 1) {
                        const lhs = alt.seq[i - 1];
                        const rhs = alt.seq[i];
                        if (lhs == .rule and rhs == .lit) {
                            assert(g.rules[lhs.rule].alts.len > 0);
                            const nb = g.rules[lhs.rule].alts.len;

                            const new_alts = try g.arena.allocator().alloc(Grammar.Alternative, rule.alts.len + nb - 1);
                            std.mem.copy(Grammar.Alternative, new_alts[0..alt_idx], rule.alts[0..alt_idx]);
                            std.mem.copy(Grammar.Alternative, new_alts[alt_idx .. rule.alts.len - 1], rule.alts[alt_idx + 1 ..]);
                            var new_idx = rule.alts.len - 1;

                            for (g.rules[lhs.rule].alts) |sub| {
                                const new_seq = try g.arena.allocator().alloc(Grammar.Node, alt.seq.len + sub.seq.len - 1);
                                std.mem.copy(Grammar.Node, new_seq[0 .. i - 1], alt.seq[0 .. i - 1]);
                                std.mem.copy(Grammar.Node, new_seq[i - 1 .. i - 1 + sub.seq.len], sub.seq);
                                std.mem.copy(Grammar.Node, new_seq[i - 1 + sub.seq.len ..], alt.seq[i..]);
                                new_alts[new_idx].seq = new_seq;
                                new_idx += 1;
                            }
                            assert(new_idx == new_alts.len);
                            rule.alts = new_alts;
                            dirty = true;
                            continue :next_rule; // cur rule.alts changed...
                        } else if (lhs == .lit and rhs == .rule) {
                            assert(g.rules[rhs.rule].alts.len > 0);
                            const nb = g.rules[rhs.rule].alts.len;

                            const new_alts = try g.arena.allocator().alloc(Grammar.Alternative, rule.alts.len + nb - 1);
                            std.mem.copy(Grammar.Alternative, new_alts[0..alt_idx], rule.alts[0..alt_idx]);
                            std.mem.copy(Grammar.Alternative, new_alts[alt_idx .. rule.alts.len - 1], rule.alts[alt_idx + 1 ..]);
                            var new_idx = rule.alts.len - 1;

                            for (g.rules[rhs.rule].alts) |sub| {
                                const new_seq = try g.arena.allocator().alloc(Grammar.Node, alt.seq.len + sub.seq.len - 1);
                                std.mem.copy(Grammar.Node, new_seq[0..i], alt.seq[0..i]);
                                std.mem.copy(Grammar.Node, new_seq[i .. i + sub.seq.len], sub.seq);
                                std.mem.copy(Grammar.Node, new_seq[i + sub.seq.len ..], alt.seq[i + 1 ..]);
                                new_alts[new_idx].seq = new_seq;
                                new_idx += 1;
                            }
                            assert(new_idx == new_alts.len);
                            rule.alts = new_alts;
                            dirty = true;
                            continue :next_rule; // cur rule.alts changed...
                        }
                    }
                }
            }
        }

        {
            for (g.rules[0..max_rule]) |*r| {
                if (r.alts.len == 0) continue; //empty_rule
                var min_len: u8 = 255;
                for (r.alts) |a| {
                    var seq_len: usize = 0;
                    for (a.seq) |n| {
                        seq_len += if (n == .rule) g.rules[n.rule].min_len else n.lit.len;
                    }
                    if (seq_len < min_len) {
                        min_len = @intCast(seq_len);
                    }
                }
                if (r.min_len < min_len) {
                    r.min_len = min_len;
                    dirty = true;
                }
            }
        }

        if (do_dce) { // dce
            max_rule = 0;
            var used = [_]bool{false} ** 200;
            used[0] = true; // pin entry-point
            for (g.rules) |r| {
                for (r.alts) |a| {
                    for (a.seq) |n| {
                        if (n == .rule) used[n.rule] = true;
                    }
                }
            }

            for (g.rules, 0..) |*r, i| {
                if (!used[i]) {
                    r.* = Grammar.empty_rule;
                } else {
                    max_rule = i + 1;
                    assert(r.alts.len > 0);
                }
            }
        }
    }

    if (false) {
        g.debugPrint();
    }
    return g;
}

fn matchSeq(text: []const u8, seq: []const Grammar.Node, grammar: *Grammar) bool {
    if (seq.len == 0) {
        return (text.len == 0);
    }

    //std.debug.print("    {} vs {}\n", .{ text, seq[0] });
    switch (seq[0]) {
        .lit => |l| {
            if (!std.mem.startsWith(u8, text, l))
                return false;
            return matchSeq(text[l.len..], seq[1..], grammar);
        },
        .rule => |sub| {
            const min_len_rest = blk: {
                var l: usize = 0;
                for (seq[1..]) |s| {
                    switch (s) {
                        .lit => |lit| l += lit.len,
                        .rule => |r| l += grammar.rules[r].min_len,
                    }
                }
                break :blk l;
            };
            if (text.len < min_len_rest) return false;

            var sub_len: usize = grammar.rules[sub].min_len;
            while (sub_len <= text.len - min_len_rest) : (sub_len += 1) {
                if (match(text[0..sub_len], sub, grammar) and matchSeq(text[sub_len..], seq[1..], grammar)) {
                    return true;
                }
            }
            return false;
        },
    }
}

fn match(text: []const u8, r: u8, g: *Grammar) bool {
    if (text.len < g.rules[r].min_len) return false;

    if (g.memoize_cache == null) {
        g.memoize_cache = Grammar.MemoizeCache.init(g.arena.allocator());
    }

    if (g.memoize_cache) |*memo| {
        if (memo.get(.{ .ptr = @intFromPtr(text.ptr), .len = @intCast(text.len), .r = r })) |v|
            return v;
    }

    const ok = for (g.rules[r].alts) |alt| {
        if (matchSeq(text, alt.seq, g))
            break true;
    } else false;

    if (g.memoize_cache) |*memo| {
        memo.put(.{ .ptr = @intFromPtr(text.ptr), .len = @intCast(text.len), .r = r }, ok) catch unreachable;
    }
    return ok;
}

pub fn run(input_text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var grammar = try Grammar.init(allocator);
    defer grammar.deinit();

    const param: struct {
        mesgs: [][]const u8,
    } = blk: {
        var mesgs = std.ArrayList([]const u8).init(arena.allocator());
        const rules = grammar.rules;

        var it = std.mem.tokenize(u8, input_text, "\n\r");
        while (it.next()) |line| {
            if (tools.match_pattern("{}: \"{}\"", line)) |fields| { //44: "a"
                const name: u8 = @intCast(fields[0].imm);
                const lit = fields[1].lit;
                assert(lit.len == 1);
                assert(rules[name].alts.len == 0);
                rules[name] = try grammar.newRuleLit(lit);
            } else if (tools.match_pattern("{}: {} {} | {} {}", line)) |fields| { //44: 82 117 | 26 54
                const name: u8 = @as(u8, @intCast(fields[0].imm));
                const r0: u8 = @as(u8, @intCast(fields[1].imm));
                const r1: u8 = @as(u8, @intCast(fields[2].imm));
                const r2: u8 = @as(u8, @intCast(fields[3].imm));
                const r3: u8 = @as(u8, @intCast(fields[4].imm));
                assert(rules[name].alts.len == 0);
                rules[name] = try grammar.newRuleSimple(&[_][]const u8{ &[_]u8{ r0, r1 }, &[_]u8{ r2, r3 } });
            } else if (tools.match_pattern("{}: {} | {}", line)) |fields| { //44: 82 | 54
                const name: u8 = @intCast(fields[0].imm);
                const r0: u8 = @intCast(fields[1].imm);
                const r1: u8 = @intCast(fields[2].imm);
                assert(rules[name].alts.len == 0);
                rules[name] = try grammar.newRuleSimple(&[_][]const u8{ &[_]u8{r0}, &[_]u8{r1} });
            } else if (tools.match_pattern("{}: {} {}", line)) |fields| { //44: 82 117
                const name: u8 = @intCast(fields[0].imm);
                const r0: u8 = @intCast(fields[1].imm);
                const r1: u8 = @intCast(fields[2].imm);
                assert(rules[name].alts.len == 0);
                rules[name] = try grammar.newRuleSimple(&[_][]const u8{&[_]u8{ r0, r1 }});
            } else if (tools.match_pattern("{}: {}", line)) |fields| { //44: 82
                const name: u8 = @intCast(fields[0].imm);
                const r0: u8 = @intCast(fields[1].imm);
                assert(rules[name].alts.len == 0);
                rules[name] = try grammar.newRuleSimple(&[_][]const u8{&[_]u8{r0}});
            } else {
                assert(std.mem.indexOfScalar(u8, line, ':') == null);
                try mesgs.append(line);
            }
        }

        //grammar.debugPrint();

        break :blk .{
            .mesgs = mesgs.items,
        };
    };

    const ans1 = ans: {
        var g = try reduce(&grammar, allocator);
        defer g.deinit();

        var nb: usize = 0;
        for (param.mesgs) |msg| {
            if (match(msg, 0, &g))
                nb += 1;
        }
        break :ans nb;
    };

    const ans2 = ans: {
        // 8: 42 | 42 8
        // 11: 42 31 | 42 11 31
        grammar.rules[8] = try grammar.newRuleSimple(&[_][]const u8{ &[_]u8{42}, &[_]u8{ 42, 8 } });
        grammar.rules[11] = try grammar.newRuleSimple(&[_][]const u8{ &[_]u8{ 42, 31 }, &[_]u8{ 42, 11, 31 } });

        var g = try reduce(&grammar, allocator);
        defer g.deinit();

        var nb: usize = 0;
        for (param.mesgs) |msg| {
            if (match(msg, 0, &g)) nb += 1;
        }
        break :ans nb;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2020/input_day19.txt", run);
