const value_command = @import("./value.zig");
const Session = @import("../Session.zig");
const std = @import("std");

const Allocator = std.mem.Allocator;

pub fn handle(session: *Session, _: []const u8, allocator: Allocator) !void {
    // Alias: /pos behaves like /scene pos
    return value_command.sceneCommand(session, "pos", allocator);
}

