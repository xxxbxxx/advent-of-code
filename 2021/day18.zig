const std = @import("std");
const tools = @import("tools");

const with_trace = false;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}
const assert = std.debug.assert;

pub const main = tools.defaultMain("2021/day18.txt", run);

const Digit = u8;
const PAIR_MARK = @as(Digit, 0xFF);

const SnailfishNumber = [63]Digit; // maximum five levels -> 32 nums + 31 '['

const SnailfishBuilder = struct {
    n: SnailfishNumber = undefined,
    len: u32 = 0,
    fn append(self: *@This(), d: Digit) void {
        self.n[self.len] = d;
        self.len += 1;
    }
};

fn parse(str: []const u8) SnailfishNumber {
    var snail = SnailfishBuilder{};
    for (str) |c| {
        switch (c) {
            '0'...'9' => snail.append(c - '0'),
            'A'...'Z' => snail.append(10 + c - 'A'),
            '[' => snail.append(PAIR_MARK),
            else => continue,
        }
    }
    return snail.n;
}

fn print_recurse(buf: *[]u8, ptr: *[]const Digit) void {
    const d = ptr.*[0];
    ptr.* = ptr.*[1..];
    switch (d) {
        PAIR_MARK => {
            buf.*[0] = '[';
            buf.* = buf.*[1..];
            print_recurse(buf, ptr);
            buf.*[0] = ',';
            buf.* = buf.*[1..];
            print_recurse(buf, ptr);
            buf.*[0] = ']';
            buf.* = buf.*[1..];
        },
        else => |v| {
            buf.*[0] = (if (v < 10) '0' + v else 'A' + (v - 10));
            buf.* = buf.*[1..];
        },
    }
}

fn print(buf: []u8, snail: SnailfishNumber) []u8 {
    var b = buf;
    var s: []const Digit = snail[0..];
    print_recurse(&b, &s);
    return buf[0 .. @ptrToInt(b.ptr) - @ptrToInt(buf.ptr)];
}

fn magnitude_recurse(snail: SnailfishNumber, cur_digit: *u32) u32 {
    const d = snail[cur_digit.*];
    cur_digit.* += 1;
    switch (d) {
        PAIR_MARK => {
            const left = magnitude_recurse(snail, cur_digit);
            const right = magnitude_recurse(snail, cur_digit);
            return left * 3 + right * 2;
        },
        else => |v| return v,
    }
}

fn magnitude(snail: SnailfishNumber) u32 {
    var cur_digit: u32 = 0;
    return magnitude_recurse(snail, &cur_digit);
}

fn add(a: SnailfishNumber, b: SnailfishNumber) SnailfishNumber {
    var r = SnailfishBuilder{};
    r.append(PAIR_MARK);

    var len: u32 = 1;
    for (a) |d, i| {
        if (i >= len) break;
        if (d == PAIR_MARK) len += 2;
        r.append(d);
    }
    len = 1;
    for (b) |d, i| {
        if (i >= len) break;
        if (d == PAIR_MARK) len += 2;
        r.append(d);
    }
    return r.n;
}

fn equal(a: SnailfishNumber, b: SnailfishNumber) bool {
    var len: u32 = 1;
    for (a) |d, i| {
        if (i >= len) return true;
        if (a[i] != b[i]) return false;
        if (d == PAIR_MARK) len += 2;
    }
    unreachable;
}

fn explode(a: SnailfishNumber) SnailfishNumber {
    var r = SnailfishBuilder{};

    var has_exploded = false;
    var depth: u32 = 0;
    var stack: [5]u1 = undefined;
    var carry: u8 = 0;

    for (a) |d| {
        switch (d) {
            PAIR_MARK => {
                r.append(d);

                stack[depth] = 0;
                depth += 1;
            },
            else => {
                if (!has_exploded and depth == 5) {
                    if (stack[depth - 1] == 0) { //left
                        // change '[' -> 0
                        r.n[r.len - 1] = 0;

                        // find the first left number and add
                        var left = r.len - 1;
                        while (left > 0 and r.n[left - 1] == PAIR_MARK) : (left -= 1) {}
                        if (left > 0) r.n[left - 1] += d;
                    } else { //right
                        carry = d;
                        has_exploded = true;
                    }
                } else {
                    r.append(d + carry);
                    carry = 0;
                }

                while (depth > 0 and stack[depth - 1] == 1) depth -= 1;
                if (depth == 0) break;
                stack[depth - 1] += 1;
            },
        }
    }
    return r.n;
}

fn split(a: SnailfishNumber) SnailfishNumber {
    var r = SnailfishBuilder{};

    var has_split = false;

    var len: u32 = 1;
    for (a) |d, i| {
        if (i >= len) break;
        switch (d) {
            PAIR_MARK => {
                len += 2;
                r.append(d);
            },
            else => {
                if (!has_split and d > 9) {
                    has_split = true;
                    r.append(PAIR_MARK);
                    r.append(d / 2);
                    r.append(d - d / 2);
                } else {
                    r.append(d);
                }
            },
        }
    }
    return r.n;
}

fn reduce(a: SnailfishNumber) SnailfishNumber {
    var next = a;
    var cur: SnailfishNumber = undefined;
    while (true) {
        cur = next;
        next = explode(cur);
        if (equal(next, cur))
            next = split(cur);
        if (equal(next, cur))
            break;
    }
    return cur;
}

test "operations" {
    try std.testing.expect(equal( //
        add(parse("[1,2]"), parse("[[3,4],5]")), //
        parse("[[1,2],[[3,4],5]]") //
    ));

    for ([_][2][]const u8{
        .{ "[[1,2],[[3,4],5]]", "[[1,2],[[3,4],5]]" },
        .{ "[[[[[9,8],1],2],3],4]", "[[[[0,9],2],3],4]" },
        .{ "[7,[6,[5,[4,[3,2]]]]]", "[7,[6,[5,[7,0]]]]" },
        .{ "[[6,[5,[4,[3,2]]]],1]", "[[6,[5,[7,0]]],3]" },
        .{ "[[3,[2,[1,[7,3]]]],[6,[5,[4,[3,2]]]]]", "[[3,[2,[8,0]]],[9,[5,[4,[3,2]]]]]" },
        .{ "[[3,[2,[8,0]]],[9,[5,[4,[3,2]]]]]", "[[3,[2,[8,0]]],[9,[5,[7,0]]]]" },
    }) |example| {
        var buf: [100]u8 = undefined;
        trace("explode({s}) -> {s}\n", .{ example[0], print(&buf, explode(parse(example[0]))) });

        try std.testing.expect(equal(explode(parse(example[0])), parse(example[1])));
    }

    for ([_][2][]const u8{
        .{ "[[[[0,7],4],[F,[0,D]]],[1,1]]", "[[[[0,7],4],[[7,8],[0,D]]],[1,1]]" },
        .{ "[[[[0,7],4],[[7,8],[0,D]]],[1,1]]", "[[[[0,7],4],[[7,8],[0,[6,7]]]],[1,1]]" },
    }) |example| {
        var buf: [100]u8 = undefined;
        trace("split({s}) -> {s}\n", .{ example[0], print(&buf, split(parse(example[0]))) });

        try std.testing.expect(equal(split(parse(example[0])), parse(example[1])));
    }

    try std.testing.expect(equal( //
        reduce(parse("[[[[[4,3],4],4],[7,[[8,4],9]]],[1,1]]")), //
        parse("[[[[0,7],4],[[7,8],[6,0]]],[8,1]]") //
    ));

    try std.testing.expect(equal( //
        reduce(add(parse("[[2,[[7,7],7]],[[5,8],[[9,3],[0,2]]]]"), //
        parse("[[[0,[5,8]],[[1,7],[9,6]]],[[4,[1,2]],[[1,4],2]]]"))), //
        parse("[[[[7,8],[6,6]],[[6,0],[7,7]]],[[[7,8],[8,8]],[[7,9],[0,6]]]]")));

    try std.testing.expectEqual(@as(u32, 143), magnitude(parse("[[1,2],[[3,4],5]]")));
    try std.testing.expectEqual(@as(u32, 1384), magnitude(parse("[[[[0,7],4],[[7,8],[6,0]]],[8,1]]")));
    try std.testing.expectEqual(@as(u32, 445), magnitude(parse("[[[[1,1],[2,2]],[3,3]],[4,4]]")));
    try std.testing.expectEqual(@as(u32, 791), magnitude(parse("[[[[3,0],[5,3]],[4,4]],[5,5]]")));
    try std.testing.expectEqual(@as(u32, 1137), magnitude(parse("[[[[5,0],[7,4]],[5,5]],[6,6]]")));
    try std.testing.expectEqual(@as(u32, 3488), magnitude(parse("[[[[8,7],[7,7]],[[8,6],[7,7]]],[[[0,7],[6,6]],[8,7]]]")));
}

pub fn run(input: []const u8, gpa: std.mem.Allocator) tools.RunError![2][]const u8 {
    //var arena_alloc = std.heap.ArenaAllocator.init(gpa);
    //defer arena_alloc.deinit();
    //const arena = arena_alloc.allocator();

    var input_list = std.ArrayList(SnailfishNumber).init(gpa);
    defer input_list.deinit();

    var it = std.mem.tokenize(u8, input, "\n");
    while (it.next()) |line| {
        const snail = parse(line);
        try input_list.append(snail);
    }

    const ans1 = ans: {
        const zone = tools.tracy.traceEx(@src(), .{ .name = "part1" });
        defer zone.end();

        var snail_sum = input_list.items[0];
        for (input_list.items[1..]) |snail| {
            snail_sum = reduce(add(snail_sum, snail));
        }

        break :ans magnitude(snail_sum);
    };

    const ans2 = ans: {
        const zone = tools.tracy.traceEx(@src(), .{ .name = "part2" });
        defer zone.end();

        var max: u32 = 0;
        for (input_list.items) |a, i| {
            for (input_list.items) |b, j| {
                if (i == j) continue;
                max = @max(max, magnitude(reduce(add(a, b))));
            }
        }

        break :ans max;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(gpa, "{}", .{ans1}),
        try std.fmt.allocPrint(gpa, "{}", .{ans2}),
    };
}

test {
    {
        const res = try run(
            \\[[[0,[4,5]],[0,0]],[[[4,5],[2,6]],[9,5]]]
            \\[7,[[[3,7],[4,3]],[[6,3],[8,8]]]]
            \\[[2,[[0,8],[3,4]]],[[[6,7],1],[7,[1,6]]]]
            \\[[[[2,4],7],[6,[0,5]]],[[[6,8],[2,8]],[[2,1],[4,5]]]]
            \\[7,[5,[[3,8],[1,4]]]]
            \\[[2,[2,2]],[8,[8,1]]]
            \\[2,9]
            \\[1,[[[9,3],9],[[9,0],[0,7]]]]
            \\[[[5,[7,4]],7],1]
            \\[[[[4,2],2],6],[8,7]]
        , std.testing.allocator);
        defer std.testing.allocator.free(res[0]);
        defer std.testing.allocator.free(res[1]);
        try std.testing.expectEqualStrings("3488", res[0]);
        try std.testing.expectEqualStrings("3805", res[1]);
    }

    {
        const res = try run(
            \\[[[0,[5,8]],[[1,7],[9,6]]],[[4,[1,2]],[[1,4],2]]]
            \\[[[5,[2,8]],4],[5,[[9,9],0]]]
            \\[6,[[[6,2],[5,6]],[[7,6],[4,7]]]]
            \\[[[6,[0,7]],[0,9]],[4,[9,[9,0]]]]
            \\[[[7,[6,4]],[3,[1,3]]],[[[5,5],1],9]]
            \\[[6,[[7,3],[3,2]]],[[[3,8],[5,7]],4]]
            \\[[[[5,4],[7,7]],8],[[8,3],8]]
            \\[[9,3],[[9,9],[6,[4,9]]]]
            \\[[2,[[7,7],7]],[[5,8],[[9,3],[0,2]]]]
            \\[[[[5,2],5],[8,[3,7]]],[[5,[7,5]],[4,4]]]
        , std.testing.allocator);
        defer std.testing.allocator.free(res[0]);
        defer std.testing.allocator.free(res[1]);
        try std.testing.expectEqualStrings("4140", res[0]);
        try std.testing.expectEqualStrings("3993", res[1]);
    }
}
