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
        if (readBits(self, 1)) |v| return @as(u1, @intCast(v & 0x01)) else return error.UnexpectedEOS;
    }
    pub fn read3(self: *@This()) !u3 {
        if (readBits(self, 3)) |v| return @as(u3, @intCast(v & 0x07)) else return error.UnexpectedEOS;
    }
    pub fn read4(self: *@This()) !u4 {
        if (readBits(self, 4)) |v| return @as(u4, @intCast(v & 0x0F)) else return error.UnexpectedEOS;
    }
    pub fn read11(self: *@This()) !u11 {
        if (readBits(self, 11)) |v| return @as(u11, @intCast(v & 0x03FF)) else return error.UnexpectedEOS;
    }
    pub fn read15(self: *@This()) !u15 {
        if (readBits(self, 15)) |v| return @as(u15, @intCast(v & 0x7FFF)) else return error.UnexpectedEOS;
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

const TreeIndex = u16;
const Packet = struct { // "packed"  -> zig crash  "Assertion failed at zig/src/stage1/analyze.cpp:530 in get_pointer_to_type_extra2."
    version: u3,
    type_id: TypeId,
    payload: union {
        litteral: u64,
        pair: struct {
            idx: [2]TreeIndex = undefined,
        },
        list: struct {
            len: u16 = 0,
            entry_in_indexes_table: u16 = undefined,
        },
    },
};

/// returns parsed packet index in the packet_tree
const ParseError = std.mem.Allocator.Error || error{ UnsupportedInput, UnexpectedEOS };
fn parse(stream: *BitStream, packet_tree: *std.ArrayList(Packet), indexes_table: *std.ArrayList(TreeIndex)) ParseError!TreeIndex {
    const version = try stream.read3();
    const type_id = @as(TypeId, @enumFromInt(try stream.read3()));
    switch (type_id) {
        .litteral => {
            var lit: u64 = 0;
            var continuation = true;
            while (continuation) {
                continuation = (try stream.read1()) != 0;
                lit = (lit << 4) | (try stream.read4());
            }
            try packet_tree.append(Packet{ .version = version, .type_id = type_id, .payload = .{ .litteral = @as(u64, @intCast(lit)) } });
            return @as(TreeIndex, @intCast(packet_tree.items.len - 1));
        },
        else => {
            var children = std.BoundedArray(TreeIndex, 128).init(0) catch unreachable; // TODO: is there copy elision?

            const mode = try stream.read1();
            if (mode == 0) { // mode "len"
                const bitlen = try stream.read15();
                const startbit = stream.curBit();
                while (stream.curBit() < startbit + bitlen) {
                    const idx = try parse(stream, packet_tree, indexes_table);
                    children.append(idx) catch return error.UnsupportedInput;
                }
            } else { // mode "count"
                const count = try stream.read11();
                var i: u32 = 0;
                while (i < count) : (i += 1) {
                    const idx = try parse(stream, packet_tree, indexes_table);
                    children.append(idx) catch return error.UnsupportedInput;
                }
            }

            if (children.len == 0) return error.UnsupportedInput; // sinon les operteurs sont pas très bien définis.
            switch (type_id) {
                .litteral => unreachable,
                .gt, .lt, .eq => {
                    if (children.len != 2) return error.UnsupportedInput;
                    try packet_tree.append(Packet{
                        .version = version,
                        .type_id = type_id,
                        .payload = .{ .pair = .{ .idx = .{ children.buffer[0], children.buffer[1] } } },
                    });
                },
                else => {
                    const first = indexes_table.items.len;
                    try indexes_table.appendSlice(children.slice());
                    try packet_tree.append(Packet{
                        .version = version,
                        .type_id = type_id,
                        .payload = .{ .list = .{ .len = @as(u16, @intCast(children.len)), .entry_in_indexes_table = @as(u16, @intCast(first)) } },
                    });
                },
            }
            return @as(TreeIndex, @intCast(packet_tree.items.len - 1));
        },
    }
}

const PacketTree = struct {
    items: []const Packet,
    indexes_table: []const u16,
};

fn eval(tree: PacketTree, root: TreeIndex) u64 {
    const p = tree.items[root];
    switch (p.type_id) {
        .litteral => {
            return p.payload.litteral;
        },
        .gt, .lt, .eq => {
            const left = eval(tree, p.payload.pair.idx[0]);
            const right = eval(tree, p.payload.pair.idx[1]);
            return switch (p.type_id) {
                .gt => @intFromBool(left > right),
                .lt => @intFromBool(left < right),
                .eq => @intFromBool(left == right),
                else => unreachable,
            };
        },
        .sum => {
            const list = tree.indexes_table[p.payload.list.entry_in_indexes_table .. p.payload.list.entry_in_indexes_table + p.payload.list.len];
            var v: u64 = 0;
            for (list) |idx| v += eval(tree, idx);
            return v;
        },
        .product => {
            const list = tree.indexes_table[p.payload.list.entry_in_indexes_table .. p.payload.list.entry_in_indexes_table + p.payload.list.len];
            var v: u64 = 1;
            for (list) |idx| v *= eval(tree, idx);
            return v;
        },
        .minimum => {
            const list = tree.indexes_table[p.payload.list.entry_in_indexes_table .. p.payload.list.entry_in_indexes_table + p.payload.list.len];
            var v: u64 = 0xFFFFFFFFFFFFFFFF;
            for (list) |idx| v = @min(v, eval(tree, idx));
            return v;
        },
        .maximum => {
            const list = tree.indexes_table[p.payload.list.entry_in_indexes_table .. p.payload.list.entry_in_indexes_table + p.payload.list.len];
            var v: u64 = 0;
            for (list) |idx| v = @max(v, eval(tree, idx));
            return v;
        },
    }
}

fn dumpPacketTree(tree: PacketTree, root: TreeIndex, indentation: u8) void {
    const indent_spaces = "\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t";
    const p = tree.items[root];
    trace("{s}ver={} type={} ", .{ indent_spaces[0..indentation], p.version, p.type_id });
    switch (p.type_id) {
        .litteral => {
            trace("litteral={}\n", .{p.payload.litteral});
        },
        .gt, .lt, .eq => {
            trace("pair:\n", .{});
            for (p.payload.pair.idx) |idx| {
                dumpPacketTree(tree, idx, indentation + 1);
            }
        },
        else => {
            trace("subpackets[{}]:\n", .{p.payload.list.len});
            for (tree.indexes_table[p.payload.list.entry_in_indexes_table .. p.payload.list.entry_in_indexes_table + p.payload.list.len]) |idx| {
                dumpPacketTree(tree, idx, indentation + 1);
            }
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
    var indexes_table = std.ArrayList(u16).init(gpa);
    defer indexes_table.deinit();

    const root = try parse(&stream, &packet_tree, &indexes_table);
    try stream.flushTrailingZeroes();
    const tree = PacketTree{ .items = packet_tree.items, .indexes_table = indexes_table.items };
    dumpPacketTree(tree, root, 0);

    const ans1 = ans: {
        var totalversion: u32 = 0;
        for (tree.items) |p| totalversion += p.version;
        break :ans totalversion;
    };

    const ans2 = eval(tree, root);

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
