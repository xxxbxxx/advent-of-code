const std = @import("std");
const builtin = @import("builtin");

pub const enable = if (builtin.is_test) false else @import("build_options").enable_tracy;

extern fn ___tracy_emit_frame_mark_start(name: ?[*:0]const u8) void;
extern fn ___tracy_emit_frame_mark_end(name: ?[*:0]const u8) void;
//extern fn ___tracy_set_thread_name(name: ?[*:0]const u8) void;

extern fn ___tracy_emit_zone_begin_callstack(
    srcloc: *const ___tracy_source_location_data,
    depth: c_int,
    active: c_int,
) ___tracy_c_zone_context;

extern fn ___tracy_alloc_srcloc(line: u32, source: ?[*:0]const u8, sourceSz: usize, function: ?[*:0]const u8, functionSz: usize) u64;
extern fn ___tracy_alloc_srcloc_name(line: u32, source: ?[*:0]const u8, sourceSz: usize, function: ?[*:0]const u8, functionSz: usize, name: ?[*:0]const u8, nameSz: usize) u64;
extern fn ___tracy_emit_zone_begin_alloc_callstack(srcloc: u64, depth: c_int, active: c_int) ___tracy_c_zone_context;
extern fn ___tracy_emit_zone_begin_alloc(srcloc: u64, active: c_int) ___tracy_c_zone_context;

extern fn ___tracy_emit_zone_end(ctx: ___tracy_c_zone_context) void;

pub const ___tracy_source_location_data = extern struct {
    name: ?[*:0]const u8,
    function: [*:0]const u8,
    file: [*:0]const u8,
    line: u32,
    color: u32,
};

pub const ___tracy_c_zone_context = extern struct {
    id: u32,
    active: c_int,

    pub fn end(self: ___tracy_c_zone_context) void {
        ___tracy_emit_zone_end(self);
    }
};

pub const Ctx = if (enable) ___tracy_c_zone_context else struct {
    pub fn end(self: Ctx) void {
        _ = self;
    }
};

pub inline fn trace(comptime src: std.builtin.SourceLocation) Ctx {
    if (!enable) return .{};

    const loc: ___tracy_source_location_data = .{
        .name = null,
        .function = src.fn_name.ptr,
        .file = src.file.ptr,
        .line = src.line,
        .color = 0,
    };
    return ___tracy_emit_zone_begin_callstack(&loc, 1, 1);
}

const TraceOptions = struct { name: ?[:0]const u8 = null, color: u32 = 0, callstack: bool = false };
pub inline fn traceEx(comptime src: std.builtin.SourceLocation, opt: TraceOptions) Ctx {
    if (!enable) return .{};

    const srcloc = if (opt.name) |name|
        ___tracy_alloc_srcloc_name(src.line, src.file.ptr, src.file.len, src.fn_name.ptr, src.fn_name.len, name.ptr, name.len)
    else
        ___tracy_alloc_srcloc(src.line, src.file.ptr, src.file.len, src.fn_name.ptr, src.fn_name.len);

    if (opt.callstack)
        return ___tracy_emit_zone_begin_alloc_callstack(srcloc, 7, 1)
    else
        return ___tracy_emit_zone_begin_alloc(srcloc, 1);
}

pub const ___tracy_c_frame_context = extern struct {
    name: ?[*:0]const u8,
    pub fn end(self: ___tracy_c_frame_context) void {
        ___tracy_emit_frame_mark_end(self.name);
    }
};

pub const FrameCtx = if (enable) ___tracy_c_frame_context else struct {
    pub fn end(self: FrameCtx) void {
        _ = self;
    }
};

pub fn traceFrame(name: ?[*:0]const u8) FrameCtx {
    if (!enable) return .{};

    ___tracy_emit_frame_mark_start(name);
    return ___tracy_c_frame_context{ .name = name };
}
