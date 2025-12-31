const commandhandler = @import("../command.zig");
const std = @import("std");
const Session = @import("../Session.zig");
const sync_command = @import("./sync.zig");

const Allocator = std.mem.Allocator;

pub fn handle(session: *Session, _: []const u8, allocator: Allocator) !void {
    try sync_command.onGenerateAndSync(session, "", allocator);
    try commandhandler.sendMessage(session, "Reload done (/sync).", allocator);
}

