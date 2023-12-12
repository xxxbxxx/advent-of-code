const std = @import("std");
const assert = std.debug.assert;
const print = std.debug.print;
const tools = @import("tools");

const VM = struct {
    const Word = u16;

    const OpCode = enum(Word) { halt, set, push, pop, eq, gt, jmp, jt, jf, add, mult, mod, band, bor, not, rmem, wmem, call, ret, out, in, noop };

    const Insn = union(OpCode) {
        halt: struct {}, //  stop execution and terminate the program
        set: struct { a: Word, b: Word }, //  set register <a> to the value of <b>
        push: struct { a: Word }, //  push <a> onto the stack
        pop: struct { a: Word }, //  remove the top element from the stack and write it into <a>; empty stack = error
        eq: struct { a: Word, b: Word, c: Word }, //  set <a> to 1 if <b> is equal to <c>; set it to 0 otherwise
        gt: struct { a: Word, b: Word, c: Word }, //  set <a> to 1 if <b> is greater than <c>; set it to 0 otherwise
        jmp: struct { a: Word }, //   jump to <a>
        jt: struct { a: Word, b: Word }, //  if <a> is nonzero, jump to <b>
        jf: struct { a: Word, b: Word }, //   if <a> is zero, jump to <b>
        add: struct { a: Word, b: Word, c: Word }, //  assign into <a> the sum of <b> and <c> (modulo 32768)
        mult: struct { a: Word, b: Word, c: Word }, //  store into <a> the product of <b> and <c> (modulo 32768)
        mod: struct { a: Word, b: Word, c: Word }, //  store into <a> the remainder of <b> divided by <c>
        band: struct { a: Word, b: Word, c: Word }, //  stores into <a> the bitwise and of <b> and <c>
        bor: struct { a: Word, b: Word, c: Word }, //  stores into <a> the bitwise or of <b> and <c>
        not: struct { a: Word, b: Word }, //   stores 15-bit bitwise inverse of <b> in <a>
        rmem: struct { a: Word, b: Word }, //   read memory at address <b> and write it to <a>
        wmem: struct { a: Word, b: Word }, //  write the value from <b> into memory at address <a>
        call: struct { a: Word }, //   write the address of the next instruction to the stack and jump to <a>
        ret: struct {}, //     remove the top element from the stack and jump to it; empty stack = halt
        out: struct { a: Word }, //   write the character represented by ascii code <a> to the terminal
        in: struct { a: Word }, //   read a character from the terminal and write its ascii code to <a>; it can be assumed that once input starts, it will continue until a newline is encountered; this means that you can safely read whole lines from the keyboard and trust that they will be fully read
        noop: struct {}, //    no operation
    };

    const Debug = struct {
        breakpoints: []const u15,
        watchpoints: []const u15,
    };

    const State = struct {
        ip: ?u15,
        sp: u8,
        regs: [8]u15,
        stack: [64]u15, // doc: "unbounded"
        mem: [32768]u16,
    };

    fn asRegister(a: Word) ?u3 {
        if (a <= 32767) return null;
        if (a >= 32776) return null;
        return @as(u3, @intCast(a - 32768));
    }

    fn asImmediate(a: Word) ?u15 {
        if (a <= 32767) return @as(u15, @intCast(a));
        return null;
    }

    fn getVal(s: *const State, a: Word) u15 {
        if (asImmediate(a)) |v| return v;
        return s.regs[asRegister(a).?];
    }

    fn dumpArg(a: Word, buf: []u8) ![]const u8 {
        if (a >= 32776) return error.InvalidVal;
        if (a >= 32768) return std.fmt.bufPrint(buf, "R{}", .{a - 32768});
        if (a >= 0x20 and a < 0x7F) return std.fmt.bufPrint(buf, "#{} '{c}'", .{ a, @as(u7, @intCast(a)) });
        return std.fmt.bufPrint(buf, "#{}", .{a});
    }

    fn dumpInsn(insn: Insn, buf: []u8) ![]u8 {
        var bufA: [16]u8 = undefined;
        var bufB: [16]u8 = undefined;
        var bufC: [16]u8 = undefined;

        switch (insn) {
            .halt, .ret, .noop => return std.fmt.bufPrint(buf, "{s}", .{@tagName(insn)}),
            .set => |arg| return std.fmt.bufPrint(buf, "{s}\t{s}", .{ @tagName(insn), try dumpArg(arg.a, &bufA) }),
            .push => |arg| return std.fmt.bufPrint(buf, "{s}\t{s}", .{ @tagName(insn), try dumpArg(arg.a, &bufA) }),
            .pop => |arg| return std.fmt.bufPrint(buf, "{s}\t{s}", .{ @tagName(insn), try dumpArg(arg.a, &bufA) }),
            .jmp => |arg| return std.fmt.bufPrint(buf, "{s}\t{s}", .{ @tagName(insn), try dumpArg(arg.a, &bufA) }),
            .call => |arg| return std.fmt.bufPrint(buf, "{s}\t{s}", .{ @tagName(insn), try dumpArg(arg.a, &bufA) }),
            .out => |arg| return std.fmt.bufPrint(buf, "{s}\t{s}", .{ @tagName(insn), try dumpArg(arg.a, &bufA) }),
            .in => |arg| return std.fmt.bufPrint(buf, "{s}\t{s}", .{ @tagName(insn), try dumpArg(arg.a, &bufA) }),
            .eq => |arg| return std.fmt.bufPrint(buf, "{s}\t{s}, {s}, {s}", .{ @tagName(insn), try dumpArg(arg.a, &bufA), try dumpArg(arg.b, &bufB), try dumpArg(arg.c, &bufC) }),
            .gt => |arg| return std.fmt.bufPrint(buf, "{s}\t{s}, {s}, {s}", .{ @tagName(insn), try dumpArg(arg.a, &bufA), try dumpArg(arg.b, &bufB), try dumpArg(arg.c, &bufC) }),
            .jt => |arg| return std.fmt.bufPrint(buf, "{s}\t{s}, {s}", .{ @tagName(insn), try dumpArg(arg.a, &bufA), try dumpArg(arg.b, &bufB) }),
            .jf => |arg| return std.fmt.bufPrint(buf, "{s}\t{s}, {s}", .{ @tagName(insn), try dumpArg(arg.a, &bufA), try dumpArg(arg.b, &bufB) }),
            .not => |arg| return std.fmt.bufPrint(buf, "{s}\t{s}, {s}", .{ @tagName(insn), try dumpArg(arg.a, &bufA), try dumpArg(arg.b, &bufB) }),
            .wmem => |arg| return std.fmt.bufPrint(buf, "{s}\t{s}, {s}", .{ @tagName(insn), try dumpArg(arg.a, &bufA), try dumpArg(arg.b, &bufB) }),
            .rmem => |arg| return std.fmt.bufPrint(buf, "{s}\t{s}, {s}", .{ @tagName(insn), try dumpArg(arg.a, &bufA), try dumpArg(arg.b, &bufB) }),
            .add => |arg| return std.fmt.bufPrint(buf, "{s}\t{s}, {s}, {s}", .{ @tagName(insn), try dumpArg(arg.a, &bufA), try dumpArg(arg.b, &bufB), try dumpArg(arg.c, &bufC) }),
            .mult => |arg| return std.fmt.bufPrint(buf, "{s}\t{s}, {s}, {s}", .{ @tagName(insn), try dumpArg(arg.a, &bufA), try dumpArg(arg.b, &bufB), try dumpArg(arg.c, &bufC) }),
            .mod => |arg| return std.fmt.bufPrint(buf, "{s}\t{s}, {s}, {s}", .{ @tagName(insn), try dumpArg(arg.a, &bufA), try dumpArg(arg.b, &bufB), try dumpArg(arg.c, &bufC) }),
            .band => |arg| return std.fmt.bufPrint(buf, "{s}\t{s}, {s}, {s}", .{ @tagName(insn), try dumpArg(arg.a, &bufA), try dumpArg(arg.b, &bufB), try dumpArg(arg.c, &bufC) }),
            .bor => |arg| return std.fmt.bufPrint(buf, "{s}\t{s}, {s}, {s}", .{ @tagName(insn), try dumpArg(arg.a, &bufA), try dumpArg(arg.b, &bufB), try dumpArg(arg.c, &bufC) }),
        }
    }

    fn execInsn(s: *State, insn: Insn, out: *[]u8, in: *[]const u8) !void {
        switch (insn) {
            .halt => |_| s.ip = null,
            .set => |arg| s.regs[asRegister(arg.a).?] = getVal(s, arg.b),
            .push => |arg| {
                s.stack[s.sp] = getVal(s, arg.a);
                s.sp += 1;
            },
            .pop => |arg| {
                s.sp -= 1;
                s.regs[asRegister(arg.a).?] = s.stack[s.sp];
            },
            .eq => |arg| s.regs[asRegister(arg.a).?] = @intFromBool(getVal(s, arg.b) == getVal(s, arg.c)),
            .gt => |arg| s.regs[asRegister(arg.a).?] = @intFromBool(getVal(s, arg.b) > getVal(s, arg.c)),
            .jmp => |arg| s.ip = getVal(s, arg.a),
            .jt => |arg| if (getVal(s, arg.a) != 0) {
                s.ip = getVal(s, arg.b);
            },
            .jf => |arg| if (getVal(s, arg.a) == 0) {
                s.ip = getVal(s, arg.b);
            },
            .add => |arg| s.regs[asRegister(arg.a).?] = (getVal(s, arg.b) +% getVal(s, arg.c)),
            .mult => |arg| s.regs[asRegister(arg.a).?] = (getVal(s, arg.b) *% getVal(s, arg.c)),
            .mod => |arg| s.regs[asRegister(arg.a).?] = (getVal(s, arg.b) % getVal(s, arg.c)),
            .band => |arg| s.regs[asRegister(arg.a).?] = (getVal(s, arg.b) & getVal(s, arg.c)),
            .bor => |arg| s.regs[asRegister(arg.a).?] = (getVal(s, arg.b) | getVal(s, arg.c)),
            .not => |arg| s.regs[asRegister(arg.a).?] = ~getVal(s, arg.b),
            .rmem => |arg| s.regs[asRegister(arg.a).?] = @as(u15, @intCast(s.mem[getVal(s, arg.b)])),
            .wmem => |arg| s.mem[getVal(s, arg.a)] = getVal(s, arg.b),
            .call => |arg| {
                s.stack[s.sp] = s.ip.?;
                s.sp += 1;
                s.ip = getVal(s, arg.a);
            },
            .ret => |_| if (s.sp > 0) {
                s.sp -= 1;
                s.ip = s.stack[s.sp];
            } else {
                s.ip = null;
            },
            .out => |arg| {
                if (out.len == 0) return error.NeedOuput;
                out.*[0] = @as(u8, @intCast(getVal(s, arg.a)));
                out.* = out.*[1..];
            },
            .in => |arg| {
                if (in.len == 0) return error.NeedInput;
                s.regs[asRegister(arg.a).?] = in.*[0];
                in.* = in.*[1..];
            },
            .noop => |_| {},
        }
        if (s.sp >= s.stack.len) return error.StackOverflow;
    }

    fn fetchInsn(ip: u15, mem: []const Word) struct { insn: Insn, sz: u2 } {
        const opcode = @as(*const OpCode, @ptrCast(&mem[ip])).*;
        switch (opcode) {
            .halt => return .{ .sz = 0, .insn = Insn{ .halt = .{} } },
            .set => return .{ .sz = 2, .insn = Insn{ .set = .{ .a = mem[ip + 1], .b = mem[ip + 2] } } },
            .push => return .{ .sz = 1, .insn = Insn{ .push = .{ .a = mem[ip + 1] } } },
            .pop => return .{ .sz = 1, .insn = Insn{ .pop = .{ .a = mem[ip + 1] } } },
            .eq => return .{ .sz = 3, .insn = Insn{ .eq = .{ .a = mem[ip + 1], .b = mem[ip + 2], .c = mem[ip + 3] } } },
            .gt => return .{ .sz = 3, .insn = Insn{ .gt = .{ .a = mem[ip + 1], .b = mem[ip + 2], .c = mem[ip + 3] } } },
            .jmp => return .{ .sz = 1, .insn = Insn{ .jmp = .{ .a = mem[ip + 1] } } },
            .jt => return .{ .sz = 2, .insn = Insn{ .jt = .{ .a = mem[ip + 1], .b = mem[ip + 2] } } },
            .jf => return .{ .sz = 2, .insn = Insn{ .jf = .{ .a = mem[ip + 1], .b = mem[ip + 2] } } },
            .add => return .{ .sz = 3, .insn = Insn{ .add = .{ .a = mem[ip + 1], .b = mem[ip + 2], .c = mem[ip + 3] } } },
            .mult => return .{ .sz = 3, .insn = Insn{ .mult = .{ .a = mem[ip + 1], .b = mem[ip + 2], .c = mem[ip + 3] } } },
            .mod => return .{ .sz = 3, .insn = Insn{ .mod = .{ .a = mem[ip + 1], .b = mem[ip + 2], .c = mem[ip + 3] } } },
            .band => return .{ .sz = 3, .insn = Insn{ .band = .{ .a = mem[ip + 1], .b = mem[ip + 2], .c = mem[ip + 3] } } },
            .bor => return .{ .sz = 3, .insn = Insn{ .bor = .{ .a = mem[ip + 1], .b = mem[ip + 2], .c = mem[ip + 3] } } },
            .not => return .{ .sz = 2, .insn = Insn{ .not = .{ .a = mem[ip + 1], .b = mem[ip + 2] } } },
            .rmem => return .{ .sz = 2, .insn = Insn{ .rmem = .{ .a = mem[ip + 1], .b = mem[ip + 2] } } },
            .wmem => return .{ .sz = 2, .insn = Insn{ .wmem = .{ .a = mem[ip + 1], .b = mem[ip + 2] } } },
            .call => return .{ .sz = 1, .insn = Insn{ .call = .{ .a = mem[ip + 1] } } },
            .ret => return .{ .sz = 0, .insn = Insn{ .ret = .{} } },
            .out => return .{ .sz = 1, .insn = Insn{ .out = .{ .a = mem[ip + 1] } } },
            .in => return .{ .sz = 1, .insn = Insn{ .in = .{ .a = mem[ip + 1] } } },
            .noop => return .{ .sz = 0, .insn = Insn{ .noop = .{} } },
        }
    }

    fn run(state: *State, input: []const u8, outbuf: []u8, debug: ?Debug) []u8 {
        var out = outbuf;
        var in = input;
        runloop: while (state.ip) |ip| {
            const insn = VM.fetchInsn(ip, &state.mem);
            if (debug) |dbg| {
                if (std.mem.indexOfScalar(u15, dbg.breakpoints, ip) != null) {
                    print("[DEBUG] break at ip={}\n", .{ip});
                    break :runloop;
                }
                assert(dbg.watchpoints.len == 0); // TODO
            }
            state.ip = ip + 1 + insn.sz;
            VM.execInsn(state, insn.insn, &out, &in) catch |err| switch (err) {
                error.NeedInput => {
                    state.ip = ip;
                    break :runloop;
                },
                error.StackOverflow => unreachable,
                error.NeedOuput => unreachable,
            };
        }

        return outbuf[0 .. outbuf.len - out.len];
    }
};

const IFPlayer = struct {
    const Object = enum(u8) { tablet, @"empty lantern", can, lantern, @"lit lantern", @"red coin", @"blue coin", @"concave coin", @"shiny coin", @"corroded coin", teleporter, @"business card", @"strange book" };
    const Exit = enum(u8) { north, west, east, south, down, up, @"continue", back, doorway, bridge, passage, cavern, ladder, darkness, forward, run, investigate, wait, hide, outside, inside };

    const RoomId = struct { desc_hash: u64, pos: [3]i8 };
    const RoomDesc = struct {
        id: RoomId,
        name: []const u8,
        desc: []const u8 = "",
        objects: []const Object = &[0]Object{},
        exits: []const Exit = &[0]Exit{},
        inventory: []const Object = &[0]Object{},
    };

    fn applyDir(p: [3]i8, d: Exit, reverse: bool) [3]i8 {
        if (reverse) {
            return switch (d) {
                .north => applyDir(p, .south, false),
                .south => applyDir(p, .north, false),
                .east => applyDir(p, .west, false),
                .west => applyDir(p, .east, false),
                .up => applyDir(p, .down, false),
                .down => applyDir(p, .up, false),
                else => unreachable,
            };
        }

        return switch (d) {
            .north => .{ p[0], p[1] + 1, p[2] },
            .south => .{ p[0], p[1] - 1, p[2] },
            .east => .{ p[0] + 1, p[1], p[2] },
            .west => .{ p[0] - 1, p[1], p[2] },
            .up => .{ p[0], p[1], p[2] + 1 },
            .down => .{ p[0], p[1], p[2] - 1 },
            else => unreachable,
        };
    }

    fn computeRoomId(prev: RoomId, e: Exit, curdir: Exit, new_room_rawtext: []const u8) RoomId {
        // mmm pas trop reflechit comment trouver un id unique sachant que ya des racourcis et des bouclages dans tous les sens, mais qu'il y a aussi des pieces repetées (je pense?) ou c'est aumoins sévéremetn non-euclidien.
        //  donc j'essaye d'utiliser:
        //    - hash de la desc complete + inventaire pour distinguer deux passages dans la meme piece avec des objets différents.
        //    - plus un accu de position pour les repèt.
        //    - plus un forçage des possitions dans certaines salles pour resnapper
        const hash = std.hash.Wyhash.hash(0, new_room_rawtext);
        const pos: [3]i8 = blk: {
            if (std.mem.indexOf(u8, new_room_rawtext, "It must have broken your fall!") != null)
                break :blk .{ 0, 0, -1 };

            break :blk switch (e) {
                .north, .south, .east, .west, .up, .down => applyDir(prev.pos, e, false),
                .@"continue", .forward, .run => applyDir(prev.pos, curdir, false),
                .back => applyDir(prev.pos, curdir, true),
                .doorway, .bridge => applyDir(prev.pos, .north, false),
                .passage, .cavern, .ladder, .darkness, .outside, .inside => prev.pos,
                .investigate, .wait, .hide => prev.pos,
            };
        };

        return RoomId{ .desc_hash = hash, .pos = pos };
    }

    fn parseRoom(id: RoomId, text: []const u8, arena: std.mem.Allocator) !RoomDesc {
        var it = std.mem.tokenize(u8, text, "\n");
        const name = while (it.next()) |line| {
            if (tools.match_pattern("== {} ==", line)) |fields| {
                break try arena.dupe(u8, fields[0].lit);
            } else {
                print("ignoring line: {s}\n", .{line});
            }
        } else return RoomDesc{ .id = id, .name = "null" };

        const desc = try arena.dupe(u8, it.next() orelse unreachable);

        var objs = std.ArrayList(Object).init(arena);
        var inv = std.ArrayList(Object).init(arena);
        var exits = std.ArrayList(Exit).init(arena);

        section: while (it.next()) |line| {
            if (tools.match_pattern("There {} exit", line)) |_| {
                var it2 = it;
                while (it2.next()) |line2| {
                    if (tools.match_pattern("- {}", line2)) |fields2| {
                        const e = tools.nameToEnum(Exit, fields2[0].lit) catch |err| {
                            print("unknown Exit: '{s}\n", .{fields2[0].lit});
                            return err;
                        };
                        try exits.append(e);
                    } else {
                        continue :section;
                    }
                    it = it2;
                }
            } else if (tools.match_pattern("Things of interest here:", line)) |_| {
                var it2 = it;
                while (it2.next()) |line2| {
                    if (tools.match_pattern("- {}", line2)) |fields2| {
                        const o = tools.nameToEnum(Object, fields2[0].lit) catch |err| {
                            print("unknown Object: '{s}\n", .{fields2[0].lit});
                            return err;
                        };
                        try objs.append(o);
                    } else {
                        continue :section;
                    }
                    it = it2;
                }
            } else if (tools.match_pattern("Your inventory:", line)) |_| {
                var it2 = it;
                while (it2.next()) |line2| {
                    if (tools.match_pattern("- {}", line2)) |fields2| {
                        const o = tools.nameToEnum(Object, fields2[0].lit) catch |err| {
                            print("unknown Object: '{s}\n", .{fields2[0].lit});
                            return err;
                        };
                        try inv.append(o);
                    } else {
                        continue :section;
                    }
                    it = it2;
                }
            } else if (tools.match_pattern("What do you do?", line)) |_| {
                continue;
            } else if (tools.match_pattern("{} a Grue.", line)) |_| {
                continue;
            } else {
                print("ignoring line: {s}\n", .{line});
            }
        }

        return RoomDesc{ .id = id, .name = name, .desc = desc, .objects = objs.items, .exits = exits.items, .inventory = inv.items };
    }
};

const SearchState = struct {
    room: IFPlayer.RoomId,
    dir: IFPlayer.Exit,
    vm: VM.State,
};
const TraceStep = union(enum) { go: IFPlayer.Exit, take: IFPlayer.Object, use: IFPlayer.Object, drop: IFPlayer.Object };
const BFS = tools.BestFirstSearch(SearchState, []const TraceStep);
fn abs(x: anytype) usize {
    return if (x > 0) @as(usize, @intCast(x)) else @as(usize, @intCast(-x));
}

fn maybeQueueNewRoomToExplore(vms: *VM.State, node: BFS.Node, t: TraceStep, rooms: anytype, agenda: *BFS, arena: std.mem.Allocator) !void {
    var buf_out: [1024]u8 = undefined;
    const out = VM.run(vms, "look\ninv\n", &buf_out);
    const dir = blk: {
        if (t == .go) {
            switch (t.go) {
                .north, .south, .east, .west, .up, .down => break :blk t.go,
                else => {},
            }
        }
        break :blk node.state.dir; // continue on same dir
    };
    const id = IFPlayer.computeRoomId(node.state.room, if (t == .go) t.go else .wait, dir, out);
    if (abs(id.pos[0]) + abs(id.pos[1]) + abs(id.pos[2]) > 7)
        return; // n'explore pas trop loin avec les repet etc..
    const entry = try rooms.getOrPut(id);

    if (entry.found_existing) return;

    //print("nesw room: {s}\n", .{out});
    const room = try IFPlayer.parseRoom(id, out, arena);
    entry.entry.value = room;

    const trace = try arena.alloc(TraceStep, node.trace.len + 1);
    @memcpy(trace[0..node.trace.len], node.trace);
    trace[node.trace.len] = t;

    try agenda.insert(BFS.Node{
        .cost = node.cost + 1,
        .rating = node.rating + switch (t) {
            .go => @as(i8, 1),
            .use => @as(i8, 1),
            .take => @as(i8, 0),
            .drop => @as(i8, 10),
        },
        .trace = trace,
        .state = .{ .vm = vms.*, .room = id, .dir = dir },
    });
}

fn grepCode(text: []const u8, stdout: std.fs.File.Writer, visited_codes: anytype) !void {
    var it = std.mem.tokenize(u8, text, " .,-;:!?\"'\t\n");
    // de la forme:      "fFHcqYpjxGoi"
    next_word: while (it.next()) |word| {
        if (word.len < 12) continue :next_word;
        for ([_][]const u8{ "bioluminescent", "Headquarters", "dramatically", "unfortunately", "Introduction", "interdimensional", "Interdimensional", "fundamentals", "mathematical", "interactions", "teleportation", "hypothetical", "destinations", "preconfigured", "confirmation", "computationally" }) |notcode| {
            if (std.mem.eql(u8, word, notcode)) continue :next_word;
        }

        if ((try visited_codes.getOrPut(word)).found_existing) continue :next_word;
        //print("{s}\n", .{text});
        try stdout.print("maybe code: '{s}'\n", .{word});
    }
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var vm_state = VM.State{
        .ip = 0,
        .sp = 0,
        .regs = undefined,
        .mem = undefined,
        .stack = undefined,
    };
    _ = try std.fs.cwd().readFile("synacor/challenge.bin", @as([*]u8, @ptrCast(&vm_state.mem))[0 .. vm_state.mem.len * @sizeOf(VM.Word)]);

    var buf_out: [10000]u8 = undefined;
    var buf_in: [1024]u8 = undefined;
    var visitedcodes = std.StringHashMap(void).init(allocator);
    defer visitedcodes.deinit();

    if (true) {
        print("going to the ruins...\n", .{});
        const in = "take tablet\nuse tablet\ndoorway\nnorth\nnorth\nbridge\ncontinue\ndown\neast\ntake empty lantern\nwest\nwest\npassage\nladder\nwest\nsouth\nnorth\ntake can\nwest\nladder\ndarkness\nuse can\nuse lantern\ncontinue\nwest\nwest\nwest\nwest\n";
        try grepCode(VM.run(&vm_state, in, &buf_out, null), stdout, &visitedcodes);
    }
    if (true) {
        print("going to the headquarters...\n", .{});
        const in = "north\ntake red coin\nnorth\neast\ntake concave coin\ndown\ntake corroded coin\nup\nwest\nwest\nup\ntake shiny coin\ndown\ntake blue coin\neast\nuse blue coin\nuse red coin\nuse shiny coin\nuse concave coin\nuse corroded coin\nnorth\ntake teleporter\nuse teleporter\n";
        try grepCode(VM.run(&vm_state, in, &buf_out, null), stdout, &visitedcodes);
    }
    if (true) {
        print("going to the teleport hack...\n", .{});
        const in = "take business card\ntake strange book\noutside\n";
        try grepCode(VM.run(&vm_state, in, &buf_out, null), stdout, &visitedcodes);
    }

    const interractive = true;
    const bruteforce_teleporter = false; // laisse béton. il faut vraiment decompiler et debugguer
    if (interractive) {
        var in: []const u8 = "";
        var breakpoints = std.ArrayList(u15).init(allocator);
        defer breakpoints.deinit();
        while (vm_state.ip != null) {
            const out = VM.run(&vm_state, in, &buf_out, VM.Debug{ .breakpoints = breakpoints.items, .watchpoints = &[0]u15{} });

            try stdout.writeAll(out);

            while (true) {
                print("[DEBUG] ip={?}, sp={} regs={d}\n", .{ vm_state.ip, vm_state.sp, vm_state.regs });

                in = (try stdin.readUntilDelimiterOrEof(&buf_in, '\n')) orelse break;
                buf_in[in.len] = '\n';
                in.len += 1;

                if (!std.mem.startsWith(u8, in, "dbg "))
                    break;
                in = in[4..];

                if (tools.match_pattern("r{}={}", in)) |fields| {
                    vm_state.regs[@as(u3, @intCast(fields[0].imm))] = @as(u15, @intCast(fields[1].imm));
                } else if (tools.match_pattern("m{}={}", in)) |fields| {
                    const adr = @as(u15, @intCast(fields[0].imm));
                    vm_state.mem[adr] = @as(u15, @intCast(fields[1].imm));
                } else if (tools.match_pattern("m{}", in)) |fields| {
                    const adr = @as(u15, @intCast(fields[0].imm));
                    print("[DEBUG] @{} = {s}\n", .{ adr, try VM.dumpArg(vm_state.mem[adr], &buf_out) });
                } else if (tools.match_pattern("set bp {}", in)) |fields| {
                    const adr = @as(u15, @intCast(fields[0].imm));
                    try breakpoints.append(adr);
                } else if (tools.match_pattern("clr bp {}", in)) |fields| {
                    const adr = @as(u15, @intCast(fields[0].imm));
                    while (std.mem.indexOfScalar(u15, breakpoints.items, adr)) |idx| {
                        _ = breakpoints.swapRemove(idx);
                    }
                } else if (tools.match_pattern("stack", in)) |_| {
                    for (vm_state.stack[0..vm_state.sp]) |v| {
                        print("[DEBUG] stack = {s}\n", .{try VM.dumpArg(v, &buf_out)});
                    }
                } else if (tools.match_pattern("asm {}", in)) |fields| {
                    var ip = if (fields[0] == .imm) @as(u15, @intCast(fields[0].imm)) else vm_state.ip.?;
                    var nb: u32 = 0;
                    while (nb < 30) : (nb += 1) {
                        const insn = VM.fetchInsn(ip, &vm_state.mem);
                        try stdout.print("[{}]\t{s}\n", .{ ip, try VM.dumpInsn(insn.insn, &buf_out) });
                        ip += @as(u15, 1) + insn.sz;
                    }
                }
                in = "";
            }
        }
    } else if (bruteforce_teleporter) {
        const all_states = try allocator.alloc(struct { out: [1024]u8, out_len: u16, vms: VM.State }, 32767);
        defer allocator.free(all_states);

        for (all_states, 0..) |*s, i| {
            s.vms = vm_state;
            s.vms.regs[7] = @as(u15, @intCast(i + 1));
            s.out_len = 0;
            _ = VM.run(&s.vms, "use teleporter", &buf_out);
        }

        var yolo: u32 = 10;
        var nb_still_running: usize = all_states.len;
        while (nb_still_running > 0) {
            nb_still_running = 0;
            for (all_states, 0..) |*s, i| {
                const ip = s.vms.ip orelse continue;
                nb_still_running += 1;
                var in: []const u8 = "\n";
                var out: []u8 = s.out[s.out_len..];
                const insn = VM.fetchInsn(ip, &s.vms.mem);
                s.vms.ip = ip + 1 + insn.sz;
                const err = VM.execInsn(&s.vms, insn.insn, &out, &in);
                s.out_len = @as(u16, @intCast(s.out.len - out.len));
                err catch |e| switch (e) {
                    error.NeedInput => unreachable,
                    error.StackOverflow => {
                        print("OVERFLOW {}...\n", .{i + 1});
                        print("... {s}\n", .{s.out[0..s.out_len]});
                        s.vms.ip = null;
                        yolo -= 1;
                    },
                    error.NeedOuput => {
                        print("interresting {}...\n", .{i + 1});
                        const msg = VM.run(&s.vms, "", &buf_out);
                        print("... {s}\n", .{msg});
                        s.vms.ip = null;
                        //return;
                    },
                };
            }
        }
    } else {
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();

        var rooms = std.AutoHashMap(IFPlayer.RoomId, IFPlayer.RoomDesc).init(allocator);
        defer rooms.deinit();
        const init_room_id = blk: {
            const id = IFPlayer.RoomId{ .desc_hash = 0, .pos = .{ 0, 0, 0 } };
            const out = VM.run(&vm_state, "look\ninv\n", &buf_out, null);
            //print("init room: {s}\n", .{out});
            const room = try IFPlayer.parseRoom(id, out, arena.allocator());
            try rooms.put(id, room);

            break :blk id;
        };

        var agenda = BFS.init(allocator);
        defer agenda.deinit();

        try agenda.insert(BFS.Node{
            .cost = 0,
            .rating = 0,
            .state = .{ .vm = vm_state, .room = init_room_id, .dir = .north },
            .trace = &[0]TraceStep{},
        });

        var longest_trace: []const TraceStep = &[0]TraceStep{};

        while (agenda.pop()) |node| {
            const room = rooms.get(node.state.room) orelse unreachable;
            //if (std.mem.eql(u8, room.name, "Synacor Headquarters")) {
            if (false and node.trace.len > longest_trace.len) {
                longest_trace = node.trace;
                print("longuest trace = ", .{});
                for (longest_trace) |t| switch (t) {
                    .go => print("{s}\\n", .{@tagName(t.go)}),
                    .use => print("use {s}\\n", .{@tagName(t.use)}),
                    .take => print("take {s}\\n", .{@tagName(t.take)}),
                    .drop => print("drop {s}\\n", .{@tagName(t.drop)}),
                };

                print("\n", .{});
                print(" -> leads to == {s} == {s}\n", .{ room.name, room.desc });
                print(" -> pos == {d}\n", .{room.id.pos});
                print(" -> with {} items in inventory\n", .{room.inventory.len});
                break;
            }

            //  print("\n----------------\nexploring '{s}', trace={D}...\n", .{ room.name, node.trace });

            for (room.exits) |e| {
                if (e == .east and std.mem.eql(u8, room.name, "Ruins") and std.mem.indexOf(u8, room.desc, "A crevice in the rock to the east leads to an alarmingly dark passageway.") != null)
                    continue; // don't go back in the caves.

                // print("trying: go {s}...\n", .{e});

                var vms = node.state.vm;
                const in = try std.fmt.bufPrint(&buf_in, "go {s}\n", .{@tagName(e)});
                const out = VM.run(&vms, in, &buf_out);
                try grepCode(out, stdout, &visitedcodes);
                //print("out: {s}\n", .{out});

                try maybeQueueNewRoomToExplore(&vms, node, .{ .go = e }, &rooms, &agenda, arena.allocator());
            }

            for (room.objects) |o| {
                var vms = node.state.vm;
                const in = try std.fmt.bufPrint(&buf_in, "take {s}\nlook {s}\n", .{ @tagName(o), @tagName(o) });
                const out = VM.run(&vms, in, &buf_out);
                try grepCode(out, stdout, &visitedcodes);
                //print("out: {s}\n", .{out});
                assert(std.mem.indexOf(u8, out, "You see no such item here.") == null);

                try maybeQueueNewRoomToExplore(&vms, node, .{ .take = o }, &rooms, &agenda, arena.allocator());
            }

            for (room.inventory) |o| {
                // if (o == .lantern) continue; // don't use lanter -> don't exit cave
                // print("trying: use {s}...\n", .{o});
                var vms = node.state.vm;
                const in = try std.fmt.bufPrint(&buf_in, "use {s}\nlook {s}\n", .{ @tagName(o), @tagName(o) });
                const out = VM.run(&vms, in, &buf_out);
                try grepCode(out, stdout, &visitedcodes);
                //print("out: {s}\n", .{out});
                assert(std.mem.indexOf(u8, out, "You can't find that in your pack.") == null);

                try maybeQueueNewRoomToExplore(&vms, node, .{ .use = o }, &rooms, &agenda, arena.allocator());
            }

            for (room.inventory) |o| {
                var vms = node.state.vm;
                const in = try std.fmt.bufPrint(&buf_in, "drop {s}\nlook {s}\n", .{ @tagName(o), @tagName(o) });
                const out = VM.run(&vms, in, &buf_out);
                try grepCode(out, stdout, &visitedcodes);
                //print("out: {s}\n", .{out});
                assert(std.mem.indexOf(u8, out, "You can't find that in your pack.") == null);

                try maybeQueueNewRoomToExplore(&vms, node, .{ .drop = o }, &rooms, &agenda, arena.allocator());
            }
        }
        print("explored {} unique rooms\n", .{rooms.count()});
    }

    try stdout.print("fin.\n", .{});
}
