const std = @import("std");
const tools = @import("tools");

const with_trace = false;
const with_dissassemble = false;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

const Vec2 = tools.Vec2;
const Computer = tools.IntCode_Computer;
const Map = tools.Map(u8, 1024 * 2, 1024 * 2, false);

fn cpu_request(cpu: *Computer, boot_image: []const Computer.Data, in: Vec2) bool {
    cpu.boot(boot_image);
    trace("starting {}\n", .{cpu.name});
    _ = async cpu.run();

    assert(cpu.io_mode == .input);
    cpu.io_port = in.x;
    trace("wrting input to {} = {}\n", .{ cpu.name, cpu.io_port });
    resume cpu.io_runframe;

    assert(cpu.io_mode == .input);
    cpu.io_port = in.y;
    trace("wrting input to {} = {}\n", .{ cpu.name, cpu.io_port });
    resume cpu.io_runframe;

    assert(cpu.io_mode == .output);
    trace("{} outputs {}\n", .{ cpu.name, cpu.io_port });
    const ret = (cpu.io_port != 0);
    resume cpu.io_runframe;

    assert(cpu.is_halted());

    return ret;
}

fn request_canfit(cpu: *Computer, boot_image: []const Computer.Data, map: *Map, pos: Vec2, size: Vec2) enum {
    out,
    partial,
    in,
} {
    {
        const p = Vec2{ .x = pos.x, .y = pos.y + size.y - 1 };
        var m = map.get(p) orelse ' ';
        if (m == ' ') {
            const is_affected = cpu_request(cpu, boot_image, p);
            m = if (is_affected) '#' else '.';
            map.set(p, m);
        }

        if (m == '.')
            return .out;
    }

    {
        const p = Vec2{ .x = pos.x + size.x - 1, .y = pos.y };
        var m = map.get(p) orelse ' ';
        if (m == ' ') {
            const is_affected = cpu_request(cpu, boot_image, p);
            m = if (is_affected) '#' else '.';
            map.set(p, m);
        }

        if (m == '.')
            return .partial;
    }

    {
        const p = Vec2{ .x = pos.x, .y = pos.y };
        var m = map.get(p) orelse ' ';
        if (m == ' ') {
            const is_affected = cpu_request(cpu, boot_image, p);
            m = if (is_affected) '#' else '.';
            map.set(p, m);
        }

        assert(m == '#');
        if (m == '.')
            return .out;
    }

    return .in;
}

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

    var cpu = Computer{
        .name = "Drone",
        .memory = try allocator.alloc(Computer.Data, 5000),
    };
    defer allocator.free(cpu.memory);

    var map = try allocator.create(Map);
    defer allocator.destroy(map);
    map.default_tile = ' ';
    map.bbox = tools.BBox.empty;

    const affected = blk: {
        var affected: u32 = 0;
        var cursor = Vec2{ .x = 0, .y = 0 };
        cursor.y = 0;
        while (cursor.y < 50) : (cursor.y += 1) {
            cursor.x = 0;
            while (cursor.x < 50) : (cursor.x += 1) {
                const is_affected = cpu_request(&cpu, boot_image, cursor);

                map.set(cursor, if (is_affected) '#' else '.');
                if (is_affected)
                    affected += 1;
            }
        }
        //{
        //    var buf: [15000]u8 = undefined;
        //    std.debug.print("{s}\n", .{map.printToBuf(cursor, null, null, &buf)});
        //}
        trace("affected: {}\n", .{affected});
        break :blk affected;
    };

    const answer = blk: {
        var cursor = Vec2{ .x = 1300, .y = 750 };
        var lineref: ?Vec2 = null;
        while (true) {
            const fits = request_canfit(&cpu, boot_image, map, cursor, Vec2{ .x = 100, .y = 100 });

            if (fits == .in)
                break;
            if (lineref != null and fits == .out) {
                trace("Trying {}-{}\n", .{ lineref, cursor });
                cursor = Vec2{ .x = lineref.?.x, .y = lineref.?.y + 1 };
                lineref = null;
            } else if (lineref == null and fits != .out) {
                lineref = cursor;
            } else {
                cursor.x += 1;
            }
        }

        trace("fits @ {} : {}\n", .{ cursor, cursor.x * 10000 + cursor.y });
        break :blk cursor.x * 10000 + cursor.y;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{}", .{affected}),
        try std.fmt.allocPrint(allocator, "{}", .{answer}),
    };
}

pub const main = tools.defaultMain("2019/day19.txt", run);
