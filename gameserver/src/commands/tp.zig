const commandhandler = @import("../command.zig");
const std = @import("std");
const Session = @import("../Session.zig");
const protocol = @import("protocol");
const LineupManager = @import("../manager/lineup_mgr.zig");
const SceneManager = @import("../manager/scene_mgr.zig");
const ConfigManager = @import("../manager/config_mgr.zig");
const PlayerStateMod = @import("../player_state.zig");

const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

fn calcDefaultEntryId(plane_id: u32, floor_id: u32) u32 {
    var floor_suffix: u32 = floor_id % 100;
    if (floor_suffix == 0) floor_suffix = 1;
    return plane_id * 100 + floor_suffix;
}

fn resolveTeleportId(plane_id: u32, entry_id: u32) u32 {
    var teleport_id: u32 = 0;
    const anchors_cfg = &ConfigManager.global_game_config_cache.anchor_config;
    const res_cfg = &ConfigManager.global_game_config_cache.res_config;

    const anchor_id_opt: ?u32 = blk: {
        for (anchors_cfg.anchor_config.items) |a| {
            if (a.entryID != entry_id) continue;
            if (a.anchor.items.len == 0) break;
            break :blk a.anchor.items[0].id;
        }
        break :blk null;
    };

    if (anchor_id_opt) |anchor_id| {
        outer: for (res_cfg.scene_config.items) |sceneConf| {
            for (sceneConf.teleports.items) |tele| {
                if (tele.anchorId == anchor_id) {
                    teleport_id = tele.teleportId;
                    break :outer;
                }
            }
        }
    }

    if (teleport_id == 0) {
        // Some entries are missing Anchor.json mappings; fall back to the first teleportId for this scene,
        // or (most commonly) teleportId == entryId.
        for (res_cfg.scene_config.items) |sceneConf| {
            if (sceneConf.planeID != plane_id or sceneConf.entryID != entry_id) continue;
            if (sceneConf.teleports.items.len > 0) teleport_id = sceneConf.teleports.items[0].teleportId;
            break;
        }
        if (teleport_id == 0) teleport_id = entry_id;
    }

    return teleport_id;
}

fn looksLikeEntryPlaneFloor(entry_id: u32, plane_id: u32, floor_id: u32) bool {
    // Heuristic for backward-compat: old syntax was `/tp <entry_id> [plane_id] [floor_id]`.
    // Typical sizes: entry_id ~= 7 digits, plane_id ~= 5 digits, floor_id ~= 8 digits.
    return entry_id >= 1_000_000 and plane_id < 1_000_000 and floor_id >= 1_000_000;
}

pub fn handle(session: *Session, args: []const u8, allocator: Allocator) !void {
    var it = std.mem.tokenizeAny(u8, args, " \t\r\n");
    const a0 = it.next() orelse {
        return commandhandler.sendMessage(session, "Usage: /tp <entryId> | /tp <planeId> <floorId> [entryId] [teleportId]", allocator);
    };
    const a1 = it.next();
    const a2 = it.next();
    const a3 = it.next();
    if (it.next() != null) {
        return commandhandler.sendMessage(session, "Usage: /tp <entryId> | /tp <planeId> <floorId> [entryId] [teleportId]", allocator);
    }

    const n0 = std.fmt.parseInt(u32, a0, 10) catch {
        return commandhandler.sendMessage(session, "Error: invalid number.", allocator);
    };
    const n1 = if (a1) |s| (std.fmt.parseInt(u32, s, 10) catch {
        return commandhandler.sendMessage(session, "Error: invalid number.", allocator);
    }) else null;
    const n2 = if (a2) |s| (std.fmt.parseInt(u32, s, 10) catch {
        return commandhandler.sendMessage(session, "Error: invalid number.", allocator);
    }) else null;
    const n3 = if (a3) |s| (std.fmt.parseInt(u32, s, 10) catch {
        return commandhandler.sendMessage(session, "Error: invalid number.", allocator);
    }) else null;

    var plane_id: u32 = 0;
    var floor_id: u32 = 0;
    var entry_id: u32 = 0;
    var teleport_id: u32 = 0;

    if (n1 == null) {
        // /tp <entryId>  (use current plane/floor)
        entry_id = n0;
        if (session.player_state) |*state| {
            plane_id = state.position.plane_id;
            floor_id = state.position.floor_id;
        }
        if (plane_id == 0 or floor_id == 0) {
            return commandhandler.sendMessage(session, "Error: current plane/floor unknown; use /tp <planeId> <floorId> <entryId>.", allocator);
        }
    } else if (n2 == null) {
        // /tp <planeId> <floorId>  (auto entryId)
        plane_id = n0;
        floor_id = n1.?;
        entry_id = calcDefaultEntryId(plane_id, floor_id);
    } else if (n3 == null) {
        // /tp <planeId> <floorId> <entryId>  (or legacy: /tp <entryId> <planeId> <floorId>)
        const x1 = n1.?;
        const x2 = n2.?;
        if (looksLikeEntryPlaneFloor(n0, x1, x2)) {
            entry_id = n0;
            plane_id = x1;
            floor_id = x2;
        } else {
            plane_id = n0;
            floor_id = x1;
            entry_id = x2;
        }
    } else {
        // /tp <planeId> <floorId> <entryId> <teleportId>
        plane_id = n0;
        floor_id = n1.?;
        entry_id = n2.?;
        teleport_id = n3.?;
    }

    if (teleport_id == 0) teleport_id = resolveTeleportId(plane_id, entry_id);

    var scene_manager = SceneManager.SceneManager.init(allocator);
    const scene_info = try scene_manager.createScene(plane_id, floor_id, entry_id, teleport_id);
    var lineup_mgr = LineupManager.LineupManager.init(allocator);
    const lineup = try lineup_mgr.createLineup();
    try session.send(CmdID.CmdEnterSceneByServerScNotify, protocol.EnterSceneByServerScNotify{
        .reason = protocol.EnterSceneReason.ENTER_SCENE_REASON_NONE,
        .lineup = lineup,
        .scene = scene_info,
    });

    // Update player position in save if available.
    if (session.player_state) |*state| {
        state.position = .{ .plane_id = plane_id, .floor_id = floor_id, .entry_id = entry_id, .teleport_id = teleport_id };
        try PlayerStateMod.save(state);
    }

    const msg = try std.fmt.allocPrint(
        allocator,
        "Teleported: planeId={d}, floorId={d}, entryId={d}, teleportId={d}",
        .{ plane_id, floor_id, entry_id, teleport_id },
    );
    defer allocator.free(msg);
    try commandhandler.sendMessage(session, msg, allocator);
}
