const std = @import("std");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const md5 = std.crypto.Md5.init();

    var pending = std.ArrayList(struct {
        letter: u8,
        index: usize,
    }).init(allocator);
    defer pending.deinit();

    var answers: [100]usize = undefined;
    var found: usize = 0;
    var i: u64 = 1;
    while (found < 80) : (i += 1) {
        var buflen: usize = 0;
        var buf: [100]u8 = undefined;
        var input = std.fmt.bufPrint(&buf, "jlmsuwbz{}", .{i}) catch unreachable;
        var repeat: usize = 0;
        while (repeat <= 2016) : (repeat += 1) {
            var hash: [std.crypto.Md5.digest_length]u8 = undefined;
            std.crypto.Md5.hash(input, &hash);

            buflen = 0;
            for (hash) |h| {
                _ = std.fmt.bufPrint(buf[buflen .. buflen + 2], "{x:0>2}", .{h}) catch unreachable;
                buflen += 2;
            }
            input = buf[0..buflen];
        }

        var is_first_tripplet = true;
        var seq = [5]u8{ 0, 0, 0, 0, 0 };
        for (buf[0..buflen]) |c| {
            assert(c != 0);
            seq[0] = seq[1];
            seq[1] = seq[2];
            seq[2] = seq[3];
            seq[3] = seq[4];
            seq[4] = c;
            const interresting = seq[2] == c and seq[3] == c and seq[4] == c;

            const valid = interresting and seq[0] == c and seq[1] == c;
            if (valid) {
                for (pending.items) |*it, j| {
                    if (it.letter == c and it.index + 1000 >= i and it.index != i) {
                        answers[found] = it.index;
                        found += 1;
                        try stdout.print("found key at i='{}' (pair at {}, repeated char='{c}')\n", .{ it.index, i, c });
                        it.letter = 0; // used!
                    }
                }
            }
            if (interresting and is_first_tripplet) {
                var dup = false;
                for (pending.items) |it| {
                    dup = dup or (it.letter == c and it.index == i);
                }
                assert(!dup);
                is_first_tripplet = false;
                if (!dup)
                    try pending.append(.{ .letter = c, .index = i });
            }
        }

        // enleve les périmés...
        {
            var j: usize = 0;
            var len = pending.len;
            while (j < len) {
                if (pending.at(j).index + 1000 < i) {
                    _ = pending.swapRemove(j);
                    len -= 1;
                } else {
                    j += 1;
                }
            }
        }
    }

    std.sort.sort(usize, answers[0..found], std.sort.asc(usize));
    try stdout.print("key 64 at i='{}'\n", .{answers[63]});
}
