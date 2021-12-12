const std = @import("std");
const tools = @import("tools");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

fn regIndex(name: []const u8) u32 {
    var num: u32 = 0;
    for (name) |c| {
        num = (num * 27) + c - 'a';
    }
    return num;
}
pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().writer();
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day8.txt", limit);
    defer allocator.free(text);

    var registers = [1]i64{0} ** (27 * 27 * 27);
    var highest = registers[0];

    {
        var it = std.mem.split(u8, text, "\n");
        while (it.next()) |line0| {
            var dest: ?u32 = null;
            var delta: i64 = undefined;
            var cond_txt: []const u8 = "";
            if (tools.match_pattern("{} inc {} if {}", line0)) |vals| {
                dest = regIndex(vals[0].name);
                cond_txt = vals[2].name;
                delta = vals[1].imm;
            } else if (tools.match_pattern("{} dec {} if {}", line0)) |vals| {
                dest = regIndex(vals[0].name);
                cond_txt = vals[2].name;
                delta = -vals[1].imm;
            } else {
                unreachable;
            }

            var cond_reg: ?u32 = null;
            var cond_val: i64 = undefined;
            var cond: enum {
                eq,
                ne,
                gt,
                lt,
                ge,
                le,
            } = undefined;
            if (tools.match_pattern("{} > {}", cond_txt)) |vals| {
                cond_reg = regIndex(vals[0].name);
                cond = .gt;
                cond_val = vals[1].imm;
            } else if (tools.match_pattern("{} < {}", cond_txt)) |vals| {
                cond_reg = regIndex(vals[0].name);
                cond = .lt;
                cond_val = vals[1].imm;
            } else if (tools.match_pattern("{} >= {}", cond_txt)) |vals| {
                cond_reg = regIndex(vals[0].name);
                cond = .ge;
                cond_val = vals[1].imm;
            } else if (tools.match_pattern("{} <= {}", cond_txt)) |vals| {
                cond_reg = regIndex(vals[0].name);
                cond = .le;
                cond_val = vals[1].imm;
            } else if (tools.match_pattern("{} == {}", cond_txt)) |vals| {
                cond_reg = regIndex(vals[0].name);
                cond = .eq;
                cond_val = vals[1].imm;
            } else if (tools.match_pattern("{} != {}", cond_txt)) |vals| {
                cond_reg = regIndex(vals[0].name);
                cond = .ne;
                cond_val = vals[1].imm;
            } else {
                unreachable;
            }

            switch (cond) {
                .eq => {
                    if (registers[cond_reg.?] == cond_val) registers[dest.?] += delta;
                },
                .ne => {
                    if (registers[cond_reg.?] != cond_val) registers[dest.?] += delta;
                },
                .gt => {
                    if (registers[cond_reg.?] > cond_val) registers[dest.?] += delta;
                },
                .lt => {
                    if (registers[cond_reg.?] < cond_val) registers[dest.?] += delta;
                },
                .ge => {
                    if (registers[cond_reg.?] >= cond_val) registers[dest.?] += delta;
                },
                .le => {
                    if (registers[cond_reg.?] <= cond_val) registers[dest.?] += delta;
                },
            }

            if (registers[dest.?] > highest) highest = registers[dest.?];
        }
    }

    var largest = registers[0];
    for (registers) |r| {
        if (r > largest) largest = r;
    }
    try stdout.print("largest={}, highest={}\n", .{ largest, highest });
}
