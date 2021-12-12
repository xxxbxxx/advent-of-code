const std = @import("std");

const with_trace = true;

const assert = std.debug.assert;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const limit = 1 * 1024 * 1024 * 1024;
    const text = try std.fs.cwd().readFileAlloc(allocator, "day8.txt", limit);

    var size_doubleescpaed: u32 = 0;
    var size_escaped: u32 = 0;
    var size_final: u32 = 0;
    var it = std.mem.split(u8, text, "\n");
    while (it.next()) |line_full| {
        const line_quoted = std.mem.trim(u8, line_full, " \n\r\t");
        if (line_quoted.len < 2)
            continue;
        assert(line_quoted[0] == '"' and line_quoted[line_quoted.len - 1] == '"');
        const line = line_quoted[1 .. line_quoted.len - 1];
        size_escaped += 2;
        size_doubleescpaed += 6;
        var i: u32 = 0;
        while (i < line.len) : (i += 1) {
            const c = line[i];
            if (c == '\\') {
                size_doubleescpaed += 2;
                const c1 = line[i + 1];
                if (c1 == '\\' or c1 == '"') {
                    size_doubleescpaed += 2;
                    size_escaped += 2;
                    size_final += 1;
                    i += 1;
                } else if (c1 == 'x') {
                    size_doubleescpaed += 3;
                    size_escaped += 4;
                    size_final += 1;
                    i += 3;
                } else {
                    unreachable;
                }
            } else {
                size_doubleescpaed += 1;
                size_escaped += 1;
                size_final += 1;
            }
        }
    }

    const out = std.io.getStdOut().writer();
    try out.print("chars {}-{} = {}\n", size_escaped, size_final, size_escaped - size_final);
    try out.print("chars {}-{} = {}\n", size_doubleescpaed, size_escaped, size_doubleescpaed - size_escaped);

    //    return error.SolutionNotFound;
}
