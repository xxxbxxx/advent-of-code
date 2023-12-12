const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

const Registers = [6]u48;
const Opcode = enum { addi, addr, muli, mulr, bani, banr, bori, borr, setr, seti, gtir, gtri, gtrr, eqir, eqri, eqrr };
const Insn = struct { op: Opcode, par: [3]u32 };
const State = struct {
    reg: Registers = Registers{ 0, 0, 0, 0, 0, 0 },
};

fn peekState1(ip: u48, _: *const State, _: void) bool {
    return (ip == 28); // eqrr 4 0 1
}

const PeekCtx2 = struct {
    visited: []bool,
    prev: u48,
};
fn peekState2(ip: u48, state: *const State, ctx: *PeekCtx2) bool {
    if (ip == 28) {
        const val = state.reg[4];
        if (ctx.visited[val])
            return true;
        ctx.visited[val] = true;
        ctx.prev = val;
    }
    return false;
}

fn compile(comptime prg: []Insn, comptime ip_reg: u8) type {
    return struct {
        fn run(init_state: State, peekCtx: anytype, comptime peekFn: fn (ip: u48, s: *const State, ctx: @TypeOf(peekCtx)) bool) State {
            var state = init_state;
            while (true) {
                const ip = state.reg[ip_reg];
                if (peekFn(ip, &state, peekCtx)) return state;

                switch (ip) {
                    inline 0...prg.len - 1 => |i| comptime_eval(prg[i].op, prg[i].par, &state.reg),
                    else => unreachable,
                }
                state.reg[ip_reg] += 1;
            }
        }
    };
}

inline fn comptime_eval(comptime op: Opcode, comptime par: [3]u32, r: *Registers) void {
    switch (op) {
        .addi => r[par[2]] = r[par[0]] + par[1],
        .addr => r[par[2]] = r[par[0]] + r[par[1]],
        .muli => r[par[2]] = r[par[0]] * par[1],
        .mulr => r[par[2]] = r[par[0]] * r[par[1]],
        .bani => r[par[2]] = r[par[0]] & par[1],
        .banr => r[par[2]] = r[par[0]] & r[par[1]],
        .bori => r[par[2]] = r[par[0]] | par[1],
        .borr => r[par[2]] = r[par[0]] | r[par[1]],
        .setr => r[par[2]] = r[par[0]],
        .seti => r[par[2]] = par[0],
        .gtir => r[par[2]] = if (par[0] > r[par[1]]) @as(u32, 1) else @as(u32, 0),
        .gtri => r[par[2]] = if (r[par[0]] > par[1]) @as(u32, 1) else @as(u32, 0),
        .gtrr => r[par[2]] = if (r[par[0]] > r[par[1]]) @as(u32, 1) else @as(u32, 0),
        .eqir => r[par[2]] = if (par[0] == r[par[1]]) @as(u32, 1) else @as(u32, 0),
        .eqri => r[par[2]] = if (r[par[0]] == par[1]) @as(u32, 1) else @as(u32, 0),
        .eqrr => r[par[2]] = if (r[par[0]] == r[par[1]]) @as(u32, 1) else @as(u32, 0),
    }
}

fn parse(text: []const u8) struct { insns: []Insn, ip_reg: u8 } {
    @setEvalBranchQuota(20000);
    var buf: [50]Insn = undefined; // comme c'est comptime, ça marche de renvoyer un pointeur la dessus.

    var l: u32 = 0;
    var ip: ?u8 = null;

    var it = std.mem.tokenize(u8, text, "\n\r");
    while (it.next()) |line| {
        var it2 = std.mem.tokenize(u8, line, " \t");
        while (it2.next()) |field| {
            if (std.mem.eql(u8, field, "#ip")) {
                const arg = it2.next().?;
                assert(ip == null);
                ip = std.fmt.parseInt(u8, arg, 10) catch unreachable;
            } else {
                const op = tools.nameToEnum(Opcode, field) catch unreachable;
                const par = [3]u32{
                    std.fmt.parseInt(u32, it2.next().?, 10) catch unreachable,
                    std.fmt.parseInt(u32, it2.next().?, 10) catch unreachable,
                    std.fmt.parseInt(u32, it2.next().?, 10) catch unreachable,
                };
                buf[l] = Insn{ .op = op, .par = par };
                l += 1;
            }
        }
    }

    return .{ .ip_reg = ip.?, .insns = buf[0..l] };
}

pub fn run(_: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const prog = comptime parse(@embedFile("input_day21.txt"));
    const compiled_prg = comptime compile(prog.insns, prog.ip_reg);

    const ans1 = ans: {
        const result = compiled_prg.run(State{ .reg = .{ 0, 0, 0, 0, 0, 0 } }, {}, peekState1);
        break :ans result.reg[4];
    };

    const ans2 = ans: {
        const visited = try allocator.alloc(bool, 16 * 1024 * 1024);
        defer allocator.free(visited);
        @memset(visited, false);

        var ctx = PeekCtx2{ .visited = visited, .prev = 0 };
        _ = compiled_prg.run(State{ .reg = .{ 0, 0, 0, 0, 0, 0 } }, &ctx, peekState2);
        break :ans ctx.prev; // last non repeat
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2018/input_day21.txt", run);
