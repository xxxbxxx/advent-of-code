const std = @import("std");
const tools = @import("tools");

const with_trace = false;
const with_dissassemble = false;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

const Computer = tools.IntCode_Computer;

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

    const names = [_][]const u8{ "Tester", "Sensor" }; // part 1 and 2.
    var computers: [names.len]Computer = undefined;
    for (computers, 0..) |*c, i| {
        c.* = Computer{
            .name = names[i],
            .memory = try allocator.alloc(Computer.Data, 10000),
        };
    }
    defer for (computers) |c| {
        allocator.free(c.memory);
    };

    const inputs = [names.len]Computer.Data{ 1, 2 };

    var outputs: [names.len]Computer.Data = undefined;

    for (computers) |*c| {
        c.boot(boot_image);
        trace("starting {}\n", c.name);
        _ = async c.run();
    }

    var num_halted: usize = 0;
    while (num_halted < computers.len) {
        num_halted = 0;
        for (computers, 0..) |*c, i| {
            if (c.is_halted()) {
                num_halted += 1;
                continue;
            }

            if (c.io_mode == .input) {
                c.io_port = inputs[i];
                trace("wrting input to {} = {}\n", .{ c.name, c.io_port });
            } else if (c.io_mode == .output) {
                trace("{} outputs {}\n", .{ c.name, c.io_port });
                outputs[i] = c.io_port;
            }

            trace("resuming {}\n", c.name);
            resume c.io_runframe;
        }
    }

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{outputs[0]}),
        try std.fmt.allocPrint(allocator, "{}", .{outputs[1]}),
    };
}

pub const main = tools.defaultMain("2019/day09.txt", run);
