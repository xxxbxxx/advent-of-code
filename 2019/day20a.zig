const std = @import("std");

const with_trace = false;
const with_dissassemble = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.warn(fmt, args);
}

const Computer = struct {
    name: []const u8,
    memory: []Data,
    pc: usize = undefined,
    base: Data = undefined,
    io_mode: IOMode = undefined,
    io_port: Data = undefined,
    io_runframe: @Frame(run) = undefined,

    const Data = i64;
    const halted: usize = 9999999;

    const OperandType = enum {
        any,
        adr,
    };
    const OperandMode = enum {
        pos,
        imm,
        rel,
    };
    const Operation = enum {
        hlt,
        jne,
        jeq,
        add,
        mul,
        slt,
        seq,
        in,
        out,
        err,
        arb,
    };
    const Instruction = struct {
        op: Operation,
        name: []const u8,
        operands: []const OperandType,
    };

    const insn_table = comptime build_instruction_table();

    fn add_insn(op: Operation, name: []const u8, code: u8, operands: []const OperandType, table: []Instruction) void {
        table[code].op = op;
        table[code].name = name;
        table[code].operands = operands;
    }
    fn build_instruction_table() [100]Instruction {
        var table = [1]Instruction{.{ .op = Operation.err, .name = "invalid", .operands = &[_]OperandType{s} }} ** 100;

        add_insn(.hlt, "ctl.HALT", 99, &[_]OperandType{s}, &table);
        add_insn(.jne, "ctl.JNE", 5, &[_]OperandType{ .any, .any }, &table); // jump-if-true
        add_insn(.jeq, "ctl.JEQ", 6, &[_]OperandType{ .any, .any }, &table); // jump-if-false

        add_insn(.add, "alu.ADD", 1, &[_]OperandType{ .any, .any, .adr }, &table);
        add_insn(.mul, "alu.MUL", 2, &[_]OperandType{ .any, .any, .adr }, &table);
        add_insn(.slt, "alu.SLT", 7, &[_]OperandType{ .any, .any, .adr }, &table); // set if less than
        add_insn(.seq, "alu.SEQ", 8, &[_]OperandType{ .any, .any, .adr }, &table); // set if zero
        add_insn(.arb, "alu.ARB", 9, &[_]OperandType{.any}, &table); // adjust relative base

        add_insn(.in, "io.IN  ", 3, &[_]OperandType{.adr}, &table);
        add_insn(.out, "io.OUT ", 4, &[_]OperandType{.any}, &table);

        return table;
    }

    fn parse_mode(v: usize) !OperandMode {
        switch (v) {
            0 => return .pos,
            1 => return .imm,
            2 => return .rel,
            else => return error.unknownMode, //@panic("unknown mode"),
        }
    }
    fn parse_opcode(v: Data, opcode: *u8, modes: []OperandMode) !void {
        const opcode_and_modes: usize = @intCast(v);
        opcode.* = @intCast(opcode_and_modes % 100);
        modes[0] = try parse_mode((opcode_and_modes / 100) % 10);
        modes[1] = try parse_mode((opcode_and_modes / 1000) % 10);
        modes[2] = try parse_mode((opcode_and_modes / 10000) % 10);
    }

    fn load_param(par: Data, t: OperandType, mode: OperandMode, base: Data, mem: []const Data) Data {
        switch (t) {
            .adr => switch (mode) {
                .pos => return par,
                .imm => @panic("invalid mode"),
                .rel => return par + base,
            },
            .any => switch (mode) {
                .pos => return mem[@intCast(par)],
                .imm => return par,
                .rel => return mem[@intCast(par + base)],
            },
        }
    }

    fn reboot(c: *Computer, boot_image: []const Data) void {
        trace("[{s}] reboot\n", .{c.name});
        std.mem.copy(Data, c.memory[0..boot_image.len], boot_image);
        @memset(c.memory[boot_image.len..], 0);
        c.pc = 0;
        c.base = 0;
        c.io_port = undefined;
    }
    fn is_halted(c: *Computer) bool {
        return c.pc == halted;
    }
    const IOMode = enum {
        input,
        output,
    };
    fn run(c: *Computer) void {
        while (c.pc != halted) {
            // decode insn opcode
            var opcode: u8 = undefined;
            var modes: [3]OperandMode = undefined;
            parse_opcode(c.memory[c.pc], &opcode, &modes) catch unreachable;
            c.pc += 1;

            const insn = insn_table[opcode];
            var string_storage: [100]u8 = undefined;
            trace("[{s}]      {s}\n", .{ c.name, dissamble_insn(insn, &modes, c.memory[c.pc..], &string_storage) });

            // load parameters from insn operands
            var param_registers: [3]Data = undefined;
            const p = blk: {
                const operands = insn.operands;
                const p = param_registers[0..operands.len];
                var i: usize = 0;
                while (i < operands.len) : (i += 1) {
                    p[i] = load_param(c.memory[c.pc + i], operands[i], modes[i], c.base, c.memory);
                }
                c.pc += operands.len;
                break :blk p;
            };

            // execute insn
            switch (insn.op) {
                .hlt => c.pc = halted,
                .jne => c.pc = if (p[0] != 0) @intCast(p[1]) else c.pc,
                .jeq => c.pc = if (p[0] == 0) @intCast(p[1]) else c.pc,

                .add => c.memory[@intCast(p[2])] = p[0] + p[1],
                .mul => c.memory[@intCast(p[2])] = p[0] * p[1],
                .slt => c.memory[@intCast(p[2])] = if (p[0] < p[1]) 1 else 0,
                .seq => c.memory[@intCast(p[2])] = if (p[0] == p[1]) 1 else 0,
                .arb => c.base += p[0],

                .in => {
                    c.io_mode = .input;
                    trace("[{s}] reading...\n", .{c.name});
                    suspend {
                        c.io_runframe = @frame().*;
                    }
                    trace("[{s}] ...got {s}\n", .{ c.name, c.io_port });
                    c.memory[@intCast(p[0])] = c.io_port;
                },
                .out => {
                    c.io_mode = .output;
                    c.io_port = p[0];
                    trace("[{s}] writing {s}...\n", .{ c.name, c.io_port });
                    suspend {
                        c.io_runframe = @frame().*;
                    }
                    trace("[{s}] ...ok\n", .{c.name});
                },

                .err => @panic("Illegal instruction"),
            }
        }
    }

    fn append_fmt(storage: []u8, i: *usize, comptime fmt: []const u8, v: anytype) void {
        const r = std.fmt.bufPrint(storage[i.*..], fmt, .{v}) catch unreachable;
        i.* += r.len;
    }
    fn dissamble_insn(insn: Instruction, modes: []const OperandMode, operands: []const Data, storage: []u8) []const u8 {
        var i: usize = 0;
        std.mem.copy(u8, storage[i..], insn.name);
        i += insn.name.len;
        std.mem.copy(u8, storage[i..], "\t");
        i += 1;
        for (insn.operands, 0..) |optype, j| {
            if (j > 0) {
                std.mem.copy(u8, storage[i..], ", ");
                i += 2;
            }
            if (j >= operands.len) {
                std.mem.copy(u8, storage[i..], "ERR");
                i += 3;
            } else {
                switch (optype) {
                    .adr => switch (modes[j]) {
                        .imm => append_fmt(storage, &i, "ERR{s}", operands[j]),
                        .pos => append_fmt(storage, &i, "@{s}", operands[j]),
                        .rel => append_fmt(storage, &i, "@b+{s}", operands[j]),
                    },

                    .any => switch (modes[j]) {
                        .imm => append_fmt(storage, &i, "{s}", operands[j]),
                        .pos => append_fmt(storage, &i, "[{s}]", operands[j]),
                        .rel => append_fmt(storage, &i, "[b+{s}]", operands[j]),
                    },
                }
            }
        }
        return storage[0..i];
    }
    fn disassemble(image: []const Data) void {
        var pc: usize = 0;
        while (pc < image.len) {
            var opcode: u8 = undefined;
            var modes: [3]OperandMode = undefined;

            var insn_size: usize = 1;

            var asmstr_storage: [100]u8 = undefined;
            const asmstr = blk: {
                if (parse_opcode(image[pc], &opcode, &modes)) {
                    const insn = insn_table[opcode];
                    insn_size += insn.operands.len;
                    break :blk dissamble_insn(insn, &modes, image[pc + 1 ..], &asmstr_storage);
                } else |err| {
                    break :blk "";
                }
            };

            var datastr_storage: [100]u8 = undefined;
            const datastr = blk: {
                var i: usize = 0;
                var l: usize = 0;
                while (i < insn_size) : (i += 1) {
                    append_fmt(&datastr_storage, &l, "{s} ", if (pc + i < image.len) image[pc + i] else 0);
                }
                break :blk datastr_storage[0..l];
            };

            std.debug.warn("{d:0>4}: {s:15} {s}\n", .{ pc, datastr, asmstr });
            pc += insn_size;
        }
    }
};

const Vec2 = struct {
    x: i32,
    y: i32,
};

fn vecmin(a: Vec2, b: Vec2) Vec2 {
    return Vec2{
        .x = if (a.x < b.x) a.x else b.x,
        .y = if (a.y < b.y) a.y else b.y,
    };
}
fn vecmax(a: Vec2, b: Vec2) Vec2 {
    return Vec2{
        .x = if (a.x > b.x) a.x else b.x,
        .y = if (a.y > b.y) a.y else b.y,
    };
}
const BBox = struct {
    min: Vec2,
    max: Vec2,
};

const Map = struct {
    const Tile = u8;
    const stride = 128;

    map: [stride * stride]Tile = undefined,
    bbox: BBox = BBox{ .min = Vec2{ .x = 99999, .y = 99999 }, .max = Vec2{ .x = -99999, .y = -99999 } },

    fn print_to_buf(map: Map, pos: Vec2, crop: ?BBox, buf: []u8) []const u8 {
        var i: usize = 0;
        const b = if (crop) |box|
            BBox{
                .min = vecmax(map.bbox.min, box.min),
                .max = vecmin(map.bbox.max, box.max),
            }
        else
            map.bbox;

        var p = b.min;
        while (p.y <= b.max.y) : (p.y += 1) {
            p.x = b.min.x;
            while (p.x <= b.max.x) : (p.x += 1) {
                const offset = map.offsetof(p);
                buf[i] = map.map[offset];
                if (p.x == pos.x and p.y == pos.y) {
                    buf[i] = '@';
                }
                i += 1;
            }
            buf[i] = '\n';
            i += 1;
        }
        return buf[0..i];
    }

    fn offsetof(map: *const Map, p: Vec2) usize {
        _ = map;
        return @as(usize, @intCast(p.x)) + @as(usize, @intCast(p.y)) * stride;
    }
    fn at(map: *const Map, p: Vec2) Tile {
        assert(p.x >= map.bbox.min.x and p.y >= map.bbox.min.y and p.x <= map.bbox.max.x and p.y <= map.bbox.max.y);
        assert(p.x >= 0 and p.y >= 0 and p.x < stride);
        const offset = map.offsetof(p);
        return map.map[offset];
    }
    fn get(map: *const Map, p: Vec2) ?Tile {
        if (p.x < map.bbox.min.x or p.y < map.bbox.min.y)
            return null;
        if (p.x > map.bbox.max.x or p.y > map.bbox.max.y)
            return null;

        if (p.x < 0 or p.y < 0)
            return null;
        if (p.x >= stride)
            return null;
        const offset = map.offsetof(p);
        if (offset >= map.map.len)
            return null;
        return map.map[offset];
    }

    fn set(map: *Map, p: Vec2, t: Tile) void {
        map.bbox.min = vecmin(p, map.bbox.min);
        map.bbox.max = vecmax(p, map.bbox.max);

        assert(p.x >= 0 or p.y >= 0);
        assert(p.x < stride);
        const offset = map.offsetof(p);
        assert(offset < map.map.len);
        map.map[offset] = t;
    }
};

const BestFirstSearch = struct {
    const State = struct {
        maplevel: u32,
        curtp: u16,
    };
    const Node = struct {
        rating: i32,
        steps: u32,
        state: State,
    };

    const Agenda = std.ArrayList(*const Node);
    const VisitedNodes = std.AutoHashMap(State, *const Node);

    allocator: *std.mem.Allocator,
    agenda: Agenda,
    recyclebin: std.ArrayList(*Node),
    visited: VisitedNodes,

    fn init(allocator: *std.mem.Allocator) BestFirstSearch {
        return BestFirstSearch{
            .allocator = allocator,
            .agenda = BestFirstSearch.Agenda.init(allocator),
            .recyclebin = std.ArrayList(*BestFirstSearch.Node).init(allocator),
            .visited = BestFirstSearch.VisitedNodes.init(allocator),
        };
    }
    fn deinit(s: *BestFirstSearch) void {
        var iterator = s.visited.iterator();
        while (iterator.next()) |it| {
            s.allocator.destroy(it.value);
        }
        s.visited.deinit();
        s.recyclebin.deinit();
        s.agenda.deinit();
    }
    fn insert(s: *BestFirstSearch, node: Node) !void {
        if (s.visited.get(node.state)) |kv| {
            if (kv.value.cost <= node.cost) {
                return;
            }
        }

        var index: ?usize = null;
        for (s.agenda.items, 0..) |n, i| {
            if (n.rating <= node.rating) {
                index = i;
                break;
            }
        }

        const poolelem = if (s.recyclebin.popOrNull()) |n| n else try s.allocator.create(Node);
        poolelem.* = node;

        if (index) |i| {
            try s.agenda.insert(i, poolelem);
        } else {
            try s.agenda.append(poolelem);
        }

        if (try s.visited.put(poolelem.state, poolelem)) |kv| { // overwriten elem?
            for (s.agenda.items, 0..) |v, i| {
                if (v == kv.value) {
                    _ = s.agenda.orderedRemove(i);
                    break;
                }
            }
            s.allocator.destroy(kv.value);
        }
    }
    fn pop(s: *BestFirstSearch) ?Node {
        if (s.agenda.popOrNull()) |n| {
            // if (!visited) {
            //const writable_node: *Node = @intToPtr(*Node, @ptrToInt(n));
            //s.recyclebin.append(writable_node) catch unreachable;
            // }
            return n.*;
        } else {
            return null;
        }
    }
};

fn decode_tp(map: *Map, maplevel: u32, p: Vec2) ?u16 {
    const m = map.at(p);
    if (m < 'A' or m > 'Z')
        return null;

    const is_outer = (p.x < map.bbox.min.x + 2 or p.y < map.bbox.min.y + 2 or p.x >= map.bbox.max.x - 2 or p.y >= map.bbox.max.y - 2);
    if (maplevel > 0 and (m == 'A' or m == 'Z'))
        return null;
    //if (maplevel == 0 and !(m == 'A' or m == 'Z') and is_outer)
    //    return null; // outer tp

    var firstletter: u8 = undefined;
    var secondletter: u8 = undefined;
    const up = map.get(Vec2{ .x = p.x, .y = p.y - 1 }) orelse ' ';
    const down = map.get(Vec2{ .x = p.x, .y = p.y + 1 }) orelse ' ';
    const left = map.get(Vec2{ .x = p.x - 1, .y = p.y }) orelse ' ';
    const right = map.get(Vec2{ .x = p.x + 1, .y = p.y }) orelse ' ';
    if (up >= 'A' and up <= 'Z') {
        firstletter = up;
        secondletter = m;
    } else if (down >= 'A' and down <= 'Z') {
        firstletter = m;
        secondletter = down;
    } else if (left >= 'A' and left <= 'Z') {
        firstletter = left;
        secondletter = m;
    } else if (right >= 'A' and right <= 'Z') {
        firstletter = m;
        secondletter = right;
    } else {
        unreachable;
    }

    return (@as(u16, @intCast(firstletter - 'A')) * 26 + @as(u16, @intCast(secondletter - 'A'))) + (if (is_outer) 0 else maxtp);
}

const maxtp: u16 = 26 * 26;
fn compute_tpdists(map: *Map, maplevel: u32, start_tp: u16) [maxtp * 2]u16 {
    const maxdist: u16 = 65535;
    var dmap = [1]u16{maxdist - 1} ** (Map.stride * Map.stride);
    var tpdist = [1]u16{maxdist} ** (maxtp * 2);
    tpdist[start_tp] = 0;

    var changed = true;
    while (changed) {
        changed = false;
        var p = map.bbox.min;
        p.y = map.bbox.min.y + 1;
        while (p.y <= map.bbox.max.y - 1) : (p.y += 1) {
            p.x = map.bbox.min.x + 1;
            while (p.x <= map.bbox.max.x - 1) : (p.x += 1) {
                const up = Vec2{ .x = p.x, .y = p.y - 1 };
                const down = Vec2{ .x = p.x, .y = p.y + 1 };
                const left = Vec2{ .x = p.x - 1, .y = p.y };
                const right = Vec2{ .x = p.x + 1, .y = p.y };

                const tpup = decode_tp(map, maplevel, up);
                const tpdown = decode_tp(map, maplevel, down);
                const tpleft = decode_tp(map, maplevel, left);
                const tpright = decode_tp(map, maplevel, right);

                const offsetup = map.offsetof(up);
                const offsetdown = map.offsetof(down);
                const offsetleft = map.offsetof(left);
                const offsetright = map.offsetof(right);

                //const distup = if (tpup) |tp| tpdist[tp] else dmap[offsetup] + 1;
                //const distdown = if (tpdown) |tp| tpdist[tp] else dmap[offsetdown] + 1;
                //const distleft = if (tpleft) |tp| tpdist[tp] else dmap[offsetleft] + 1;
                //const distright = if (tpright) |tp| tpdist[tp] else dmap[offsetright] + 1;
                const distup = if (tpup) |tp| (if (tp == start_tp) 0 else maxdist) else dmap[offsetup] + 1;
                const distdown = if (tpdown) |tp| (if (tp == start_tp) 0 else maxdist) else dmap[offsetdown] + 1;
                const distleft = if (tpleft) |tp| (if (tp == start_tp) 0 else maxdist) else dmap[offsetleft] + 1;
                const distright = if (tpright) |tp| (if (tp == start_tp) 0 else maxdist) else dmap[offsetright] + 1;

                var cur_dist: u16 = maxdist;
                if (cur_dist > distup) cur_dist = distup;
                if (cur_dist > distdown) cur_dist = distdown;
                if (cur_dist > distleft) cur_dist = distleft;
                if (cur_dist > distright) cur_dist = distright;

                {
                    const offset = map.offsetof(p);
                    const m = map.map[offset];
                    if (decode_tp(map, maplevel, p)) |tp| {
                        if (tpdist[tp] > cur_dist) {
                            tpdist[tp] = cur_dist;
                            changed = true;
                        }
                    } else if (m == '.') {
                        if (dmap[offset] > cur_dist) {
                            dmap[offset] = cur_dist;
                            changed = true;
                        }
                    }
                }
            }
        }
    }
    return tpdist;
}

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().outStream();
    const allocator = &std.heap.ArenaAllocator.init(std.heap.page_allocator).allocator;
    const limit = 1 * 1024 * 1024 * 1024;

    var random = std.rand.DefaultPrng.init(12).random;
    _ = random;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day20.txt", limit);
    defer allocator.free(text);

    var map = Map{};
    var map_cursor = Vec2{ .x = 0, .y = 0 };
    for (text) |c| {
        if (c == '\n') {
            map_cursor = Vec2{ .x = 0, .y = map_cursor.y + 1 };
        } else {
            map.set(map_cursor, c);
            map_cursor.x += 1;
        }
    }

    {
        var buf: [15000]u8 = undefined;
        try stdout.print("{s}\n", .{map.print_to_buf(map_cursor, null, &buf)});
    }

    var searcher = BestFirstSearch.init(allocator);
    defer searcher.deinit();

    try searcher.insert(BestFirstSearch.Node{
        .rating = 0,
        .cost = 0,
        .state = .{
            .maplevel = 0,
            .curtp = 0,
        },
    });

    var trace_dep: usize = 0;
    _ = trace_dep;
    var best: u32 = 999999;
    while (searcher.pop()) |node| {
        if (node.cost >= best)
            continue;
        //if (node.keylistlen > trace_dep) {
        //    trace_dep = node.keylistlen;
        //    trace("so far... steps={s}, agendalen={s}, visited={s}, recyclebin={s}, keylist[{s}]={s}\n", .{ node.cost, searcher.agenda.items.len, searcher.visited.count(), searcher.recyclebin.len, node.keylistlen, node.keylist[0..node.keylistlen] });
        //}

        const tpdists = compute_tpdists(&map, node.state.maplevel, node.state.curtp);

        for (tpdists, 0..) |dist, tp| {
            if (dist >= 65534)
                continue;
            if (tp == (maxtp - 1)) {
                const steps = node.cost + (dist - 1);
                try stdout.print("Solution: steps={s}\n", .{steps});
                best = steps;
                continue;
            }
            const is_outer = (tp / maxtp == 0);
            const tpname: u16 = @intCast(tp % maxtp);
            var next: BestFirstSearch.Node = undefined;
            next.cost = node.cost + dist;
            next.state.curtp = tpname + (if (is_outer) maxtp else 0);
            next.state.maplevel = node.state.maplevel;
            next.rating = @intCast(next.cost); // - @intCast(i32, next.keylistlen * next.keylistlen);
            try searcher.insert(next);
        }
    }

    // partie1
    {
        const tpdist = compute_tpdists(&map, 0, 0);
        try stdout.print("ZZ : {s}\n", .{tpdist[maxtp - 1] - 1});
    }
}
