const std = @import("std");
const assert = std.debug.assert;
const print = std.debug.print;

pub const RunError = std.mem.Allocator.Error || std.fmt.ParseIntError || error{ UnsupportedInput, InvalidEnumName, UnexpectedEOS };
const MainError = RunError || std.fs.File.OpenError || std.os.ReadError || std.os.SeekError || std.os.WriteError;

pub fn defaultMain(comptime input_fname: []const u8, comptime runFn: fn (input: []const u8, allocator: std.mem.Allocator) RunError![2][]const u8) fn () MainError!void {
    const T = struct {
        pub fn main() MainError!void {
            const stdout = std.io.getStdOut().writer();

            var gpa = std.heap.GeneralPurposeAllocator(.{}){};
            defer _ = gpa.deinit();
            const allocator = gpa.allocator();

            //var args_it = std.process.args();
            //defer args_it.deinit();
            //const prog_name = try args_it.next(allocator) orelse @panic("Could not find self argument");
            //allocator.free(prog_name);
            //const short_name = std.fs.path.basename(prog_name);

            const limit = 1024 * 1024;
            const text = if (input_fname.len > 0) try std.fs.cwd().readFileAlloc(allocator, input_fname, limit) else "";
            defer if (text.len > 0) allocator.free(text);

            const answer = try runFn(text, allocator);
            defer allocator.free(answer[0]);
            defer allocator.free(answer[1]);

            try stdout.print("{s}:\n", .{input_fname});
            for (answer) |ans, i| {
                const multiline = (std.mem.indexOfScalar(u8, ans, '\n') != null);
                if (multiline) {
                    try stdout.print("\tPART {d}:\n{s}", .{ i + 1, ans });
                } else {
                    try stdout.print("\tPART {d}: {s}\n", .{ i + 1, ans });
                }
            }
        }
    };
    return T.main;
}

// -----------------------------------------------------------
// -----  2d Map
// -----------------------------------------------------------

pub const Vec2 = struct {
    x: i32,
    y: i32,

    pub fn min(a: Vec2, b: Vec2) Vec2 {
        return Vec2{
            .x = if (a.x < b.x) a.x else b.x,
            .y = if (a.y < b.y) a.y else b.y,
        };
    }
    pub fn max(a: Vec2, b: Vec2) Vec2 {
        return Vec2{
            .x = if (a.x > b.x) a.x else b.x,
            .y = if (a.y > b.y) a.y else b.y,
        };
    }
    pub fn add(a: Vec2, b: Vec2) Vec2 {
        return Vec2{
            .x = a.x + b.x,
            .y = a.y + b.y,
        };
    }
    pub fn dist(a: Vec2, b: Vec2) u32 {
        return @intCast(u32, (std.math.absInt(a.x - b.x) catch unreachable) + (std.math.absInt(a.y - b.y) catch unreachable));
    }

    pub fn scale(a: i32, v: Vec2) Vec2 {
        return Vec2{
            .x = a * v.x,
            .y = a * v.y,
        };
    }

    pub const Rot = enum { none, cw, ccw };
    pub fn rotate(vec: Vec2, rot: Rot) Vec2 {
        const v = vec; // copy to avoid return value alias
        return switch (rot) {
            .none => return v,
            .cw => Vec2{ .x = -v.y, .y = v.x },
            .ccw => Vec2{ .x = v.y, .y = -v.x },
        };
    }

    pub fn lessThan(_: void, lhs: Vec2, rhs: Vec2) bool {
        if (lhs.y < rhs.y) return true;
        if (lhs.y == rhs.y and lhs.x < rhs.x) return true;
        return false;
    }

    pub fn eq(lhs: Vec2, rhs: Vec2) bool {
        return (lhs.y == rhs.y and lhs.x == rhs.x);
    }

    pub const cardinal_dirs = [_]Vec2{
        Vec2{ .x = 0, .y = -1 }, // N
        Vec2{ .x = -1, .y = 0 }, // W
        Vec2{ .x = 1, .y = 0 }, // E
        Vec2{ .x = 0, .y = 1 }, // S
    };

    pub const Transfo = enum { r0, r90, r180, r270, r0_flip, r90_flip, r180_flip, r270_flip };
    pub const all_tranfos = [_]Transfo{ .r0, .r90, .r180, .r270, .r0_flip, .r90_flip, .r180_flip, .r270_flip };
    pub fn referential(t: Transfo) struct { x: Vec2, y: Vec2 } {
        return switch (t) {
            .r0 => .{ .x = Vec2{ .x = 1, .y = 0 }, .y = Vec2{ .x = 0, .y = 1 } },
            .r90 => .{ .x = Vec2{ .x = 0, .y = 1 }, .y = Vec2{ .x = -1, .y = 0 } },
            .r180 => .{ .x = Vec2{ .x = -1, .y = 0 }, .y = Vec2{ .x = 0, .y = -1 } },
            .r270 => .{ .x = Vec2{ .x = 0, .y = -1 }, .y = Vec2{ .x = 1, .y = 0 } },
            .r0_flip => .{ .x = Vec2{ .x = -1, .y = 0 }, .y = Vec2{ .x = 0, .y = 1 } },
            .r90_flip => .{ .x = Vec2{ .x = 0, .y = 1 }, .y = Vec2{ .x = 1, .y = 0 } },
            .r180_flip => .{ .x = Vec2{ .x = 1, .y = 0 }, .y = Vec2{ .x = 0, .y = -1 } },
            .r270_flip => .{ .x = Vec2{ .x = 0, .y = -1 }, .y = Vec2{ .x = -1, .y = 0 } },
        };
    }
};

pub fn spiralIndexFromPos(p: Vec2) u32 {
    //  https://stackoverflow.com/questions/9970134/get-spiral-index-from-location
    if (p.y * p.y >= p.x * p.x) {
        var i = 4 * p.y * p.y - p.y - p.x;
        if (p.y < p.x)
            i -= 2 * (p.y - p.x);
        return @intCast(u32, i);
    } else {
        var i = 4 * p.x * p.x - p.y - p.x;
        if (p.y < p.x)
            i += 2 * (p.y - p.x);
        return @intCast(u32, i);
    }
}

fn sqrtRound(v: usize) usize {
    // todo: cf std.math.sqrt(idx)
    return @floatToInt(usize, @round(std.math.sqrt(@intToFloat(f64, v))));
}

pub fn posFromSpiralIndex(idx: usize) Vec2 {
    const i = @intCast(i32, idx);
    const j = @intCast(i32, sqrtRound(idx));
    const k = (std.math.absInt(j * j - i) catch unreachable) - j;
    const parity: i32 = @mod(j, 2); // 0 ou 1
    const sign: i32 = if (parity == 0) 1 else -1;
    return Vec2{
        .x = sign * @divFloor(k + j * j - i - parity, 2),
        .y = sign * @divFloor(-k + j * j - i - parity, 2),
    };
}

pub const BBox = struct {
    min: Vec2,
    max: Vec2,
    pub fn isEmpty(bbox: BBox) bool {
        return bbox.min.x > bbox.max.x or bbox.min.y > bbox.max.y;
    }
    pub const empty = BBox{ .min = Vec2{ .x = 999999, .y = 999999 }, .max = Vec2{ .x = -999999, .y = -999999 } };
};

pub fn Map(comptime TileType: type, width: usize, height: usize, allow_negative_pos: bool) type {
    return struct {
        pub const stride = width;
        pub const Tile = TileType;

        const center_offset: isize = if (allow_negative_pos) ((width / 2) + stride * (height / 2)) else 0;

        map: [height * width]Tile = undefined,
        default_tile: Tile,
        bbox: BBox = BBox.empty,

        const Self = @This();

        pub fn intToChar(t: Tile) u8 {
            return switch (t) {
                0 => '.',
                1...9 => (@intCast(u8, t) + '0'),
                else => '?',
            };
        }
        pub fn printToBuf(map: *const Self, pos: ?Vec2, clip: ?BBox, comptime tile_to_char: ?fn (m: Tile) u8, buf: []u8) []const u8 {
            var i: usize = 0;
            const b = if (clip) |box|
                BBox{
                    .min = Vec2.max(map.bbox.min, box.min),
                    .max = Vec2.min(map.bbox.max, box.max),
                }
            else
                map.bbox;

            var p = b.min;
            while (p.y <= b.max.y) : (p.y += 1) {
                p.x = b.min.x;
                while (p.x <= b.max.x) : (p.x += 1) {
                    const offset = map.offsetof(p);

                    if (pos != null and p.x == pos.?.x and p.y == pos.?.y) {
                        buf[i] = '@';
                    } else {
                        buf[i] = if (tile_to_char) |t2c| t2c(map.map[offset]) else map.map[offset];
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
                while (p.y <= b.max.y) : (p.y += 1) {
                    p.x = b.min.x;
                    while (p.x <= b.max.x) : (p.x += 1) {
                        map.set(p, v);
                    }
                }
            } else {
                std.mem.set(Tile, &map.map, v);
            }
        }

        pub fn fillIncrement(map: *Self, v: Tile, clip: BBox) void {
            const b = clip;
            var p = b.min;
            while (p.y <= b.max.y) : (p.y += 1) {
                p.x = b.min.x;
                while (p.x <= b.max.x) : (p.x += 1) {
                    if (map.get(p)) |prev| {
                        map.set(p, prev + v);
                    } else {
                        map.set(p, map.default_tile + v);
                    }
                }
            }
        }

        pub fn growBBox(map: *Self, p: Vec2) void {
            if (allow_negative_pos) {
                assert(p.x <= Self.stride / 2 and -p.x <= Self.stride / 2);
            } else {
                assert(p.x >= 0 and p.y >= 0);
            }
            if (p.x >= map.bbox.min.x and p.x <= map.bbox.max.x and p.y >= map.bbox.min.y and p.y <= map.bbox.max.y)
                return;

            const prev = map.bbox;
            map.bbox.min = Vec2.min(p, map.bbox.min);
            map.bbox.max = Vec2.max(p, map.bbox.max);

            // marchait sans ça avant, mais je vois pas comment.
            if (prev.isEmpty()) {
                map.fill(map.default_tile, map.bbox);
            } else {
                var y = map.bbox.min.y;
                while (y < prev.min.y) : (y += 1) {
                    const o = map.offsetof(Vec2{ .x = map.bbox.min.x, .y = y });
                    std.mem.set(Tile, map.map[o .. o + @intCast(usize, map.bbox.max.x + 1 - map.bbox.min.x)], map.default_tile);
                }
                if (map.bbox.min.x < prev.min.x) {
                    assert(map.bbox.max.x == prev.max.x); // une seule colonne, on n'a grandi que d'un point.
                    while (y <= prev.max.y) : (y += 1) {
                        const o = map.offsetof(Vec2{ .x = map.bbox.min.x, .y = y });
                        std.mem.set(Tile, map.map[o .. o + @intCast(usize, prev.min.x - map.bbox.min.x)], map.default_tile);
                    }
                } else if (map.bbox.max.x > prev.max.x) {
                    assert(map.bbox.min.x == prev.min.x);
                    while (y <= prev.max.y) : (y += 1) {
                        const o = map.offsetof(Vec2{ .x = prev.max.x + 1, .y = y });
                        std.mem.set(Tile, map.map[o .. o + @intCast(usize, map.bbox.max.x + 1 - (prev.max.x + 1))], map.default_tile);
                    }
                } else {
                    y += (prev.max.y - prev.min.y) + 1;
                }
                while (y <= map.bbox.max.y) : (y += 1) {
                    const o = map.offsetof(Vec2{ .x = map.bbox.min.x, .y = y });
                    std.mem.set(Tile, map.map[o .. o + @intCast(usize, map.bbox.max.x + 1 - map.bbox.min.x)], map.default_tile);
                }
            }

            var v = map.bbox.min;
            while (v.y <= map.bbox.max.y) : (v.y += 1) {
                v.x = map.bbox.min.x;
                while (v.x <= map.bbox.max.x) : (v.x += 1) {
                    if (v.x >= prev.min.x and v.x <= prev.max.x and v.y >= prev.min.y and v.y <= prev.max.y)
                        continue;

                    map.map[map.offsetof(v)] = map.default_tile;
                }
            }
        }

        pub fn offsetof(_: *const Self, p: Vec2) usize {
            return @intCast(usize, center_offset + @intCast(isize, p.x) + @intCast(isize, p.y) * @intCast(isize, stride));
        }
        pub fn at(map: *const Self, p: Vec2) Tile {
            assert(p.x >= map.bbox.min.x and p.y >= map.bbox.min.y and p.x <= map.bbox.max.x and p.y <= map.bbox.max.y);
            const offset = map.offsetof(p);
            return map.map[offset];
        }
        pub fn get(map: *const Self, p: Vec2) ?Tile {
            if (p.x < map.bbox.min.x or p.y < map.bbox.min.y)
                return null;
            if (p.x > map.bbox.max.x or p.y > map.bbox.max.y)
                return null;

            if (allow_negative_pos) {
                if (p.x > Self.stride / 2 or -p.x > Self.stride / 2)
                    return null;
            } else {
                if (p.x < 0 or p.y < 0)
                    return null;
            }

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
                assert(p.x <= Self.stride / 2 and -p.x <= Self.stride / 2);
                assert(p.x + @intCast(i32, t.len - 1) <= Self.stride / 2 and -p.x + @intCast(i32, t.len - 1) <= Self.stride / 2);
            } else {
                assert(p.x >= 0 and p.y >= 0);
            }

            map.growBBox(p);
            map.growBBox(p.add(Vec2{ .x = @intCast(i32, t.len - 1), .y = 0 }));

            const offset = map.offsetof(p);
            std.mem.copy(Tile, map.map[offset .. offset + t.len], t);
        }

        const Iterator = struct {
            map: *Self,
            b: BBox,
            p: Vec2,

            pub fn next(self: *@This()) ?Tile {
                if (self.p.y > self.b.max.y) return null;
                const t = self.map.at(self.p);
                self.p.x += 1;
                if (self.p.x > self.b.max.x) {
                    self.p.x = self.b.min.x;
                    self.p.y += 1;
                }
                return t;
            }

            pub fn nextPos(self: *@This()) ?Vec2 {
                if (self.p.y > self.b.max.y) return null;
                const t = self.p;
                self.p.x += 1;
                if (self.p.x > self.b.max.x) {
                    self.p.x = self.b.min.x;
                    self.p.y += 1;
                }
                return t;
            }

            const TileAndNeighbours = struct {
                t: *Tile,
                p: Vec2,
                neib: [4]?Tile,
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
                if (self.p.y > self.b.max.y) return null;

                const t: *Tile = &self.map.map[self.map.offsetof(self.p)];
                const n = [4]?Tile{
                    self.map.get(self.p.add(Vec2{ .x = 1, .y = 0 })),
                    self.map.get(self.p.add(Vec2{ .x = -1, .y = 0 })),
                    self.map.get(self.p.add(Vec2{ .x = 0, .y = 1 })),
                    self.map.get(self.p.add(Vec2{ .x = 0, .y = -1 })),
                };

                var r = TileAndNeighbours{
                    .t = t,
                    .p = self.p,
                    .neib = n,
                    .up_left = self.map.get(self.p.add(Vec2{ .x = -1, .y = -1 })),
                    .up = self.map.get(self.p.add(Vec2{ .x = 0, .y = -1 })),
                    .up_right = self.map.get(self.p.add(Vec2{ .x = 1, .y = -1 })),
                    .left = self.map.get(self.p.add(Vec2{ .x = -1, .y = 0 })),
                    .right = self.map.get(self.p.add(Vec2{ .x = 1, .y = 0 })),
                    .down_left = self.map.get(self.p.add(Vec2{ .x = -1, .y = 1 })),
                    .down = self.map.get(self.p.add(Vec2{ .x = 0, .y = 1 })),
                    .down_right = self.map.get(self.p.add(Vec2{ .x = 1, .y = 1 })),
                };

                self.p.x += 1;
                if (self.p.x > self.b.max.x) {
                    self.p.x = self.b.min.x;
                    self.p.y += 1;
                }

                return r;
            }
        };
        pub fn iter(map: *Self, clip: ?BBox) Iterator {
            const b = if (clip) |box|
                BBox{
                    .min = Vec2.max(map.bbox.min, box.min),
                    .max = Vec2.min(map.bbox.max, box.max),
                }
            else
                map.bbox;

            return Iterator{ .map = map, .b = b, .p = b.min };
        }
    };
}

// -----------------------------------------------------------
// -----  CircularBuffer
// -----------------------------------------------------------

pub fn CircularBuffer(comptime T: anytype) type {
    return struct {
        const Node = struct { item: T, prev: *Node, next: ?*Node };

        arena: std.heap.ArenaAllocator,
        cur: ?*Node = null,
        recyclebin: ?*Node = null,
        len: usize = 0,

        pub fn init(allocator: std.mem.Allocator) @This() {
            return .{ .arena = std.heap.ArenaAllocator.init(allocator) };
        }
        pub fn deinit(self: @This()) void {
            self.arena.deinit();
        }
        pub fn reserve(self: *@This(), nb: usize) !void {
            const nodes = try self.arena.allocator().alloc(Node, nb);
            var next = self.recyclebin;
            for (nodes) |*n| {
                n.next = next;
                next = n;
            }
            self.recyclebin = &nodes[nodes.len - 1];
        }
        pub fn pushHead(self: *@This(), item: T) !void {
            const new = blk: {
                if (self.recyclebin) |node| {
                    self.recyclebin = node.next;
                    break :blk node;
                } else {
                    break :blk try self.arena.allocator().create(Node);
                }
            };
            new.item = item;
            if (self.cur) |cur| {
                new.prev = cur.prev;
                cur.prev.next = new;
                new.next = cur;
                cur.prev = new;
            } else {
                new.prev = new;
                new.next = new;
            }
            self.cur = new;
            self.len += 1;
        }
        pub fn pushTail(self: *@This(), item: T) !void {
            try self.pushHead(item);
            self.rotate(1);
        }

        pub fn pop(self: *@This()) ?T {
            if (self.cur) |cur| {
                self.len -= 1;
                if (cur.next == cur) {
                    self.cur = null;
                } else {
                    cur.next.?.prev = cur.prev;
                    cur.prev.next = cur.next;
                    self.cur = cur.next;
                }

                cur.next = if (self.recyclebin) |n| n else null;
                self.recyclebin = cur;

                return cur.item;
            } else {
                return null;
            }
        }
        pub fn count(self: *@This()) usize {
            return self.len;
        }

        pub fn rotate(self: *@This(), amount: isize) void {
            if (self.cur) |cur| {
                var ptr = cur;
                var a = amount;
                while (a != 0) {
                    ptr = if (a > 0) ptr.next.? else ptr.prev;
                    a = if (a > 0) a - 1 else a + 1;
                }
                self.cur = ptr;
            }
        }

        const Iterator = struct {
            start: ?*const Node,
            ptr: ?*const Node,

            pub fn next(self: *Iterator) ?T {
                if (self.ptr) |ptr| {
                    self.ptr = if (ptr.next == self.start) null else ptr.next;
                    return ptr.item;
                } else {
                    return null;
                }
            }
        };
        pub fn iter(self: @This()) Iterator {
            return Iterator{ .start = self.cur, .ptr = self.cur };
        }
    };
}

// -----------------------------------------------------------
// -----  Search
// -----------------------------------------------------------

pub fn BestFirstSearch(comptime State: type, comptime Trace: type) type {
    return struct {
        pub const Node = struct {
            rating: i32, // explore les noeuds avec le plus petit rating en premier
            cost: u32,
            state: State,
            trace: Trace,
        };

        const Self = @This();
        const Agenda = std.PriorityDequeue(*Node, void, compare_ratings);
        const VisitedNodes = if (State == []const u8) std.StringHashMap(*const Node) else std.AutoHashMap(State, *const Node);

        arena: std.heap.ArenaAllocator,
        agenda: Agenda,
        recyclebin: ?*Node,
        visited: VisitedNodes,

        fn compare_ratings(_: void, a: *const Node, b: *const Node) std.math.Order {
            return std.math.order(a.rating, b.rating);
        }

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .arena = std.heap.ArenaAllocator.init(allocator),
                .agenda = Self.Agenda.init(allocator, {}),
                .recyclebin = null,
                .visited = Self.VisitedNodes.init(allocator),
            };
        }
        pub fn deinit(s: *Self) void {
            s.visited.deinit();
            s.agenda.deinit();
            s.arena.deinit();
        }
        pub fn insert(s: *Self, node: Node) !void {
            if (s.visited.get(node.state)) |v| {
                if (v.cost <= node.cost) {
                    return;
                }
            }

            const poolelem = if (s.recyclebin) |n| n else try s.arena.allocator().create(Node);
            s.recyclebin = null;
            poolelem.* = node;

            try s.agenda.add(poolelem);

            if (try s.visited.fetchPut(node.state, poolelem)) |kv| { // overwriten state with better cost?
                assert(kv.value != poolelem);
                var it = s.agenda.iterator();
                var i: usize = 0;
                while (it.next()) |n| : (i += 1) {
                    if (n == kv.value) {
                        const removed = s.agenda.removeIndex(i);
                        assert(removed == kv.value);
                        s.recyclebin = removed;
                        break;
                    }
                }
            }
        }
        pub fn pop(s: *Self) ?Node {
            if (s.agenda.removeMinOrNull()) |n| {
                // s.recyclebin = n;  non! car le ptr est aussi dans s.visited
                return n.*;
            } else {
                return null;
            }
        }
    };
}

fn fact(n: usize) usize {
    var f: usize = 1;
    var i: usize = 0;
    while (i < n) : (i += 1) f *= (i + 1);
    return f;
}

fn binomial(n: usize, k: usize) usize {
    //  donne le nombre de parties de k éléments dans un ensemble de n éléments
    assert(k <= n);
    return fact(n) / (fact(k) * fact(n - k));
}

fn PermutationsIterator(comptime T: type) type {
    return struct {
        in: []const T,
        index: usize,
        len: usize,

        pub fn next(self: *@This(), buf: []T) ?[]const T {
            if (self.index >= self.len) return null;

            var mod = self.in.len;
            var k = self.index;
            self.index += 1;
            const out = buf[0..self.in.len];
            std.mem.copy(T, out, self.in);
            for (out) |*e, i| {
                const t = e.*;
                e.* = out[i + k % mod];
                out[i + k % mod] = t;
                k /= mod;
                mod -= 1;
            }
            return out;
        }
    };
}

pub fn generate_permutations(comptime T: type, in: []const T) PermutationsIterator(T) {
    return PermutationsIterator(T){
        .in = in,
        .index = 0,
        .len = fact(in.len),
    };
}

fn UniquePermutationsIterator(comptime T: type) type {
    return struct {
        iter: PermutationsIterator(T),
        arena: *std.heap.ArenaAllocator,
        previous_permuts: std.StringHashMap(void),

        fn deinit(self: *@This()) void {
            const root_allocator = self.arena.child_allocator;
            self.previous_permuts.deinit();
            self.arena.deinit();
            root_allocator.destroy(self.arena);
        }

        fn next(self: *@This()) !?[]const T {
            const buf = try self.arena.allocator().alloc(T, self.iter.in.len);
            while (self.iter.next(buf)) |out| {
                const res = try self.previous_permuts.getOrPut(out);
                if (res.found_existing) {
                    continue;
                } else {
                    return out;
                }
            }
            return null;
        }
    };
}

pub fn generate_unique_permutations(comptime T: type, in: []const T, allocator: std.mem.Allocator) !UniquePermutationsIterator(T) {
    const arena = try allocator.create(std.heap.ArenaAllocator);
    arena.* = std.heap.ArenaAllocator.init(allocator);
    var it = UniquePermutationsIterator(T){
        .iter = generate_permutations(T, in),
        .arena = arena,
        .previous_permuts = std.StringHashMap(void).init(arena.allocator()),
    };
    try it.previous_permuts.ensureTotalCapacity(it.iter.len);
    return it;
}

// -----------------------------------------------------------
// -----  text stuff
// -----------------------------------------------------------
pub const Arg = union(enum) {
    lit: []const u8,
    imm: i64,
};

pub fn match_pattern_hexa(comptime pattern: []const u8, text: []const u8) ?[9]Arg {
    return match_pattern_common(pattern, text, 16);
}
pub fn match_pattern(comptime pattern: []const u8, text: []const u8) ?[9]Arg {
    return match_pattern_common(pattern, text, 10);
}

fn match_pattern_common(comptime pattern: []const u8, text: []const u8, radix: u8) ?[9]Arg {
    const txt = std.mem.trim(u8, text, " \n\r\t");
    if (txt.len == 0)
        return null;

    var in: usize = 0;
    var out: usize = 0;
    var values: [9]Arg = undefined;
    var it = std.mem.split(u8, pattern, "{}");

    var firstpart = it.next() orelse return null;
    if (txt.len < firstpart.len)
        return null;
    if (!std.mem.eql(u8, txt[0..firstpart.len], firstpart))
        return null;
    in += firstpart.len;

    while (it.next()) |part| {
        const next = blk: {
            if (txt.len < part.len)
                return null;
            if (part.len == 0)
                break :blk txt.len;
            var n = in;
            while (n <= txt.len - part.len) : (n += 1) {
                if (std.mem.eql(u8, txt[n .. n + part.len], part)) break :blk n;
            }
            return null;
        };

        if (std.fmt.parseInt(i64, std.mem.trim(u8, txt[in..next], " \t"), radix)) |imm| {
            values[out] = Arg{ .imm = imm };
            out += 1;
        } else |_| {
            values[out] = Arg{ .lit = txt[in..next] };
            out += 1;
        }

        in = next + part.len;
    }

    return values;
}

pub fn fmt_bufAppend(storage: []u8, i: *usize, comptime fmt: []const u8, v: anytype) void {
    const r = std.fmt.bufPrint(storage[i.*..], fmt, v) catch unreachable;
    i.* += r.len;
}

pub fn nameToEnum(T: anytype, name: []const u8) !T {
    for (std.meta.fieldNames(T)) |it, i| {
        if (std.mem.eql(u8, it, name))
            return std.meta.intToEnum(T, i) catch unreachable;
    } else return error.InvalidEnumName;
}

// -----------------------------------------------------------
// -----  Modular arithmetic
// -----------------------------------------------------------

pub fn ModArith(comptime T: type) type {
    assert(@typeInfo(T) == .Int);
    var T2Info = @typeInfo(T);
    T2Info.Int.bits *= 2; // to fit temp values of T * T
    const T2 = @Type(T2Info);

    return struct {
        fn mod(a: T2, m: T) T {
            return @intCast(T, @mod(a, m));
        }

        pub fn pow(base: T, exp: T, m: T) T {
            var result: T = 1;
            var e = exp;
            var b = base;
            while (e > 0) {
                if ((e & 1) != 0) result = mod(@as(T2, result) * b, m);
                e = @divFloor(e, 2);
                b = mod(@as(T2, b) * b, m);
            }

            return result;
        }

        pub fn inv(base: T, m: T) T {
            // https://fr.wikipedia.org/wiki/Algorithme_d%27Euclide_%C3%A9tendu
            // Sortie : r[0] = pgcd(base, m) et r[0] = base*r[1]+m*r[2] -> si r[0] = 1, r[1] est l'inverse de base % m
            var r: @Vector(2, T) = [_]T{ base, 1 };
            var r1: @Vector(2, T) = [_]T{ m, 0 };

            while (r1[0] != 0) {
                const q = @divFloor(r[0], r1[0]);
                const t = r;
                r = r1;
                r1 = t - @splat(2, q) * r1;
            }
            assert(r[0] == 1); // base et m ne sont pas premiers entre eux.
            assert(@mod((r[1] * @as(T2, base)), m) == 1);
            return r[1];
        }

        pub const AffineFunc = struct {
            a: T,
            b: T,
            const Func = @This();

            pub fn eval(f: Func, x: T, m: T) T {
                return mod(@as(T2, x) * f.a + f.b, m);
            }

            pub fn compose(f: Func, g: Func, m: T) Func {
                return Func{
                    .a = mod(@as(T2, f.a) * g.a, m),
                    .b = mod(@as(T2, f.a) * g.b + f.b, m),
                };
            }

            pub fn invert(f: Func, m: T) Func {
                // y=ax+b  -> x = y/a - b/a
                return Func{
                    .a = inv(f.a, m),
                    .b = mod(-@as(T2, f.b) * inv(f.a, m), m),
                };
            }

            pub fn autocompose(f: Func, times: T, m: T) Func {
                // f = f(f(f(f(...))))
                // ax+b ->  a(ax+b)+b ->  a(a(ax+b)+b)+b  a3x+(a2+a+1)b
                // ... an.x + b.(an-1)/(a-1)
                return Func{
                    .a = pow(f.a, times, m),
                    .b = mod(@mod(@as(T2, f.b) * (pow(f.a, times, m) - 1), m) * inv(f.a - 1, m), m),
                };
            }
        };
    };
}

test "ModArith" {
    const MA = ModArith(i32);
    const AffineFunc = MA.AffineFunc;

    try std.testing.expectEqual(MA.inv(1, 32), 1);
    try std.testing.expectEqual(MA.inv(3, 32), 11);
    try std.testing.expectEqual(MA.inv(5, 77), 31);
    try std.testing.expectEqual(MA.inv(22, 101), 23);
    try std.testing.expectEqual(MA.pow(12345, 1, 32768), 12345);
    try std.testing.expectEqual(MA.pow(1, 12345, 32768), 1);
    try std.testing.expectEqual(MA.pow(2, 5, 100), 32);
    try std.testing.expectEqual(MA.pow(2, 5, 10), 2);

    const m = 101;
    const f = AffineFunc{ .a = 23, .b = 34 };
    try std.testing.expectEqual(f.eval(0, m), 34);
    try std.testing.expectEqual(f.eval(1, m), 57);
    try std.testing.expectEqual(f.eval(5, m), 48);

    const g = AffineFunc{ .a = 56, .b = 78 };
    const fg = AffineFunc.compose(f, g, m);
    try std.testing.expectEqual(fg.eval(0, m), f.eval(g.eval(0, m), m));
    try std.testing.expectEqual(fg.eval(1, m), f.eval(g.eval(1, m), m));
    try std.testing.expectEqual(fg.eval(11, m), f.eval(g.eval(11, m), m));

    const ffff = AffineFunc.autocompose(f, 4, m);
    try std.testing.expectEqual(ffff.eval(0, m), f.eval(f.eval(f.eval(f.eval(0, m), m), m), m));
    try std.testing.expectEqual(ffff.eval(1, m), f.eval(f.eval(f.eval(f.eval(1, m), m), m), m));
    try std.testing.expectEqual(ffff.eval(42, m), f.eval(f.eval(f.eval(f.eval(42, m), m), m), m));

    const i = AffineFunc.invert(f, m);
    try std.testing.expectEqual(i.eval(f.eval(0, m), m), 0);
    try std.testing.expectEqual(i.eval(f.eval(1, m), m), 1);
    try std.testing.expectEqual(i.eval(f.eval(42, m), m), 42);
}

// -----------------------------------------------------------
// -----  AOC2019  intcode
// -----------------------------------------------------------
pub const IntCode_Computer = struct {
    pc: usize = undefined,
    base: Data = undefined,
    memory: []Data,
    io_mode: IOMode = undefined,
    io_port: Data = undefined,
    io_runframe: @Frame(run) = undefined,
    name: []const u8,

    debug_trace: bool = false,

    pub const Data = i64;

    const Self = @This();

    const halted: usize = 9999999;

    const OperandType = enum(u1) {
        any,
        adr,
    };
    const OperandMode = enum(u2) {
        pos,
        imm,
        rel,
    };
    const Operation = enum(u4) {
        hlt,
        jne,
        jeq,
        add,
        mul,
        slt,
        seq,
        in,
        out,
        err,
        arb,
    };
    const Instruction = struct {
        op: Operation,
        operands: []const OperandType,
        name: []const u8,
    };

    const insn_table = build_instruction_table();

    fn add_insn(op: Operation, name: []const u8, code: u8, operands: []const OperandType, table: []Instruction) void {
        table[code].op = op;
        table[code].name = name;
        table[code].operands = operands;
    }
    fn build_instruction_table() [100]Instruction {
        var table = [1]Instruction{.{ .op = Operation.err, .name = "invalid", .operands = &[_]OperandType{} }} ** 100;

        add_insn(.hlt, "ctl.HALT", 99, &[_]OperandType{}, &table);
        add_insn(.jne, "ctl.JNE", 5, &[_]OperandType{ .any, .any }, &table); // jump-if-true
        add_insn(.jeq, "ctl.JEQ", 6, &[_]OperandType{ .any, .any }, &table); // jump-if-false

        add_insn(.add, "alu.ADD", 1, &[_]OperandType{ .any, .any, .adr }, &table);
        add_insn(.mul, "alu.MUL", 2, &[_]OperandType{ .any, .any, .adr }, &table);
        add_insn(.slt, "alu.SLT", 7, &[_]OperandType{ .any, .any, .adr }, &table); // set if less than
        add_insn(.seq, "alu.SEQ", 8, &[_]OperandType{ .any, .any, .adr }, &table); // set if zero
        add_insn(.arb, "alu.ARB", 9, &[_]OperandType{.any}, &table); // adjust relative base

        add_insn(.in, "io.IN  ", 3, &[_]OperandType{.adr}, &table);
        add_insn(.out, "io.OUT ", 4, &[_]OperandType{.any}, &table);

        return table;
    }

    fn parse_mode(v: usize) !OperandMode {
        switch (v) {
            0 => return .pos,
            1 => return .imm,
            2 => return .rel,
            else => return error.unknownMode, //@panic("unknown mode"),
        }
    }
    const ParsedOpcode = struct { opcode: u8, modes: [3]OperandMode };
    fn parse_opcode(v: Data) !ParsedOpcode {
        const opcode_and_modes = @intCast(u64, v);
        return ParsedOpcode{
            .opcode = @intCast(u8, opcode_and_modes % 100),
            .modes = [3]OperandMode{
                try parse_mode((opcode_and_modes / 100) % 10),
                try parse_mode((opcode_and_modes / 1000) % 10),
                try parse_mode((opcode_and_modes / 10000) % 10),
            },
        };
    }

    fn parse_opcode_nofail(v: Data) ParsedOpcode {
        const div = @Vector(4, u16){ 1, 100, 1000, 10000 };
        const mod = @Vector(4, u16){ 100, 10, 10, 10 };
        const opcode_and_modes = (@splat(4, @intCast(u16, v)) / div) % mod;
        return ParsedOpcode{
            .opcode = @intCast(u8, opcode_and_modes[0]),
            .modes = [3]OperandMode{
                @intToEnum(OperandMode, opcode_and_modes[1]),
                @intToEnum(OperandMode, opcode_and_modes[2]),
                @intToEnum(OperandMode, opcode_and_modes[3]),
            },
        };
    }

    fn load_param(par: Data, t: OperandType, mode: OperandMode, base: Data, mem: []const Data) Data {
        switch (t) {
            .adr => switch (mode) {
                .pos => return par,
                .imm => @panic("invalid mode"),
                .rel => return par + base,
            },
            .any => switch (mode) {
                .pos => return mem[@intCast(usize, par)],
                .imm => return par,
                .rel => return mem[@intCast(usize, par + base)],
            },
        }
    }

    pub fn boot(c: *Self, boot_image: []const Data) void {
        if (c.debug_trace) print("[{s}] boot\n", .{c.name});
        std.mem.copy(Data, c.memory[0..boot_image.len], boot_image);
        std.mem.set(Data, c.memory[boot_image.len..], 0);
        c.pc = 0;
        c.base = 0;
        c.io_port = undefined;
    }
    pub fn is_halted(c: *Self) bool {
        return c.pc == halted;
    }
    const IOMode = enum(u1) {
        input,
        output,
    };
    pub fn run(c: *Self) void {
        while (c.pc != halted) {
            // decode insn opcode
            const parsed = parse_opcode_nofail(c.memory[c.pc]);

            if (c.debug_trace) {
                var buf: [100]u8 = undefined;
                print("[{s}]      {s}\n", .{ c.name, dissamble_insn(&insn_table[parsed.opcode], &parsed.modes, c.memory[c.pc..], &buf) });
            }

            const operand_len = insn_table[parsed.opcode].operands.len;
            const op = insn_table[parsed.opcode].op;
            switch (operand_len) {
                0 => {
                    switch (op) {
                        .hlt => c.pc = halted,
                        .err => @panic("Illegal instruction"),
                        else => unreachable,
                    }
                },
                1 => {
                    switch (op) {
                        .arb => {
                            const p = [1]Data{
                                load_param(c.memory[c.pc + 1], .any, parsed.modes[0], c.base, c.memory),
                            };
                            c.pc += 2;

                            c.base += p[0];
                        },
                        .in => {
                            const p = [1]Data{
                                load_param(c.memory[c.pc + 1], .adr, parsed.modes[0], c.base, c.memory),
                            };
                            c.pc += 2;

                            c.io_mode = .input;
                            if (c.debug_trace) print("[{s}] reading...\n", .{c.name});
                            suspend {
                                c.io_runframe = @frame().*;
                            }
                            if (c.debug_trace) print("[{s}] ...got {}\n", .{ c.name, c.io_port });
                            c.memory[@intCast(usize, p[0])] = c.io_port;
                        },
                        .out => {
                            const p = [1]Data{
                                load_param(c.memory[c.pc + 1], .any, parsed.modes[0], c.base, c.memory),
                            };
                            c.pc += 2;

                            c.io_mode = .output;
                            c.io_port = p[0];
                            if (c.debug_trace) print("[{s}] writing {}...\n", .{ c.name, c.io_port });
                            suspend {
                                c.io_runframe = @frame().*;
                            }
                            if (c.debug_trace) print("[{s}] ...ok\n", .{c.name});
                        },

                        else => unreachable,
                    }
                },
                2 => {
                    // load parameters from insn operands
                    const p = [2]Data{
                        load_param(c.memory[c.pc + 1], .any, parsed.modes[0], c.base, c.memory),
                        load_param(c.memory[c.pc + 2], .any, parsed.modes[1], c.base, c.memory),
                    };

                    // execute insn
                    switch (op) {
                        .jne => c.pc = if (p[0] != 0) @intCast(usize, p[1]) else c.pc + 3,
                        .jeq => c.pc = if (p[0] == 0) @intCast(usize, p[1]) else c.pc + 3,
                        else => unreachable,
                    }
                },
                3 => {
                    // load parameters from insn operands
                    const p = [3]Data{
                        load_param(c.memory[c.pc + 1], .any, parsed.modes[0], c.base, c.memory),
                        load_param(c.memory[c.pc + 2], .any, parsed.modes[1], c.base, c.memory),
                        load_param(c.memory[c.pc + 3], .adr, parsed.modes[2], c.base, c.memory),
                    };
                    c.pc += 4;

                    // execute insn
                    switch (op) {
                        .add => c.memory[@intCast(usize, p[2])] = p[0] +% p[1],
                        .mul => c.memory[@intCast(usize, p[2])] = p[0] *% p[1],
                        .slt => c.memory[@intCast(usize, p[2])] = @boolToInt(p[0] < p[1]),
                        .seq => c.memory[@intCast(usize, p[2])] = @boolToInt(p[0] == p[1]),
                        else => unreachable,
                    }
                },
                else => unreachable,
            }
        }
    }

    fn dissamble_insn(insn: *const Instruction, modes: []const OperandMode, operands: []const Data, storage: []u8) []const u8 {
        var i: usize = 0;
        std.mem.copy(u8, storage[i..], insn.name);
        i += insn.name.len;
        std.mem.copy(u8, storage[i..], "\t");
        i += 1;
        for (insn.operands) |optype, j| {
            if (j > 0) {
                std.mem.copy(u8, storage[i..], ", ");
                i += 2;
            }
            if (j >= operands.len) {
                std.mem.copy(u8, storage[i..], "ERR");
                i += 3;
            } else {
                switch (optype) {
                    .adr => switch (modes[j]) {
                        .imm => fmt_bufAppend(storage, &i, "ERR{}", .{operands[j]}),
                        .pos => fmt_bufAppend(storage, &i, "@{}", .{operands[j]}),
                        .rel => fmt_bufAppend(storage, &i, "@b+{}", .{operands[j]}),
                    },

                    .any => switch (modes[j]) {
                        .imm => fmt_bufAppend(storage, &i, "{}", .{operands[j]}),
                        .pos => fmt_bufAppend(storage, &i, "[{}]", .{operands[j]}),
                        .rel => fmt_bufAppend(storage, &i, "[b+{}]", .{operands[j]}),
                    },
                }
            }
        }
        return storage[0..i];
    }
    pub fn disassemble(image: []const Data) void {
        var pc: usize = 0;
        while (pc < image.len) {
            var insn_size: usize = 1;

            var asmstr_storage: [100]u8 = undefined;
            const asmstr = blk: {
                if (parse_opcode(image[pc])) |parsed| {
                    const insn = &insn_table[parsed.opcode];
                    insn_size += insn.operands.len;
                    break :blk dissamble_insn(insn, &parsed.modes, image[pc + 1 ..], &asmstr_storage);
                } else |_| {
                    break :blk "";
                }
            };

            var datastr_storage: [100]u8 = undefined;
            const datastr = blk: {
                var i: usize = 0;
                var l: usize = 0;
                while (i < insn_size) : (i += 1) {
                    const d = if (pc + i < image.len) image[pc + i] else 0;
                    fmt_bufAppend(&datastr_storage, &l, "{} ", .{d});
                }
                break :blk datastr_storage[0..l];
            };

            print("{d:0>4}: {s:15} {s}\n", .{ pc, datastr, asmstr });
            pc += insn_size;
        }
    }
};
