const commandhandler = @import("../command.zig");
const std = @import("std");
const Session = @import("../Session.zig");
const protocol = @import("protocol");
const ConfigManager = @import("../manager/config_mgr.zig");
const LineupManager = @import("../manager/lineup_mgr.zig");

const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

pub fn handle(session: *Session, _: []const u8, allocator: Allocator) !void {
    var lineup_mgr = LineupManager.LineupManager.init(allocator);
    // HP is computed in `LineupManager.buildLineup()` from freesr-data.json config.
    const lineup = try lineup_mgr.createLineup();

    var sync = protocol.SyncLineupNotify.init(allocator);
    sync.lineup = lineup;
    try session.send(CmdID.CmdSyncLineupNotify, sync);
    try commandhandler.sendMessage(session, "Healed current lineup (sync).", allocator);
}
