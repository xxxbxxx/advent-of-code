const std = @import("std");
const tools = @import("tools");

const with_trace = true;
fn trace(comptime fmt: []const u8, args: anytype) void {
    if (with_trace) std.debug.print(fmt, args);
}
const assert = std.debug.assert;

pub const main = tools.defaultMain("2021/day08.txt", run);

pub fn run(input: []const u8, gpa: std.mem.Allocator) tools.RunError![2][]const u8 {
    const Afficheur = []const u8;
    const Entry = struct {
        patterns: [10]Afficheur,
        output: [4]Afficheur,
    };
    var list0 = std.ArrayList(Entry).init(gpa);
    defer list0.deinit();
    {
        try list0.ensureTotalCapacity(input.len / 80);
        var it = std.mem.tokenize(u8, input, "\n");
        while (it.next()) |line| {
            var e: Entry = undefined;
            var it2 = std.mem.tokenize(u8, line, "|");
            {
                const patterns = it2.next().?;
                var it3 = std.mem.tokenize(u8, patterns, " ");
                var i: u32 = 0;
                while (it3.next()) |segment| : (i += 1) {
                    e.patterns[i] = segment;
                }
            }
            {
                const outputs = it2.next().?;
                var it3 = std.mem.tokenize(u8, outputs, " ");
                var i: u32 = 0;
                while (it3.next()) |segment| : (i += 1) {
                    e.output[i] = segment;
                }
            }

            try list0.append(e);
        }
    }

    const ans1 = ans: {
        var count: u32 = 0;
        for (list0.items) |it| {
            for (it.output) |o|
                count += @boolToInt(o.len == 2 or o.len == 3 or o.len == 4 or o.len == 7);
        }
        break :ans count;
    };

    // occurences: A: 8, B: 6, C: 8, D: 7, E: 4, F: 9, G: 7
    const models = [10][]const u8{
        "abcefg", // 0
        "cf", // 1
        "acdeg", // 2
        "acdfg", // 3
        "bcdf", // 4
        "abdfg", // 5
        "abdefg", // 6
        "acf", // 7
        "abcdefg", // 8
        "abcdfg", // 9
    };

    const matcher = comptime blk: {
        const Matcher = struct {
            digit_from_invariant: [256]u4,

            // invariant en fonction l'ordre des chiffres et des segments
            pub fn computeSymbolOccurences(self: *const @This(), patterns: []const []const u8) [7]u8 {
                _ = self;
                assert(patterns.len == 10);
                var occurences = [1]u8{0} ** 7;
                for (patterns) |p| {
                    for (p) |c| occurences[c - 'a'] += 1;
                }
                return occurences;
            }

            fn computeInvariant(pattern: []const u8, occurences: [7]u8) u8 {
                var invariant: u8 = 0;
                // +, * marchent aussi.  ^ fait des valeurs plus petites
                for (pattern) |c| invariant ^= occurences[c - 'a'];
                invariant *= @intCast(u8, pattern.len);
                return invariant;
            }

            pub fn readNumber(self: *const @This(), occurences: [7]u8, digits: []const []const u8) u32 {
                var val: u32 = 0;
                for (digits) |d| {
                    val = val * 10 + self.digit_from_invariant[
                        computeInvariant(d, occurences)
                    ];
                }
                return val;
            }
        };

        var matcher = Matcher{ .digit_from_invariant = undefined };
        var invariant_collision = [1]bool{false} ** 256;
        const occurences = matcher.computeSymbolOccurences(&models);
        for (models) |m, digit| {
            const invariant = Matcher.computeInvariant(m, occurences);
            assert(!invariant_collision[invariant]);
            invariant_collision[invariant] = true;
            matcher.digit_from_invariant[invariant] = digit;
        }
        break :blk matcher;
    };

    const ans2 = ans: {
        var sum: u64 = 0;
        for (list0.items) |it| {
            if (false) {
                // old brute force attempt:
                const dico = decode(models, it.patterns[0..]);
                sum += read(models, dico, it.output[0..]);
            } else {
                // using invariant matching
                const occurences = matcher.computeSymbolOccurences(it.patterns[0..]);
                sum += matcher.readNumber(occurences, it.output[0..]);
            }
        }
        break :ans sum;
    };

    return [_][]const u8{
        try std.fmt.allocPrint(gpa, "{}", .{ans1}),
        try std.fmt.allocPrint(gpa, "{}", .{ans2}),
    };
}

// old brute force attempt:
pub fn indexOf(models: [10][]const u8, dico: [7]u8, pat: []const u8) ?u4 {
    var buf: [7]u8 = undefined;
    for (pat) |c, i| {
        buf[i] = dico[c - 'a'];
    }
    std.sort.sort(u8, buf[0..pat.len], {}, comptime std.sort.asc(u8));
    for (models) |m, digit| {
        if (std.mem.eql(u8, m, buf[0..pat.len])) return @intCast(u4, digit);
    } else return null;
}

pub fn decode(models: [10][]const u8, patterns: []const []const u8) [7]u8 {
    var it = tools.generate_permutations(u8, "ABCDEFG");
    var dico: [7]u8 = undefined;
    while (it.next(&dico)) |_| {
        var match: bool = true;
        for (patterns) |p| {
            match = match and indexOf(models, dico, p) != null;
        }
        if (match) return dico;
    }
    unreachable;
}

pub fn read(models: [10][]const u8, dico: [7]u8, digits: []const []const u8) u32 {
    var val: u32 = 0;
    for (digits) |d| {
        val = val * 10 + indexOf(models, dico, d).?;
    }
    return val;
}

test {
    const res = try run(
        \\be cfbegad cbdgef fgaecd cgeb fdcge agebfd fecdb fabcd edb | fdgacbe cefdb cefbgd gcbe
        \\edbfga begcd cbg gc gcadebf fbgde acbgfd abcde gfcbed gfec | fcgedb cgb dgebacf gc
        \\fgaebd cg bdaec gdafb agbcfd gdcbef bgcad gfac gcb cdgabef | cg cg fdcagb cbg
        \\fbegcd cbd adcefb dageb afcb bc aefdc ecdab fgdeca fcdbega | efabcd cedba gadfec cb
        \\aecbfdg fbg gf bafeg dbefa fcge gcbea fcaegb dgceab fcbdga | gecf egdcabf bgf bfgea
        \\fgeab ca afcebg bdacfeg cfaedg gcfdb baec bfadeg bafgc acf | gebdcfa ecba ca fadegcb
        \\dbcfg fgd bdegcaf fgec aegbdf ecdfab fbedc dacgb gdcebf gf | cefg dcbef fcge gbcadfe
        \\bdfegc cbegaf gecbf dfcage bdacg ed bedf ced adcbefg gebcd | ed bcgafe cdgba cbgef
        \\egadfb cdbfeg cegd fecab cgb gbdefca cg fgcdab egfdb bfceg | gbdfcae bgc cg cgb
        \\gcafb gcf dcaebfg ecagb gf abcdeg gaef cafbge fdbac fegbdc | fgae cfgab fg bagce        
    , std.testing.allocator);
    defer std.testing.allocator.free(res[0]);
    defer std.testing.allocator.free(res[1]);
    try std.testing.expectEqualStrings("26", res[0]);
    try std.testing.expectEqualStrings("61229", res[1]);
}
