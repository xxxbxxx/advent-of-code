const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

const Registers = [6]u64;
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

    const Insn = struct { op: Opcode, par: [3]u32 };
    const param: struct {
        ip: u32,
        prg: []Insn,
    } = param: {
        var prg = std.ArrayList(Insn).init(arena.allocator());
        var ip: ?u32 = null;

        var it = std.mem.tokenize(u8, input_text, "\n\r");
        while (it.next()) |line| {
            if (tools.match_pattern("{} {} {} {}", line)) |fields| {
                const op = try tools.nameToEnum(Opcode, fields[0].lit);
                const par = [3]u32{
                    @as(u32, @intCast(fields[1].imm)),
                    @as(u32, @intCast(fields[2].imm)),
                    @as(u32, @intCast(fields[3].imm)),
                };
                try prg.append(Insn{ .op = op, .par = par });
            } else if (tools.match_pattern("#ip {}", line)) |fields| {
                assert(ip == null);
                ip = @as(u32, @intCast(fields[0].imm));
            } else unreachable;
        }
        break :param .{ .ip = ip.?, .prg = prg.items };
    };

    const ans1 = ans: {
        var reg: Registers = .{ 0, 0, 0, 0, 0, 0 };
        var ip: u32 = 0;
        while (ip < param.prg.len) {
            reg[param.ip] = ip;
            if (false and ip <= 2) {
                std.debug.print("[{}] {} {},{},{}  regs=<{}, {}, {}, {}, ({}), {}>\n", .{
                    ip,
                    param.prg[ip].op,
                    param.prg[ip].par[0],
                    param.prg[ip].par[1],
                    param.prg[ip].par[2],
                    reg[0],
                    reg[1],
                    reg[2],
                    reg[3],
                    reg[4],
                    reg[5],
                });
            }

            reg = eval(param.prg[ip].op, param.prg[ip].par, reg);
            ip = @as(u32, @intCast(reg[param.ip]));
            ip += 1;
        }
        break :ans reg[0];
    };

    const ans2 = ans: {
        //var reg: Registers = .{ 1, 0, 0, 0, 0, 0 };
        //var ip: u32 = 0;
        ////reg = .{ 1, 10551311, 105510, 0, 2, 10551312 };
        ////ip = 2;
        //while (ip < param.prg.len) {
        //    reg[param.ip] = ip;
        //    reg = eval(param.prg[ip].op, param.prg[ip].par, reg);
        //    ip = @intCast(u32, reg[param.ip]);
        //    ip += 1;
        //}

        // le programme calcule (très lentement) la some des facteurs premiers :  (cf ci-dessous)
        break :ans 1 + 431 + 24481 + 10551311;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2018/input_day19.txt", run);

// [00] addi 4 16 4     jmp lbl_start
// [01] seti 1 7 2      r2=1
// [02] seti 1 1 5      R5=1
// [03] mulr 2 5 3      R3=R5*R2
// [04] eqrr 3 1 3      if (R3 == R1)
// [05] addr 3 4 4      //
// [06] addi 4 1 4      //
// [07] addr 2 0 0      // R0 += R2
// [08] addi 5 1 5      R5+=1
// [09] gtrr 5 1 3      if (R5<=R1) jmp 03
// [10] addr 4 3 4      //
// [11] seti 2 7 4      //
// [12] addi 2 1 2      R2+=1
// [13] gtrr 2 1 3      if (R2<=R1) JUMP 01
// [14] addr 3 4 4      //
// [15] seti 1 3 4      //
// [16] mulr 4 4 4      EXIT
// [17] addi 1 2 1      lbl_start
// [18] mulr 1 1 1
// [19] mulr 4 1 1
// [20] muli 1 11 1
// [21] addi 3 3 3
// [22] mulr 3 4 3
// [23] addi 3 9 3
// [24] addr 1 3 1
// [25] addr 4 0 4      jmp lbl_part2
// [26] seti 0 1 4      // jmp lbl1
// [27] setr 4 9 3      lbl_part2:
// [28] mulr 3 4 3
// [29] addr 4 3 3
// [30] mulr 4 3 3
// [31] muli 3 14 3
// [32] mulr 3 4 3
// [33] addr 1 3 1      R1= 10551311
// [34] seti 0 6 0      R0=0
// [35] seti 0 7 4      jmp 01
