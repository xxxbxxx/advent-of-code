const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

const Vec2 = tools.Vec2;

fn getParens(line: []const u8) []const u8 {
    assert(line[0] == '(');
    var nb: usize = 0;
    for (line, 0..) |c, i| {
        if (c == '(') nb += 1;
        if (c == ')') {
            nb -= 1;
            if (nb == 0) return line[1..i];
        }
    }
    unreachable;
}

fn compute(line: []const u8, prio: enum { left, add }) usize {
    var l = line;

    var terms: [64]usize = undefined;
    var ops: [64]u8 = undefined;
    var nb: usize = 0;

    // std.debug.print("  examining {}...\n", .{line});

    while (l.len > 0) {
        var term: usize = undefined;
        if (l[0] == '(') {
            const par = getParens(l);
            term = compute(par, prio);
            l = l[par.len + 2 ..];
        } else if (l[0] >= '0' and l[0] <= '9') {
            term = l[0] - '0';
            l = l[1..];
        } else {
            unreachable;
        }
        if (l.len > 1) {
            assert(l[0] == ' ');
            l = l[1..];
        }

        terms[nb] = term;

        if (l.len > 1) {
            ops[nb] = l[0];
            assert(l[1] == ' ');
            l = l[2..];
        }

        nb += 1;

        // std.debug.print("  term={}, op={c} reste {}\n", .{ term, ops[nb - 1], l });
    }

    switch (prio) {
        .left => {
            var i: usize = 0;
            while (i < nb - 1) : (i += 1) {
                if (ops[i] == '+') {
                    terms[0] += terms[i + 1];
                } else if (ops[i] == '*') {
                    terms[0] *= terms[i + 1];
                } else unreachable;
            }
            nb = 1;
        },
        .add => {
            // apply '+'
            var i = nb - 1;
            while (i > 0) : (i -= 1) {
                if (ops[i - 1] == '+') {
                    terms[i - 1] += terms[i];
                    std.mem.copyForwards(usize, terms[i .. nb - 1], terms[i + 1 .. nb]);
                    std.mem.copyForwards(u8, ops[i - 1 .. nb - 2], ops[i .. nb - 1]);
                    nb -= 1;
                }
            }

            // apply '*'
            i = nb - 1;
            while (i > 0) : (i -= 1) {
                if (ops[i - 1] == '*') {
                    terms[i - 1] *= terms[i];
                    std.mem.copyForwards(usize, terms[i .. nb - 1], terms[i + 1 .. nb]);
                    std.mem.copyForwards(u8, ops[i - 1 .. nb - 2], ops[i .. nb - 1]);
                    nb -= 1;
                }
            }
        },
    }

    // std.debug.print("  ... res = {}\n", .{terms[0]});

    assert(nb == 1);
    return terms[0];
}

pub fn run(input_text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const ans1 = ans: {
        var sum: usize = 0;

        var it = std.mem.tokenize(u8, input_text, "\n\r");
        while (it.next()) |line| {
            const res = compute(std.mem.trim(u8, line, " "), .left);
            // std.debug.print("{} = {}\n", .{ res, line });
            sum += res;
        }

        break :ans sum;
    };

    const ans2 = ans: {
        var sum: usize = 0;

        var it = std.mem.tokenize(u8, input_text, "\n\r");
        while (it.next()) |line| {
            const res = compute(std.mem.trim(u8, line, " "), .add);
            // std.debug.print("{} = {}\n", .{ res, line });
            sum += res;
        }

        break :ans sum;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2020/input_day18.txt", run);
