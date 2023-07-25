const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

const CupIndex = u24;
const Cup = packed struct { next: CupIndex };

fn PackedArray(comptime T: type, comptime stride: usize, comptime count: usize) type {
    return struct {
        mem: [count * stride]u8,
        inline fn at(self: *@This(), i: usize) *align(1) T {
            return @as(*align(1) T, @ptrCast(&self.mem[i * stride]));
        }
    };
}

pub fn run(input_text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const cups = try allocator.create(PackedArray(Cup, 3, 1000001));
    defer allocator.destroy(cups);

    if (false) {
        // init circle
        var circle = tools.CircularBuffer(u8).init(allocator);
        defer circle.deinit();
        for (input_text) |n| {
            try circle.pushTail(n);
        }

        if (true) {
            var it = circle.iter();
            std.debug.print("circle= ", .{});
            while (it.next()) |n| std.debug.print("{c}, ", .{n});
            std.debug.print("\n", .{});
        }

        // play turns
        var turn: u32 = 1;
        while (turn <= 100) : (turn += 1) {
            const cur = circle.pop().?;
            const cup1 = circle.pop().?;
            const cup2 = circle.pop().?;
            const cup3 = circle.pop().?;
            try circle.pushHead(cur);

            const save_ptr = circle.cur.?;

            var target = cur;
            while (target == cur or target == cup1 or target == cup2 or target == cup3) {
                target = if (target > '1') target - 1 else '9';
            }
            //std.debug.print(" move: targt={c}, cups={c},{c},{c}\n", .{ target, cup1, cup2, cup3 });
            while (circle.cur.?.item != target) circle.rotate(1);

            circle.rotate(1);
            try circle.pushHead(cup3);
            try circle.pushHead(cup2);
            try circle.pushHead(cup1);

            if (true) {
                while (circle.cur.?.item != '1') circle.rotate(1);

                var it = circle.iter();
                std.debug.print("circle= ", .{});
                while (it.next()) |n| std.debug.print("{c}, ", .{n});
                std.debug.print("\n", .{});
            }

            circle.cur = save_ptr;
            circle.rotate(1);
        }

        // extract answer
        {
            var ans: [8]u8 = undefined;
            while (circle.cur.?.item != '1') circle.rotate(1);
            _ = circle.pop();
            var i: u32 = 0;
            while (circle.pop()) |n| : (i += 1) ans[i] = n;
            //       break :ans ans;
        }
    }

    const ans1 = ans: {
        // init circle
        const first: CupIndex = input_text[0] - '0';
        var prev = first;
        for (input_text) |num| {
            const n = num - '0';
            cups.at(n).next = first;
            cups.at(prev).next = n;
            prev = n;
        }
        var cursor = first;

        // play turns
        var turn: u32 = 1;
        while (turn <= 100) : (turn += 1) {
            const cup1 = cups.at(cursor).next;
            const cup2 = cups.at(cup1).next;
            const cup3 = cups.at(cup2).next;
            const next_cursor = cups.at(cup3).next;

            var target = cursor;
            while (target == cursor or target == cup1 or target == cup2 or target == cup3) {
                target = if (target > 1) target - 1 else 9;
            }

            cups.at(cup3).next = cups.at(target).next;
            cups.at(target).next = cup1;

            cups.at(cursor).next = next_cursor;
            cursor = next_cursor;
        }

        // extract answer
        {
            var ans: [8]u8 = undefined;
            var i: u32 = 0;
            var cup = cups.at(1).next;
            while (i < 8) : (i += 1) {
                ans[i] = @as(u8, @intCast(cup)) + '0';
                cup = cups.at(cup).next;
            }
            //std.debug.print("cups= {}\n", .{ans});
            break :ans ans;
        }
    };

    const ans2 = ans: {
        // init circle
        const first: CupIndex = input_text[0] - '0';
        var prev = first;
        for (input_text) |num| {
            const n = num - '0';
            cups.at(prev).next = n;
            prev = n;
        }
        var n: CupIndex = 10;
        while (n <= 1000000) : (n += 1) {
            cups.at(prev).next = n;
            prev = n;
        }
        cups.at(1000000).next = first;
        var cursor = first;

        // play turns
        var turn: u32 = 1;
        while (turn <= 10000000) : (turn += 1) {
            const cupcursor_ptr = cups.at(cursor);
            const cup1 = cupcursor_ptr.next;
            const cup2 = cups.at(cup1).next;
            const cup3 = cups.at(cup2).next;
            const cup3_ptr = cups.at(cup3);
            const next_cursor = cup3_ptr.next;

            var target = cursor;
            while (target == cursor or target == cup1 or target == cup2 or target == cup3) {
                target = if (target > 1) target - 1 else 1000000;
            }

            const cuptarget_ptr = cups.at(target);
            cup3_ptr.next = cuptarget_ptr.next;
            cuptarget_ptr.next = cup1;

            cupcursor_ptr.next = next_cursor;
            cursor = next_cursor;
        }

        {
            const cup1 = cups.at(1).next;
            const cup2 = cups.at(cup1).next;
            break :ans @as(u64, @intCast(cup1)) * @as(u64, @intCast(cup2));
        }
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{s}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    //  const limit = 1 * 1024 * 1024 * 1024;
    //  const text = try std.fs.cwd().readFileAlloc(allocator, "2020/input_day23.txt", limit);
    //  defer allocator.free(text);

    const ans = try run("156794823", allocator);
    defer allocator.free(ans[0]);
    defer allocator.free(ans[1]);

    try stdout.print("PART 1: {s}\nPART 2: {s}\n", .{ ans[0], ans[1] });
}
