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

    const Action = struct {
        write: u1,
        move: i2,
        next: u4,
    };
    const State = [2]Action;

    const steps_exemple = 6;
    const states_exemple = [_]State{
        //A
        .{
            .{ .write = 1, .move = 1, .next = 1 },
            .{ .write = 0, .move = -1, .next = 1 },
        },

        //B
        .{
            .{ .write = 1, .move = -1, .next = 0 },
            .{ .write = 1, .move = 1, .next = 0 },
        },
    };
    const steps = 12656374;
    const states = [_]State{
        //A
        .{
            .{ .write = 1, .move = 1, .next = 1 },
            .{ .write = 0, .move = -1, .next = 2 },
        },

        //B
        .{
            .{ .write = 1, .move = -1, .next = 0 },
            .{ .write = 1, .move = -1, .next = 3 },
        },

        //C
        .{
            .{ .write = 1, .move = 1, .next = 3 },
            .{ .write = 0, .move = 1, .next = 2 },
        },

        //D
        .{
            .{ .write = 0, .move = -1, .next = 1 },
            .{ .write = 0, .move = 1, .next = 4 },
        },
        //E
        .{
            .{ .write = 1, .move = 1, .next = 2 },
            .{ .write = 1, .move = -1, .next = 5 },
        },
        //F
        .{
            .{ .write = 1, .move = -1, .next = 4 },
            .{ .write = 1, .move = 1, .next = 0 },
        },
    };

    var tape = [1]u1{0} ** 100000;
    var cursor: i32 = tape.len / 2;
    var state: u4 = 0;

    var step: u32 = 0;
    while (step < steps) : (step += 1) {
        const t = &tape[@intCast(usize, cursor)];
        const action = states[state][t.*];
        t.* = action.write;
        cursor += action.move;
        state = action.next;
    }

    const ones = blk: {
        var count: u32 = 0;
        for (tape) |t| {
            count += t;
        }
        break :blk count;
    };
    try stdout.print("ones = {}\n", .{ones});
}
