const commandhandler = @import("../command.zig");
const std = @import("std");
const Session = @import("../Session.zig");
const protocol = @import("protocol");
const LineupManager = @import("../manager/lineup_mgr.zig");

const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

pub fn onRefill(session: *Session, _: []const u8, allocator: Allocator) !void {
    try commandhandler.sendMessage(session, "Refill technique points\n", allocator);

    var lineup_mgr = LineupManager.LineupManager.init(allocator);
    var lineup = try lineup_mgr.createLineup();

    // Java parity: /refill fills skill points (MP) in open world.
    lineup.mp = lineup.max_mp;

    var sync = protocol.SyncLineupNotify.init(allocator);
    try sync.ReasonList.append(.SYNC_REASON_MP_ADD);
    sync.lineup = lineup;
    try session.send(CmdID.CmdSyncLineupNotify, sync);
}
