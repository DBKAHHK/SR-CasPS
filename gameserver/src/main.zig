const std = @import("std");
const builtin = @import("builtin");
const network = @import("network.zig");
const ConfigManager = @import("../src/manager/config_mgr.zig");
const scene_service = @import("services/scene.zig");

pub const std_options: std.Options = .{
    .log_level = switch (builtin.mode) {
        .Debug => .debug,
        else => .info,
    },
};

fn readSceneDebugFromSettings(allocator: std.mem.Allocator) bool {
    const file = std.fs.cwd().openFile("CastoricePS-settings.json", .{}) catch return false;
    defer file.close();
    const file_size = file.getEndPos() catch return false;
    const buf = file.readToEndAlloc(allocator, file_size) catch return false;
    defer allocator.free(buf);

    var tree = std.json.parseFromSlice(std.json.Value, allocator, buf, .{}) catch return false;
    defer tree.deinit();

    if (tree.value != .object) return false;
    if (tree.value.object.get("scene_debug")) |v| {
        if (v == .bool) return v.bool;
    }
    return false;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Default from settings file, with env var override for convenience.
    scene_service.scene_debug_enabled = readSceneDebugFromSettings(allocator);
    if (std.process.getEnvVarOwned(allocator, "CASTORICEPS_SCENE_DEBUG") catch null) |v| {
        defer allocator.free(v);
        if (v.len == 0 or std.mem.eql(u8, v, "0")) {
            scene_service.scene_debug_enabled = false;
        } else {
            scene_service.scene_debug_enabled = true;
        }
    }

    try ConfigManager.initGameGlobals(allocator);
    defer ConfigManager.deinitGameGlobals();
    try network.listen();
    std.log.info("Server listening for connections.", .{});
}
