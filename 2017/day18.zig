const std = @import("std");
const tools = @import("tools");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

const Arg = union(enum) {
    reg: u5,
    imm: i64,
};

pub fn match_insn(comptime pattern: []const u8, text: []const u8) ?[2]Arg {
    if (tools.match_pattern(pattern, text)) |vals| {
        var count: usize = 0;
        var values: [2]Arg = undefined;
        for (values, 0..) |*v, i| {
            switch (vals[i]) {
                .imm => |imm| v.* = .{ .imm = imm },
                .name => |name| v.* = .{ .reg = @as(u5, @intCast(name[0] - 'a')) },
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
    const text = try std.fs.cwd().readFileAlloc(allocator, "day18.txt", limit);
    defer allocator.free(text);

    const Opcode = enum {
        set,
        add,
        mul,
        mod,
        jgz,
    };

    const Insn = struct {
        opcode: Opcode,
        arg: [2]Arg,
    };

    var program: [500]Insn = undefined;
    var program_len: usize = 0;

    var it = std.mem.tokenize(u8, text, "\n");
    while (it.next()) |line| {
        if (match_insn("set {} {}", line)) |vals| {
            trace("set {} {}\n", .{ vals[0], vals[1] });
            program[program_len].opcode = .set;
            program[program_len].arg[0] = vals[0];
            program[program_len].arg[1] = vals[1];
            program_len += 1;
        } else if (match_insn("add {} {}", line)) |vals| {
            trace("add {} {}\n", .{ vals[0], vals[1] });
            program[program_len].opcode = .add;
            program[program_len].arg[0] = vals[0];
            program[program_len].arg[1] = vals[1];
            program_len += 1;
        } else if (match_insn("mul {} {}", line)) |vals| {
            trace("mul {} {}\n", .{ vals[0], vals[1] });
            program[program_len].opcode = .mul;
            program[program_len].arg[0] = vals[0];
            program[program_len].arg[1] = vals[1];
            program_len += 1;
        } else if (match_insn("mod {} {}", line)) |vals| {
            trace("mod {} {}\n", .{ vals[0], vals[1] });
            program[program_len].opcode = .mod;
            program[program_len].arg[0] = vals[0];
            program[program_len].arg[1] = vals[1];
            program_len += 1;
        } else if (match_insn("jgz {} {}", line)) |vals| {
            trace("jgz {} {}\n", .{ vals[0], vals[1] });
            program[program_len].opcode = .jgz;
            program[program_len].arg[0] = vals[0];
            program[program_len].arg[1] = vals[1];
            program_len += 1;
        } else if (match_insn("snd {}", line)) |vals| {
            trace("snd {}\n", .{vals[0]});
            program[program_len].opcode = .set;
            program[program_len].arg[0] = Arg{ .reg = 31 };
            program[program_len].arg[1] = vals[0];
            program_len += 1;
        } else if (match_insn("rcv {}", line)) |vals| {
            trace("rcv {}\n", .{vals[0]});
            program[program_len].opcode = .set;
            program[program_len].arg[0] = vals[0];
            program[program_len].arg[1] = Arg{ .reg = 31 };
            program_len += 1;
        } else {
            trace("skipping {}\n", .{line});
        }
    }

    const Computer = struct {
        pc: usize,
        regs: [32]i64,
        rcv_queue: [256]i64,
        rcv_len: usize,
        send_count: usize,
    };
    var cpus = [_]Computer{
        Computer{ .pc = 0, .regs = [1]i64{0} ** 32, .rcv_queue = undefined, .rcv_len = 0, .send_count = 0 },
        Computer{ .pc = 0, .regs = [1]i64{0} ** 32, .rcv_queue = undefined, .rcv_len = 0, .send_count = 0 },
    };
    cpus[0].regs['p' - 'a'] = 0;
    cpus[1].regs['p' - 'a'] = 1;

    var prevcount0 = cpus[0].send_count + 10000;
    var prevcount1 = cpus[1].send_count;
    while (prevcount0 != cpus[0].send_count or prevcount1 != cpus[1].send_count) {
        prevcount0 = cpus[0].send_count;
        prevcount1 = cpus[1].send_count;
        for (cpus, 0..) |*c, icpu| {
            const other = &cpus[1 - icpu];

            run: while (c.pc < program_len) {
                const insn = &program[c.pc];
                switch (insn.opcode) {
                    .set => {
                        const is_input = (insn.arg[1] == .reg and insn.arg[1].reg == 31);
                        const is_output = (insn.arg[0] == .reg and insn.arg[0].reg == 31);
                        if (is_input) {
                            if (c.rcv_len == 0) {
                                trace("{}: rcv <- stalled\n", .{icpu});

                                break :run; // stall
                            }
                            trace("{}: rcv <- {}\n", .{ icpu, c.rcv_queue[0] });

                            c.regs[insn.arg[0].reg] = c.rcv_queue[0];
                            std.mem.copy(i64, c.rcv_queue[0 .. c.rcv_len - 1], c.rcv_queue[1..c.rcv_len]);
                            c.rcv_len -= 1;
                        } else if (is_output) {
                            other.rcv_queue[other.rcv_len] = switch (insn.arg[1]) {
                                .imm => |imm| imm,
                                .reg => |reg| c.regs[reg],
                            };
                            trace("{}: snd -> {}\n", .{ icpu, other.rcv_queue[other.rcv_len] });
                            other.rcv_len += 1;
                            c.send_count += 1;
                        } else {
                            c.regs[insn.arg[0].reg] = switch (insn.arg[1]) {
                                .imm => |imm| imm,
                                .reg => |reg| c.regs[reg],
                            };
                        }
                    },
                    .add => {
                        c.regs[insn.arg[0].reg] += switch (insn.arg[1]) {
                            .imm => |imm| imm,
                            .reg => |reg| c.regs[reg],
                        };
                    },
                    .mul => {
                        c.regs[insn.arg[0].reg] *= switch (insn.arg[1]) {
                            .imm => |imm| imm,
                            .reg => |reg| c.regs[reg],
                        };
                    },
                    .mod => {
                        c.regs[insn.arg[0].reg] =
                            @mod(c.regs[insn.arg[0].reg], switch (insn.arg[1]) {
                            .imm => |imm| imm,
                            .reg => |reg| c.regs[reg],
                        });
                    },

                    .jgz => {
                        const val = switch (insn.arg[0]) {
                            .imm => |imm| imm,
                            .reg => |reg| c.regs[reg],
                        };
                        const ofs = switch (insn.arg[1]) {
                            .imm => |imm| imm,
                            .reg => |reg| c.regs[reg],
                        };

                        if (val > 0) {
                            c.pc = @as(usize, @intCast(@as(i32, @intCast(c.pc)) + ofs));
                            continue; // skip c.pc + 1...
                        }
                    },
                }
                c.pc += 1;
            }
        }
    }

    try stdout.print("cpu0 = {}\ncpu1 = {}\n", .{ cpus[0], cpus[1] });
}
