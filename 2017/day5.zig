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

    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day5.txt", limit);
    defer allocator.free(text);

    var offsets: [2000]i32 = undefined;
    var len: usize = 0;

    var it = std.mem.split(u8, text, "\n");
    while (it.next()) |line0| {
        const line = std.mem.trim(u8, line0, " \n\t\r");
        if (line.len == 0) continue;
        const val = std.fmt.parseInt(i32, line, 10) catch unreachable;
        offsets[len] = val;
        len += 1;
    }

    var steps: u32 = 0;
    var pc: isize = 0;
    while (pc >= 0 and pc < len) {
        const jmp = &offsets[@as(usize, @intCast(pc))];
        pc += jmp.*;
        if (jmp.* >= 3) {
            jmp.* -= 1;
        } else {
            jmp.* += 1;
        }

        steps += 1;
    }
    try stdout.print("steps={}\n", .{steps});

    //    return error.SolutionNotFound;
}
