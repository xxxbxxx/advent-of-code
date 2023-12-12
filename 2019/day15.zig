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

const MapTile = u2;
const MapTiles = struct {
    const unknown: MapTile = 0;
    const empty: MapTile = 1;
    const wall: MapTile = 2;
    const oxygen: MapTile = 3;

    fn tochar(m: MapTile) u8 {
        const symbols = [_]u8{ '?', ' ', '#', 'O' };
        return symbols[m];
    }
};

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

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

    const map_size = 100;

    const Map = tools.Map(MapTile, map_size, map_size, true);
    var map = Map{ .default_tile = MapTiles.unknown };

    var robot_cpu = Computer{
        .name = "Robot",
        .memory = try arena.allocator().alloc(Computer.Data, 2048),
    };
    const robot_pos = Vec2{ .x = 0, .y = 0 };

    robot_cpu.boot(boot_image);
    trace("starting {}\n", .{robot_cpu.name});
    _ = async robot_cpu.run();

    const Move = struct {
        cmd: Computer.Data,
        dir: Vec2,
    };
    const moves = [_]Move{
        .{ .cmd = 1, .dir = Vec2{ .x = 0, .y = -1 } },
        .{ .cmd = 3, .dir = Vec2{ .x = -1, .y = 0 } },
        .{ .cmd = 2, .dir = Vec2{ .x = 0, .y = 1 } },
        .{ .cmd = 4, .dir = Vec2{ .x = 1, .y = 0 } },
    };
    const RobotOut = struct {
        const wall: Computer.Data = 0;
        const empty: Computer.Data = 1;
        const target: Computer.Data = 2;
    };

    const Node = struct {
        state: Computer,
        pos: Vec2,
        moves: u32,
    };
    const Agenda = std.ArrayList(Node);

    var agenda = Agenda.init(allocator);
    defer agenda.deinit();
    try agenda.ensureTotalCapacity(100000);

    try agenda.append(Node{
        .state = robot_cpu,
        .pos = robot_pos,
        .moves = 1,
    });

    var target: ?Vec2 = null;
    var moves_to_target: u32 = undefined;

    // part1: dist to target
    while (agenda.items.len > 0) {
        const node = agenda.orderedRemove(0);

        for (moves) |m| {
            const newpos = Vec2{ .x = node.pos.x + m.dir.x, .y = node.pos.y + m.dir.y };
            const tile = map.get(newpos) orelse MapTiles.unknown;
            if (tile != MapTiles.unknown)
                continue;

            const cpu = &robot_cpu;
            cpu.* = node.state;
            cpu.memory = try arena.allocator().alloc(Computer.Data, 2048);
            @memcpy(cpu.memory, node.state.memory);

            assert(!cpu.is_halted() and cpu.io_mode == .input);
            cpu.io_port = m.cmd;
            trace("wrting input to {} = {}\n", .{ cpu.name, cpu.io_port });
            trace("resuming {}\n", .{cpu.name});
            resume cpu.io_runframe;

            assert(!cpu.is_halted() and cpu.io_mode == .output);
            trace("{} outputs {}\n", .{ cpu.name, cpu.io_port });
            switch (cpu.io_port) {
                RobotOut.wall => {
                    map.set(newpos, MapTiles.wall);
                    var storage: [5000]u8 = undefined;
                    trace("{} depth={}\n", .{ map.printToBuf(newpos, null, MapTiles.tochar, &storage), node.moves });
                    continue;
                },
                RobotOut.empty => {
                    map.set(newpos, MapTiles.empty);
                    trace("resuming {}\n", .{cpu.name});
                    resume cpu.io_runframe;

                    try agenda.append(Node{
                        .state = cpu.*,
                        .pos = newpos,
                        .moves = node.moves + 1,
                    });
                },
                RobotOut.target => {
                    map.set(newpos, MapTiles.oxygen);
                    var storage: [5000]u8 = undefined;
                    trace("{} target depth={}\n", .{ map.printToBuf(newpos, null, MapTiles.tochar, &storage), node.moves });
                    target = newpos;
                    moves_to_target = node.moves;
                },
                else => unreachable,
            }
        }
    }

    // part2: seconds for diffusion O2
    var seconds: u32 = 0;
    var changed = true;
    while (changed) {
        changed = false;
        const map_init = map;
        var pos = map.bbox.min;
        while (pos.y < map.bbox.max.y) : (pos.y += 1) {
            pos.x = map.bbox.min.x;
            while (pos.x < map.bbox.max.x) : (pos.x += 1) {
                const offset = map.offsetof(pos);
                const sq = &map.map[offset];
                if (sq.* != MapTiles.empty)
                    continue;

                for (moves) |m| {
                    const neighbour_pos = Vec2{ .x = pos.x + m.dir.x, .y = pos.y + m.dir.y };
                    const neighbour_mapoffset = map.offsetof(neighbour_pos);
                    if (map_init.map[neighbour_mapoffset] == MapTiles.oxygen) {
                        sq.* = MapTiles.oxygen;
                        changed = true;
                    }
                }
            }
        }
        if (changed)
            seconds += 1;
        var storage: [5000]u8 = undefined;
        trace("{} seconds={}\n", .{ map.printToBuf(target.?, null, MapTiles.tochar, &storage), seconds });
    }

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{moves_to_target}),
        try std.fmt.allocPrint(allocator, "{}", .{seconds}),
    };
}

pub const main = tools.defaultMain("2019/day15.txt", run);
