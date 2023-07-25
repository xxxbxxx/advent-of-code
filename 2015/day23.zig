const std = @import("std");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

const Opcode = enum {
    hlf,
    tpl,
    inc,
    jmp,
    jie,
    jio,
};
const Instruction = struct {
    op: Opcode,
    reg: u1,
    off: i32,
};

fn parse_line(line: []const u8) Instruction {
    var insn: Instruction = undefined;

    var it = std.mem.tokenize(u8, line, " ,");
    if (it.next()) |opcode| {
        if (std.mem.eql(u8, opcode, "hlf")) insn.op = .hlf;
        if (std.mem.eql(u8, opcode, "tpl")) insn.op = .tpl;
        if (std.mem.eql(u8, opcode, "inc")) insn.op = .inc;
        if (std.mem.eql(u8, opcode, "jmp")) insn.op = .jmp;
        if (std.mem.eql(u8, opcode, "jie")) insn.op = .jie;
        if (std.mem.eql(u8, opcode, "jio")) insn.op = .jio;
    }
    if (insn.op != .jmp) {
        if (it.next()) |register| {
            insn.reg = if (register[0] == 'a') 0 else 1;
        }
    }
    if (insn.op == .jmp or insn.op == .jie or insn.op == .jio) {
        if (it.next()) |offset| {
            insn.off = std.fmt.parseInt(i32, offset, 10) catch unreachable;
        }
    }
    return insn;
}

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day23.txt", limit);

    var program_storage: [500]Instruction = undefined;
    var program_size: u32 = 0;
    var it = std.mem.tokenize(u8, text, "\n");
    while (it.next()) |line| {
        if (line.len == 0)
            continue;
        program_storage[program_size] = parse_line(line);
        trace("{}\n", program_storage[program_size]);
        program_size += 1;
    }
    const program = program_storage[0..program_size];

    var regs = [2]u64{ 1, 0 };
    var pc: i32 = 0;
    while (true) {
        if (pc < 0 or @as(u32, @intCast(pc)) >= program_size)
            break;
        const insn = program[@as(usize, @intCast(pc))];
        //  trace("  [{}] (a={}, b={}) \t{}\n", pc, regs[0], regs[1], insn);
        switch (insn.op) {
            .hlf => {
                regs[insn.reg] /= 2;
                pc += 1;
            },
            .tpl => {
                regs[insn.reg] *= 3;
                pc += 1;
            },
            .inc => {
                regs[insn.reg] += 1;
                pc += 1;
            },
            .jmp => {
                pc += insn.off;
            },
            .jie => {
                if (regs[insn.reg] % 2 == 0) {
                    pc += insn.off;
                } else {
                    pc += 1;
                }
            },
            .jio => {
                if (regs[insn.reg] == 1) {
                    pc += insn.off;
                } else {
                    pc += 1;
                }
            },
        }
    }

    const out = std.io.getStdOut().writer();
    try out.print("regs: a={} b={}\n", regs[0], regs[1]);

    //    return error.SolutionNotFound;
}
