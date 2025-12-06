const std = @import("std");
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
    b.installArtifact(program.artifact("CastoricePS"));

    const program_cmd = b.addRunArtifact(program.artifact("CastoricePS"));
    program_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        program_cmd.addArgs(args);
    }

    const program_step = b.step("run-program", "Run dispatch and gameserver together");
    program_step.dependOn(&program_cmd.step);
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
