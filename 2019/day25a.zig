const std = @import("std");
const tools = @import("tools");

const with_trace = true;
const with_dissassemble = false;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.warn(fmt, args);
}

const Computer = tools.IntCode_Computer;
const Map = tools.Map(u8, 512, 512, true);
const Vec2 = tools.Vec2;

const State = struct {
    room_index: usize,
    door: u2,
    next_pos: Vec2,
};
const Trace = struct {
    //    cpu: Computer,
    //    memory: [1000]Computer.Data,
    len: usize,
    commands: [4096]u8,
};

const BFS = tools.BestFirstSearch(State, Trace);

const Room = struct {
    name: []const u8,
    desc: []const u8,
    items: [][]const u8,
    doors: [4]bool,
    pos: Vec2,
};

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().outStream();
    const stdin = &std.io.getStdIn().inStream().stream;
    const allocator = &std.heap.ArenaAllocator.init(std.heap.page_allocator).allocator;
    const limit = 1 * 1024 * 1024 * 1024;

    const text = try std.fs.cwd().readFileAlloc(allocator, "day25.txt", limit);
    defer allocator.free(text);
    const int_count = blk: {
        var int_count: usize = 0;
        var it = std.mem.split(text, ",");
        while (it.next()) |_| int_count += 1;
        break :blk int_count;
    };

    const boot_image = try allocator.alloc(Computer.Data, int_count);
    defer allocator.free(boot_image);
    {
        var it = std.mem.split(text, ",");
        var i: usize = 0;
        while (it.next()) |n_text| : (i += 1) {
            const trimmed = std.mem.trim(u8, n_text, " \n\r\t");
            boot_image[i] = try std.fmt.parseInt(Computer.Data, trimmed, 10);
        }
    }

    if (with_dissassemble)
        Computer.disassemble(boot_image);

    var cpu = Computer{
        .name = "droid",
        .memory = try allocator.alloc(Computer.Data, 64000),
    };
    defer allocator.free(cpu.memory);

    cpu.reboot(boot_image);
    trace("starting {s}\n", .{cpu.name});
    _ = async cpu.run();

    var map = Map{};
    for (map.map) |*m| {
        m.* = '#';
    }
    map.set(Vec2{ .x = 0, .y = 0 }, ' ');

    var bfs = BFS.init(allocator);
    defer bfs.deinit();

    try bfs.insert(BFS.Node{
        .cost = 0,
        .rating = 0,
        .state = State{
            .room_index = 0,
            .next_pos = Vec2{ .x = 0, .y = 0 },
            .door = 0,
            //.cpu = cpu,
            //.memory = try std.mem.dupe(u8, cpu.memory),
        },
        .trace = Trace{ .len = 0, .commands = undefined },
    });

    var rooms = std.ArrayList(Room).init(allocator);
    defer rooms.deinit();
    {
        const room0 = try rooms.addOne();
        room0.name = "the void";
    }

    const dirs = [_]Vec2{ .{ .x = 0, .y = -1 }, .{ .x = -1, .y = 0 }, .{ .x = 0, .y = 1 }, .{ .x = 1, .y = 0 } };
    const cmds = [_][]const u8{ "north", "west", "south", "east" };

    const interractive = false;
    if (interractive) {
        while (true) {
            assert(!cpu.is_halted());
            if (cpu.io_mode == .input) {
                cpu.io_port = try stdin.readByte();
                //try stdout.print("{c}", .{@intCast(u8, cpu.io_port)});
                //trace("wrting input to {s} = {s}\n", .{ cpu.name, cpu.io_port });
            }

            if (cpu.io_mode == .output) {
                //trace("{s} outputs {s}\n", .{ cpu.name, cpu.io_port });
                try stdout.writeByte(@intCast(cpu.io_port));
            }
            //trace("resuming {s}\n", .{cpu.name});
            resume cpu.io_runframe;
        }
    } else {
        while (bfs.pop()) |node| {
            cpu.reboot(boot_image);
            trace("starting {s}\n", .{cpu.name});
            _ = async cpu.run();

            // replay commands
            // trace("applying commands: {s}\n", .{node.trace.commands[0..node.trace.len]});
            {
                const commands = node.trace.commands[0..node.trace.len];
                for (commands) |input| {
                    assert(!cpu.is_halted());
                    while (cpu.io_mode != .input) {
                        // drop output
                        resume cpu.io_runframe;
                    }

                    cpu.io_port = input;

                    resume cpu.io_runframe;
                }
            }

            // parse desc
            var room_index: ?usize = blk: {
                var room: Room = undefined;
                var desc: [1000]u8 = undefined;
                var out: usize = 0;
                while (true) {
                    assert(!cpu.is_halted());
                    if (cpu.io_mode == .input) {
                        break;
                    }
                    if (cpu.io_mode == .output) {
                        desc[out] = @intCast(cpu.io_port);
                        out += 1;
                    }
                    resume cpu.io_runframe;
                }

                // trace("parsing desc: {s}\n", .{desc[0..out]});

                room.desc = "";
                room.doors = [_]bool{ false, false, false, false };
                room.items = &[0][]u8{s};
                room.pos = node.state.next_pos;
                var sec: enum {
                    title,
                    desc,
                    doors,
                    items,
                    done,
                } = .title;
                var it = std.mem.tokenize(desc[0..out], "\n");
                while (it.next()) |line0| {
                    const line = std.mem.trim(u8, line0, " \n\r\t");
                    if (line.len == 0)
                        continue;
                    switch (sec) {
                        .title => {
                            if (std.mem.eql(u8, line[0..3], "== ")) {
                                room.name = line[3 .. line.len - 3]; //try std.mem.dupe(allocator, u8, line[3 .. line.len - 3]);
                                sec = .desc;
                            } else {
                                trace("Skipping: {s}\n", .{line});
                                trace("after commands: {s}\n", .{node.trace.commands[0..node.trace.len]});
                                unreachable;
                            }
                        },
                        .desc => {
                            if (std.mem.eql(u8, line, "Doors here lead:")) {
                                sec = .doors;
                            } else {
                                assert(room.desc.len == 0);
                                room.desc = line; //try std.mem.dupe(allocator, u8, line);
                            }
                        },
                        .doors => {
                            if (std.mem.eql(u8, line, "A loud, robotic voice says \"Alert! Droids on this ship are heavier than the detected value!\" and you are ejected back to the checkpoint.")) {
                                sec = .done;
                                break :blk null;
                            } else if (std.mem.eql(u8, line, "Items here:")) {
                                sec = .items;
                            } else if (std.mem.eql(u8, line, "Command?")) {
                                sec = .done;
                            } else if (std.mem.eql(u8, line, "- north")) {
                                room.doors[0] = true;
                            } else if (std.mem.eql(u8, line, "- west")) {
                                room.doors[1] = true;
                            } else if (std.mem.eql(u8, line, "- south")) {
                                room.doors[2] = true;
                            } else if (std.mem.eql(u8, line, "- east")) {
                                room.doors[3] = true;
                            } else {
                                trace("Skipping: {s}\n", .{line});
                                trace("after commands: {s}\n", .{node.trace.commands[0..node.trace.len]});
                                unreachable;
                            }
                        },
                        .items => {
                            if (std.mem.eql(u8, line[0..2], "- ")) {
                                //room.name = std.mem.dupe(u8, line[3..line.len-3]);
                                //sec = .desc;
                            } else if (std.mem.eql(u8, line, "Command?")) {
                                sec = .done;
                            } else {
                                trace("Skipping: {s}\n", .{line});
                                trace("after commands: {s}\n", .{node.trace.commands[0..node.trace.len]});
                                unreachable;
                            }
                        },
                        .done => {
                            trace("Skipping: {s}\n", .{line});
                            trace("after commands: {s}\n", .{node.trace.commands[0..node.trace.len]});
                            unreachable;
                        },
                    }
                }
                trace("room= {s}\n", .{room});

                for (rooms.items, 0..) |r, i| {
                    if (std.mem.eql(u8, room.name, r.name)) {
                        assert(room.pos.x == r.pos.x and room.pos.y == r.pos.y);
                        assert(std.mem.eql(bool, &room.doors, &r.doors));
                        assert(std.mem.eql(u8, room.desc, r.desc));
                        break :blk i;
                    }
                }
                const newroom = try rooms.addOne();
                newroom.* = room;
                newroom.name = try std.mem.dupe(allocator, u8, room.name);
                newroom.desc = try std.mem.dupe(allocator, u8, room.desc);
                break :blk rooms.len - 1;
            };

            if (room_index == null) // action erronée
                continue;

            // update map
            {
                const room = rooms.at(room_index.?);
                const p = room.pos;
                map.set(p, ' ');
                for (room.doors, 0..) |open, d| {
                    const np = Vec2{ .x = p.x + dirs[d].x, .y = p.y + dirs[d].y };
                    var prev_val = map.get(np) orelse '#';

                    const new_val: u8 = if (open) '.' else '#';
                    if (prev_val == '#' or prev_val == new_val) {
                        map.set(np, new_val);
                    } else {
                        map.set(np, '+');
                    }
                }

                var buf: [1000]u8 = undefined;
                trace("map=\n{s}\n", .{map.print_to_buf(p, null, &buf)});
            }

            // insert new nodes:
            {
                const room = rooms.at(room_index.?);
                const p = room.pos;

                for (room.doors, 0..) |open, d| {
                    if (!open)
                        continue;

                    var new = BFS.Node{
                        .cost = node.cost + 1,
                        .rating = node.rating + 1,
                        .state = State{
                            .room_index = room_index.?,
                            .door = @intCast(d),
                            .next_pos = Vec2{ .x = p.x + dirs[d].x * 2, .y = p.y + dirs[d].y * 2 },
                        },
                        .trace = node.trace,
                    };
                    std.mem.copy(u8, new.trace.commands[new.trace.len .. new.trace.len + cmds[d].len], cmds[d]);
                    new.trace.commands[new.trace.len + cmds[d].len] = '\n';
                    new.trace.len += cmds[d].len + 1;

                    try bfs.insert(new);
                }
            }
        }
    }
}
