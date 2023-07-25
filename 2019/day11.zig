const std = @import("std");
const tools = @import("tools");

const with_trace = false;
const with_dissassemble = false;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

const Computer = tools.IntCode_Computer;

const Tile = struct {
    color: u1,
    visited: u1,
    fn to_char(m: @This()) u8 {
        return if (m.color != 0) '*' else ' ';
    }
};
const Map = tools.Map(Tile, 2500, 1000, true);
const Vec2 = tools.Vec2;

fn run_part(initial_color: u1, computer: *Computer, boot_image: []const Computer.Data, map: *Map) void {
    const dirs = [_]Vec2{ .{ .x = 0, .y = -1 }, .{ .x = 1, .y = 0 }, .{ .x = 0, .y = 1 }, .{ .x = -1, .y = 0 } };
    var pos = Vec2{ .x = 0, .y = 0 };
    var dir: u2 = 0;
    var cycle = enum {
        paint,
        turn,
    }.paint;

    map.bbox = tools.BBox.empty;
    map.set(pos, Tile{ .color = initial_color, .visited = 1 });

    {
        computer.boot(boot_image);
        trace("starting {}\n", .{computer.name});
        _ = async computer.run();
    }

    {
        const c = computer;
        while (!c.is_halted()) {
            if (c.io_mode == .input) {
                c.io_port = if (map.get(pos)) |m| m.color else 0;
                trace("wrting input to {} = {}\n", .{ c.name, c.io_port });
            } else if (c.io_mode == .output) {
                // try stdout.print("{} outputs {}\n", .{ c.name, c.io_port });
                if (cycle == .paint) {
                    map.set(pos, Tile{ .color = @intCast(c.io_port), .visited = 1 });
                    cycle = .turn;
                } else {
                    if (c.io_port == 0) {
                        dir -%= 1;
                    } else {
                        dir +%= 1;
                    }
                    pos.x += dirs[dir].x;
                    pos.y += dirs[dir].y;

                    cycle = .paint;
                }
            }

            trace("resuming {}\n", .{c.name});
            resume c.io_runframe;
        }
    }
}

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    const int_count = blk: {
        var int_count: usize = 0;
        var it = std.mem.split(u8, input, ",");
        while (it.next()) |_| int_count += 1;
        break :blk int_count;
    };

    const boot_image = try allocator.alloc(Computer.Data, int_count);
    defer allocator.free(boot_image);
    {
        var it = std.mem.split(u8, input, ",");
        var i: usize = 0;
        while (it.next()) |n_text| : (i += 1) {
            const trimmed = std.mem.trim(u8, n_text, " \n\r\t");
            boot_image[i] = try std.fmt.parseInt(Computer.Data, trimmed, 10);
        }
    }

    if (with_dissassemble)
        Computer.disassemble(boot_image);

    var computer = Computer{
        .name = "Painter",
        .memory = try allocator.alloc(Computer.Data, 10000),
    };
    defer allocator.free(computer.memory);

    var map = Map{ .default_tile = Tile{ .color = 0, .visited = 0 } };

    // part1
    run_part(0, &computer, boot_image, &map);
    const totalpainted = ans: {
        var c: usize = 0;
        for (map.map) |m| {
            c += m.visited;
        }
        break :ans c;
    };

    // part2
    run_part(1, &computer, boot_image, &map);
    var storage: [10000]u8 = undefined;
    const view = map.printToBuf(null, null, Tile.to_char, &storage);

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{totalpainted}),
        try std.fmt.allocPrint(allocator, "{s}", .{view}),
    };
}

pub const main = tools.defaultMain("2019/day11.txt", run);
