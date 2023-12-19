const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub const main = tools.defaultMain("2023/day19.txt", run);

const WorkflowIndex = u16;
const accepted: WorkflowIndex = 0xFFF1;
const rejected: WorkflowIndex = 0xFFF0;
const Category = enum(u8) { x, m, a, s };
const Condition = enum(u8) { lt, gt };
const Rule = struct {
    cat: Category,
    cond: Condition,
    val: u16,
    send: WorkflowIndex,
};
const Workflow = struct {
    rules: []const Rule,
    finally: WorkflowIndex,

    fn toWorkflowIndex(wfs: *std.StringArrayHashMap(@This()), label: []const u8) !WorkflowIndex {
        if (std.mem.eql(u8, label, "A")) return accepted;
        if (std.mem.eql(u8, label, "R")) return rejected;
        return @intCast((try wfs.getOrPut(label)).index);
    }
};
const Part = [4]u16;

pub fn run(text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena_alloc = std.heap.ArenaAllocator.init(allocator);
    defer arena_alloc.deinit();
    const arena = arena_alloc.allocator();

    const workflows, const parts = input: {
        var wfs = std.StringArrayHashMap(Workflow).init(allocator);
        defer wfs.deinit();
        _ = try wfs.getOrPut("in"); // "in" at index zero

        var ps = std.ArrayList(Part).init(arena);
        defer ps.deinit();

        var it = std.mem.tokenize(u8, text, "\n\r\t");
        while (it.next()) |line| {
            if (tools.match_pattern("{x={},m={},a={},s={}}", line)) |vals| {
                var p: Part = undefined;
                p[@intFromEnum(Category.x)] = @intCast(vals[0].imm);
                p[@intFromEnum(Category.m)] = @intCast(vals[1].imm);
                p[@intFromEnum(Category.a)] = @intCast(vals[2].imm);
                p[@intFromEnum(Category.s)] = @intCast(vals[3].imm);
                try ps.append(p);
            } else if (tools.match_pattern("{}{{}}", line)) |vals| {
                const label = vals[0].lit;
                var rules = std.ArrayList(Rule).init(arena);
                defer rules.deinit();
                var final: ?WorkflowIndex = null;

                var it2 = std.mem.tokenize(u8, vals[1].lit, ",");
                while (it2.next()) |rule| {
                    if (tools.match_pattern("{}<{}:{}", rule)) |vals2| {
                        try rules.append(.{
                            .cat = std.meta.stringToEnum(Category, vals2[0].lit).?,
                            .cond = .lt,
                            .val = @intCast(vals2[1].imm),
                            .send = try Workflow.toWorkflowIndex(&wfs, vals2[2].lit),
                        });
                    } else if (tools.match_pattern("{}>{}:{}", rule)) |vals2| {
                        try rules.append(.{
                            .cat = std.meta.stringToEnum(Category, vals2[0].lit).?,
                            .cond = .gt,
                            .val = @intCast(vals2[1].imm),
                            .send = try Workflow.toWorkflowIndex(&wfs, vals2[2].lit),
                        });
                    } else {
                        final = try Workflow.toWorkflowIndex(&wfs, rule);
                    }
                }
                try wfs.put(label, .{ .rules = try rules.toOwnedSlice(), .finally = final.? });
            } else unreachable;
        }
        break :input .{ try arena.dupe(Workflow, wfs.values()), try ps.toOwnedSlice() };
    };

    const ans1 = ans: {
        var sum: u32 = 0;
        for (parts) |p| {
            var idx: WorkflowIndex = 0;
            while (idx != accepted and idx != rejected) {
                idx = next: for (workflows[idx].rules) |r| {
                    switch (r.cond) {
                        .lt => if (p[@intFromEnum(r.cat)] < r.val) break :next r.send,
                        .gt => if (p[@intFromEnum(r.cat)] > r.val) break :next r.send,
                    }
                } else workflows[idx].finally;
            }
            if (idx == accepted) {
                sum += p[0] + p[1] + p[2] + p[3];
            }
        }
        break :ans sum;
    };

    const ans2 = ans: {
        const full: PartRange = .{
            .{ .min = 1, .max = 4001 },
            .{ .min = 1, .max = 4001 },
            .{ .min = 1, .max = 4001 },
            .{ .min = 1, .max = 4001 },
        };
        break :ans propagate(workflows, 0, full);
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

const PartRange = [4]struct { min: u16, max: u16 };

fn propagate(workflows: []const Workflow, wf_idx: WorkflowIndex, p0: PartRange) u64 {
    // empty range?
    if (p0[0].min >= p0[0].max) return 0;
    if (p0[1].min >= p0[1].max) return 0;
    if (p0[2].min >= p0[2].max) return 0;
    if (p0[3].min >= p0[3].max) return 0;

    switch (wf_idx) {
        accepted => return @as(u64, p0[0].max - p0[0].min) * @as(u64, p0[1].max - p0[1].min) * @as(u64, p0[2].max - p0[2].min) * @as(u64, p0[3].max - p0[3].min),
        rejected => return 0,
        else => {
            var sum: u64 = 0;
            var p: PartRange = p0;
            for (workflows[wf_idx].rules) |r| {
                switch (r.cond) {
                    .lt => {
                        const range = &p[@intFromEnum(r.cat)];
                        const orig = range.*;
                        range.max = r.val;
                        sum += propagate(workflows, r.send, p);

                        range.* = orig;
                        range.min = r.val;
                    },
                    .gt => {
                        const range = &p[@intFromEnum(r.cat)];
                        const orig = range.*;
                        range.min = r.val + 1;
                        sum += propagate(workflows, r.send, p);

                        range.* = orig;
                        range.max = r.val + 1;
                    },
                }
            }
            sum += propagate(workflows, workflows[wf_idx].finally, p);
            return sum;
        },
    }
    unreachable;
}

test {
    const res1 = try run(
        \\px{a<2006:qkq,m>2090:A,rfg}
        \\pv{a>1716:R,A}
        \\lnx{m>1548:A,A}
        \\rfg{s<537:gd,x>2440:R,A}
        \\qs{s>3448:A,lnx}
        \\qkq{x<1416:A,crn}
        \\crn{x>2662:A,R}
        \\in{s<1351:px,qqz}
        \\qqz{s>2770:qs,m<1801:hdj,R}
        \\gd{a>3333:R,R}
        \\hdj{m>838:A,pv}
        \\
        \\{x=787,m=2655,a=1222,s=2876}
        \\{x=1679,m=44,a=2067,s=496}
        \\{x=2036,m=264,a=79,s=2244}
        \\{x=2461,m=1339,a=466,s=291}
        \\{x=2127,m=1623,a=2188,s=1013}
    , std.testing.allocator);
    defer std.testing.allocator.free(res1[0]);
    defer std.testing.allocator.free(res1[1]);
    try std.testing.expectEqualStrings("19114", res1[0]);
    try std.testing.expectEqualStrings("167409079868000", res1[1]);
}
