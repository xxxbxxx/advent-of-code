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
    //const stdout = std.io.getStdOut().writer();

    var cpu = Computer{
        .name = "Springdroid",
        .memory = try allocator.alloc(Computer.Data, 50000),
    };
    defer allocator.free(cpu.memory);

    const part1: Computer.Data = ans1: {

        //      J = 'd and(!a or !b or !c)'
        const ascii_programm =
            \\NOT A J
            \\NOT J T
            \\AND B T
            \\AND C T
            \\NOT T J
            \\AND D J
            \\WALK
            \\
        ;

        cpu.boot(boot_image);
        trace("starting {}\n", .{cpu.name});
        _ = async cpu.run();

        var i_input: usize = 0;

        while (!cpu.is_halted()) {
            if (cpu.io_mode == .input) {
                cpu.io_port = ascii_programm[i_input];
                i_input += 1;
                trace("wrting input to {} = {}\n", .{ cpu.name, cpu.io_port });
            }

            if (cpu.io_mode == .output) {
                trace("{} outputs {}\n", .{ cpu.name, cpu.io_port });
                if (cpu.io_port < 127) {
                    // stdout.print("{c}", .{@intCast(u8, cpu.io_port)}) catch unreachable;
                } else {
                    break :ans1 cpu.io_port;
                }
            }
            trace("resuming {}\n", .{cpu.name});
            resume cpu.io_runframe;
        }
        unreachable;
    };

    const part2: Computer.Data = ans2: {

        //      J = J and (H OR E)  (suffisant)
        //const ascii_programm =
        //    \\NOT A J
        //    \\NOT J T
        //    \\AND B T
        //    \\AND C T
        //    \\NOT T J
        //    \\AND D J
        //    \\NOT J T
        //    \\OR H T
        //    \\OR E T
        //    \\AND T J
        //    \\RUN
        //    \\
        //;

        // J = J and (H OR (E and (I or F))   plus robuste!
        const ascii_programm =
            \\NOT A J
            \\NOT J T
            \\AND B T
            \\AND C T
            \\NOT T J
            \\AND D J
            \\NOT F T
            \\NOT T T
            \\OR I T
            \\AND E T
            \\OR H T
            \\AND T J
            \\RUN
            \\
        ;

        cpu.boot(boot_image);
        trace("starting {}\n", .{cpu.name});
        _ = async cpu.run();

        var i_input: usize = 0;

        while (!cpu.is_halted()) {
            if (cpu.io_mode == .input) {
                cpu.io_port = ascii_programm[i_input];
                i_input += 1;
                trace("wrting input to {} = {}\n", .{ cpu.name, cpu.io_port });
            }

            if (cpu.io_mode == .output) {
                trace("{} outputs {}\n", .{ cpu.name, cpu.io_port });
                if (cpu.io_port < 127) {
                    //stdout.print("{c}", .{@intCast(u8, cpu.io_port)}) catch unreachable;
                } else {
                    break :ans2 cpu.io_port;
                }
            }
            trace("resuming {}\n", .{cpu.name});
            resume cpu.io_runframe;
        }
        unreachable;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{part1}),
        try std.fmt.allocPrint(allocator, "{}", .{part2}),
    };
}

pub const main = tools.defaultMain("2019/day21.txt", run);
