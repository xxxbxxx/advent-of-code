const std = @import("std");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

fn sum(val: std.json.Value) i64 {
    switch (val) {
        else => return 0,
        .Integer => |i| return i,
        .Array => |array| {
            var s: i64 = 0;
            for (array.items) |it| {
                s += sum(it);
            }
            return s;
        },
        .Object => |obj| {
            var s: i64 = 0;
            var isred = false;
            var iterator = obj.iterator();
            while (iterator.next()) |it| {
                switch (it.value) {
                    .String => |str| {
                        if (std.mem.eql(u8, str, "red")) isred = true;
                    },
                    else => s += sum(it.value),
                }
            }
            return if (isred) 0 else s;
        },
    }
}

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day12.txt", limit);

    var json = std.json.Parser.init(allocator, false);
    defer json.deinit();

    const jsontree = try json.parse(text);

    //    var total : i32 = 0;
    //    var it = std.mem.tokenize(u8, text, "\n:[], \t{}");
    //    while (it.next()) |field| {
    //        trace("{}\n", field);
    //        const val = std.fmt.parseInt(i32, field, 10) catch continue;
    //        total += val;
    //    }

    const out = std.io.getStdOut().writer();
    try out.print("pass = {}\n", sum(jsontree.root));

    //    return error.SolutionNotFound;
}
