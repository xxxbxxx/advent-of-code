const std = @import("std");
const tools = @import("tools");

const Computer = struct {
    const Data = i32;

    boot_image: []const Data,
    memory_bank: []Data,

    const insn_halt = 99;
    const insn_add = 1;
    const insn_mul = 2;
    const insn_input = 3;
    const insn_output = 4;
    const insn_jne = 5; // jump-if-true
    const insn_jeq = 6; // jump-if-false
    const insn_slt = 7; // less than
    const insn_seq = 8; // equals

    const insn_operands = [_][]const bool{
        &[_]bool{}, // invalid
        &[_]bool{ false, false, true }, // add
        &[_]bool{ false, false, true }, // mul
        &[_]bool{true}, // input
        &[_]bool{false}, // output
        &[_]bool{ false, false }, // jne
        &[_]bool{ false, false }, // jeq
        &[_]bool{ false, false, true }, // slt
        &[_]bool{ false, false, true }, // seq
    };

    fn read_param(c: *Computer, par: Data, mod: bool) Data {
        return (if (mod) par else c.memory_bank[@intCast(par)]);
    }

    fn run(c: *Computer, input: Data) Data {
        @memcpy(c.memory_bank, c.boot_image);

        const mem = c.memory_bank;
        var param_registers: [3]Data = undefined;
        var output: Data = 0;
        var pc: usize = 0;
        while (true) {
            // decode insn opcode
            const opcode_and_mods: usize = @intCast(mem[pc]);
            pc += 1;
            const opcode = opcode_and_mods % 100;
            const mods = [_]bool{
                (opcode_and_mods / 100) % 10 != 0,
                (opcode_and_mods / 1000) % 10 != 0,
                (opcode_and_mods / 10000) % 10 != 0,
            };
            if (opcode == insn_halt)
                break;

            // read parameters from insn operands
            const p = blk: {
                const operands = insn_operands[opcode];
                const p = param_registers[0..operands.len];
                var i: usize = 0;
                while (i < operands.len) : (i += 1) {
                    p[i] = read_param(c, mem[pc + i], mods[i] or operands[i]);
                }
                pc += operands.len;
                break :blk p;
            };

            // execute insn
            switch (opcode) {
                insn_halt => break,
                insn_add => mem[@intCast(p[2])] = p[0] + p[1],
                insn_mul => mem[@intCast(p[2])] = p[0] * p[1],
                insn_input => mem[@intCast(p[0])] = input,
                insn_output => output = p[0],
                insn_jne => pc = if (p[0] != 0) @intCast(p[1]) else pc,
                insn_jeq => pc = if (p[0] == 0) @intCast(p[1]) else pc,
                insn_slt => mem[@intCast(p[2])] = if (p[0] < p[1]) 1 else 0,
                insn_seq => mem[@intCast(p[2])] = if (p[0] == p[1]) 1 else 0,

                else => @panic("Illegal instruction"),
            }
        }

        return output;
    }
};

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    const int_count = blk: {
        var int_count: usize = 0;
        var it = std.mem.split(u8, input, ",");
        while (it.next()) |_| int_count += 1;
        break :blk int_count;
    };

    const image = try allocator.alloc(Computer.Data, int_count);
    defer allocator.free(image);
    {
        var it = std.mem.split(u8, input, ",");
        var i: usize = 0;
        while (it.next()) |n_text| : (i += 1) {
            const trimmed = std.mem.trim(u8, n_text, " \n\r\t");
            image[i] = try std.fmt.parseInt(Computer.Data, trimmed, 10);
        }
    }

    var computer = Computer{
        .boot_image = image,
        .memory_bank = try allocator.alloc(Computer.Data, int_count),
    };
    defer allocator.free(computer.memory_bank);

    const ans1 = try std.fmt.allocPrint(allocator, "{}", .{computer.run(1)});
    const ans2 = try std.fmt.allocPrint(allocator, "{}", .{computer.run(5)});
    return [_][]const u8{ ans1, ans2 };
}

pub const main = tools.defaultMain("2019/day05.txt", run);
