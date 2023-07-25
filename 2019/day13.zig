const std = @import("std");
const tools = @import("tools");

const with_trace = false;
const with_dissassemble = false;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

const Computer = tools.IntCode_Computer;
const Vec2 = tools.Vec2;

const MapTile = u3;
fn tile_to_char(m: MapTile) u8 {
    const tile_colors = [_]u8{ ' ', '#', '-', '=', 'o' };
    return tile_colors[m];
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

    const Arcade = struct {
        const screen_size = 40;
        screen: tools.Map(u3, screen_size, screen_size, false),
        score_display: Computer.Data,
        joystick: Computer.Data,

        cpu: Computer,
        cpu_out: SerialOut,

        ball: ?Vec2,
        pad: ?Vec2,

        const SerialOut = struct {
            pos: Vec2,
            val: Computer.Data,
            cycle: u32,
        };
    };

    var arcade = Arcade{
        .screen = .{ .default_tile = 0 },
        .score_display = 0,
        .joystick = 0,

        .cpu = Computer{
            .name = "ArcadeCpu",
            .memory = try allocator.alloc(Computer.Data, 10000),
        },
        .cpu_out = Arcade.SerialOut{ .pos = undefined, .val = undefined, .cycle = 0 },

        .ball = null,
        .pad = null,
    };
    defer allocator.free(arcade.cpu.memory);

    // part 1:
    const nb_blocks = part1: {
        //arcade.screen.fill(0, null);

        const c = &arcade.cpu;
        const cpu_out = &arcade.cpu_out;

        c.boot(boot_image);
        _ = async c.run();

        while (!c.is_halted()) {
            assert(c.io_mode == .output);
            switch (cpu_out.cycle) {
                0 => cpu_out.pos.x = @intCast(c.io_port),
                1 => cpu_out.pos.y = @intCast(c.io_port),
                2 => cpu_out.val = c.io_port,
                else => unreachable,
            }
            cpu_out.cycle += 1;
            if (cpu_out.cycle >= 3) {
                cpu_out.cycle = 0;
                assert(cpu_out.pos.x >= 0 and cpu_out.pos.y >= 0);
                arcade.screen.set(cpu_out.pos, @intCast(cpu_out.val));
            }

            resume c.io_runframe;
        }
        var blocks: usize = 0;
        for (arcade.screen.map) |m| {
            if (m == 2)
                blocks += 1;
        }
        break :part1 blocks;
    };

    // part 2
    {
        arcade.cpu.boot(boot_image);
        arcade.cpu.memory[0] = 2; // mode 'gratuit''

        trace("starting {}\n", .{arcade.cpu.name});
        _ = async arcade.cpu.run();

        const c = &arcade.cpu;
        const cpu_out = &arcade.cpu_out;

        while (!c.is_halted()) {
            if (arcade.ball) |ball| {
                if (arcade.pad) |pad| {
                    if (pad.x > ball.x) {
                        arcade.joystick = -1;
                    } else if (pad.x < ball.x) {
                        arcade.joystick = 1;
                    } else {
                        arcade.joystick = 0;
                    }
                }
            }

            if (c.io_mode == .input) {
                c.io_port = arcade.joystick;
                trace("wrting input to {} = {}\n", .{ c.name, c.io_port });
            } else if (c.io_mode == .output) {
                trace("{} outputs {}\n", .{ c.name, c.io_port });
                switch (cpu_out.cycle) {
                    0 => cpu_out.pos.x = @intCast(c.io_port),
                    1 => cpu_out.pos.y = @intCast(c.io_port),
                    2 => cpu_out.val = c.io_port,
                    else => unreachable,
                }
                cpu_out.cycle += 1;
                if (cpu_out.cycle >= 3) {
                    cpu_out.cycle = 0;
                    if (cpu_out.pos.x < 0 or cpu_out.pos.y < 0) {
                        arcade.score_display = cpu_out.val;
                    } else {
                        arcade.screen.set(cpu_out.pos, @intCast(cpu_out.val));
                        if (cpu_out.val == 3) arcade.pad = cpu_out.pos;
                        if (cpu_out.val == 4) arcade.ball = cpu_out.pos;
                    }
                }
            }

            trace("resuming {}\n", .{c.name});
            resume c.io_runframe;
        }

        var storage: [10000]u8 = undefined;
        trace("{}, \n score = {}\n", .{ arcade.screen.printToBuf(null, null, tile_to_char, &storage), arcade.score_display });
    }

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{nb_blocks}),
        try std.fmt.allocPrint(allocator, "{}", .{arcade.score_display}),
    };
}

pub const main = tools.defaultMain("2019/day13.txt", run);
