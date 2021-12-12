const std = @import("std");
const tools = @import("tools");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

const Arg = union(enum) {
    reg: u2,
    imm: i32,
};

pub fn match_insn(comptime pattern: []const u8, text: []const u8) ?[2]Arg {
    if (tools.match_pattern(pattern, text)) |vals| {
        var count: usize = 0;
        var values: [2]Arg = undefined;
        for (values) |*v, i| {
            switch (vals[i]) {
                .imm => |imm| v.* = .{ .imm = imm },
                .name => |name| v.* = .{ .reg = @intCast(u2, name[0] - 'a') },
            }
        }
        return values;
    }
    return null;
}

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day12.txt", limit);
    defer allocator.free(text);

    const Opcode = enum {
        cpy,
        add,
        jnz,
    };

    const Insn = struct {
        opcode: Opcode,
        arg: [2]Arg,
    };

    var program: [500]Insn = undefined;
    var program_len: usize = 0;

    var it = std.mem.tokenize(u8, text, "\n");
    while (it.next()) |line| {
        if (match_insn("cpy {} {}", line)) |vals| {
            trace("cpy {} {}\n", .{ vals[0], vals[1] });
            program[program_len].opcode = .cpy;
            program[program_len].arg[0] = vals[0];
            program[program_len].arg[1] = vals[1];
            program_len += 1;
        } else if (match_insn("inc {}", line)) |vals| {
            trace("inc {}\n", .{vals[0]});
            program[program_len].opcode = .add;
            program[program_len].arg[0] = Arg{ .imm = 1 };
            program[program_len].arg[1] = vals[0];
            program_len += 1;
        } else if (match_insn("dec {}", line)) |vals| {
            trace("dec {}\n", .{vals[0]});
            program[program_len].opcode = .add;
            program[program_len].arg[0] = Arg{ .imm = -1 };
            program[program_len].arg[1] = vals[0];
            program_len += 1;
        } else if (match_insn("jnz {} {}", line)) |vals| {
            trace("jnz {} {}\n", .{ vals[0], vals[1] });
            program[program_len].opcode = .jnz;
            program[program_len].arg[0] = vals[0];
            program[program_len].arg[1] = vals[1];
            program_len += 1;
        } else {
            trace("skipping {}\n", .{line});
        }
    }

    const Computer = struct {
        pc: usize,
        regs: [4]i32,
    };
    var c = Computer{ .pc = 0, .regs = [_]i32{ 0, 0, 1, 0 } };

    while (c.pc < program_len) {
        const insn = &program[c.pc];
        switch (insn.opcode) {
            .cpy => {
                c.regs[insn.arg[1].reg] = switch (insn.arg[0]) {
                    .imm => |imm| imm,
                    .reg => |reg| c.regs[reg],
                };
                c.pc += 1;
            },
            .add => {
                c.regs[insn.arg[1].reg] += switch (insn.arg[0]) {
                    .imm => |imm| imm,
                    .reg => |reg| c.regs[reg],
                };
                c.pc += 1;
            },
            .jnz => {
                const val = switch (insn.arg[0]) {
                    .imm => |imm| imm,
                    .reg => |reg| c.regs[reg],
                };
                if (val != 0) {
                    c.pc = @intCast(usize, @intCast(i32, c.pc) + insn.arg[1].imm);
                } else {
                    c.pc += 1;
                }
            },
        }
    }
    try stdout.print("a = {}\n", .{c.regs[0]});
}
