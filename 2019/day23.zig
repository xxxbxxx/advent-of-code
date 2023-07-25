const std = @import("std");
const tools = @import("tools");

const with_trace = false;
const with_dissassemble = false;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

const Computer = tools.IntCode_Computer;

pub fn run(input: []const u8, allocator: std.mem.Allocator) tools.RunError![2][]const u8 {
    const int_count = std.mem.count(u8, input, ",") + 1;

    const boot_image = try allocator.alloc(Computer.Data, int_count);
    defer allocator.free(boot_image);
    {
        var it = std.mem.split(u8, input, ",");
        var i: usize = 0;
        while (it.next()) |num| : (i += 1) {
            const trimmed = std.mem.trim(u8, num, " \n\r\t");
            boot_image[i] = try std.fmt.parseInt(Computer.Data, trimmed, 10);
        }

        if (with_dissassemble)
            Computer.disassemble(boot_image);
    }

    const Packet = [2]Computer.Data;
    const NIC = struct {
        cpu: Computer,
        in_queue: std.ArrayList(Packet),
        in_index: u32,
        out_packet: Packet,
        out_dest: u32,
        out_index: u32,
    };
    var prev_nat: ?Packet = undefined;
    var nat: ?Packet = undefined;
    var cpus: [50]NIC = undefined;
    for (cpus) |*c, i| {
        c.cpu = Computer{
            .name = try std.fmt.allocPrint(allocator, "Computer n°{}", .{i}),
            .memory = try allocator.alloc(Computer.Data, 5000),
        };
        c.in_queue = std.ArrayList(Packet).init(allocator);
        c.in_index = 0;
        c.out_packet = undefined;
        c.out_index = 0;
        c.out_dest = undefined;

        c.cpu.boot(boot_image);
        trace("starting {s}\n", .{c.cpu.name});
        _ = async c.cpu.run();

        assert(c.cpu.io_mode == .input);
        c.cpu.io_port = @intCast(Computer.Data, i);
        trace("wrting input to {s} = {}\n", .{ c.cpu.name, c.cpu.io_port });
        trace("resuming {s}\n", .{c.cpu.name});
        resume c.cpu.io_runframe;
    }
    defer {
        for (cpus) |c| {
            c.in_queue.deinit();
            allocator.free(c.cpu.memory);
            allocator.free(c.cpu.name);
        }
    }

    var ans1: ?Computer.Data = null;
    var ans2: ?Computer.Data = null;

    while (true) {
        var net_idle = true;
        for (cpus) |*c| {
            assert(!c.cpu.is_halted());
            if (c.cpu.io_mode == .input) {
                if (c.in_queue.items.len == 0) {
                    c.cpu.io_port = -1;
                } else {
                    net_idle = false;
                    const p = c.in_queue.items[0];
                    c.cpu.io_port = p[c.in_index];
                    c.in_index += 1;
                    if (c.in_index >= p.len) {
                        c.in_index = 0;
                        _ = c.in_queue.orderedRemove(0);
                    }
                }
                trace("wrting input to {s} = {}\n", .{ c.cpu.name, c.cpu.io_port });
            }

            if (c.cpu.io_mode == .output) {
                net_idle = false;
                trace("{s} outputs {}\n", .{ c.cpu.name, c.cpu.io_port });
                if (c.out_index == 0) {
                    c.out_dest = @intCast(u32, c.cpu.io_port);
                } else {
                    c.out_packet[c.out_index - 1] = c.cpu.io_port;
                }
                c.out_index += 1;
                if (c.out_index >= c.out_packet.len + 1) {
                    c.out_index = 0;
                    if (c.out_dest >= cpus.len) {
                        if (ans1 == null) ans1 = c.out_packet[1];
                        nat = c.out_packet;
                    } else {
                        try cpus[c.out_dest].in_queue.append(c.out_packet);
                    }
                }
            }
            trace("resuming {s}\n", .{c.cpu.name});
            resume c.cpu.io_runframe;
        }

        if (net_idle and nat != null) {
            if (prev_nat) |prev| {
                if (prev[1] == nat.?[1]) {
                    ans2 = nat.?[1];
                    break;
                }
            }
            try cpus[0].in_queue.append(nat.?);
            prev_nat = nat;
            nat = null;
        }
    }

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{?}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{?}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2019/day23.txt", run);
