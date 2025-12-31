const tp_command = @import("./tp.zig");
const Session = @import("../Session.zig");
const std = @import("std");

const Allocator = std.mem.Allocator;

pub fn handle(session: *Session, args: []const u8, allocator: Allocator) !void {
    // Alias: /move behaves like /tp
    return tp_command.handle(session, args, allocator);
}

