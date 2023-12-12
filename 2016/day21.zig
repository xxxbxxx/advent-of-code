const std = @import("std");
const tools = @import("tools");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day21.txt", limit);
    defer allocator.free(text);

    var string: [8]u8 = undefined;
    var orig: [8]u8 = undefined;
    const permuts = 8 * 7 * 6 * 5 * 4 * 3 * 2 * 1;
    var p: u32 = 0;
    while (p < permuts) : (p += 1) {
        {
            @memcpy(&string, "abcdefgh");
            var mod: u32 = 8;
            var k = p;
            for (string, 0..) |*c, i| {
                const t = c.*;
                c.* = string[i + k % mod];
                string[i + k % mod] = t;
                k /= mod;
                mod -= 1;
            }
        }
        @memcpy(&orig, &string);

        var it = std.mem.tokenize(u8, text, "\n");
        while (it.next()) |line| {
            if (tools.match_pattern("swap position {} with position {}", line)) |vals| {
                //trace("swap @{}/@{}\n", .{ vals[0].imm, vals[1].imm });
                const min = @as(usize, @intCast(vals[0].imm));
                const max = @as(usize, @intCast(vals[1].imm));
                const t = string[min];
                string[min] = string[max];
                string[max] = t;
            } else if (tools.match_pattern("rotate left {} steps", line)) |vals| {
                const n = @as(usize, @intCast(vals[0].imm));
                std.mem.rotate(u8, &string, (n % string.len));
            } else if (tools.match_pattern("rotate left {} step", line)) |vals| {
                const n = @as(usize, @intCast(vals[0].imm));
                assert(n == 1);
                std.mem.rotate(u8, &string, (n % string.len));
            } else if (tools.match_pattern("rotate right {} steps", line)) |vals| {
                const n = @as(usize, @intCast(vals[0].imm));
                std.mem.rotate(u8, &string, string.len - (n % string.len));
            } else if (tools.match_pattern("rotate right {} step", line)) |vals| {
                const n = @as(usize, @intCast(vals[0].imm));
                assert(n == 1);
                std.mem.rotate(u8, &string, string.len - (n % string.len));
            } else if (tools.match_pattern("reverse positions {} through {}", line)) |vals| {
                const min = @as(usize, @intCast(vals[0].imm));
                const max = @as(usize, @intCast(vals[1].imm));
                std.mem.reverse(u8, string[min .. max + 1]);
            } else if (tools.match_pattern("move position {} to position {}", line)) |vals| {
                const from = @as(usize, @intCast(vals[0].imm));
                const to = @as(usize, @intCast(vals[1].imm));
                const t = string[from];
                if (from < to) {
                    @memcpy(string[from..to], string[from + 1 .. to + 1]);
                } else {
                    std.mem.copyBackwards(u8, string[to + 1 .. from + 1], string[to..from]);
                }
                string[to] = t;
            } else if (tools.match_pattern("swap letter {} with letter {}", line)) |vals| {
                const a = vals[0].name[0];
                const b = vals[1].name[0];
                for (string) |*c| {
                    if (c.* == a) {
                        c.* = b;
                    } else if (c.* == b) {
                        c.* = a;
                    }
                }
            } else if (tools.match_pattern("rotate based on position of letter {}", line)) |vals| {
                const a = vals[0].name[0];
                const idx = blk: {
                    for (string, 0..) |c, i| {
                        if (c == a) break :blk i;
                    }
                    unreachable;
                };
                const n = idx + 1 + if (idx >= 4) @as(usize, 1) else @as(usize, 0);
                std.mem.rotate(u8, &string, string.len - (n % string.len));
            } else {
                trace("ignoring '{}'\n", .{line});
                assert(tools.match_pattern("rotate left {} step", line) == null);
            }
        }

        trace("{} -> {}'\n", .{ orig[0..], string[0..] });
        if (std.mem.eql(u8, string[0..], "fbgdceah"))
            break;
    }

    try stdout.print("====================================\n", .{});
}
