const std = @import("std");
const tools = @import("tools");

const with_trace = false;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}
const assert = std.debug.assert;

pub const main = tools.defaultMain("2021/day24.txt", run);

const Reg = enum { x, y, z, w };
const OpCode = enum { inp, add, mul, div, mod, eql };
const Inst = struct { op: OpCode, a: Reg, b: union(enum) { reg: Reg, imm: i64 } };

fn parseReg(name: []const u8) Reg {
    return std.meta.stringToEnum(Reg, name).?;
}

fn runPrg(prg: []const Inst, in: []const u8) i64 {
    var in_idx: u32 = 0;
    var vars = [4]i64{ 0, 0, 0, 0 };
    for (prg) |inst| {
        const a = &vars[@enumToInt(inst.a)];
        const b = if (inst.b == .reg) vars[@enumToInt(inst.b.reg)] else inst.b.imm;
        switch (inst.op) {
            .inp => {
                a.* = in[in_idx] - '0';
                in_idx += 1;
            },
            .add => a.* += b,
            .mul => a.* *= b,
            .div => a.* = @divFloor(a.*, b),
            .mod => a.* = @mod(a.*, b),
            .eql => a.* = @boolToInt(a.* == b),
        }
    }
    return vars[@enumToInt(Reg.z)];
}

fn decompiledToZig(in: [14]i64) i64 {
    var x: i64 = 0;
    var y: i64 = 0;
    var z: i64 = 0;
    var w: i64 = 0;

    // zig fmt: off
    w = in[0]; x *= 0;x += z;x = @mod(x, 26);z = @divFloor(z, 1);x += 15;x = @boolToInt(x == w);x = @boolToInt(x == 0);y *= 0;y += 25;y *= x;y += 1;z *= y;y *= 0;y += w;y += 9;y *= x;z += y;
    w = in[1]; x *= 0;x += z;x = @mod(x, 26);z = @divFloor(z, 1);x += 11;x = @boolToInt(x == w);x = @boolToInt(x == 0);y *= 0;y += 25;y *= x;y += 1;z *= y;y *= 0;y += w;y += 1;y *= x;z += y;
    w = in[2]; x *= 0;x += z;x = @mod(x, 26);z = @divFloor(z, 1);x += 10;x = @boolToInt(x == w);x = @boolToInt(x == 0);y *= 0;y += 25;y *= x;y += 1;z *= y;y *= 0;y += w;y += 11;y *= x;z += y;
    w = in[3]; x *= 0;x += z;x = @mod(x, 26);z = @divFloor(z, 1);x += 12;x = @boolToInt(x == w);x = @boolToInt(x == 0);y *= 0;y += 25;y *= x;y += 1;z *= y;y *= 0;y += w;y += 3;y *= x;z += y;
    w = in[4]; x *= 0;x += z;x = @mod(x, 26);z = @divFloor(z, 26);x += -11;x = @boolToInt(x == w);x = @boolToInt(x == 0);y *= 0;y += 25;y *= x;y += 1;z *= y;y *= 0;y += w;y += 10;y *= x;z += y;
    w = in[5]; x *= 0;x += z;x = @mod(x, 26);z = @divFloor(z, 1);x += 11;x = @boolToInt(x == w);x = @boolToInt(x == 0);y *= 0;y += 25;y *= x;y += 1;z *= y;y *= 0;y += w;y += 5;y *= x;z += y;
    w = in[6]; x *= 0;x += z;x = @mod(x, 26);z = @divFloor(z, 1);x += 14;x = @boolToInt(x == w);x = @boolToInt(x == 0);y *= 0;y += 25;y *= x;y += 1;z *= y;y *= 0;y += w;y += 0;y *= x;z += y;
    w = in[7]; x *= 0;x += z;x = @mod(x, 26);z = @divFloor(z, 26);x += -6;x = @boolToInt(x == w);x = @boolToInt(x == 0);y *= 0;y += 25;y *= x;y += 1;z *= y;y *= 0;y += w;y += 7;y *= x;z += y;
    w = in[8]; x *= 0;x += z;x = @mod(x, 26);z = @divFloor(z, 1);x += 10;x = @boolToInt(x == w);x = @boolToInt(x == 0);y *= 0;y += 25;y *= x;y += 1;z *= y;y *= 0;y += w;y += 9;y *= x;z += y;
    w = in[9]; x *= 0;x += z;x = @mod(x, 26);z = @divFloor(z, 26);x += -6;x = @boolToInt(x == w);x = @boolToInt(x == 0);y *= 0;y += 25;y *= x;y += 1;z *= y;y *= 0;y += w;y += 15;y *= x;z += y;
    w = in[10]; x *= 0;x += z;x = @mod(x, 26);z = @divFloor(z, 26);x += -6;x = @boolToInt(x == w);x = @boolToInt(x == 0);y *= 0;y += 25;y *= x;y += 1;z *= y;y *= 0;y += w;y += 4;y *= x;z += y;
    w = in[11]; x *= 0;x += z;x = @mod(x, 26);z = @divFloor(z, 26);x += -16;x = @boolToInt(x == w);x = @boolToInt(x == 0);y *= 0;y += 25;y *= x;y += 1;z *= y;y *= 0;y += w;y += 10;y *= x;z += y;
    w = in[12]; x *= 0;x += z;x = @mod(x, 26);z = @divFloor(z, 26);x += -4;x = @boolToInt(x == w);x = @boolToInt(x == 0);y *= 0;y += 25;y *= x;y += 1;z *= y;y *= 0;y += w;y += 4;y *= x;z += y;
    w = in[13]; x *= 0;x += z;x = @mod(x, 26);z = @divFloor(z, 26);x += -2;x = @boolToInt(x == w);x = @boolToInt(x == 0);y *= 0;y += 25;y *= x;y += 1;z *= y;y *= 0;y += w;y += 9;y *= x;z += y;
    // zig fmt: on

    return z;
}

fn decompiledToZig1(in: [14]i64) i64 {
    //var x: i64 = 0;
    //var y: i64 = 0;
    var z: i64 = 0;
    //var w: i64 = 0;

    z = z * 26 + (in[0] + 9);
    z = z * 26 + (in[1] + 1);
    z = z * 26 + (in[2] + 11);
    z = z * 26 + (in[3] + 3);
    if (@mod(z, 26) - 11 != in[4]) {
        z = @divFloor(z, 26) * 26 + (in[4] + 10);
    } else {
        z = @divFloor(z, 26);
    }
    z = z * 26 + (in[5] + 5);
    z = z * 26 + (in[6] + 0);

    if (@mod(z, 26) - 6 != in[7]) {
        z = @divFloor(z, 26) * 26 + (in[7] + 7);
    } else {
        z = @divFloor(z, 26);
    }

    z = z * 26 + (in[8] + 9);

    if (@mod(z, 26) - 6 != in[9]) {
        z = @divFloor(z, 26) * 26 + (in[9] + 15);
    } else {
        z = @divFloor(z, 26);
    }

    if (@mod(z, 26) - 6 != in[10]) {
        z = @divFloor(z, 26) * 26 + (in[10] + 4);
    } else {
        z = @divFloor(z, 26);
    }

    if (@mod(z, 26) - 16 != in[11]) {
        z = @divFloor(z, 26) * 26 + (in[11] + 10);
    } else {
        z = @divFloor(z, 26);
    }

    if (@mod(z, 26) - 4 != in[12]) {
        z = @divFloor(z, 26) * 26 + (in[12] + 4);
    } else {
        z = @divFloor(z, 26);
    }

    if (@mod(z, 26) - 2 != in[13]) {
        z = @divFloor(z, 26) * 26 + (in[13] + 9);
    } else {
        z = @divFloor(z, 26);
    }

    return z;
}

fn addDigit(z: i64, d: i64) i64 {
    assert(d >= 0 and d < 26);
    return z * 26 + d;
}

fn replaceLastDigit(z: i64, d: i64) i64 {
    assert(d >= 0 and d < 26);
    return @divFloor(z, 26) * 26 + d;
}

fn dropLastDigit(z: i64) i64 {
    return @divFloor(z, 26);
}

fn isLastDigit(z: i64, d: i64) bool {
    assert(d >= 0 and d < 26);
    return @mod(z, 26) == d;
}

fn decompiledToZig2(in: [14]i64) i64 {
    //var x: i64 = 0;
    //var y: i64 = 0;
    var z: i64 = 0;
    //var w: i64 = 0;

    z = addDigit(z, (in[0] + 9));
    z = addDigit(z, (in[1] + 1));
    z = addDigit(z, (in[2] + 11));
    z = addDigit(z, (in[3] + 3));
    z = if (!isLastDigit(z, in[4] + 11)) replaceLastDigit(z, (in[4] + 10)) else dropLastDigit(z);
    z = z * 26 + (in[5] + 5);
    z = z * 26 + (in[6] + 0);
    z = if (!isLastDigit(z, in[7] + 6)) replaceLastDigit(z, (in[7] + 7)) else dropLastDigit(z);
    z = z * 26 + (in[8] + 9);
    z = if (!isLastDigit(z, in[9] + 6)) replaceLastDigit(z, (in[9] + 15)) else dropLastDigit(z);
    z = if (!isLastDigit(z, in[10] + 6)) replaceLastDigit(z, (in[10] + 4)) else dropLastDigit(z);
    z = if (!isLastDigit(z, in[11] + 16)) replaceLastDigit(z, (in[11] + 10)) else dropLastDigit(z);
    z = if (!isLastDigit(z, in[12] + 4)) replaceLastDigit(z, (in[12] + 4)) else dropLastDigit(z);
    z = if (!isLastDigit(z, in[13] + 2)) replaceLastDigit(z, (in[13] + 9)) else dropLastDigit(z);

    return z;
}

fn dumpAsZigCode(prg: []const Inst, allocator: std.mem.Allocator) ![]u8 {
    var buf = try allocator.alloc(u8, 10000);
    var num_buf: [16]u8 = undefined;
    var len: usize = 0;
    var in_idx: u32 = 0;
    for (prg) |inst| {
        const a = std.meta.tagName(inst.a);
        const b = if (inst.b == .reg) std.meta.tagName(inst.b.reg) else std.fmt.bufPrintIntToSlice(&num_buf, inst.b.imm, 10, .lower, .{});
        switch (inst.op) {
            .inp => {
                len += (try std.fmt.bufPrint(buf[len..], "{s} = in[{d}];\n", .{ a, in_idx })).len;
                in_idx += 1;
            },
            .add => len += (try std.fmt.bufPrint(buf[len..], "{s} += {s};", .{ a, b })).len,
            .mul => len += (try std.fmt.bufPrint(buf[len..], "{s} *= {s};", .{ a, b })).len,
            .div => len += (try std.fmt.bufPrint(buf[len..], "{s} = @divFloor({s}, {s});", .{ a, a, b })).len,
            .mod => len += (try std.fmt.bufPrint(buf[len..], "{s} = @mod({s}, {s});", .{ a, a, b })).len,
            .eql => len += (try std.fmt.bufPrint(buf[len..], "{s} = @boolToInt({s} == {s});", .{ a, a, b })).len,
        }
    }
    return buf[0..len];
}

pub fn run(input: []const u8, gpa: std.mem.Allocator) tools.RunError![2][]const u8 {
    var arena_alloc = std.heap.ArenaAllocator.init(gpa);
    defer arena_alloc.deinit();
    const arena = arena_alloc.allocator();

    var prg = std.ArrayList(Inst).init(gpa);
    defer prg.deinit();

    var it = std.mem.tokenize(u8, input, "\n");
    while (it.next()) |line| {
        inline for ([_]OpCode{ .inp, .add, .mul, .div, .mod, .eql }) |op| {
            if (tools.match_pattern(std.meta.tagName(op) ++ " {} {}", line)) |val| {
                if (val[1] == .imm) {
                    try prg.append(Inst{
                        .op = op,
                        .a = parseReg(val[0].lit),
                        .b = .{ .imm = val[1].imm },
                    });
                } else {
                    try prg.append(Inst{
                        .op = op,
                        .a = parseReg(val[0].lit),
                        .b = .{ .reg = parseReg(val[1].lit) },
                    });
                }
            } else if (tools.match_pattern(std.meta.tagName(op) ++ " {}", line)) |val| {
                try prg.append(Inst{ .op = op, .a = parseReg(val[0].lit), .b = .{ .imm = 0 } });
            }
        }
    }

    if (false) {
        trace("\n{s}\n", .{try dumpAsZigCode(prg.items, arena)});
    }

    trace("runbytecode={}\n", .{runPrg(prg.items, "13579246899999")});
    trace("rundecompile={}\n", .{decompiledToZig2([_]i64{ 1, 3, 5, 7, 9, 2, 4, 6, 8, 9, 9, 9, 9, 9 })});

    {
        // pour arriver à zéro, il faut zero chiffres.
        // => que des dropLastDigit(), pas de replaceLastDigit()  pour compenser tous les addDigits.
        //  (7 addDigits => 7 dropDigit)

        // num == abcdDefFgGECBA
        // avec (a+9 == A+2)
        // avec (b+1 == B+4)
        // avec (c+11 == C+16)
        // avec (d+3 == D+11)
        // avec (e+5 == E+6)
        // avec (f+0 == F+6)
        // avec (g+9 == G+6)

        // => abcdefg=2999996
        //    ABCDEFG=9641839
        trace("runbytecode(answer)={}\n", .{runPrg(prg.items, "29991993698469")});
    }
    const ans1 = 29991993698469;

    {
        // => abcdefg=0358160
        //    ABCDEFG=7000003

        trace("runbytecode(answer)={}\n", .{runPrg(prg.items, "03580160030007")});

        // => abcdefg=1358160
        //    ABCDEFG=8000003
        trace("runbytecode(answer)={}\n", .{runPrg(prg.items, "13580160030008")}); // too low?!?

        // "The digit 0 cannot appear in a model number." aaah.
        // => abcdefg=1469271
        //    ABCDEFG=8111114
        trace("runbytecode(answer)={}\n", .{runPrg(prg.items, "14691271141118")}); // too low?!?
    }
    const ans2 = 14691271141118;

    return [_][]const u8{
        try std.fmt.allocPrint(gpa, "{}", .{ans1}),
        try std.fmt.allocPrint(gpa, "{}", .{ans2}),
    };
}

test {}
