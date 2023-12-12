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

    const names = [_][]const u8{ "Amp A", "Amp B", "Amp C", "Amp D", "Amp E" };
    const computers: [5]Computer = undefined;
    for (computers, 0..) |*c, i| {
        c.* = Computer{
            .name = names[i],
            .memory = try allocator.alloc(Computer.Data, int_count),
        };
    }
    defer for (computers) |c| {
        allocator.free(c.memory);
    };

    // part1:
    var max_output_1: Computer.Data = 0;
    {
        var buf: [5]Computer.Data = undefined;
        var it = tools.generate_permutations(Computer.Data, &[_]Computer.Data{ 0, 1, 2, 3, 4 });
        while (it.next(&buf)) |phases| {
            var bus: Computer.Data = 0;

            for (computers, 0..) |*c, i| {
                c.boot(boot_image);

                // input the phase:
                trace("starting {}\n", .{c.name});
                _ = async c.run();

                assert(!c.is_halted() and c.io_mode == .input);
                c.io_port = phases[i];
                trace("wrting input to {} = {}\n", .{ c.name, c.io_port });
                trace("resuming {}\n", .{c.name});
                resume c.io_runframe;

                assert(!c.is_halted() and c.io_mode == .input);
                c.io_port = bus;
                trace("wrting input to {} = {}\n", .{ c.name, c.io_port });
                trace("resuming {}\n", .{c.name});
                resume c.io_runframe;

                assert(!c.is_halted() and c.io_mode == .output);
                bus = c.io_port;
                trace("copying output from {} = {}\n", .{ c.name, c.io_port });
                trace("resuming {}\n", .{c.name});
                resume c.io_runframe;

                assert(c.is_halted());
            }

            if (bus > max_output_1) {
                max_output_1 = bus;
            }
        }
    }

    // part 2:
    var max_output_2: Computer.Data = 0;
    {
        var buf: [5]Computer.Data = undefined;
        var it = tools.generate_permutations(Computer.Data, &[_]Computer.Data{ 9, 8, 7, 6, 5 });
        while (it.next(&buf)) |phases| {
            for (computers, 0..) |*c, i| {
                c.boot(boot_image);

                // input the phase:
                trace("starting {}\n", .{c.name});
                _ = async c.run();
                assert(!c.is_halted() and c.io_mode == .input);

                c.io_port = phases[i];
                trace("wrting input to {} = {}\n", .{ c.name, c.io_port });
                trace("resuming {}\n", .{c.name});
                resume c.io_runframe;
            }

            const output = blk: {
                var bus: Computer.Data = 0;
                var halted = false;
                while (!halted) {
                    for (computers, 0..) |*c, i| {
                        if (c.io_mode == .input) {
                            c.io_port = bus;
                            trace("wrting input to {} = {}\n", .{ c.name, c.io_port });
                        }

                        trace("resuming {}\n", .{c.name});
                        resume c.io_runframe;

                        if (c.is_halted()) {
                            assert(halted or i == 0); // everybody should stop at the same time.
                            halted = true;
                        } else if (c.io_mode == .output) {
                            trace("copying output from {} = {}\n", .{ c.name, c.io_port });
                            bus = c.io_port;
                        }
                    }
                }
                break :blk bus;
            };

            if (output > max_output_2) {
                max_output_2 = output;
            }
        }
    }
    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{max_output_1}),
        try std.fmt.allocPrint(allocator, "{}", .{max_output_2}),
    };
}

pub const main = tools.defaultMain("2019/day07.txt", run);
