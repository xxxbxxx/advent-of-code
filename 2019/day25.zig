const std = @import("std");
const tools = @import("tools");

const with_trace = false;
const with_dissassemble = false;
const interractive = false;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

pub const main = tools.defaultMain("2019/day25.txt", run);

const Computer = tools.IntCode_Computer;
const Map = tools.Map(u8, 512, 512, true);
const Vec2 = tools.Vec2;

const State = struct {
    room_index: usize,
    inventory: u64,
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
    items: [2]usize,
    items_count: usize,
    doors: [4]bool,
    pos: Vec2,
};

pub fn run(input: []const u8, allocator: std.mem.Allocator) tools.RunError![2][]const u8 {
    const int_count = std.mem.count(u8, input, ",") + 1;
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
        .name = "droid",
        .memory = try allocator.alloc(Computer.Data, 8000),
    };
    defer allocator.free(cpu.memory);

    var arena_alloc = std.heap.ArenaAllocator.init(allocator);
    defer arena_alloc.deinit();
    const arena = arena_alloc.allocator();

    var map = Map{ .default_tile = '#' };
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
            .inventory = 0,
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

    var items = std.ArrayList([]const u8).init(allocator);
    defer items.deinit();
    try items.append("infinite loop");
    try items.append("giant electromagnet");
    try items.append("escape pod");
    try items.append("molten lava");
    try items.append("photons");
    const items_firstvalid = items.items.len;

    const dirs = [_]Vec2{ .{ .x = 0, .y = -1 }, .{ .x = -1, .y = 0 }, .{ .x = 0, .y = 1 }, .{ .x = 1, .y = 0 } };
    const cmds = [_][]const u8{ "north", "west", "south", "east" };

    const ans1 = ans: {
        if (interractive) {
            const stdin = &std.io.getStdIn().reader();
            const stdout = std.io.getStdOut().writer();
            cpu.boot(boot_image);
            _ = async cpu.run();
            while (true) {
                assert(!cpu.is_halted());
                if (cpu.io_mode == .input) {
                    cpu.io_port = stdin.readByte() catch return error.UnsupportedInput;
                    //try stdout.print("{c}", .{@intCast(u8, cpu.io_port)});
                    //trace("wrting input to {s} = {}\n", .{ cpu.name, cpu.io_port });
                }

                if (cpu.io_mode == .output) {
                    //trace("{s} outputs {}\n", .{ cpu.name, cpu.io_port });
                    stdout.writeByte(@intCast(cpu.io_port)) catch return error.UnsupportedInput;
                }
                //trace("resuming {s}\n", .{cpu.name});
                resume cpu.io_runframe;
            }
            unreachable;
        } else {
            while (bfs.pop()) |node| {
                cpu.boot(boot_image);
                // trace("starting {s}\n", .{cpu.name});
                _ = async cpu.run();

                // replay commands
                // trace("applying commands: {}\n", .{node.trace.commands[0..node.trace.len]});
                {
                    const commands = node.trace.commands[0..node.trace.len];
                    for (commands) |command| {
                        assert(!cpu.is_halted());
                        var deathtext: [1000]u8 = undefined;
                        var deathtextlen: usize = 0;
                        while (cpu.io_mode != .input) {
                            deathtext[deathtextlen] = @intCast(cpu.io_port);
                            deathtextlen += 1;
                            if (cpu.is_halted()) {
                                trace("halted by {s}, after commands: {s}\n", .{ deathtext[0..deathtextlen], node.trace.commands[0..node.trace.len] });
                                unreachable;
                            }
                            // drop output
                            resume cpu.io_runframe;
                        }

                        cpu.io_port = command;

                        resume cpu.io_runframe;
                    }
                }

                // parse desc
                var found_new_room = false;
                const room_index: ?usize = blk: {
                    var room: Room = undefined;
                    var desc: [1000]u8 = undefined;
                    var out: usize = 0;
                    while (true) {
                        if (cpu.is_halted()) {
                            trace("halted by {s}, after commands: {s}\n", .{ desc[0..out], node.trace.commands[0..node.trace.len] });
                            const sentence = "You should be able to get in by typing ";
                            if (std.mem.indexOf(u8, &desc, sentence)) |index| {
                                const str = desc[index + sentence.len ..];
                                const code = std.mem.tokenize(u8, str, " ").next().?;
                                break :ans try std.fmt.parseInt(u64, code, 10);
                            }
                            unreachable;
                        }
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
                    room.items_count = 0;
                    room.pos = node.state.next_pos;
                    {
                        var sec: enum {
                            title,
                            desc,
                            doors,
                            items,
                            done,
                        } = .title;
                        var it = std.mem.tokenize(u8, desc[0..out], "\n");
                        while (it.next()) |line0| {
                            const line = std.mem.trim(u8, line0, " \n\r\t");
                            if (line.len == 0)
                                continue;
                            switch (sec) {
                                .title => {
                                    if (std.mem.eql(u8, line[0..3], "== ")) {
                                        room.name = line[3 .. line.len - 3]; //try arena.dupe(u8, line[3 .. line.len - 3]);
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
                                        room.desc = line; //try arena.dupe(u8, line);
                                    }
                                },
                                .doors => {
                                    if (std.mem.eql(u8, line, "A loud, robotic voice says \"Alert! Droids on this ship are heavier than the detected value!\" and you are ejected back to the checkpoint.")) {
                                        trace("rejected (too light) after: {s}\n", .{node.trace.commands[0..node.trace.len]});
                                        sec = .done;
                                        break :blk null;
                                    } else if (std.mem.eql(u8, line, "A loud, robotic voice says \"Alert! Droids on this ship are lighter than the detected value!\" and you are ejected back to the checkpoint.")) {
                                        trace("rejected (too heavy) after: {s}\n", .{node.trace.commands[0..node.trace.len]});
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
                                        const item = line[2..];
                                        const item_num = itemblk: {
                                            for (items.items, 0..) |existing, i| {
                                                if (std.mem.eql(u8, item, existing))
                                                    break :itemblk i;
                                            }
                                            try items.append(try arena.dupe(u8, item));
                                            break :itemblk items.items.len - 1;
                                        };
                                        room.items[room.items_count] = item_num;
                                        room.items_count += 1;
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
                    }

                    for (rooms.items, 0..) |r, i| {
                        if (std.mem.eql(u8, room.name, r.name)) {
                            assert(room.pos.x == r.pos.x and room.pos.y == r.pos.y);
                            assert(std.mem.eql(bool, &room.doors, &r.doors));
                            assert(std.mem.eql(u8, room.desc, r.desc));
                            break :blk i;
                        }
                    }

                    found_new_room = true;

                    const newroom = try rooms.addOne();
                    newroom.* = room;
                    newroom.name = try arena.dupe(u8, room.name);
                    newroom.desc = try arena.dupe(u8, room.desc);
                    break :blk rooms.items.len - 1;
                };

                if (room_index == null) // action erronée
                    continue;

                // update map
                {
                    const room = rooms.items[room_index.?];
                    const p = room.pos;
                    map.set(p, ' ');
                    for (room.doors, 0..) |open, d| {
                        const np = Vec2{ .x = p.x + dirs[d].x, .y = p.y + dirs[d].y };
                        const prev_val = map.get(np) orelse '#';

                        const new_val: u8 = if (open) '.' else '#';
                        if (prev_val == '#' or prev_val == new_val) {
                            map.set(np, new_val);
                        } else {
                            map.set(np, '+');
                        }
                    }

                    //var buf: [1000]u8 = undefined;
                    //trace("map=\n{}\n", .{map.printToBuf(p, null, null, &buf)});
                }

                if (found_new_room) {
                    const room = rooms.items[room_index.?];
                    const p = room.pos;
                    trace("\n==========================\nfound a new room! commands:\n{s}desc:{s}\n", .{ node.trace.commands[0..node.trace.len], room });
                    var buf: [1000]u8 = undefined;
                    trace("map=\n{s}\n", .{map.printToBuf(p, null, null, &buf)});
                    trace("so far, {} rooms and {} items\n", .{ rooms.items.len, items.items.len });
                    trace("so far, agenda: {}, visited: {}\n", .{ bfs.agenda.items.len, bfs.visited.count() });
                }

                // insert new nodes:
                {
                    const room = rooms.items[room_index.?];
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
                                .inventory = node.state.inventory,
                                .next_pos = Vec2{ .x = p.x + dirs[d].x * 2, .y = p.y + dirs[d].y * 2 },
                            },
                            .trace = node.trace,
                        };
                        tools.fmt_bufAppend(&new.trace.commands, &new.trace.len, "{s}\n", .{cmds[d]});
                        try bfs.insert(new);

                        for (room.items[0..room.items_count]) |itemidx| {
                            if (itemidx < items_firstvalid)
                                continue;
                            new.cost = node.cost + 1 + 1;
                            new.rating = node.rating + 1 + 10;
                            new.trace.len = node.trace.len;
                            new.state.inventory |= (@as(u64, 1) << @intCast(itemidx));
                            tools.fmt_bufAppend(&new.trace.commands, &new.trace.len, "take {s}\n", .{items.items[itemidx]});
                            tools.fmt_bufAppend(&new.trace.commands, &new.trace.len, "{s}\n", .{cmds[d]});
                            try bfs.insert(new);
                        }
                    }
                }
            }
        }
        unreachable;
    };

    const ans2 = ans: {
        break :ans "gratis!";
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{s}", .{ans2}),
    };
}
