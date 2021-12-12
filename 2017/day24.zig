const std = @import("std");
const tools = @import("tools");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

const Component = [2]u32;
const Bridge = struct {
    strength: u32,
    length: u32,
};
fn recurse(components: []Component, depth: u32, con: u32, strength: u32) Bridge {
    if (depth > 0) {
        assert(components[depth - 1][0] == con or components[depth - 1][1] == con);
    } else {
        assert(con == 0);
    }

    var best: ?Bridge = null;
    var exhausted = true;
    var i = depth;
    while (i < components.len) : (i += 1) {
        const c = components[i];
        var nextcon: u32 = undefined;
        if (c[0] == con) {
            nextcon = c[1];
        } else if (c[1] == con) {
            nextcon = c[0];
        } else {
            continue;
        }

        exhausted = false;

        components[i] = components[depth];
        components[depth] = c;

        const s = recurse(components, depth + 1, nextcon, strength + (c[0] + c[1]));
        if (best == null or s.length > best.?.length or (s.length == best.?.length and s.strength > best.?.strength))
            best = s;

        components[depth] = components[i];
        components[i] = c;
    }

    if (exhausted) {
        trace("found: {} @ depth={}\n", .{ strength, depth });
        return .{ .strength = strength, .length = depth };
    } else {
        return best.?;
    }
}

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day24.txt", limit);
    defer allocator.free(text);

    var components_buf: [5000]Component = undefined;

    const components = blk: {
        var len: usize = 0;
        var it = std.mem.tokenize(u8, text, "\n");
        while (it.next()) |line| {
            if (tools.match_pattern("{}/{}", line)) |vals| {
                components_buf[len] = Component{ @intCast(u32, vals[0].imm), @intCast(u32, vals[1].imm) };
                len += 1;
            } else {
                trace("skipping {}\n", .{line});
            }
        }
        break :blk components_buf[0..len];
    };

    try stdout.print("components = {}\n", .{components.len});

    const before = blk: {
        var sum: u32 = 0;
        for (components) |c| {
            sum += c[0] + 1000 * c[1];
        }
        break :blk sum;
    };
    try stdout.print("strongest = {}\n", .{recurse(components, 0, 0, 0)});
    const after = blk: {
        var sum: u32 = 0;
        for (components) |c| {
            sum += c[0] + 1000 * c[1];
        }
        break :blk sum;
    };
    assert(before == after);
}
