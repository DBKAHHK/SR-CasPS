const commandhandler = @import("../command.zig");
const std = @import("std");
const Session = @import("../Session.zig");
const ConfigManager = @import("../manager/config_mgr.zig");
const Sync = @import("./sync.zig");
const protocol = @import("protocol");
const LineupManager = @import("../manager/lineup_mgr.zig");

const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

pub fn handle(session: *Session, args: []const u8, allocator: Allocator) !void {
    var it = std.mem.tokenizeAny(u8, args, " \t");
    const token = it.next() orelse {
        return commandhandler.sendMessage(session, "Usage: /mhp <max|number>", allocator);
    };

    const hp: u32 = blk: {
        if (std.ascii.eqlIgnoreCase(token, "max")) break :blk 2147483647;
        const parsed = std.fmt.parseInt(u32, token, 10) catch {
            return commandhandler.sendMessage(session, "Usage: /mhp <max|number>", allocator);
        };
        if (parsed == 0) return commandhandler.sendMessage(session, "HP must be >= 1", allocator);
        break :blk parsed;
    };

    const cfg = &ConfigManager.global_game_config_cache.game_config;
    for (cfg.avatar_config.items) |*avatar| {
        avatar.hp = hp;
    }

    // Sync avatar data so client refreshes stats.
    try Sync.onSyncAvatar(session, "", allocator);

    // Also refresh lineup HP shown in UI.
    var lineup_mgr = LineupManager.LineupManager.init(allocator);
    const lineup = try lineup_mgr.createLineup();
    var sync_lineup = protocol.SyncLineupNotify.init(allocator);
    sync_lineup.lineup = lineup;
    try session.send(CmdID.CmdSyncLineupNotify, sync_lineup);

    const msg = try std.fmt.allocPrint(allocator, "Set max HP to {d} and synced.", .{hp});
    defer allocator.free(msg);
    try commandhandler.sendMessage(session, msg, allocator);
}
