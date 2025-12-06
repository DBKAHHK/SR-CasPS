const commandhandler = @import("../command.zig");
const std = @import("std");
const Session = @import("../Session.zig");
const protocol = @import("protocol");
const LineupManager = @import("../manager/lineup_mgr.zig");
const SceneManager = @import("../manager/scene_mgr.zig");

const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

pub fn handle(session: *Session, _: []const u8, allocator: Allocator) !void {
    var lineup_mgr = LineupManager.LineupManager.init(allocator);
    const lineup = try lineup_mgr.createLineup();
    var scene_manager = SceneManager.SceneManager.init(allocator);
    const scene_info = try scene_manager.createScene(20421, 20421001, 2042101, 2042106);

    try session.send(CmdID.CmdEnterSceneByServerScNotify, protocol.EnterSceneByServerScNotify{
        .reason = protocol.EnterSceneReason.ENTER_SCENE_REASON_DIMENSION_MERGE,
        .lineup = lineup,
        .scene = scene_info,
    });
}
