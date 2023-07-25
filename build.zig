const Builder = @import("std").build.Builder;
const Step = @import("std").build.Step;
const mem = @import("std").mem;
const fs = @import("std").fs;
const debug = @import("std").debug;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    const tracy = b.option([]const u8, "tracy", "Enable Tracy integration. Supply path to Tracy source");
    const exe_options = b.addOptions();

    if (tracy != null) debug.print("BUG: need to manually edit common/tracy.zig to enable the instrumentation\n", .{});
    exe_options.addOption(bool, "enable_tracy", tracy != null);

    const Problem = struct {
        year: []const u8,
        day: []const u8,
    };
    const problems = [_]Problem{
        .{ .year = "2021", .day = "day01" },
        .{ .year = "2021", .day = "day02" },
        .{ .year = "2021", .day = "day03" },
        .{ .year = "2021", .day = "day04" },
        .{ .year = "2021", .day = "day05" },
        .{ .year = "2021", .day = "day06" },
        .{ .year = "2021", .day = "day07" },
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

        .{ .year = "2019", .day = "day25" },
        .{ .year = "2019", .day = "day24" },
        .{ .year = "2019", .day = "day23" },
        .{ .year = "2019", .day = "day22" },
        .{ .year = "2019", .day = "day21" },
        .{ .year = "2019", .day = "day20" },
        .{ .year = "2019", .day = "day19" },
        .{ .year = "2019", .day = "day18" },
        .{ .year = "2019", .day = "day17" },
        .{ .year = "2019", .day = "day16" },
        .{ .year = "2019", .day = "day15" },
        .{ .year = "2019", .day = "day14" },
        .{ .year = "2019", .day = "day13" },
        .{ .year = "2019", .day = "day12" },
        .{ .year = "2019", .day = "day11" },
        .{ .year = "2019", .day = "day10" },
        .{ .year = "2019", .day = "day09" },
        .{ .year = "2019", .day = "day08" },
        .{ .year = "2019", .day = "day07" },
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
    const years = [_][]const u8{ "2018", "2019", "2020", "2021", "synacor" };

    const run_step = b.step("run", "Run all the days");
    var runyear_step: [years.len]*Step = undefined;
    inline for (years) |year, i| {
        runyear_step[i] = b.step("run" ++ year, "Run days from " ++ year);
    }

    for (problems) |pb| {
        const path = b.fmt("{s}/{s}.zig", .{ pb.year, pb.day });

        const exe = b.addExecutable(pb.day, path);
        exe.use_stage1 = true;
        exe.setBuildMode(mode);
        exe.addOptions("build_options", exe_options); // XXX Does not apply to package tools / 'tracy'.  no idea how to make it work

        if (mem.eql(u8, pb.year, "2021")) {
            exe.addPackagePath("tools", "common/tools_v2.zig");
        } else {
            exe.addPackagePath("tools", "common/tools.zig");
        }

        if (tracy) |tracy_path| {
            const client_cpp = fs.path.join(
                b.allocator,
                &[_][]const u8{ tracy_path, "TracyClient.cpp" },
            ) catch unreachable;
            exe.addIncludePath(tracy_path);
            exe.addCSourceFile(client_cpp, &[_][]const u8{ "-DTRACY_ENABLE=1", "-fno-sanitize=undefined" });
            exe.linkLibCpp();
        }

        //exe.install();
        const installstep = &b.addInstallArtifact(exe).step;

        const run_cmd = exe.run();
        run_cmd.step.dependOn(installstep);

        if (!mem.eql(u8, pb.year, "synacor")) {
            run_step.dependOn(&run_cmd.step);
        }
        for (runyear_step) |s, i| {
            if (mem.eql(u8, years[i], pb.year))
                s.dependOn(&run_cmd.step);
        }
    }

    const test_step = b.step("test", "Test all days of 2021");
    {
        const test_cmd = b.addTest("2021/alldays.zig");
        test_cmd.addPackagePath("tools", "common/tools_v2.zig");
        test_step.dependOn(&test_cmd.step);
    }

    const info_step = b.step("info", "Additional info");
    {
        const log = b.addLog(
            \\ to run a single day:
            \\   for 2021:    `zig run 2021/day03.zig  --pkg-begin "tools" "common/tools_v2.zig" --pkg-end'
            \\   older years: `zig run 2018/day10.zig  --pkg-begin "tools" "common/tools.zig" --pkg-end'
            \\
            \\ 2019 intcode bench: (best year by far! ) 
            \\    `zig run 2019/intcode_bench.zig  --pkg-begin "tools" "common/tools.zig" --pkg-end -OReleaseFast'
            \\
        , .{});
        info_step.dependOn(&log.step);
    }
}
