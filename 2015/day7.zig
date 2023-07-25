const std = @import("std");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

const Operation = enum {
    NONE,
    AND,
    OR,
    NOT,
    LSHIFT,
    RSHIFT,
};

const Wire = [2]u8;
const Input = union(enum) {
    immediate: u16,
    wire: Wire,
};

fn parse_line(line: []const u8, op: *Operation, in: []Input, out: *Wire) void {
    var index_in: u32 = 0;
    var arrow_found: bool = false;
    op.* = .NONE;
    var it = std.mem.split(u8, line, " ");
    while (it.next()) |par| {
        if (std.mem.eql(u8, "AND", par)) {
            op.* = .AND;
        } else if (std.mem.eql(u8, "OR", par)) {
            op.* = .OR;
        } else if (std.mem.eql(u8, "NOT", par)) {
            op.* = .NOT;
        } else if (std.mem.eql(u8, "LSHIFT", par)) {
            op.* = .LSHIFT;
        } else if (std.mem.eql(u8, "RSHIFT", par)) {
            op.* = .RSHIFT;
        } else if (std.mem.eql(u8, "->", par)) {
            arrow_found = true;
        } else if (std.fmt.parseInt(u16, par, 10)) |imm| {
            assert(!arrow_found);
            in[index_in] = Input{ .immediate = imm };
            index_in += 1;
        } else |err| {
            assert(par.len <= 2);
            const wire = Wire{ par[0], if (par.len > 1) par[1] else ' ' };
            if (!arrow_found) {
                in[index_in] = Input{ .wire = wire };
                index_in += 1;
            } else {
                out.* = wire;
            }
        }
    }
}

const Gate = struct {
    op: Operation,
    in: [2]Input,
    out: Wire,

    val: ?u16,
};

fn getgate(gates: []Gate, w: Wire) *Gate {
    var g_maybe: ?*Gate = null;
    for (gates) |*it| {
        if (it.out[0] == w[0] and it.out[1] == w[1]) {
            g_maybe = it;
            break;
        }
    }
    assert(g_maybe != null);
    return g_maybe.?;
}
fn compute(gates: []Gate, w: Wire) u16 {
    const g = getgate(gates, w);
    if (g.val) |v|
        return v;

    // recusrse
    const ninputs: u32 = if (g.op == .NONE or g.op == .NOT) 1 else 2;
    var in: [2]u16 = undefined;
    var i: u32 = 0;
    while (i < ninputs) : (i += 1) {
        switch (g.in[i]) {
            .wire => |wi| in[i] = compute(gates, wi),
            .immediate => |imm| in[i] = imm,
        }
    }

    trace("computed {} -> {}\n", w, in[0]);

    var v: u16 = 0;
    // applyop
    switch (g.op) {
        .NONE => v = in[0],
        .NOT => v = ~in[0],
        .AND => v = in[0] & in[1],
        .OR => v = in[0] | in[1],
        .LSHIFT => v = in[0] << @as(u4, @intCast(in[1])),
        .RSHIFT => v = in[0] >> @as(u4, @intCast(in[1])),
    }
    g.val = v;
    return v;
}

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day7.txt", limit);

    const gates = try allocator.alloc(Gate, 1000);
    var igate: u32 = 0;

    var it = std.mem.split(u8, text, "\n");
    while (it.next()) |line_full| {
        const line = std.mem.trim(u8, line_full, " \n\r\t");
        if (line.len == 0)
            continue;

        var op: Operation = undefined;
        var in: [2]Input = undefined;
        var out: Wire = undefined;
        const g = &gates[igate];
        igate += 1;
        parse_line(line, &g.op, &g.in, &g.out);
        //trace("'{}' : {}, {}, {}\n", line, g.op, g.in[0], g.out);
    }

    const force_wire = Wire{ 'b', ' ' };
    getgate(gates, force_wire).val = 3176;

    const out = std.io.getStdOut().writer();
    const w = Wire{ 'a', ' ' };
    try out.print("lights={} \n", compute(gates, w));

    //    return error.SolutionNotFound;
}
