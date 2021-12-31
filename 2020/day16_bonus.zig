const std = @import("std");
const assert = std.debug.assert;
const tools = @import("tools");

const Vec2 = tools.Vec2;

pub fn run(input_text: []const u8, allocator: *std.mem.Allocator) ![2][]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const chunk_sz = 3 * 1024 * 1024;

    const FileRange = struct { name: []const u8, start: usize, size: usize };
    const param: struct {
        files: []const FileRange,
    } = blk: {
        var files = std.ArrayList(FileRange).init(&arena.allocator);

        var it = std.mem.tokenize(input_text, "\n\r");
        while (it.next()) |line| {
            if (tools.match_pattern_hexa("{}...{}  {}", line)) |fields| { //   00000000...00000340  TMStadium.Title.Gbx
                const start = @intCast(usize, fields[0].imm);
                const end = @intCast(usize, fields[1].imm);
                assert(fields[2].lit.len > 0);
                const name = if (std.mem.eql(u8, fields[2].lit, "--- padding ---")) "" else fields[2].lit;
                try files.append(FileRange{
                    .name = name,
                    .start = start,
                    .size = end - start,
                });
            } else {
                std.debug.print("could not parse '{s}'\n", .{line});
                unreachable;
            }
        }

        // std.debug.print("{s}\n", .{input});
        break :blk .{
            .files = files.items,
        };
    };

    const ans1 = ans: {
        //std.debug.print("------------------------------------\n", .{});
        //std.debug.print("------------------------------------\n", .{});
        var padded_sz: usize = 0;
        var base_sz: usize = 0;
        var padding_used: usize = 0;
        var padding_nb: usize = 0;
        var offset: usize = 0;
        var prev_padding: ?FileRange = null;

        for (param.files) |file| {
            var f = file;
            if (f.name.len == 0) {
                padding_nb += 1;
                var rotate_padding = if (prev_padding) |p| (offset - p.start > chunk_sz * 3) else true;

                if (rotate_padding) {
                    padding_used += 1;
                    const partial_chunk = offset % chunk_sz;
                    const padding = if (partial_chunk == 0) 0 else (chunk_sz - partial_chunk);

                    //std.debug.print("### {s} bytes padding ###\n", .{padding});

                    f.start = offset;
                    f.size = padding;
                    padded_sz += f.size;

                    assert((f.start + f.size) % chunk_sz == 0);

                    prev_padding = f;
                } else {
                    f.start = offset;
                    f.size = 0;
                }
                base_sz += 0;
            } else {
                //std.debug.print("{s}\n", .{f.name});
                f.start = offset;
                padded_sz += f.size;
                base_sz += f.size;
            }
            offset = f.start + f.size;
        }
        break :ans std.fmt.allocPrint(&arena.allocator, "{}->{} ({}%)  using {}/{} paddings", .{ base_sz, padded_sz, (padded_sz * 100) / base_sz, padding_used, padding_nb });
    };

    const ans2 = ans: {
        //std.debug.print("------------------------------------\n", .{});
        //std.debug.print("------------------------------------\n", .{});
        var padding_points = std.ArrayList(*const FileRange).init(&arena.allocator);

        var padding_nb: usize = 0;
        var accu: usize = 0;
        for (param.files) |_, i| {
            const it = &param.files[param.files.len - 1 - i];
            if (it.name.len == 0) {
                padding_nb += 1;

                if (accu > chunk_sz * 3) {
                    try padding_points.append(it);
                    accu = chunk_sz / 2; // on prevoit mettre en moyenne cette taille là..
                }
            } else {
                accu += it.size;
            }
        }

        var padded_sz: usize = 0;
        var base_sz: usize = 0;
        var offset: usize = 0;
        for (param.files) |*f| {
            if (f.name.len == 0) {
                if (std.mem.indexOfScalar(*const FileRange, padding_points.items, f) != null) {
                    const partial_chunk = offset % chunk_sz;
                    const padding = if (partial_chunk == 0) 0 else (chunk_sz - partial_chunk);

                    offset += padding;
                    assert(offset % chunk_sz == 0);

                    // std.debug.print("### {s} bytes padding ###\n", .{padding});
                    padded_sz += padding;
                    base_sz += 0;
                }
                // else skip.
            } else {
                // std.debug.print("{s}\n", .{f.name});
                offset += f.size;
                padded_sz += f.size;
                base_sz += f.size;
            }
        }

        break :ans std.fmt.allocPrint(&arena.allocator, "{}->{} ({}%)  using {}/{} paddings", .{ base_sz, padded_sz, (padded_sz * 100) / base_sz, padding_points.items.len, padding_nb });
    };

    return [_][]const u8{
        try std.fmt.allocPrint(allocator, "{s}", .{ans1}),
        try std.fmt.allocPrint(allocator, "{s}", .{ans2}),
    };
}

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().outStream();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = &gpa.allocator;

    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "2020/input_day16_bonus.txt", limit);
    defer allocator.free(text);

    const ans = try run(text, allocator);
    defer allocator.free(ans[0]);
    defer allocator.free(ans[1]);

    try stdout.print("PART 1: {s}\nPART 2: {s}\n", .{ ans[0], ans[1] });
}
