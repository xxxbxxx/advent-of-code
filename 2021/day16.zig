const std = @import("std");
const tools = @import("tools");

const with_trace = false;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}
const assert = std.debug.assert;

pub const main = tools.defaultMain("2021/day16.txt", run);

const BitStream = struct {
    hexdata: []const u8,
    cur: u32 = 0,
    accu: u32 = 0,
    accu_bits: u5 = 0, // how many valid bits in the accumulator?

    fn fillAccu(self: *@This()) void {
        while (self.accu_bits < 15) {
            if (self.cur >= self.hexdata.len) return; // EOS
            const c = self.hexdata[self.cur];
            self.cur += 1;
            const val: u32 = switch (c) {
                '0'...'9' => c - '0',
                'A'...'F' => 10 + c - 'A',
                else => continue, //skip garbage
            };
            self.accu = (self.accu << 4) | val;
            self.accu_bits += 4;
        }
    }
    fn readBits(self: *@This(), bits: u4) ?u32 {
        fillAccu(self);
        if (self.accu_bits < bits) return null; // EOS
        const v = (self.accu >> (self.accu_bits - bits));
        self.accu_bits -= bits;
        return v;
    }

    pub fn curBit(self: *@This()) u32 {
        return self.cur * 4 - self.accu_bits;
    }

    pub fn read1(self: *@This()) !u1 {
        if (readBits(self, 1)) |v| return @intCast(u1, v & 0x01) else return error.UnexpectedEOS;
    }
    pub fn read3(self: *@This()) !u3 {
        if (readBits(self, 3)) |v| return @intCast(u3, v & 0x07) else return error.UnexpectedEOS;
    }
    pub fn read4(self: *@This()) !u4 {
        if (readBits(self, 4)) |v| return @intCast(u4, v & 0x0F) else return error.UnexpectedEOS;
    }
    pub fn read11(self: *@This()) !u11 {
        if (readBits(self, 11)) |v| return @intCast(u11, v & 0x03FF) else return error.UnexpectedEOS;
    }
    pub fn read15(self: *@This()) !u15 {
        if (readBits(self, 15)) |v| return @intCast(u15, v & 0x7FFF) else return error.UnexpectedEOS;
    }

    pub fn flushTrailingZeroes(self: *@This()) !void {
        while (true) {
            const b = self.read1() catch |err| switch (err) {
                error.UnexpectedEOS => return,
            };
            if (b != 0) return error.UnsupportedInput;
        }
    }
};

const TypeId = enum(u3) {
    sum,
    product,
    minimum,
    maximum,
    litteral, // 4
    gt,
    lt,
    eq,
};

const TreeIndex = u10;
const Packet = struct { // "packed"  -> zig crash  "Assertion failed at zig/src/stage1/analyze.cpp:530 in get_pointer_to_type_extra2."
    version: u3,
    type_id: TypeId,
    payload: union {
        litteral: u64,
        subpackets: struct {
            len: u6 = 0,
            idx: [64]TreeIndex = undefined, // mmmeh
        },
    },
};

/// returns parsed packet index in the packet_tree
fn parse(stream: *BitStream, packet_tree: *std.ArrayList(Packet)) tools.RunError!TreeIndex {
    const version = try stream.read3();
    const type_id = @intToEnum(TypeId, try stream.read3());
    switch (type_id) {
        .litteral => {
            var lit: u64 = 0;
            var continuation = true;
            while (continuation) {
                continuation = (try stream.read1()) != 0;
                lit = (lit << 4) | (try stream.read4());
            }
            try packet_tree.append(Packet{ .version = version, .type_id = type_id, .payload = .{ .litteral = @intCast(u64, lit) } });
            return @intCast(TreeIndex, packet_tree.items.len - 1);
        },
        else => {
            const mode = try stream.read1();
            if (mode == 0) {
                // mode "len"
                const bitlen = try stream.read15();
                var p = Packet{ .version = version, .type_id = type_id, .payload = .{ .subpackets = .{ .len = 0 } } };

                const startbit = stream.curBit();
                while (stream.curBit() < startbit + bitlen) {
                    const idx = try parse(stream, packet_tree);
                    p.payload.subpackets.idx[p.payload.subpackets.len] = idx;
                    p.payload.subpackets.len += 1;
                }
                try packet_tree.append(p);
                return @intCast(TreeIndex, packet_tree.items.len - 1);
            } else {
                // mode "count"
                const count = try stream.read11();
                var p = Packet{ .version = version, .type_id = type_id, .payload = .{ .subpackets = .{ .len = @intCast(u6, count) } } };

                for (p.payload.subpackets.idx[0..count]) |*subp| {
                    subp.* = try parse(stream, packet_tree);
                }
                try packet_tree.append(p);
                return @intCast(TreeIndex, packet_tree.items.len - 1);
            }
        },
    }
}

fn dumpPacketTree(tree: []const Packet, root: TreeIndex, indentation: u8) void {
    const indent_spaces = "\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t";
    const p = tree[root];
    trace("{s}ver={} type={} ", .{ indent_spaces[0..indentation], p.version, p.type_id });
    switch (p.type_id) {
        .litteral => {
            trace("litteral={}\n", .{p.payload.litteral});
        },
        else => {
            trace("subpackets={}\n", .{p.payload.subpackets.len});
            for (p.payload.subpackets.idx[0..p.payload.subpackets.len]) |idx| {
                dumpPacketTree(tree, idx, indentation + 1);
            }
        },
    }
}

fn eval(tree: []const Packet, root: TreeIndex) u64 {
    const p = tree[root];
    switch (p.type_id) {
        .litteral => {
            return p.payload.litteral;
        },
        .gt, .lt, .eq => {
            assert(p.payload.subpackets.len == 2);
            const left = eval(tree, p.payload.subpackets.idx[0]);
            const right = eval(tree, p.payload.subpackets.idx[1]);
            return switch (p.type_id) {
                .gt => @boolToInt(left > right),
                .lt => @boolToInt(left < right),
                .eq => @boolToInt(left == right),
                else => unreachable,
            };
        },
        .sum => {
            var v: u64 = 0;
            for (p.payload.subpackets.idx[0..p.payload.subpackets.len]) |idx| {
                v += eval(tree, idx);
            }
            return v;
        },
        .product => {
            var v: u64 = 1;
            for (p.payload.subpackets.idx[0..p.payload.subpackets.len]) |idx| {
                v *= eval(tree, idx);
            }
            return v;
        },
        .minimum => {
            var v: u64 = 0xFFFFFFFFFFFFFFFF;
            for (p.payload.subpackets.idx[0..p.payload.subpackets.len]) |idx| {
                v = @minimum(v, eval(tree, idx));
            }
            return v;
        },
        .maximum => {
            var v: u64 = 0;
            for (p.payload.subpackets.idx[0..p.payload.subpackets.len]) |idx| {
                v = @maximum(v, eval(tree, idx));
            }
            return v;
        },
    }
}

pub fn run(input: []const u8, gpa: std.mem.Allocator) tools.RunError![2][]const u8 {
    //var arena_alloc = std.heap.ArenaAllocator.init(gpa);
    //defer arena_alloc.deinit();
    //const arena = arena_alloc.allocator();

    var stream = BitStream{ .hexdata = input };

    var packet_tree = std.ArrayList(Packet).init(gpa);
    defer packet_tree.deinit();

    const root = try parse(&stream, &packet_tree);
    try stream.flushTrailingZeroes();
    dumpPacketTree(packet_tree.items, root, 0);

    const ans1 = ans: {
        var totalversion: u32 = 0;
        for (packet_tree.items) |p| totalversion += p.version;
        break :ans totalversion;
    };

    const ans2 = eval(packet_tree.items, root);

    return [_][]const u8{
        try std.fmt.allocPrint(gpa, "{}", .{ans1}),
        try std.fmt.allocPrint(gpa, "{}", .{ans2}),
    };
}

test {
    const examples = [_]struct { in: []const u8, ans1: []const u8, ans2: []const u8 }{
        .{ .in = "D2FE28", .ans1 = "6", .ans2 = "2021" },
        .{ .in = "38006F45291200", .ans1 = "9", .ans2 = "1" },
        .{ .in = "EE00D40C823060", .ans1 = "14", .ans2 = "3" },
        .{ .in = "8A004A801A8002F478", .ans1 = "16", .ans2 = "15" },
        .{ .in = "620080001611562C8802118E34", .ans1 = "12", .ans2 = "46" },
        .{ .in = "C0015000016115A2E0802F182340", .ans1 = "23", .ans2 = "46" },
        .{ .in = "A0016C880162017C3686B18A3D4780", .ans1 = "31", .ans2 = "54" },

        .{ .in = "C200B40A82", .ans1 = "14", .ans2 = "3" },
        .{ .in = "04005AC33890", .ans1 = "8", .ans2 = "54" },
        .{ .in = "880086C3E88112", .ans1 = "15", .ans2 = "7" },
        .{ .in = "CE00C43D881120", .ans1 = "11", .ans2 = "9" },
        .{ .in = "D8005AC2A8F0", .ans1 = "13", .ans2 = "1" },
        .{ .in = "F600BC2D8F", .ans1 = "19", .ans2 = "0" },
        .{ .in = "9C005AC2F8F0", .ans1 = "16", .ans2 = "0" },
        .{ .in = "9C0141080250320F1802104A08", .ans1 = "20", .ans2 = "1" },
    };

    for (examples) |e| {
        const res = try run(e.in, std.testing.allocator);
        defer std.testing.allocator.free(res[0]);
        defer std.testing.allocator.free(res[1]);
        try std.testing.expectEqualStrings(e.ans1, res[0]);
        try std.testing.expectEqualStrings(e.ans2, res[1]);
    }
}
