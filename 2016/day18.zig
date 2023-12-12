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

    const initvector = "." ++ ".^^.^^^..^.^..^.^^.^^^^.^^.^^...^..^...^^^..^^...^..^^^^^^..^.^^^..^.^^^^.^^^.^...^^^.^^.^^^.^.^^.^." ++ ".";
    const len = initvector.len;
    var prevline: [len]u8 = undefined;
    @memcpy(&prevline, initvector);

    var numsafe: u32 = blk: {
        var c: u32 = 0;
        for (initvector[1 .. len - 1]) |t| {
            if (t == '.') c += 1;
        }
        break :blk c;
    };

    var iline: u32 = 1;
    while (iline < 400000) : (iline += 1) {
        var line: [len]u8 = undefined;
        line[0] = '.';
        line[line.len - 1] = '.';
        for (line[1 .. len - 1], 0..) |*c, i| {
            const left = prevline[i + 0] == '^';
            const center = prevline[i + 1] == '^';
            const right = prevline[i + 2] == '^';
            const trap = ((center and left and !right) or (center and right and !left) or (left and !center and !right) or (right and !center and !left));
            c.* = if (trap) '^' else '.';
            if (!trap)
                numsafe += 1;
        }
        trace("{}: {} [{}]\n", .{ iline, line[1 .. len - 1], numsafe });
        prevline = line;
    }

    try stdout.print("safe={}\n", .{numsafe});
}
