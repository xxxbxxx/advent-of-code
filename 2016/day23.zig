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
    comptime const argcount = blk: {
        var it = std.mem.split(u8, pattern, "{}");
        var c: usize = 0;
        while (it.next()) |part| {
            c += 1;
        }
        break :blk c - 1;
    };

    if (tools.match_pattern(pattern, text)) |vals| {
        var count: usize = 0;
        var values: [2]Arg = undefined;
        for (values[0..argcount], 0..) |*v, i| {
            switch (vals[i]) {
                .imm => |imm| v.* = .{ .imm = @as(i32, @intCast(imm)) },
                .name => |name| v.* = .{ .reg = @as(u2, @intCast(name[0] - 'a')) },
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
    const text = try std.fs.cwd().readFileAlloc(allocator, "day23.txt", limit);
    defer allocator.free(text);

    const Opcode = enum {
        cpy,
        add,
        jnz,
        tgl,
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
        } else if (match_insn("tgl {}", line)) |vals| {
            trace("tgl {}\n", .{vals[0]});
            program[program_len].opcode = .tgl;
            program[program_len].arg[0] = Arg{ .imm = 1 };
            program[program_len].arg[1] = vals[0];
            program_len += 1;
        } else {
            trace("skipping {}\n", .{line});
        }
    }

    const Computer = struct {
        pc: usize,
        regs: [4]i32,
    };
    var c = Computer{ .pc = 0, .regs = [_]i32{ 12, 0, 0, 0 } };

    while (c.pc < program_len) {
        const insn = &program[c.pc];
        //trace("executing {} {} {}\n", .{ insn.opcode, insn.arg[0], insn.arg[1] });

        switch (insn.opcode) {
            .cpy => {
                if (insn.arg[1] == .reg) {
                    c.regs[insn.arg[1].reg] = switch (insn.arg[0]) {
                        .imm => |imm| imm,
                        .reg => |reg| c.regs[reg],
                    };
                }
                c.pc += 1;
            },
            .add => {
                if (insn.arg[1] == .reg) {
                    c.regs[insn.arg[1].reg] += switch (insn.arg[0]) {
                        .imm => |imm| imm,
                        .reg => |reg| c.regs[reg],
                    };
                }
                c.pc += 1;
            },
            .jnz => {
                const val = switch (insn.arg[0]) {
                    .imm => |imm| imm,
                    .reg => |reg| c.regs[reg],
                };
                const offset = switch (insn.arg[1]) {
                    .imm => |imm| imm,
                    .reg => |reg| c.regs[reg],
                };
                if (val != 0) {
                    c.pc = @as(usize, @intCast(@as(i32, @intCast(c.pc)) + offset));
                } else {
                    c.pc += 1;
                }
            },
            .tgl => {
                const val = switch (insn.arg[1]) {
                    .imm => |imm| imm,
                    .reg => |reg| c.regs[reg],
                };
                if (@as(i32, @intCast(c.pc)) + val >= 0 and @as(i32, @intCast(c.pc)) + val < program_len) {
                    const mod_insn = &program[@as(usize, @intCast(@as(i32, @intCast(c.pc)) + val))];
                    switch (mod_insn.opcode) {
                        .cpy => {
                            mod_insn.opcode = .jnz;
                        },
                        .add => {
                            mod_insn.arg[0].imm *= -1;
                        },
                        .jnz => {
                            mod_insn.opcode = .cpy;
                        },
                        .tgl => {
                            mod_insn.opcode = .add;
                        },
                    }
                }
                c.pc += 1;
            },
        }
    }
    try stdout.print("a = {}\n", .{c.regs[0]});
}
