const std = @import("std");
const protobuf = @import("protobuf");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const protobuf_dep = b.dependency("protobuf", .{
        .optimize = optimize,
        .target = target,
    });

    const protocol = b.addModule("protocol", .{
        .root_source_file = b.path("src/root.zig"),
    });
    //
    protocol.addImport("protobuf", protobuf_dep.module("protobuf"));
}
