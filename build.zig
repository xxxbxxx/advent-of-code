const std = @import("std");
const Step = std.Build.Step;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const tracy = b.option([]const u8, "tracy", "Enable Tracy integration. Supply path to Tracy source");
    const exe_options = b.addOptions();
    exe_options.addOption(bool, "enable_tracy", tracy != null);

    const Problem = struct {
        year: []const u8,
        day: []const u8,
    };
    const problems = [_]Problem{
        .{ .year = "2023", .day = "day01" },
        .{ .year = "2023", .day = "day02" },
        .{ .year = "2023", .day = "day03" },
        .{ .year = "2023", .day = "day04" },
        .{ .year = "2023", .day = "day05" },
        .{ .year = "2023", .day = "day06" },
        .{ .year = "2023", .day = "day07" },
        .{ .year = "2023", .day = "day08" },
        .{ .year = "2023", .day = "day09" },
        .{ .year = "2023", .day = "day10" },
        .{ .year = "2023", .day = "day11" },
        .{ .year = "2023", .day = "day12" },
        .{ .year = "2023", .day = "day13" },
        .{ .year = "2023", .day = "day14" },
        .{ .year = "2023", .day = "day15" },
        .{ .year = "2023", .day = "day16" },
        .{ .year = "2023", .day = "day17" },
        .{ .year = "2023", .day = "day18" },
        .{ .year = "2023", .day = "day19" },
        .{ .year = "2023", .day = "day20" },
        .{ .year = "2023", .day = "alldays" }, // alldays in one exe

        .{ .year = "2021", .day = "day01" },
        .{ .year = "2021", .day = "day02" },
        .{ .year = "2021", .day = "day03" },
        .{ .year = "2021", .day = "day04" },
        .{ .year = "2021", .day = "day05" },
        .{ .year = "2021", .day = "day06" },
        //        .{ .year = "2021", .day = "day07" },  // async
        .{ .year = "2021", .day = "day08" },
        .{ .year = "2021", .day = "day09" },
        .{ .year = "2021", .day = "day10" },
        .{ .year = "2021", .day = "day11" },
        .{ .year = "2021", .day = "day12" },
        .{ .year = "2021", .day = "day13" },
        .{ .year = "2021", .day = "day14" },
        .{ .year = "2021", .day = "day15" },
        .{ .year = "2021", .day = "day16" },
        .{ .year = "2021", .day = "day17" },
        .{ .year = "2021", .day = "day18" },
        .{ .year = "2021", .day = "day19" },
        .{ .year = "2021", .day = "day20" },
        .{ .year = "2021", .day = "day21" },
        .{ .year = "2021", .day = "day22" },
        .{ .year = "2021", .day = "day23" },
        .{ .year = "2021", .day = "day24" },
        .{ .year = "2021", .day = "day25" },
        .{ .year = "2021", .day = "alldays" }, // alldays in one exe

        .{ .year = "2020", .day = "day25" },
        .{ .year = "2020", .day = "day24" },
        .{ .year = "2020", .day = "day23" },
        .{ .year = "2020", .day = "day22" },
        .{ .year = "2020", .day = "day21" },
        .{ .year = "2020", .day = "day20" },
        .{ .year = "2020", .day = "day19" },
        .{ .year = "2020", .day = "day18" },
        .{ .year = "2020", .day = "day17" },
        .{ .year = "2020", .day = "day16" },
        .{ .year = "2020", .day = "day15" },
        .{ .year = "2020", .day = "day14" },
        .{ .year = "2020", .day = "day13" },
        .{ .year = "2020", .day = "day12" },
        .{ .year = "2020", .day = "day11" },
        .{ .year = "2020", .day = "day10" },
        .{ .year = "2020", .day = "day09" },
        .{ .year = "2020", .day = "day08" },
        .{ .year = "2020", .day = "day07" },
        .{ .year = "2020", .day = "day06" },
        .{ .year = "2020", .day = "day05" },
        .{ .year = "2020", .day = "day04" },
        .{ .year = "2020", .day = "day03" },
        .{ .year = "2020", .day = "day02" },
        .{ .year = "2020", .day = "day01" },
        .{ .year = "2020", .day = "alldays" }, // alldays in one exe

        //async .{ .year = "2019", .day = "day25" },
        .{ .year = "2019", .day = "day24" },
        //async .{ .year = "2019", .day = "day23" },
        .{ .year = "2019", .day = "day22" },
        //async .{ .year = "2019", .day = "day21" },
        .{ .year = "2019", .day = "day20" },
        //async .{ .year = "2019", .day = "day19" },
        .{ .year = "2019", .day = "day18" },
        //async .{ .year = "2019", .day = "day17" },
        .{ .year = "2019", .day = "day16" },
        //async .{ .year = "2019", .day = "day15" },
        .{ .year = "2019", .day = "day14" },
        //async .{ .year = "2019", .day = "day13" },
        .{ .year = "2019", .day = "day12" },
        //async .{ .year = "2019", .day = "day11" },
        .{ .year = "2019", .day = "day10" },
        //async .{ .year = "2019", .day = "day09" },
        .{ .year = "2019", .day = "day08" },
        //async .{ .year = "2019", .day = "day07" },
        .{ .year = "2019", .day = "day06" },
        .{ .year = "2019", .day = "day05" },
        .{ .year = "2019", .day = "day04" },
        .{ .year = "2019", .day = "day03" },
        .{ .year = "2019", .day = "day02" },
        .{ .year = "2019", .day = "day01" },
        .{ .year = "2019", .day = "alldays" }, // alldays in one exe

        .{ .year = "2018", .day = "day25" },
        .{ .year = "2018", .day = "day24" },
        .{ .year = "2018", .day = "day23" },
        .{ .year = "2018", .day = "day22" },
        .{ .year = "2018", .day = "day21_comptime" },
        .{ .year = "2018", .day = "day20" },
        .{ .year = "2018", .day = "day19" },
        .{ .year = "2018", .day = "day18" },
        .{ .year = "2018", .day = "day17" },
        .{ .year = "2018", .day = "day16" },
        .{ .year = "2018", .day = "day15" },
        .{ .year = "2018", .day = "day14" },
        .{ .year = "2018", .day = "day13" },
        .{ .year = "2018", .day = "day12" },
        .{ .year = "2018", .day = "day11" },
        .{ .year = "2018", .day = "day10" },
        .{ .year = "2018", .day = "day09" },
        .{ .year = "2018", .day = "day08" },
        .{ .year = "2018", .day = "day07" },
        .{ .year = "2018", .day = "day06" },
        .{ .year = "2018", .day = "day05" },
        .{ .year = "2018", .day = "day04" },
        .{ .year = "2018", .day = "day03" },
        .{ .year = "2018", .day = "day02" },
        .{ .year = "2018", .day = "day01" },

        .{ .year = "synacor", .day = "main" },
    };
    const years = [_][]const u8{ "2018", "2019", "2020", "2021", "2023", "synacor" };

    const run_step = b.step("run", "Run all the days");
    var runyear_step: [years.len]*Step = undefined;
    inline for (years, 0..) |year, i| {
        runyear_step[i] = b.step("run" ++ year, "Run days from " ++ year);
    }

    const tools_module_v2 = b.createModule(.{ .root_source_file = .{ .path = "common/tools_v2.zig" } });
    const tools_module_v1 = b.createModule(.{ .root_source_file = .{ .path = "common/tools.zig" } });
    tools_module_v2.addOptions("build_options", exe_options);

    for (problems) |pb| {
        const path = b.fmt("{s}/{s}.zig", .{ pb.year, pb.day });

        const exe = b.addExecutable(.{
            .name = pb.day,
            .root_source_file = .{ .path = path },
            .target = target,
            .optimize = optimize,
        });
        exe.root_module.addOptions("build_options", exe_options);
        //exe.use_llvm = false;
        //exe.use_lld = false;

        if (std.mem.eql(u8, pb.year, "2021") or std.mem.eql(u8, pb.year, "2023")) {
            exe.root_module.addImport("tools", tools_module_v2);
        } else {
            exe.root_module.addImport("tools", tools_module_v1);
        }

        if (tracy) |tracy_path| {
            const client_cpp = std.fs.path.join(
                b.allocator,
                &[_][]const u8{ tracy_path, "public/TracyClient.cpp" },
            ) catch unreachable;
            exe.addIncludePath(.{ .path = tracy_path });
            exe.addCSourceFile(.{ .file = .{ .path = client_cpp }, .flags = &[_][]const u8{ "-DTRACY_ENABLE=1", "-fno-sanitize=undefined" } });
            exe.linkLibCpp();
        }

        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);

        if (!std.mem.eql(u8, pb.year, "synacor")) {
            run_step.dependOn(&run_cmd.step);
        }
        for (runyear_step, 0..) |s, i| {
            if (std.mem.eql(u8, years[i], pb.year))
                s.dependOn(&run_cmd.step);
        }
    }

    const test_step = b.step("test", "Test all days of 2023");
    {
        const test_cmd21 = b.addTest(.{
            .root_source_file = .{ .path = "2021/alldays.zig" },
            .target = target,
            .optimize = optimize,
            // .use_lld = false,
            // .use_llvm = false,
        });
        test_cmd21.root_module.addImport("tools", tools_module_v2);
        const run_cmd21 = b.addRunArtifact(test_cmd21);
        _ = run_cmd21;

        const test_cmd23 = b.addTest(.{
            .root_source_file = .{ .path = "2023/alldays.zig" },
            .target = target,
            .optimize = optimize,
            //.use_lld = false,
            //.use_llvm = false,
        });
        test_cmd23.root_module.addImport("tools", tools_module_v2);
        const run_cmd23 = b.addRunArtifact(test_cmd23);

        //test_step.dependOn(&run_cmd21.step);
        test_step.dependOn(&run_cmd23.step);
    }

    // const info_step = b.step("info", "Additional info");
    // {
    //     const log = b.addLog(
    //         \\ to run a single day:
    //         \\   for 2021:    `zig run --dep tools --mod root 2021/day03.zig --mod tools common/tools_v2.zig'
    //         \\   older years: `zig run --dep tools --mod root 2018/day10.zig --mod tools common/tools.zig'
    //         \\
    //         \\ 2019 intcode bench: (best year by far! )
    //         \\    `zig run --dep tools --mod root 2019/intcode_bench.zig --mod tools common/tools.zig -OReleaseFast'
    //         \\
    //     , .{});
    //     info_step.dependOn(&log.step);
    // }
}
