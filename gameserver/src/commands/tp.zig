const commandhandler = @import("../command.zig");
const std = @import("std");
const Session = @import("../Session.zig");
const protocol = @import("protocol");
const LineupManager = @import("../manager/lineup_mgr.zig");
const SceneManager = @import("../manager/scene_mgr.zig");

const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

pub fn handle(session: *Session, args: []const u8, allocator: Allocator) !void {
    var arg_iter = std.mem.splitSequence(u8, args, " ");
    const entry_id_str = arg_iter.next() orelse {
        try commandhandler.sendMessage(session, "Error: Missing arguments.\nUsage: /tp <entry_id> [plane_id] [floor_id]", allocator);
        return;
    };
    const entry_id = std.fmt.parseInt(u32, entry_id_str, 10) catch {
        try commandhandler.sendMessage(session, "Error: Invalid entry ID. Please provide a valid unsigned 32-bit integer.", allocator);
        return;
    };
    var plane_id: ?u32 = null;
    if (arg_iter.next()) |plane_id_str| {
        plane_id = std.fmt.parseInt(u32, plane_id_str, 10) catch {
            try commandhandler.sendMessage(session, "Error: Invalid plane ID. Please provide a valid unsigned 32-bit integer.", allocator);
            return;
        };
    }
    var floor_id: ?u32 = null;
    if (arg_iter.next()) |floor_id_str| {
        floor_id = std.fmt.parseInt(u32, floor_id_str, 10) catch {
            try commandhandler.sendMessage(session, "Error: Invalid floor ID. Please provide a valid unsigned 32-bit integer.", allocator);
            return;
        };
    }
    var tp_msg = try std.fmt.allocPrint(allocator, "Teleporting to entry ID: {d}", .{entry_id});
    if (plane_id) |pid| {
        tp_msg = try std.fmt.allocPrint(allocator, "{s}, plane ID: {d}", .{ tp_msg, pid });
    }
    if (floor_id) |fid| {
        tp_msg = try std.fmt.allocPrint(allocator, "{s}, floor ID: {d}", .{ tp_msg, fid });
    }

    try commandhandler.sendMessage(session, std.fmt.allocPrint(allocator, "Teleporting to entry ID: {d} {any} {any}\n", .{ entry_id, plane_id, floor_id }) catch "Error formatting message", allocator);

    var planeID: u32 = 0;
    var floorID: u32 = 0;
    if (session.player_state) |*state| {
        planeID = state.position.plane_id;
        floorID = state.position.floor_id;
    }
    if (plane_id) |pid| planeID = pid;
    if (floor_id) |fid| floorID = fid;

    var scene_manager = SceneManager.SceneManager.init(allocator);
    const scene_info = try scene_manager.createScene(planeID, floorID, entry_id, 0);
    var lineup_mgr = LineupManager.LineupManager.init(allocator);
    const lineup = try lineup_mgr.createLineup();
    try session.send(CmdID.CmdEnterSceneByServerScNotify, protocol.EnterSceneByServerScNotify{
        .reason = protocol.EnterSceneReason.ENTER_SCENE_REASON_NONE,
        .lineup = lineup,
        .scene = scene_info,
    });

    // Update player position in save if available.
    if (session.player_state) |*state| {
        state.position = .{ .plane_id = planeID, .floor_id = floorID, .entry_id = entry_id, .teleport_id = 0 };
    }
}
