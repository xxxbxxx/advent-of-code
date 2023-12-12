// tools_v2:  Vec2: struct -> @Vector

const std = @import("std");
const tools_v1 = @import("tools.zig");
const assert = std.debug.assert;
const print = std.debug.print;

pub const tracy = @import("tracy.zig");
pub const RunError = tools_v1.RunError;
pub const defaultMain = tools_v1.defaultMain;
pub const BestFirstSearch = tools_v1.BestFirstSearch;
pub const ModArith = tools_v1.ModArith;

pub const generate_permutations = tools_v1.generate_permutations;
pub const generate_unique_permutations = tools_v1.generate_unique_permutations;
pub const match_pattern_hexa = tools_v1.match_pattern_hexa;
pub const match_pattern = tools_v1.match_pattern;
pub const nameToEnum = tools_v1.nameToEnum;

pub const IntCode_Computer = tools_v1.IntCode_Computer;

// -----------------------------------------------------------
// -----  2d Map
// -----------------------------------------------------------

pub const Vec2 = @Vector(2, i32);

pub const Vec = struct {
    pub fn clamp(v: Vec2, mini: Vec2, maxi: Vec2) Vec2 {
        return @min(@max(v, mini), maxi);
    }
    pub fn min(a: Vec2, b: Vec2) Vec2 {
        return @min(a, b);
    }
    pub fn max(a: Vec2, b: Vec2) Vec2 {
        return @max(a, b);
    }

    pub fn dist(a: Vec2, b: Vec2) u32 {
        return @reduce(.Add, @abs(a - b));
    }

    pub fn scale(a: i32, v: Vec2) Vec2 {
        return v * @as(Vec2, @splat(a));
    }

    pub const Rot = enum { none, cw, ccw };
    pub fn rotate(vec: Vec2, rot: Rot) Vec2 {
        const v = vec; // copy to avoid return value alias
        return switch (rot) {
            .none => return v,
            .cw => Vec2{ -v[1], v[0] },
            .ccw => Vec2{ v[1], -v[0] },
        };
    }

    pub fn lessThan(_: void, lhs: Vec2, rhs: Vec2) bool {
        if (lhs[1] < rhs[1]) return true;
        if (lhs[1] == rhs[1] and lhs[0] < rhs[0]) return true;
        return false;
    }

    pub fn eq(lhs: Vec2, rhs: Vec2) bool {
        return @reduce(.And, lhs == rhs);
    }

    pub const cardinal4_dirs = [_]Vec2{
        Vec2{ 0, -1 }, // N
        Vec2{ -1, 0 }, // W
        Vec2{ 1, 0 }, // E
        Vec2{ 0, 1 }, // S
    };
    pub const cardinal8_dirs = [_]Vec2{
        Vec2{ 0, -1 }, // N
        Vec2{ -1, -1 },
        Vec2{ -1, 0 }, // W
        Vec2{ -1, 1 },
        Vec2{ 0, 1 }, // S
        Vec2{ 1, 1 },
        Vec2{ 1, 0 }, // E
        Vec2{ 1, -1 },
    };

    pub const Transfo = enum { r0, r90, r180, r270, r0_flip, r90_flip, r180_flip, r270_flip };
    pub const all_tranfos = [_]Transfo{ .r0, .r90, .r180, .r270, .r0_flip, .r90_flip, .r180_flip, .r270_flip };
    pub fn referential(t: Transfo) struct { x: Vec2, y: Vec2 } {
        return switch (t) {
            .r0 => .{ .x = Vec2{ 1, 0 }, .y = Vec2{ 0, 1 } },
            .r90 => .{ .x = Vec2{ 0, 1 }, .y = Vec2{ -1, 0 } },
            .r180 => .{ .x = Vec2{ -1, 0 }, .y = Vec2{ 0, -1 } },
            .r270 => .{ .x = Vec2{ 0, -1 }, .y = Vec2{ 1, 0 } },
            .r0_flip => .{ .x = Vec2{ -1, 0 }, .y = Vec2{ 0, 1 } },
            .r90_flip => .{ .x = Vec2{ 0, 1 }, .y = Vec2{ 1, 0 } },
            .r180_flip => .{ .x = Vec2{ 1, 0 }, .y = Vec2{ 0, -1 } },
            .r270_flip => .{ .x = Vec2{ 0, -1 }, .y = Vec2{ -1, 0 } },
        };
    }
};

pub fn spiralIndexFromPos(p: Vec2) u32 {
    //  https://stackoverflow.com/questions/9970134/get-spiral-index-from-location
    const x = p[0];
    const y = p[1];
    if (y * y >= x * x) {
        var i = 4 * y * y - y - x;
        if (y < x)
            i -= 2 * (y - x);
        return @intCast(i);
    } else {
        var i = 4 * x * x - y - x;
        if (y < x)
            i += 2 * (y - x);
        return @intCast(i);
    }
}

fn sqrtRound(v: usize) usize {
    // todo: cf std.math.sqrt(idx)
    return @intFromFloat(@round(std.math.sqrt(@floatFromInt(v))));
}

pub fn posFromSpiralIndex(idx: usize) Vec2 {
    const i: i32 = @intCast(idx);
    const j: i32 = @intCast(sqrtRound(idx));
    const k = @abs(j * j - i) - j;
    const parity: i32 = @mod(j, 2); // 0 ou 1
    const sign: i32 = if (parity == 0) 1 else -1;
    return Vec2{
        sign * @divFloor(k + j * j - i - parity, 2),
        sign * @divFloor(-k + j * j - i - parity, 2),
    };
}

pub const BBox = struct {
    min: Vec2,
    max: Vec2,
    pub fn includes(bbox: BBox, p: Vec2) bool {
        return @reduce(.And, Vec.clamp(p, bbox.min, bbox.max) == p);
    }
    pub fn isEmpty(bbox: BBox) bool {
        return @reduce(.Or, bbox.min > bbox.max);
    }
    pub fn size(bbox: BBox) u32 {
        assert(!bbox.isEmpty());
        const sz = (bbox.max - bbox.min) + Vec2{ 1, 1 };
        return @intCast(@reduce(.Mul, sz));
    }
    pub const empty = BBox{ .min = Vec2{ 999999, 999999 }, .max = Vec2{ -999999, -999999 } };
};

pub fn Map(comptime TileType: type, comptime width: usize, comptime height: usize, comptime allow_negative_pos: bool) type {
    return struct {
        pub const stride = width;
        pub const Tile = TileType;
        const Self = @This();

        map: [height * width]Tile = undefined, // TODO: u1 -> std.StaticBitSet
        bbox: BBox = BBox.empty,
        default_tile: Tile,

        const center_offset: isize = if (allow_negative_pos) ((width / 2) + stride * (height / 2)) else 0;

        pub fn intToChar(t: Tile) u8 {
            return switch (t) {
                0 => '.',
                1...9 => (@as(u8, @intCast(t)) + '0'),
                else => '?',
            };
        }
        fn defaultTileToChar(t: Tile) u8 {
            if (Tile == u8)
                return t;
            unreachable;
        }
        pub fn printToBuf(map: *const Self, buf: []u8, comptime opt: struct { pos: ?Vec2 = null, clip: ?BBox = null, tileToCharFn: fn (m: Tile) u8 = defaultTileToChar }) []const u8 {
            var i: usize = 0;
            const b = if (opt.clip) |box|
                BBox{
                    .min = Vec.max(map.bbox.min, box.min),
                    .max = Vec.min(map.bbox.max, box.max),
                }
            else
                map.bbox;

            var p = b.min;
            while (p[1] <= b.max[1]) : (p += Vec2{ 0, 1 }) {
                p[0] = b.min[0];
                while (p[0] <= b.max[0]) : (p += Vec2{ 1, 0 }) {
                    const offset = map.offsetof(p);

                    if (opt.pos != null and @reduce(.And, p == opt.pos.?)) {
                        buf[i] = '@';
                    } else {
                        buf[i] = opt.tileToCharFn(map.map[offset]);
                    }
                    i += 1;
                }
                buf[i] = '\n';
                i += 1;
            }
            return buf[0..i];
        }

        pub fn fill(map: *Self, v: Tile, clip: ?BBox) void {
            if (clip) |b| {
                var p = b.min;
                while (p[1] <= b.max[1]) : (p += Vec2{ 0, 1 }) {
                    p[0] = b.min[0];
                    while (p[0] <= b.max[0]) : (p += Vec2{ 1, 0 }) {
                        map.set(p, v);
                    }
                }
            } else {
                @memset(&map.map, v);
            }
        }

        pub fn fillIncrement(map: *Self, v: Tile, clip: BBox) void {
            const b = clip;
            var p = b.min;
            while (p[1] <= b.max[1]) : (p += Vec2{ 0, 1 }) {
                p[0] = b.min[0];
                while (p[0] <= b.max[0]) : (p += Vec2{ 1, 0 }) {
                    if (map.get(p)) |prev| {
                        map.set(p, prev + v);
                    } else {
                        map.set(p, v);
                    }
                }
            }
        }

        pub fn growBBox(map: *Self, p: Vec2) void {
            if (map.bbox.includes(p)) return;
            if (allow_negative_pos) {
                assert(p[0] <= Self.stride / 2 and -p[0] <= Self.stride / 2);
            } else {
                assert(p[0] >= 0 and p[1] >= 0);
            }

            const prev = map.bbox;
            map.bbox.min = Vec.min(p, map.bbox.min);
            map.bbox.max = Vec.max(p, map.bbox.max);

            if (prev.isEmpty()) {
                map.fill(map.default_tile, map.bbox);
            } else {
                var y = map.bbox.min[1];
                while (y < prev.min[1]) : (y += 1) {
                    const o = map.offsetof(Vec2{ map.bbox.min[0], y });
                    @memset(map.map[o .. o + @as(usize, @intCast(map.bbox.max[0] + 1 - map.bbox.min[0]))], map.default_tile);
                }
                if (map.bbox.min[0] < prev.min[0]) {
                    assert(map.bbox.max[0] == prev.max[0]); // une seule colonne, on n'a grandi que d'un point.
                    while (y <= prev.max[1]) : (y += 1) {
                        const o = map.offsetof(Vec2{ map.bbox.min[0], y });
                        @memset(map.map[o .. o + @as(usize, @intCast(prev.min[0] - map.bbox.min[0]))], map.default_tile);
                    }
                } else if (map.bbox.max[0] > prev.max[0]) {
                    assert(map.bbox.min[0] == prev.min[0]);
                    while (y <= prev.max[1]) : (y += 1) {
                        const o = map.offsetof(Vec2{ prev.max[0] + 1, y });
                        @memset(map.map[o .. o + @as(usize, @intCast(map.bbox.max[0] + 1 - (prev.max[0] + 1)))], map.default_tile);
                    }
                } else {
                    y += (prev.max[1] - prev.min[1]) + 1;
                }
                while (y <= map.bbox.max[1]) : (y += 1) {
                    const o = map.offsetof(Vec2{ map.bbox.min[0], y });
                    @memset(map.map[o .. o + @as(usize, @intCast(map.bbox.max[0] + 1 - map.bbox.min[0]))], map.default_tile);
                }
            }
        }

        pub fn offsetof(_: *const Self, p: Vec2) usize {
            return @intCast(center_offset + @reduce(.Add, @as(@Vector(2, isize), p) * @Vector(2, isize){ 1, @intCast(stride) }));
        }
        pub fn at(map: *const Self, p: Vec2) Tile {
            assert(map.bbox.includes(p));
            const offset = map.offsetof(p);
            return map.map[offset];
        }
        pub fn get(map: *const Self, p: Vec2) ?Tile {
            if (!map.bbox.includes(p)) return null;

            const offset = map.offsetof(p);
            if (offset >= map.map.len)
                return null;
            return map.map[offset];
        }

        pub fn set(map: *Self, p: Vec2, t: Tile) void {
            map.growBBox(p);

            const offset = map.offsetof(p);
            map.map[offset] = t;
        }

        pub fn setLine(map: *Self, p: Vec2, t: []const Tile) void {
            if (allow_negative_pos) {
                assert(p[0] <= Self.stride / 2 and -p[0] <= Self.stride / 2);
                assert(p[0] + @as(i32, @intCast(t.len - 1)) <= Self.stride / 2);
            } else {
                assert(p[0] >= 0 and p[1] >= 0);
            }

            map.growBBox(p);
            map.growBBox(p + Vec2{ @intCast(t.len - 1), 0 });

            const offset = map.offsetof(p);
            @memcpy(map.map[offset .. offset + t.len], t);
        }

        const Iterator = struct {
            map: *Self,
            b: BBox,
            p: Vec2,

            pub fn next(self: *@This()) ?Tile {
                if (self.p[1] > self.b.max[1]) return null;
                const t = self.map.at(self.p);
                self.p[0] += 1;
                if (self.p[0] > self.b.max[0]) {
                    self.p[0] = self.b.min[0];
                    self.p[1] += 1;
                }
                return t;
            }

            pub fn nextPos(self: *@This()) ?Vec2 {
                if (self.p[1] > self.b.max[1]) return null;
                const t = self.p;
                self.p[0] += 1;
                if (self.p[0] > self.b.max[0]) {
                    self.p[0] = self.b.min[0];
                    self.p[1] += 1;
                }
                return t;
            }

            const TileAndNeighbours = struct {
                t: *Tile,
                p: Vec2,
                neib4: [4]?Tile,
                neib8: [8]?Tile,

                up_left: ?Tile,
                up: ?Tile,
                up_right: ?Tile,
                left: ?Tile,
                right: ?Tile,
                down_left: ?Tile,
                down: ?Tile,
                down_right: ?Tile,
            };
            pub fn nextEx(self: *@This()) ?TileAndNeighbours {
                if (self.p[1] > self.b.max[1]) return null;

                const t: *Tile = &self.map.map[self.map.offsetof(self.p)];
                const n4 = [4]?Tile{
                    self.map.get(self.p + Vec2{ 1, 0 }),
                    self.map.get(self.p + Vec2{ -1, 0 }),
                    self.map.get(self.p + Vec2{ 0, 1 }),
                    self.map.get(self.p + Vec2{ 0, -1 }),
                };
                const n8 = [8]?Tile{
                    n4[0],                                 n4[1],                                n4[2],                                n4[3],
                    self.map.get(self.p + Vec2{ -1, -1 }), self.map.get(self.p + Vec2{ 1, -1 }), self.map.get(self.p + Vec2{ -1, 1 }), self.map.get(self.p + Vec2{ 1, 1 }),
                };

                const r = TileAndNeighbours{
                    .t = t,
                    .p = self.p,
                    .neib4 = n4,
                    .neib8 = n8,
                    .up_left = n8[4],
                    .up = n4[3],
                    .up_right = n8[5],
                    .left = n4[1],
                    .right = n4[0],
                    .down_left = n8[6],
                    .down = n4[2],
                    .down_right = n8[7],
                };

                self.p[0] += 1;
                if (self.p[0] > self.b.max[0]) {
                    self.p[0] = self.b.min[0];
                    self.p[1] += 1;
                }

                return r;
            }
        };
        pub fn iter(map: *Self, clip: ?BBox) Iterator {
            const b = if (clip) |box|
                BBox{
                    .min = Vec.max(map.bbox.min, box.min),
                    .max = Vec.min(map.bbox.max, box.max),
                }
            else
                map.bbox;

            return Iterator{ .map = map, .b = b, .p = b.min };
        }
    };
}
