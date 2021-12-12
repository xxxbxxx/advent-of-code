const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

pub fn run(input: []const u8, allocator: std.mem.Allocator) ![2][]const u8 {
    const required_fields = enum {
        byr, // (Birth Year)
        iyr, // (Issue Year)
        eyr, // (Expiration Year)
        hgt, // (Height)
        hcl, // (Hair Color)
        ecl, // (Eye Color)
        pid, // (Passport ID)
        // cid, // (Country ID)  -> optional
    };
    const required_field_names = comptime std.meta.fieldNames(required_fields);

    // === part 1 ==============
    const ans1 = ans: {
        var valid_entries: u32 = 0;
        var it = std.mem.split(u8, input, "\n\n");
        while (it.next()) |entry| {
            const is_valid = inline for (required_field_names) |field| {
                if (std.mem.indexOf(u8, entry, field ++ ":") == null)
                    break false;
            } else true;

            if (is_valid) valid_entries += 1;
        }
        break :ans valid_entries;
    };

    // === part 2 ==============
    const ans2 = ans: {
        var valid_entries: u32 = 0;
        var it1 = std.mem.split(u8, input, "\n\n");
        next_entry: while (it1.next()) |entry| {
            var fields_count: u32 = 0;
            var it2 = std.mem.tokenize(u8, entry, " \n\t");
            next_kvpair: while (it2.next()) |kv| {
                if (kv.len < 5 or kv[3] != ':')
                    continue :next_entry;
                const key = kv[0..3];
                const value = kv[4..];

                const field = tools.nameToEnum(required_fields, key) catch continue :next_kvpair; // ignore unknown keys

                switch (field) {
                    .byr => { // (Birth Year) - four digits; at least 1920 and at most 2002.
                        if (value.len != 4) continue :next_entry;
                        const v = std.fmt.parseInt(u32, value, 10) catch continue :next_entry;
                        if (v < 1920 or v > 2002) continue :next_entry;
                        fields_count += 1;
                    },
                    .iyr => { // (Issue Year) - four digits; at least 2010 and at most 2020.
                        if (value.len != 4) continue :next_entry;
                        const v = std.fmt.parseInt(u32, value, 10) catch continue :next_entry;
                        if (v < 2010 or v > 2020) continue :next_entry;
                        fields_count += 1;
                    },
                    .eyr => { // (Expiration Year) - four digits; at least 2020 and at most 2030.
                        if (value.len != 4) continue :next_entry;
                        const v = std.fmt.parseInt(u32, value, 10) catch continue :next_entry;
                        if (v < 2020 or v > 2030) continue :next_entry;
                        fields_count += 1;
                    },
                    .hgt => {
                        // (Height) - a number followed by either cm or in:
                        //    If cm, the number must be at least 150 and at most 193.
                        //    If in, the number must be at least 59 and at most 76.
                        if (value.len < 4) continue :next_entry;
                        const unit = value[value.len - 2 ..];
                        const h = std.fmt.parseInt(u32, value[0 .. value.len - 2], 10) catch continue :next_entry;
                        if (std.mem.eql(u8, unit, "cm")) {
                            if (h < 150 or h > 193) continue :next_entry;
                        } else if (std.mem.eql(u8, unit, "in")) {
                            if (h < 59 or h > 76) continue :next_entry;
                        } else {
                            continue :next_entry;
                        }
                        fields_count += 1;
                    },
                    .hcl => { // (Hair Color) - a # followed by exactly six characters 0-9 or a-f.
                        if (value.len != 7) continue :next_entry;
                        if (value[0] != '#') continue :next_entry;
                        _ = std.fmt.parseInt(u32, value[1..], 16) catch continue :next_entry;
                        fields_count += 1;
                    },
                    .ecl => { // (Eye Color) - exactly one of: amb blu brn gry grn hzl oth.
                        if (value.len != 3) continue :next_entry;
                        if (std.mem.indexOf(u8, "amb blu brn gry grn hzl oth", value) == null) continue :next_entry;
                        fields_count += 1;
                    },
                    .pid => { // (Passport ID) - a nine-digit number, including leading zeroes.
                        if (value.len != 9) continue :next_entry;
                        _ = std.fmt.parseInt(u32, value, 10) catch continue :next_entry;
                        fields_count += 1;
                    },
                }

                if (fields_count == std.meta.fields(required_fields).len)
                    valid_entries += 1;
            }
        }
        break :ans valid_entries;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{}", .{ans2}),
    };
}

pub const main = tools.defaultMain("2020/input_day04.txt", run);
