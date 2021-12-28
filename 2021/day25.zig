const std = @import("std");
const tools = @import("tools");

const with_trace = false;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}
const assert = std.debug.assert;

pub const main = tools.defaultMain("2021/day25.txt", run);

pub fn run(input: []const u8, gpa: std.mem.Allocator) tools.RunError![2][]const u8 {
    const stride = std.mem.indexOfScalar(u8, input, '\n').? + 1;
    const height = @intCast(u32, (input.len + 1) / stride);
    const width = @intCast(u32, stride - 1);
    trace("input: {}x{}\n", .{ width, height });

    const ans1 = ans: {
        const map = try gpa.dupe(u8, input);
        defer gpa.free(map);
        const tmp = try gpa.dupe(u8, input);
        defer gpa.free(tmp);

        var gen: u32 = 0;
        var dirty = true;
        while (dirty) : (gen += 1) {
            dirty = false;
            trace("== gen:{} ==\n{s}\n", .{ gen, map });

            {
                // horiz
                var y: u32 = 0;
                while (y < height) : (y += 1) {
                    var x: u32 = 0;
                    while (x < width) : (x += 1) {
                        const x1 = (x + 1) % width;
                        tmp[x + y * stride] = if (map[x + y * stride] == '>' and map[x1 + y * stride] == '.') 'm' else '.';
                    }
                }

                y = 0;
                while (y < height) : (y += 1) {
                    var x: u32 = 0;
                    while (x < width) : (x += 1) {
                        if (tmp[x + y * stride] == 'm') {
                            const x1 = (x + 1) % width;
                            assert(map[x + y * stride] == '>');
                            assert(map[x1 + y * stride] == '.');
                            map[x1 + y * stride] = '>';
                            map[x + y * stride] = '.';
                            dirty = true;
                        }
                    }
                }
            }
            {
                // vert
                var y: u32 = 0;
                while (y < height) : (y += 1) {
                    var x: u32 = 0;
                    while (x < width) : (x += 1) {
                        const y1 = (y + 1) % height;
                        tmp[x + y * stride] = if (map[x + y * stride] == 'v' and map[x + y1 * stride] == '.') 'm' else '.';
                    }
                }

                y = 0;
                while (y < height) : (y += 1) {
                    var x: u32 = 0;
                    while (x < width) : (x += 1) {
                        if (tmp[x + y * stride] == 'm') {
                            const y1 = (y + 1) % height;
                            assert(map[x + y * stride] == 'v');
                            assert(map[x + y1 * stride] == '.');
                            map[x + y1 * stride] = 'v';
                            map[x + y * stride] = '.';
                            dirty = true;
                        }
                    }
                }
            }
        }
        break :ans gen;
    };

    const ans2 = "gratis";

    return [_][]const u8{
        try std.fmt.allocPrint(gpa, "{}", .{ans1}),
        try std.fmt.allocPrint(gpa, "{s}", .{ans2}),
    };
}

test {
    {
        const res = try run(
            \\v...>>.vv>
            \\.vv>>.vv..
            \\>>.>v>...v
            \\>>v>>.>.v.
            \\v>v.vv.v..
            \\>.>>..v...
            \\.vv..>.>v.
            \\v.v..>>v.v
            \\....v..v.>
        , std.testing.allocator);
        defer std.testing.allocator.free(res[0]);
        defer std.testing.allocator.free(res[1]);
        try std.testing.expectEqualStrings("58", res[0]);
        try std.testing.expectEqualStrings("gratis", res[1]);
    }
}
