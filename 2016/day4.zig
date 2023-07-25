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

    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day4.txt", limit);
    defer allocator.free(text);

    var totalvalidroomid: u32 = 0;
    {
        var it = std.mem.tokenize(u8, text, "\n");
        while (it.next()) |line_full| {
            const line = std.mem.trim(u8, line_full, " \n\r\t");
            if (line.len == 0)
                continue;

            var room_id: u32 = 0;
            const LetterFreq = struct {
                freq: u8,
                letter: u8,
                fn lessthan(a: @This(), b: @This()) bool {
                    if (a.freq > b.freq)
                        return true;
                    if (a.freq == b.freq and a.letter < b.letter)
                        return true;
                    return false;
                }
            };
            const checksum = line[line.len - 6 .. line.len - 1];

            var letters: [26]LetterFreq = [1]LetterFreq{.{ .letter = 0, .freq = 0 }} ** 26;
            for (line[0 .. line.len - 7]) |c| {
                if (c >= 'a' and c <= 'z') {
                    letters[c - 'a'].letter = c;
                    letters[c - 'a'].freq += 1;
                } else if (c >= '0' and c <= '9') {
                    room_id = (10 * room_id) + (c - '0');
                } else if (c == '-') {
                    continue;
                } else {
                    unreachable;
                }
            }

            std.mem.sort(LetterFreq, &letters, LetterFreq.lessthan);

            var valid = true;
            for (checksum, 0..) |c, i| {
                if (letters[i].letter != c)
                    valid = false;
            }
            if (valid) {
                totalvalidroomid += room_id;

                var decrypt: [100]u8 = undefined;

                for (line[0 .. line.len - 7], 0..) |c, i| {
                    if (c >= 'a' and c <= 'z') {
                        decrypt[i] = 'a' + @as(u8, @intCast((@as(u32, @intCast(c - 'a')) + room_id) % 26));
                    } else if (c == '-') {
                        decrypt[i] = ' ';
                    } else {
                        decrypt[i] = c;
                    }
                }
                const north = std.mem.indexOf(u8, &decrypt, "north") != null;
                const prefix = if (north) "############        " else "  ";
                try stdout.print("{}{}\n", .{ prefix, decrypt[0 .. line.len - 7] });
            }

            //trace("letters=", .{});
            //for (letters) |l| {
            //    trace("{}, ", .{l});
            //}
            //trace("\n checksum = {}, valid={}, room_id={}\n", .{ checksum, valid, room_id });
        }
    }

    try stdout.print("num={}\n", .{totalvalidroomid});

    //    return error.SolutionNotFound;
}
