const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub const main = tools.defaultMain("2023/day09.txt", run);

pub fn run(text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena_alloc = std.heap.ArenaAllocator.init(allocator);
    defer arena_alloc.deinit();
    const arena = arena_alloc.allocator();

    const histories = blk: {
        var hists = std.ArrayList([]const i32).init(arena);
        defer hists.deinit();

        var it = std.mem.tokenize(u8, text, "\n\r\t");
        while (it.next()) |line| {
            var hist = std.ArrayList(i32).init(arena);
            defer hist.deinit();
            try hist.ensureUnusedCapacity(text.len / 3);
            var it2 = std.mem.tokenize(u8, line, " ");
            while (it2.next()) |num| {
                const val = std.fmt.parseInt(i32, num, 10) catch continue;
                try hist.append(val);
            }
            try hists.append(try hist.toOwnedSlice());
        }

        break :blk try hists.toOwnedSlice();
    };

    const ans1 = ans: {
        var sum: i32 = 0;
        for (histories) |hist| {
            sum += try predict(allocator, hist);
        }
        break :ans sum;
    };

    const ans2 = ans: {
        var sum: i32 = 0;
        for (histories) |hist| {
            sum += try predictBack(allocator, hist);
        }
        break :ans sum;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

fn predict(allocator: std.mem.Allocator, list: []const i32) !i32 {
    const buf = try allocator.alloc(i32, list.len);
    defer allocator.free(buf);
    var stack = try std.ArrayList(i32).initCapacity(allocator, list.len);
    defer stack.deinit();

    var len = list.len - 1;
    @memcpy(buf[0 .. len + 1], list);

    // pack:
    while (len > 0) : (len -= 1) {
        var allzero = false;
        for (0..len) |i| {
            buf[i] = buf[i + 1] - buf[i];
            allzero = allzero and buf[i] == 0;
        }
        stack.appendAssumeCapacity(buf[len]);
        if (allzero) break;
    }

    // unpack
    var next: i32 = 0;
    for (stack.items) |v| next += v;
    return @intCast(next);
}

fn predictBack(allocator: std.mem.Allocator, list: []const i32) !i32 {
    const buf = try allocator.alloc(i32, list.len);
    defer allocator.free(buf);
    var stack = try std.ArrayList(i32).initCapacity(allocator, list.len);
    defer stack.deinit();

    var len = list.len - 1;
    @memcpy(buf[0 .. len + 1], list);

    // pack:
    while (len > 0) : (len -= 1) {
        var allzero = false;
        stack.appendAssumeCapacity(buf[0]);
        for (0..len) |i| {
            buf[i] = buf[i + 1] - buf[i];
            allzero = allzero and buf[i] == 0;
        }
        if (allzero) break;
    }

    // unpack
    var next: i32 = 0;
    for (1..stack.items.len + 1) |i| next = stack.items[stack.items.len - i] - next;
    return @intCast(next);
}

test {
    const res1 = try run(
        \\0 3 6 9 12 15
        \\1 3 6 10 15 21
        \\10 13 16 21 30 45
    , std.testing.allocator);
    defer std.testing.allocator.free(res1[0]);
    defer std.testing.allocator.free(res1[1]);
    try std.testing.expectEqualStrings("114", res1[0]);
    try std.testing.expectEqualStrings("2", res1[1]);
}
