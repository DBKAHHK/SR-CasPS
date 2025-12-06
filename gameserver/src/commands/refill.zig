const commandhandler = @import("../command.zig");
const std = @import("std");
const Session = @import("../Session.zig");
const protocol = @import("protocol");
const Packet = @import("../Packet.zig");
const LineupManager = @import("../manager/lineup_mgr.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

pub fn onRefill(session: *Session, _: []const u8, allocator: Allocator) !void {
    try commandhandler.sendMessage(session, "Refill skill points\n", allocator);
    var sync = protocol.SyncLineupNotify.init(allocator);
    var lineup_mgr = LineupManager.LineupManager.init(allocator);
    sync.lineup = try lineup_mgr.createLineup();
    if (sync.lineup) |*lineup| {
        // Force SP to max for every avatar in lineup.
        for (lineup.avatar_list.items) |*ava| {
            ava.sp_bar = .{ .cur_sp = 10000, .max_sp = 10000 };
        }
    }
    try session.send(CmdID.CmdSyncLineupNotify, sync);
}
