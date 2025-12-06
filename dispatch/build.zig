const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "dispatch",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const httpz_dep = b.dependency("httpz", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("httpz", httpz_dep.module("httpz"));

    const protocol_dep = b.dependency("protocol", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("protocol", protocol_dep.module("protocol"));

    const tls_dep = b.dependency("tls", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("tls", tls_dep.module("tls"));

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const run_dispatch_step = b.step("run-dispatch", "Run dispatch");
    run_dispatch_step.dependOn(&run_cmd.step);
}
