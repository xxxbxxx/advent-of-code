const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

const Registers = [4]u32;
const Opcode = enum { addi, addr, muli, mulr, bani, banr, bori, borr, setr, seti, gtir, gtri, gtrr, eqir, eqri, eqrr };
fn eval(op: Opcode, par: [3]u32, r: Registers) Registers {
    var o = r;
    switch (op) {
        .addi => o[par[2]] = r[par[0]] + par[1],
        .addr => o[par[2]] = r[par[0]] + r[par[1]],
        .muli => o[par[2]] = r[par[0]] * par[1],
        .mulr => o[par[2]] = r[par[0]] * r[par[1]],
        .bani => o[par[2]] = r[par[0]] & par[1],
        .banr => o[par[2]] = r[par[0]] & r[par[1]],
        .bori => o[par[2]] = r[par[0]] | par[1],
        .borr => o[par[2]] = r[par[0]] | r[par[1]],
        .setr => o[par[2]] = r[par[0]],
        .seti => o[par[2]] = par[0],
        .gtir => o[par[2]] = if (par[0] > r[par[1]]) @as(u32, 1) else @as(u32, 0),
        .gtri => o[par[2]] = if (r[par[0]] > par[1]) @as(u32, 1) else @as(u32, 0),
        .gtrr => o[par[2]] = if (r[par[0]] > r[par[1]]) @as(u32, 1) else @as(u32, 0),
        .eqir => o[par[2]] = if (par[0] == r[par[1]]) @as(u32, 1) else @as(u32, 0),
        .eqri => o[par[2]] = if (r[par[0]] == par[1]) @as(u32, 1) else @as(u32, 0),
        .eqrr => o[par[2]] = if (r[par[0]] == r[par[1]]) @as(u32, 1) else @as(u32, 0),
    }

    return o;
}

pub fn run(input_text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var opcode_table = [_][16]bool{[_]bool{true} ** 16} ** 16;
    var it = std.mem.tokenize(u8, input_text, "\n\r");
    const ans1 = ans: {
        var nb_triple_abiguous: u32 = 0;
        var it_rollback = it;
        while (it.next()) |line0| {
            var before: Registers = undefined;
            var after: Registers = undefined;
            var op: u4 = undefined;
            var par: [3]u32 = undefined;

            if (tools.match_pattern("Before: [{}, {}, {}, {}]", line0)) |fields| {
                before[0] = @as(u32, @intCast(fields[0].imm));
                before[1] = @as(u32, @intCast(fields[1].imm));
                before[2] = @as(u32, @intCast(fields[2].imm));
                before[3] = @as(u32, @intCast(fields[3].imm));
            } else {
                break;
            }

            const line1 = it.next().?;
            if (tools.match_pattern("{} {} {} {}", line1)) |fields| {
                op = @as(u4, @intCast(fields[0].imm));
                par[0] = @as(u32, @intCast(fields[1].imm));
                par[1] = @as(u32, @intCast(fields[2].imm));
                par[2] = @as(u32, @intCast(fields[3].imm));
            } else unreachable;

            const line2 = it.next().?;
            if (tools.match_pattern("After:  [{}, {}, {}, {}]", line2)) |fields| {
                after[0] = @as(u32, @intCast(fields[0].imm));
                after[1] = @as(u32, @intCast(fields[1].imm));
                after[2] = @as(u32, @intCast(fields[2].imm));
                after[3] = @as(u32, @intCast(fields[3].imm));
            } else unreachable;

            var nb: u32 = 0;
            for (&opcode_table[op], 0..) |*b, i| {
                const res = eval(@as(Opcode, @enumFromInt(@as(u4, @intCast(i)))), par, before);
                if (!std.mem.eql(u32, &res, &after)) {
                    b.* = false;
                } else {
                    nb += 1;
                }
            }
            if (nb >= 3) nb_triple_abiguous += 1;

            it_rollback = it;
        }

        it = it_rollback;
        break :ans nb_triple_abiguous;
    };

    const ans2 = ans: {
        var opcodes: [16]Opcode = undefined;
        var done = false;
        while (!done) {
            done = true;
            for (opcode_table, 0..) |table, op| {
                var code: u4 = undefined;
                var nb: u32 = 0;
                for (table, 0..) |b, i| {
                    if (b) {
                        nb += 1;
                        code = @as(u4, @intCast(i));
                    }
                }
                if (nb == 1) {
                    opcodes[op] = @as(Opcode, @enumFromInt(code));
                    for (&opcode_table) |*t| {
                        t[code] = false;
                    }
                } else if (nb > 1) {
                    done = false;
                }
            }
        }

        //for (opcodes) |op, code| {
        //    std.debug.print("opcode n°{} = {}\n", .{ code, op });
        //}

        var reg: Registers = .{ 0, 0, 0, 0 };
        while (it.next()) |line| {
            if (tools.match_pattern("{} {} {} {}", line)) |fields| {
                const op = @as(u4, @intCast(fields[0].imm));
                const par = [3]u32{
                    @as(u32, @intCast(fields[1].imm)),
                    @as(u32, @intCast(fields[2].imm)),
                    @as(u32, @intCast(fields[3].imm)),
                };
                reg = eval(opcodes[op], par, reg);
            } else unreachable;
        }
        break :ans reg[0];
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2018/input_day16.txt", run);
