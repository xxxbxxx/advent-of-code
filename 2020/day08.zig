const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

// inutilement complexe, mais avec un peu de chance servira pour des instructions plus riches...
const Insn = union(enum) {
    nop: struct { arg: i32 },
    acc: struct { arg: i32 },
    jmp: struct { arg: i32 },
};

fn runProg(prog: []const Insn, mutation: ?usize, allocator: std.mem.Allocator) !isize {
    const visited = try allocator.alloc(bool, prog.len);
    defer allocator.free(visited);
    @memset(visited, false);

    var accu: isize = 0;
    var pc: usize = 0;
    while (pc < prog.len) {
        if (visited[pc]) {
            if (mutation != null)
                return error.infiniteLoop;
            return accu;
        }
        visited[pc] = true;

        const insn = if (pc != mutation) prog[pc] else switch (prog[pc]) {
            .nop => |arg| Insn{ .jmp = .{ .arg = arg.arg } },
            .acc => |arg| Insn{ .acc = .{ .arg = arg.arg } },
            .jmp => |arg| Insn{ .nop = .{ .arg = arg.arg } },
        };

        switch (insn) {
            .nop => {
                pc += 1;
            },
            .acc => |arg| {
                accu += arg.arg;
                pc += 1;
            },
            .jmp => |arg| {
                pc = @intCast(@as(isize, @intCast(pc)) + arg.arg);
            },
        }
    }
    return accu;
}

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {

    // index by color_id
    var prog = try allocator.alloc(Insn, input.len / 6);
    defer allocator.free(prog);
    var prog_len: usize = 0;

    {
        var it = std.mem.tokenize(u8, input, "\n\r");
        while (it.next()) |line| {
            const fields = tools.match_pattern("{} {}", line) orelse unreachable;
            const opcode = fields[0].lit;
            const arg: i32 = @intCast(fields[1].imm);

            if (std.mem.eql(u8, opcode, "nop")) {
                prog[prog_len] = .{ .nop = .{ .arg = arg } };
            } else if (std.mem.eql(u8, opcode, "acc")) {
                prog[prog_len] = .{ .acc = .{ .arg = arg } };
            } else if (std.mem.eql(u8, opcode, "jmp")) {
                prog[prog_len] = .{ .jmp = .{ .arg = arg } };
            } else {
                unreachable;
            }
            prog_len += 1;
        }
    }

    const ans1 = runProg(prog[0..prog_len], null, allocator) catch unreachable;

    const ans2 = ans: {
        var mutation: usize = 0;
        while (mutation < prog.len) : (mutation += 1) {
            break :ans runProg(prog[0..prog_len], mutation, allocator) catch continue;
        }
        unreachable;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2020/input_day08.txt", run);
