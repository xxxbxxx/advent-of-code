const std = @import("std");
const tools = @import("tools");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().writer();
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day4.txt", limit);
    defer allocator.free(text);

    var words = std.StringHashMap(void).init(allocator);
    defer words.deinit();

    const part1 = false;
    var count: u32 = 0;
    var it = std.mem.split(u8, text, "\n");
    while (it.next()) |line0| {
        const line = std.mem.trim(u8, line0, " \n\t\r");
        const valid = valid: {
            if (line.len == 0) break :valid false;
            words.clear();
            var it2 = std.mem.tokenize(u8, line, " \t");
            while (it2.next()) |field| {
                if (part1) {
                    if (try words.put(field, {})) |_| {
                        break :valid false;
                    }
                } else {
                    //trace("word={}\n", .{field});
                    var it3 = try tools.generate_unique_permutations(u8, field, allocator);
                    defer it3.deinit();
                    while (try it3.next()) |permut| {
                        //trace("  permut={}\n", .{dup});
                        if (try words.put(permut, {})) |_| {
                            break :valid false;
                        }
                    }
                }
            }
            break :valid true;
        };

        trace("'{}' >>> {}\n", .{ line, valid });
        if (valid) count += 1;
    }
    try stdout.print("count={}\n", .{count});

    //    return error.SolutionNotFound;
}
