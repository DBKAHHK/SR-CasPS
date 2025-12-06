const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const protocol_dep = b.dependency("protocol", .{
        .target = target,
        .optimize = optimize,
    });

    const httpz_dep = b.dependency("httpz", .{
        .target = target,
        .optimize = optimize,
    });
    const tls_dep = b.dependency("tls", .{
        .target = target,
        .optimize = optimize,
    });

    const dispatch_mod = b.addModule("dispatch_main", .{
        .root_source_file = b.path("../dispatch/src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "protocol", .module = protocol_dep.module("protocol") },
            .{ .name = "httpz", .module = httpz_dep.module("httpz") },
            .{ .name = "tls", .module = tls_dep.module("tls") },
        },
    });

    const gameserver_mod = b.addModule("gameserver_main", .{
        .root_source_file = b.path("../gameserver/src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "protocol", .module = protocol_dep.module("protocol") },
        },
    });

    const exe = b.addExecutable(.{
        .name = "CastoricePS",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    // Windows icon embedding (requires zig.exe to have llvm-rc available).
    const rc_files = b.addWriteFiles();
    const rc_path = rc_files.add("castoriceps.rc",
        \\ 1 ICON "../icon_output.ico"
    );
    const rc_cmd = b.addSystemCommand(&.{ "zig", "rc", "/nologo", "/fo" });
    const res_output = rc_cmd.addOutputFileArg("castoriceps.res");
    rc_cmd.addFileArg(rc_path);
    exe.addWin32ResourceFile(.{ .file = res_output });
    exe.step.dependOn(&rc_cmd.step);
    exe.root_module.addImport("dispatch_main", dispatch_mod);
    exe.root_module.addImport("gameserver_main", gameserver_mod);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run dispatch and gameserver together");
    run_step.dependOn(&run_cmd.step);

    const run_program_step = b.step("run-program", "Run dispatch and gameserver together");
    run_program_step.dependOn(&run_cmd.step);
}
