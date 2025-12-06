const std = @import("std");
const builtin = @import("builtin");
const network = @import("network.zig");
const ConfigManager = @import("../src/manager/config_mgr.zig");

pub const std_options: std.Options = .{
    .log_level = switch (builtin.mode) {
        .Debug => .debug,
        else => .info,
    },
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    try ConfigManager.initGameGlobals(allocator);
    defer ConfigManager.deinitGameGlobals();
    try network.listen();
    std.log.info("Server listening for connections.", .{});
}
