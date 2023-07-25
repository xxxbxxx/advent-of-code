const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

const Policy = struct { letter: u8, min: u8, max: u8 };
fn check_password1(pol: Policy, password: []const u8) bool {
    var count: u8 = 0;
    for (password) |it| {
        if (it == pol.letter) count += 1;
    }
    return count >= pol.min and count <= pol.max;
}
fn check_password2(pol: Policy, password: []const u8) bool {
    if (password.len < pol.max)
        return false;
    return ((password[pol.min - 1] == pol.letter and password[pol.max - 1] != pol.letter) or (password[pol.min - 1] != pol.letter and password[pol.max - 1] == pol.letter));
}

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {

    // part1
    const ans1 = ans: {
        var valid: usize = 0;
        var it = std.mem.tokenize(u8, input, "\n\r");
        while (it.next()) |line| {
            const fields = tools.match_pattern("{}-{} {}: {}", line) orelse unreachable;
            const policy = Policy{
                .min = @intCast(fields[0].imm),
                .max = @intCast(fields[1].imm),
                .letter = fields[2].lit[0],
            };
            const password = fields[3].lit;
            if (check_password1(policy, password))
                valid += 1;
        }
        break :ans valid;
    };

    // part1
    const ans2 = ans: {
        var valid: usize = 0;
        var it = std.mem.tokenize(u8, input, "\n\r");
        while (it.next()) |line| {
            const fields = tools.match_pattern("{}-{} {}: {}", line) orelse unreachable;
            const policy = Policy{
                .min = @intCast(fields[0].imm),
                .max = @intCast(fields[1].imm),
                .letter = fields[2].lit[0],
            };
            const password = fields[3].lit;
            if (check_password2(policy, password))
                valid += 1;
        }
        break :ans valid;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2020/input_day02.txt", run);
