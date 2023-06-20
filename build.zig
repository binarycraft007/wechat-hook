const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    var winapi_module = b.addModule(
        "winapi",
        .{ .source_file = .{ .path = "lib/winapi.zig" } },
    );

    const lib = b.addSharedLibrary(.{
        .name = "wechat-hook",
        .root_source_file = .{ .path = "src/dll/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    lib.linkLibC();
    b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "wechat-injector",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.addModule("winapi", winapi_module);
    exe.addAnonymousModule("wechat_hook", .{
        .source_file = lib.getOutputSource(),
    });
    exe.step.dependOn(&lib.step);
    b.installArtifact(exe);

    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/dll/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_main_tests = b.addRunArtifact(main_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);
}
