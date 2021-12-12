const std = @import("std");
const tools = @import("tools");

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

    const numelves = 3005290;
    var len: usize = numelves;
    var elves = try allocator.alloc(u22, numelves);
    defer allocator.free(elves);
    {
        var i: u22 = 1;
        while (i <= numelves) : (i += 1) {
            elves[numelves - i] = i;
        }
    }

    // brute force... pleins de copies!
    {
        var victim: usize = (len - 1) / 2;
        var i: usize = 0;
        while (len > 1) {
            if (len % 2 == 0) {
                victim = (victim + 1) % len;
            } else {
                victim = victim % len;
            }

            const eliminated = if (false) // part 1
                (i + 1) % len
            else // part 2
                victim;
            //    ((i + i + len) / 2) % len;

            //trace("elf {} eliminated. remaining:", .{elves[len - 1 - eliminated]});
            //for (elves[0..len]) |e, j| {
            //    if (j == ((len - 1) - (i % (len - 1)))) {
            //        trace("|{}|,", .{e});
            //    } else if (j == ((len - 1) - (eliminated % (len - 1)))) {
            //        trace("x{}x,", .{e});
            //    } else {
            //        trace("{},", .{e});
            //    }
            //}
            //trace("\n", .{});

            assert(victim == ((i + (i + len)) / 2) % len);

            std.mem.copy(u22, elves[len - 1 - eliminated .. len - 1], elves[len - eliminated .. len]);

            len -= 1;
            if (victim >= i) {
                i = (i + 1) % len;
            } else {
                i = i % len;
            }

            if (len % 1000 == 0)
                trace("len = {}\n", .{len});
        }
    }

    try stdout.print("last elf={}\n", .{elves[0]});
}
