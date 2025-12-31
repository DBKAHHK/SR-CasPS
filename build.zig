const std = @import("std");
const builtin = @import("builtin");
const protobuf = @import("protobuf");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const dep_opts = .{ .target = target, .optimize = optimize };

    const protobuf_dep = b.dependency("protobuf", dep_opts);

    if (std.fs.cwd().access("protocol/StarRail.proto", .{})) {
        const protoc_step = protobuf.RunProtocStep.create(b, protobuf_dep.builder, target, .{
            .destination_directory = b.path("protocol/src"),
            .source_files = &.{
                "protocol/StarRail.proto",
            },
            .include_directories = &.{},
        });

        b.getInstallStep().dependOn(&protoc_step.step);
    } else |_| {} // don't invoke protoc if proto definition doesn't exist

    const program = b.dependency("program", dep_opts);
    // program/build.zig produces:
    // - native/desktop: executable "CastoricePS"
    // - android: shared lib "castoriceps" (libcastoriceps.so)
    if (target.result.abi == .android) {
        b.installArtifact(program.artifact("castoriceps"));
    } else {
        b.installArtifact(program.artifact("CastoricePS"));
    }

    // Optional: build bundled firefly-go-proxy (Go) and install it next to CastoricePS.
    // Only run for native builds so cross-compiling doesn't require Go toolchains.
    if (target.result.os.tag == builtin.os.tag and target.result.cpu.arch == builtin.cpu.arch) {
        const proxy_dir = b.path("fireflygo_proxy");
        const proxy_exe_name = if (target.result.os.tag == .windows) "firefly-proxy.exe" else "firefly-proxy";
        const proxy_out = b.pathFromRoot(b.getInstallPath(.bin, proxy_exe_name));
        const build_proxy_cmd = b.addSystemCommand(&.{
            "go",
            "build",
            "-trimpath",
            "-ldflags=-s -w",
            "-o",
            proxy_out,
            ".",
        });
        build_proxy_cmd.setCwd(proxy_dir);
        if (target.result.os.tag == .windows) {
            build_proxy_cmd.setEnvironmentVariable("GOOS", "windows");
            build_proxy_cmd.setEnvironmentVariable("GOARCH", "amd64");
            build_proxy_cmd.setEnvironmentVariable("CGO_ENABLED", "0");
        }
        b.getInstallStep().dependOn(&build_proxy_cmd.step);
    }

    // Running is only meaningful for native builds.
    if (target.result.abi != .android) {
        const program_cmd = b.addRunArtifact(program.artifact("CastoricePS"));
        program_cmd.step.dependOn(b.getInstallStep());

        if (b.args) |args| {
            program_cmd.addArgs(args);
        }

        const program_step = b.step("run-program", "Run dispatch and gameserver together");
        program_step.dependOn(&program_cmd.step);
    }
    // "gen-proto"
    const gen_proto = b.step("gen-proto", "generates zig files from protocol buffer definitions");

    const protoc_step = protobuf.RunProtocStep.create(b, protobuf_dep.builder, target, .{
        // out directory for the generated zig files
        .destination_directory = b.path("protocol/src"),
        .source_files = &.{
            "protocol/StarRail.proto",
        },
        .include_directories = &.{},
    });

    gen_proto.dependOn(&protoc_step.step);
}
