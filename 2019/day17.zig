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

const Map = tools.Map(u7, 100, 100, false);
const MapTiles = struct {
    const unknown: Map.Tile = '?';
    const empty: Map.Tile = '.';
    const scafold: Map.Tile = '#';
    const visited: Map.Tile = 'O';
};

fn longuest_seq(candidate: []const u8, string: []const u8) []const u8 {
    var l = candidate.len;
    var best_reduc: usize = 0;
    var best_l: usize = 0;
    while (l > 1) : (l -= 1) {
        if (candidate[l - 1] == ',')
            continue;
        var matches: u32 = 0;
        var pos: usize = 0;
        while (std.mem.indexOfPos(u8, string, pos, candidate[0..l])) |p| {
            matches += 1;
            pos = p + 1;
        }

        if (matches > 1) {
            trace("matched {} times {}\n", .{ matches, candidate[0..l] });
        }

        if (matches * l > best_reduc) {
            best_reduc = matches * l;
            best_l = l;
        }
    }
    return candidate[0..best_l];
}

fn reduce(string: []const u8, pattern: []const u8, replace: []const u8, storage: []u8) []const u8 {
    var cursor: usize = 0;
    var first = true;
    var it = std.mem.split(u8, string, pattern);
    while (it.next()) |str| {
        if (!first) {
            @memcpy(storage[cursor .. cursor + replace.len], replace);
            cursor += replace.len;
        }
        @memcpy(storage[cursor .. cursor + str.len], str);
        first = false;
        cursor += str.len;
    }
    return storage[0..cursor];
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

    var cpu = Computer{
        .name = "Vacuum",
        .memory = try allocator.alloc(Computer.Data, 5000),
    };
    defer allocator.free(cpu.memory);

    cpu.boot(boot_image);
    cpu.memory[0] = 2;
    trace("starting {}\n", .{cpu.name});
    _ = async cpu.run();

    var map = Map{ .default_tile = MapTiles.unknown };

    var map_cursor = Vec2{ .x = 0, .y = 0 };

    var robot_pos: ?Vec2 = null;
    var robot_dir: u2 = 0;
    const Dir = struct {
        const up: u2 = 0;
        const left: u2 = 1;
        const down: u2 = 2;
        const right: u2 = 3;
    };

    const moves = [_]Vec2{
        Vec2{ .x = 0, .y = -1 },
        Vec2{ .x = -1, .y = 0 },
        Vec2{ .x = 0, .y = 1 },
        Vec2{ .x = 1, .y = 0 },
    };

    while (!cpu.is_halted()) {
        if (cpu.io_mode == .input) {
            break;
            //cpu.io_port = 0;
            //trace("wrting input to {} = {}\n", .{ cpu.name, cpu.io_port });
        }

        if (cpu.io_mode == .output) {
            trace("{} outputs {}\n", .{ cpu.name, cpu.io_port });
            //try stdout.print("{c}", .{@intCast(u8, cpu.io_port)});

            var write: ?Map.Tile = null;
            switch (cpu.io_port) {
                10 => map_cursor = Vec2{ .x = 0, .y = map_cursor.y + 1 },
                '#' => write = MapTiles.scafold,
                '.' => write = MapTiles.empty,
                '^' => {
                    write = MapTiles.scafold;
                    robot_pos = map_cursor;
                    robot_dir = Dir.up;
                },
                'v' => {
                    write = MapTiles.scafold;
                    robot_pos = map_cursor;
                    robot_dir = Dir.down;
                },
                '>' => {
                    write = MapTiles.scafold;
                    robot_pos = map_cursor;
                    robot_dir = Dir.left;
                },
                '<' => {
                    write = MapTiles.scafold;
                    robot_pos = map_cursor;
                    robot_dir = Dir.right;
                },
                else => {
                    trace("{c}", .{@as(u8, @intCast(cpu.io_port))});

                    //                    unreachable,
                },
            }

            trace("{}:{}\n", .{ map_cursor, write });
            if (write) |tile| {
                map.set(map_cursor, tile);
                map_cursor.x += 1;
            }
        }
        trace("resuming {}\n", .{cpu.name});
        resume cpu.io_runframe;
    }

    var alignpar: i32 = 0;
    var nb_scafolds: u32 = 0;
    {
        assert(map.bbox.min.x == 0 and map.bbox.min.y == 0);
        var y: i32 = 1;
        while (y < map.bbox.max.y - 1) : (y += 1) {
            var x: i32 = 1;
            while (x < map.bbox.max.x - 1) : (x += 1) {
                const m = map.get(Vec2{ .x = x, .y = y }) orelse MapTiles.unknown;
                if (m != MapTiles.scafold)
                    continue;

                const up = map.at(Vec2{ .x = x, .y = y - 1 });
                const down = map.at(Vec2{ .x = x, .y = y + 1 });
                const left = map.at(Vec2{ .x = x - 1, .y = y });
                const right = map.at(Vec2{ .x = x + 1, .y = y });

                if (up == MapTiles.scafold and down == MapTiles.scafold and left == MapTiles.scafold and right == MapTiles.scafold) {
                    alignpar += (x * y);
                }
            }
        }

        for (map.map) |m| {
            if (m == MapTiles.scafold)
                nb_scafolds += 1;
        }
        var storage: [10000]u8 = undefined;
        trace("{}, align={}\n", .{ map.printToBuf(robot_pos.?, null, null, &storage), alignpar });
    }

    // sequence de parcours:
    var commandstring_storage: [500]u8 = undefined;
    var commandstring: []u8 = undefined;
    {
        var seq: [500]struct {
            rot: i2,
            steps: u8,
        } = undefined;
        var pos = robot_pos.?;
        {
            map.set(pos, MapTiles.visited);
            nb_scafolds -= 1;
        }
        var iseq: usize = 0;
        while (nb_scafolds > 0) {

            // tout droit tant qu'on peut
            const d = moves[robot_dir];
            const m = map.get(Vec2{ .x = pos.x + d.x, .y = pos.y + d.y }) orelse MapTiles.unknown;
            if (m == MapTiles.scafold or m == MapTiles.visited) {
                const s = &seq[iseq - 1];
                s.steps += 1;
                pos = Vec2{ .x = pos.x + d.x, .y = pos.y + d.y };

                if (m == MapTiles.scafold) {
                    map.set(pos, MapTiles.visited);
                    nb_scafolds -= 1;
                }
                continue;
            }

            // tourne sinon
            const dR = moves[robot_dir +% 1];
            const dL = moves[robot_dir -% 1];
            const mR = map.get(Vec2{ .x = pos.x + dR.x, .y = pos.y + dR.y }) orelse MapTiles.unknown;
            const mL = map.get(Vec2{ .x = pos.x + dL.x, .y = pos.y + dL.y }) orelse MapTiles.unknown;
            if (mR == MapTiles.scafold) {
                const s = &seq[iseq];
                iseq += 1;
                s.rot = 1;
                s.steps = 0;
                robot_dir +%= 1;
            } else if (mL == MapTiles.scafold) {
                const s = &seq[iseq];
                iseq += 1;
                s.rot = -1;
                s.steps = 0;
                robot_dir -%= 1;
            } else {
                unreachable; // TODO backtrack?
            }
        }

        var storage: [10000]u8 = undefined;
        trace("{}, steps={}\n", .{ map.printToBuf(pos, null, null, &storage), iseq });

        {
            var l: usize = 0;
            for (seq[0..iseq]) |s| {
                if (s.rot == -1) {
                    tools.fmt_bufAppend(&commandstring_storage, &l, ",R,{}", .{s.steps});
                } else {
                    tools.fmt_bufAppend(&commandstring_storage, &l, ",L,{}", .{s.steps});
                }
            }
            commandstring = commandstring_storage[1..l];
            trace("seq='{}' len={}\n", .{ commandstring, commandstring.len });
        }
    }

    // version simple "on reduit par seq la plus longue en zero." marche pas
    //    const seqA = longuest_seq(commandstring[0..(if (commandstring.len / 2 <= 20) commandstring.len / 2 else 20)], commandstring);

    var storage_1: [200]u8 = undefined;
    var storage_2: [200]u8 = undefined;
    var storage_3: [200]u8 = undefined;
    const inputs = blk: {
        var l1: usize = 1;
        while (l1 <= 20) : (l1 += 1) {
            const patternA = commandstring[0..l1];
            if (patternA[0] == ',' or patternA[patternA.len - 1] == ',')
                continue;
            const reduceA = reduce(commandstring, patternA, "A", &storage_1);

            var l2: usize = 1;
            while (l2 <= 20) : (l2 += 1) {
                const patternB = std.mem.trim(u8, reduceA, ",ABC")[0..l2];
                if (patternB[0] == ',' or patternB[patternB.len - 1] == ',')
                    continue;
                const reduceB = reduce(reduceA, patternB, "B", &storage_2);
                var l3: usize = 1;
                while (l3 <= 20) : (l3 += 1) {
                    const patternC = std.mem.trim(u8, reduceB, ",ABC")[0..l3];
                    if (patternC[0] == ',' or patternC[patternC.len - 1] == ',')
                        continue;
                    const reduceC = reduce(reduceB, patternC, "C", &storage_3);

                    if (reduceC.len < 20) {
                        break :blk .{ reduceC, patternA, patternB, patternC };
                    }
                }
            }
        }
        unreachable;
    };

    trace("inputs: '{s}' with A='{s}' B='{s}' C='{s}'\n", inputs);

    var fullinputseq_buf: [100]u8 = undefined;
    const fullinputseq = std.fmt.bufPrint(&fullinputseq_buf, "{s}\n{s}\n{s}\n{s}\nn\n", inputs) catch unreachable;
    var i_input: usize = 0;
    var answer2: Computer.Data = undefined;
    //    cpu.boot(boot_image);
    //    cpu.memory[0] = 2;
    //    trace("starting {}\n", .{cpu.name});
    //    _ = async cpu.run();

    while (!cpu.is_halted()) {
        if (cpu.io_mode == .input) {
            cpu.io_port = fullinputseq[i_input];
            i_input += 1;
            trace("wrting input to {s} = {}\n", .{ cpu.name, cpu.io_port });
        }

        if (cpu.io_mode == .output) {
            trace("{s} outputs {}\n", .{ cpu.name, cpu.io_port });
            if (cpu.io_port < 127) {
                trace("{c}", .{@as(u8, @intCast(cpu.io_port))});
            } else {
                trace("\nans = {}\n", .{cpu.io_port});
                answer2 = cpu.io_port;
            }
        }
        trace("resuming {s}\n", .{cpu.name});
        resume cpu.io_runframe;
    }

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{alignpar}),
        try std.fmt.allocPrint(allocator, "{}", .{answer2}),
    };
}

pub const main = tools.defaultMain("2019/day17.txt", run);
