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

    const key = "wtnhxymk";

    var buf: [100]u8 = undefined;
    var hash: [std.crypto.Md5.digest_length]u8 = undefined;

    var answer_text: [8]u8 = [1]u8{'_'} ** 8;
    var answer_cursor: u32 = 0;
    var i: u64 = 1;
    while (true) : (i += 1) {
        const input = std.fmt.bufPrint(&buf, "wtnhxymk{}", .{i}) catch unreachable;
        std.crypto.Md5.hash(input, &hash);

        if (hash[0] == 0 and hash[1] == 0 and hash[2] < 16) {
            trace("{} i={}\n", .{ answer_text[0..], i });

            //answer_text[answer_cursor] = if (hash[2] < 10) hash[2] + '0' else hash[2] + 'a' - 10;
            const pos = hash[2];
            if (pos >= 8)
                continue;
            if (answer_text[pos] != '_')
                continue;
            answer_text[pos] = if (hash[3] / 16 < 10) (hash[3] / 16) + '0' else (hash[3] / 16) + 'a' - 10;
            trace("{} i={}\n", .{ answer_text[0..], i });
            answer_cursor += 1;
            if (answer_cursor == 8)
                break;
        }

        if (i % (1024 * 1024) == 0) {
            trace("{} i={}\n", .{ answer_text[0..], i });
        }
    }

    try stdout.print("answer='{}'\n", .{&answer_text});

    //    return error.SolutionNotFound;
}
