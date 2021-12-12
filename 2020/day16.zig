const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

const Vec2 = tools.Vec2;

pub fn run(input_text: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const Range = struct { min: u32, max: u32 };
    const FieldRange = struct { name: []const u8, r1: Range, r2: Range };
    const Ticket = []const u32;
    const param: struct {
        fields: []const FieldRange,
        my_ticket: Ticket,
        all_tickets: []Ticket,
    } = blk: {
        var field_descs = std.ArrayList(FieldRange).init(arena.allocator());
        var tickets = std.ArrayList(Ticket).init(arena.allocator());

        var it = std.mem.tokenize(u8, input_text, "\n\r");
        while (it.next()) |line| {
            if (tools.match_pattern("{}: {}-{} or {}-{}", line)) |fields| { //zone: 47-249 or 265-972
                const name = fields[0].lit;
                const m0 = @intCast(u32, fields[1].imm);
                const m1 = @intCast(u32, fields[2].imm);
                const m2 = @intCast(u32, fields[3].imm);
                const m3 = @intCast(u32, fields[4].imm);
                try field_descs.append(FieldRange{
                    .name = name,
                    .r1 = Range{ .min = m0, .max = m1 },
                    .r2 = Range{ .min = m2, .max = m3 },
                });
            } else if (tools.match_pattern("your ticket:", line)) |_| {
                continue;
            } else if (tools.match_pattern("nearby tickets:", line)) |_| {
                continue;
            } else { // 73,167,113,61,89,59,191,103,67,83,163,109,101,71,97,151,107,79,157,53
                const numbers = try arena.allocator().alloc(u32, 32);
                var nb: u32 = 0;
                var it2 = std.mem.tokenize(u8, line, ",");
                while (it2.next()) |num| {
                    numbers[nb] = std.fmt.parseInt(u32, num, 10) catch unreachable;
                    nb += 1;
                }
                try tickets.append(numbers[0..nb]);
            }
        }

        // std.debug.print("{}\n", .{input});
        break :blk .{
            .fields = field_descs.items,
            .my_ticket = tickets.items[0],
            .all_tickets = tickets.items,
        };
    };

    const ans1 = ans: {
        var valid = [_]bool{false} ** 1000;
        for (param.fields) |f| {
            var i: u32 = f.r1.min;
            while (i < f.r1.max) : (i += 1) {
                valid[i] = true;
            }
            var j: u32 = f.r2.min;
            while (j < f.r2.max) : (j += 1) {
                valid[j] = true;
            }
        }

        var sum: u32 = 0;
        for (param.all_tickets) |t| {
            for (t) |it| {
                if (!valid[it]) sum += it;
            }
        }
        break :ans sum;
    };

    const ans2 = ans: {
        var valid = [_]bool{false} ** 1000;
        for (param.fields) |f| {
            var i: u32 = f.r1.min;
            while (i < f.r1.max) : (i += 1) {
                valid[i] = true;
            }
            var j: u32 = f.r2.min;
            while (j < f.r2.max) : (j += 1) {
                valid[j] = true;
            }
        }

        var possible_fields = [_]bool{true} ** 1000;
        const nb_fields = param.fields.len;
        for (param.all_tickets) |t| {
            const is_valid_ticket = for (t) |it| {
                if (!valid[it]) break false;
            } else true;
            if (!is_valid_ticket) continue;

            assert(t.len == nb_fields);
            for (t) |val, j| {
                for (param.fields) |f, i| {
                    if ((val >= f.r1.min and val <= f.r1.max) or (val >= f.r2.min and val <= f.r2.max)) {
                        // vlaue valid for field
                    } else {
                        possible_fields[j * nb_fields + i] = false;
                    }
                }
            }
        }

        var nb_fields_determined: u32 = 0;
        var field_indexes: [100]usize = undefined;
        while (nb_fields_determined < nb_fields) {
            for (param.fields) |_, i| {
                //std.debug.print("field n°{}: ", .{i});
                var index: ?usize = null;
                var unique = true;
                for (possible_fields[i * nb_fields .. (i + 1) * nb_fields]) |b, j| {
                    if (b) {
                        if (index != null) unique = false;
                        //     std.debug.print("X", .{});
                        index = j;
                    } else {
                        //   std.debug.print("_", .{});
                    }
                }
                if (index == null) { // fait précédement
                    // std.debug.print("\n", .{});
                } else if (unique) {
                    const idx = index.?;
                    field_indexes[i] = idx;
                    nb_fields_determined += 1;
                    // std.debug.print(" -> {}\n", .{param.fields[idx].name});

                    var j: usize = 0;
                    while (j < nb_fields) : (j += 1) {
                        possible_fields[j * nb_fields + idx] = false;
                    }
                } else {
                    // std.debug.print(" -> ???\n", .{});
                }
            }
        }

        var sum: u64 = 1;
        for (param.my_ticket) |v, i| {
            const name = param.fields[field_indexes[i]].name;
            //std.debug.print("{}: {}\n", .{ name, v });
            if (std.mem.startsWith(u8, name, "departure")) {
                sum *= v;
            }
        }
        break :ans sum;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2020/input_day16.txt", run);
