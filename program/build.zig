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

    // Android app embeds CastoricePS as a shared library (JNI), not an executable.
    // Zig represents Android as `os=linux` + `abi=android`.
    if (target.result.abi == .android) {
        const android_no_libc = b.option(bool, "android_no_libc", "Build Android JNI .so without linking libc (not runnable; CI-only)") orelse false;
        const android_lib = b.addSharedLibrary(.{
            .name = "castoriceps",
            .root_source_file = b.path("src/android_lib.zig"),
            .target = target,
            .optimize = optimize,
        });
        // Default: link bionic libc (requires NDK sysroot). If we don't link libc,
        // Android's loader cannot resolve libc symbols unless they are in DT_NEEDED.
        if (android_no_libc) {
            android_lib.root_module.link_libc = false;
            dispatch_mod.link_libc = false;
            gameserver_mod.link_libc = false;
            protocol_dep.module("protocol").link_libc = false;
            httpz_dep.module("httpz").link_libc = false;
            tls_dep.module("tls").link_libc = false;
        } else {
            android_lib.root_module.link_libc = true;
            dispatch_mod.link_libc = true;
            gameserver_mod.link_libc = true;
            protocol_dep.module("protocol").link_libc = true;
            httpz_dep.module("httpz").link_libc = true;
            tls_dep.module("tls").link_libc = true;
        }

        android_lib.root_module.addImport("dispatch_main", dispatch_mod);
        android_lib.root_module.addImport("gameserver_main", gameserver_mod);
        b.installArtifact(android_lib);
        return;
    }

    const exe = b.addExecutable(.{
        .name = "CastoricePS",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    // Windows icon embedding (skip for non-Windows targets).
    if (target.result.os.tag == .windows) {
        const rc_files = b.addWriteFiles();
        const rc_path = rc_files.add("castoriceps.rc",
            \\ 1 ICON "../icon_output.ico"
        );
        const rc_cmd = b.addSystemCommand(&.{ "zig", "rc", "/nologo", "/fo" });
        const res_output = rc_cmd.addOutputFileArg("castoriceps.res");
        rc_cmd.addFileArg(rc_path);
        exe.addWin32ResourceFile(.{ .file = res_output });
        exe.step.dependOn(&rc_cmd.step);
    }
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
