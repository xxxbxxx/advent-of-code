const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

fn pgcd(_a: u64, _b: u64) u64 {
    var a = _a;
    var b = _b;
    while (b != 0) {
        var t = b;
        b = a % b;
        a = t;
    }
    return a;
}

const Registers = [6]u48;
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
                    @intCast(u32, fields[1].imm),
                    @intCast(u32, fields[2].imm),
                    @intCast(u32, fields[3].imm),
                };
                try prg.append(Insn{ .op = op, .par = par });
            } else if (tools.match_pattern("#ip {}", line)) |fields| {
                assert(ip == null);
                ip = @intCast(u32, fields[0].imm);
            } else unreachable;
        }
        break :param .{ .ip = ip.?, .prg = prg.items };
    };

    const ans1 = ans: {
        const State = struct {
            reg: Registers = .{ 0, 0, 0, 0, 0, 0 },
            //ip: u32 = 0,
        };
        var states = try allocator.alloc(State, 1); // 16 * 1024 * 1024);
        defer allocator.free(states);
        for (states) |*s, i| {
            s.* = State{ .reg = .{ @intCast(u32, i), 0, 0, 0, 0, 0 } }; // 13443200
        }
        var cycles: u32 = 0;
        while (true) {
            for (states) |*s, i| {
                const ip = s.reg[param.ip];
                s.reg = eval(param.prg[ip].op, param.prg[ip].par, s.reg);
                s.reg[param.ip] += 1;
                if (false)
                    std.debug.print("[{}] {} {},{},{}  regs=<{}, {}, ({}), {}, {}, {}>\n", .{
                        s.reg[param.ip],
                        param.prg[s.ip].op,
                        param.prg[s.ip].par[0],
                        param.prg[s.ip].par[1],
                        param.prg[s.ip].par[2],
                        s.reg[0],
                        s.reg[1],
                        s.reg[2],
                        s.reg[3],
                        s.reg[4],
                        s.reg[5],
                    });

                if (s.reg[param.ip] == 28) break :ans s.reg[4]; // insn 28 tests r0 vs r4 -> halt
                // if (s.reg[param.ip] >= param.prg.len) break :ans i;
            }
            cycles += 1;
            //if (cycles % 1000 == 0) {
            //    std.debug.print("### cycles = {}\n", .{cycles});
            //}
        }
    };

    const ans2 = ans: {
        const State = struct { reg: Registers };
        var s = State{ .reg = .{ 0, 0, 0, 0, 0, 0 } };
        const repeats = try allocator.alloc(bool, 16 * 1024 * 1024);
        defer allocator.free(repeats);
        std.mem.set(bool, repeats, false);
        var prev: u64 = 0;
        while (true) {
            const ip = s.reg[param.ip];
            s.reg = eval(param.prg[ip].op, param.prg[ip].par, s.reg);
            s.reg[param.ip] += 1;
            if (false and (ip == 26 or ip == 13))
                std.debug.print("[{}] {} {},{},{}  regs=<{}, {}, ({}), {}, {}, {}>\n", .{
                    ip,
                    param.prg[ip].op,
                    param.prg[ip].par[0],
                    param.prg[ip].par[1],
                    param.prg[ip].par[2],
                    s.reg[0],
                    s.reg[1],
                    s.reg[2],
                    s.reg[3],
                    s.reg[4],
                    s.reg[5],
                });

            if (ip == 28) {
                const val = s.reg[4];
                //std.debug.print("halting R0 = {}\n", .{val});
                if (repeats[val]) break :ans prev; // -> 7717135
                repeats[val] = true;
                prev = val;
            }

            //if (s.reg[param.ip] >= param.prg.len) break :ans s.reg[0];
        }
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2018/input_day21.txt", run);

// xx seti 123 0 4
// xx bani 4 456 4
// xx eqri 4 72 4
// xx addr 4 2 2
// xx seti 0 0 2
//  seti 0 7 4              R4=0
//  bori 4 65536 3  next:   R3=R4|0x10000
//  seti 10283511 1 4       R4=10283511
//  bani 3 255 1    again:  ||
//  addr 4 1 4              ||
//  bani 4 16777215 4       ||
//  muli 4 65899 4          || R4=((R4+(R3%255))*65899)%0xFFFFFF
//  bani 4 16777215 4       ||
//  gtir 256 3 1            if (R3<256)
//  addr 1 2 2              //
//  addi 2 1 2              //
//  seti 27 8 2             // jmp LabelExitTest
//  seti 0 1 1              R1 = 0
//  addi 1 1 5      loop:   ||
//  muli 5 256 5            ||R5=(R5+1)*256   = ((0+1)*256+1)*256.... = 0 *256^n +256^n = 256^R1
//  gtrr 5 3 5              if (R5>R3)
//  addr 5 2 2              //
//  addi 2 1 2              //
//  seti 25 3 2             // jmp break
//  addi 1 1 1              R1++
//  seti 17 0 2             jmp loop
//  setr 1 4 3       break: R3=R1              R3=ln(R3)/ln(256)
//  seti 7 6 2              jmp again
//  eqrr 4 0 1       LabelExitTest
//  addr 1 2 2
//  seti 5 2 2
