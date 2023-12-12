const std = @import("std");
const tools = @import("tools");

fn run_program(prg: []const u32, verb: u32, noun: u32) u32 {
    var mem: [512]u32 = undefined;
    @memcpy(&mem, prg);
    mem[1] = noun;
    mem[2] = verb;

    var done = false;
    var pc: u32 = 0;
    while (!done) {
        const opcode = mem[pc + 0];
        const p0 = mem[pc + 1];
        const p1 = mem[pc + 2];
        const p2 = mem[pc + 3];
        pc += 4;
        switch (opcode) {
            99 => done = true,
            1 => mem[p2] = mem[p1] + mem[p0],
            2 => mem[p2] = mem[p1] * mem[p0],
            else => unreachable,
        }
    }

    return mem[0];
}

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var mem: [512]u32 = undefined;
    var len: usize = 0;
    {
        var it = std.mem.tokenize(u8, input, ", \n\r\t");
        while (it.next()) |tok| {
            mem[len] = try std.fmt.parseInt(u32, tok, 10);
            len += 1;
        }
    }

    const ans1 = run_program(&mem, 2, 12);

    const ans2 = part2: {
        var verb: u32 = 0;
        while (verb < 100) : (verb += 1) {
            var noun: u32 = 0;
            while (noun < 100) : (noun += 1) {
                const val = run_program(&mem, verb, noun);
                if (val == 19690720) {
                    break :part2 (100 * noun + verb);
                }
            }
        }
        unreachable;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2019/day02.txt", run);
