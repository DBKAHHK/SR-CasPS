const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const LineupManager = @import("../manager/lineup_mgr.zig");
const PlayerStateMod = @import("../player_state.zig");
const SceneManager = @import("../manager/scene_mgr.zig");
const ConfigManager = @import("../manager/config_mgr.zig");
const ItemService = @import("item.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

const log = std.log.scoped(.scene_service);
const enable_position_log = false;

const entrance_config = &ConfigManager.global_game_config_cache.map_entrance_config;
const res_config = &ConfigManager.global_game_config_cache.res_config;

pub fn onGetCurSceneInfo(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var scene_manager = SceneManager.SceneManager.init(allocator);
    const scene_info = try scene_manager.createScene(20422, 20422001, 2042201, 1025);

    try session.send(CmdID.CmdGetCurSceneInfoScRsp, protocol.GetCurSceneInfoScRsp{
        .scene = scene_info,
        .retcode = 0,
    });
}
pub fn onSceneEntityMove(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.SceneEntityMoveCsReq, allocator);
    defer req.deinit();
    for (req.entity_motion_list.items) |entity_motion| {
        if (entity_motion.motion) |motion| {
            if (enable_position_log and (entity_motion.entity_id > 99999 and entity_motion.entity_id < 1000000 or entity_motion.entity_id == 0))
                log.debug("[POSITION] entity_id: {}, motion: {}", .{ entity_motion.entity_id, motion });
        }
    }
    try session.send(CmdID.CmdSceneEntityMoveScRsp, protocol.SceneEntityMoveScRsp{
        .retcode = 0,
        .entity_motion_list = req.entity_motion_list,
        .download_data = null,
    });
}

pub fn onEnterScene(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.EnterSceneCsReq, allocator);
    defer req.deinit();

    // 如果 session �?player_state，从存档强制应用最新编队到运行时（保证进入场景时使用存档值）
    if (session.player_state) |*state| {
        // we ignore errors here to avoid killing the scene entry �?failure will be logged by caller
        _ = PlayerStateMod.applySavedLineup(state) catch |err| {
            std.debug.print("applySavedLineup failed: {any}\n", .{err});
        };
    }

    var lineup_mgr = LineupManager.LineupManager.init(allocator);
    const lineup = try lineup_mgr.createLineup();
    var scene_manager = SceneManager.SceneManager.init(allocator);
    var floorID: u32 = 0;
    var planeID: u32 = 0;
    var teleportID: u32 = 0;
    for (entrance_config.map_entrance_config.items) |entrConf| {
        if (entrConf.id == req.entry_id) {
            floorID = entrConf.floor_id;
            planeID = entrConf.plane_id;
            teleportID = req.teleport_id;
        }
    }

    try session.send(CmdID.CmdEnterSceneScRsp, protocol.EnterSceneScRsp{
        .retcode = 0,
        .game_story_line_id = req.game_story_line_id,
        .is_close_map = req.is_close_map,
        .content_id = req.content_id,
        .is_over_map = false,
    });
    const scene_info = try scene_manager.createScene(planeID, floorID, req.entry_id, teleportID);
    if (enable_position_log) {
        std.debug.print("ENTER SCENE ENTRY ID: {}, PLANE ID: {}, FLOOR ID: {}, TELEPORT ID: {}\n", .{ req.entry_id, planeID, floorID, teleportID });
    }
    try session.send(CmdID.CmdEnterSceneByServerScNotify, protocol.EnterSceneByServerScNotify{
        .lineup = lineup,
        .reason = protocol.EnterSceneReason.ENTER_SCENE_REASON_NONE,
        .scene = scene_info,
    });
}

pub fn onGetSceneMapInfo(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.GetSceneMapInfoCsReq, allocator);
    defer req.deinit();

    const ranges = [_][2]usize{
        .{ 0, 101 },
        .{ 10000, 10051 },
        .{ 20000, 20001 },
        .{ 30000, 30020 },
    };
    const chest_list = &[_]protocol.ChestInfo{
        .{ .chest_type = protocol.ChestType.MAP_INFO_CHEST_TYPE_NORMAL },
        .{ .chest_type = protocol.ChestType.MAP_INFO_CHEST_TYPE_CHALLENGE },
        .{ .chest_type = protocol.ChestType.MAP_INFO_CHEST_TYPE_PUZZLE },
    };
    for (req.floor_id_list.items) |floor_id| {
        var rsp = protocol.GetSceneMapInfoScRsp.init(allocator);
        rsp.retcode = 0;
        rsp.content_id = req.content_id;
        rsp.entry_story_line_id = req.entry_story_line_id;
        rsp.unk1 = true;
        var map_info = protocol.SceneMapInfo.init(allocator);
        try map_info.chest_list.appendSlice(chest_list);
        map_info.entry_id = @intCast(floor_id);
        map_info.floor_id = @intCast(floor_id);
        map_info.cur_map_entry_id = @intCast(floor_id);
        for (res_config.scene_config.items) |sceneConf| {
            if (sceneConf.planeID != floor_id / 1000) continue;
            try map_info.unlock_teleport_list.ensureUnusedCapacity(sceneConf.teleports.items.len);
            try map_info.maze_prop_list.ensureUnusedCapacity(sceneConf.props.items.len);
            try map_info.maze_group_list.ensureUnusedCapacity(sceneConf.props.items.len);
            for (ranges) |range| {
                for (range[0]..range[1]) |i| {
                    try map_info.lighten_section_list.append(@intCast(i));
                }
            }
            for (sceneConf.teleports.items) |teleConf| {
                try map_info.unlock_teleport_list.append(@intCast(teleConf.teleportId));
            }
            for (sceneConf.props.items) |propConf| {
                try map_info.maze_prop_list.append(protocol.MazePropState{
                    .group_id = propConf.groupId,
                    .config_id = propConf.instId,
                    .state = propConf.propState,
                });
                try map_info.maze_prop_extra_state_list.append(protocol.MazePropExtraState{
                    .group_id = propConf.groupId,
                    .config_id = propConf.instId,
                    .state = propConf.propState,
                });
                try map_info.maze_group_list.append(protocol.MazeGroup{
                    .DDNOEGPCACF = std.ArrayList(u32).init(allocator),
                    .group_id = propConf.groupId,
                });
            }
        }
        try rsp.scene_map_info.append(map_info);
        try session.send(protocol.CmdID.CmdGetSceneMapInfoScRsp, rsp);
    }
}
pub fn onGetUnlockTeleport(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetUnlockTeleportScRsp.init(allocator);
    var total_tps: usize = 0;
    for (res_config.scene_config.items) |scene| {
        total_tps += scene.teleports.items.len;
    }
    try rsp.unlock_teleport_list.ensureTotalCapacity(total_tps);
    for (res_config.scene_config.items) |sceneCof| {
        for (sceneCof.teleports.items) |tp| {
            rsp.unlock_teleport_list.appendAssumeCapacity(tp.teleportId);
        }
    }
    rsp.retcode = 0;
    try session.send(CmdID.CmdGetUnlockTeleportScRsp, rsp);
}
pub fn onEnterSection(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.EnterSectionCsReq, allocator);
    defer req.deinit();

    var rsp = protocol.EnterSectionScRsp.init(allocator);
    rsp.retcode = 0;
    std.debug.print("ENTER SECTION Id: {}\n", .{req.section_id});
    try session.send(CmdID.CmdEnterSectionScRsp, rsp);
}

pub fn onGetEnteredScene(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetEnteredSceneScRsp.init(allocator);
    var noti = protocol.EnteredSceneChangeScNotify.init(allocator);
    for (entrance_config.map_entrance_config.items) |entrance| {
        try rsp.entered_scene_info_list.append(protocol.EnteredSceneInfo{
            .floor_id = entrance.floor_id,
            .plane_id = entrance.plane_id,
        });
        try noti.entered_scene_info_list.append(protocol.EnteredSceneInfo{
            .floor_id = entrance.floor_id,
            .plane_id = entrance.plane_id,
        });
    }
    rsp.retcode = 0;
    try session.send(CmdID.CmdEnteredSceneChangeScNotify, noti);
    try session.send(CmdID.CmdGetEnteredSceneScRsp, rsp);
}

pub fn onSceneEntityTeleport(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.SceneEntityTeleportCsReq, allocator);
    defer req.deinit();

    var rsp = protocol.SceneEntityTeleportScRsp.init(allocator);
    rsp.retcode = 0;
    rsp.entity_motion = req.entity_motion;
    std.debug.print("SCENE ENTITY TP ENTRY ID: {}\n", .{req.entry_id});
    try session.send(CmdID.CmdSceneEntityTeleportScRsp, rsp);
}

pub fn onGetFirstTalkNpc(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.GetFirstTalkNpcCsReq, allocator);
    defer req.deinit();

    var rsp = protocol.GetFirstTalkNpcScRsp.init(allocator);
    rsp.retcode = 0;
    for (req.npc_id_list.items) |id| {
        try rsp.npc_meet_status_list.append(protocol.FirstNpcTalkInfo{ .npc_id = id, .is_meet = true });
    }
    try session.send(CmdID.CmdGetFirstTalkNpcScRsp, rsp);
}

pub fn onGetFirstTalkByPerformanceNp(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.GetFirstTalkByPerformanceNpcCsReq, allocator);
    defer req.deinit();

    var rsp = protocol.GetFirstTalkByPerformanceNpcScRsp.init(allocator);
    rsp.retcode = 0;
    for (req.performance_id_list.items) |id| {
        try rsp.npc_meet_status_list.append(
            protocol.NpcMeetByPerformanceStatus{ .performance_id = id, .is_meet = true },
        );
    }
    try session.send(CmdID.CmdGetFirstTalkByPerformanceNpcScRsp, rsp);
}

pub fn onGetNpcTakenReward(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.GetNpcTakenRewardCsReq, allocator);
    defer req.deinit();

    var rsp = protocol.GetNpcTakenRewardScRsp.init(allocator);
    const EventList = [_]u32{ 2136, 2134 };
    rsp.retcode = 0;
    rsp.npc_id = req.npc_id;
    try rsp.talk_event_list.appendSlice(&EventList);
    try session.send(CmdID.CmdGetNpcTakenRewardScRsp, rsp);
}
pub fn onUpdateGroupProperty(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.UpdateGroupPropertyCsReq, allocator);
    defer req.deinit();

    var rsp = protocol.UpdateGroupPropertyScRsp.init(allocator);
    rsp.retcode = 0;
    rsp.floor_id = req.floor_id;
    rsp.group_id = req.group_id;
    rsp.dimension_id = req.dimension_id;
    rsp.DELEKFMGGCM = req.DELEKFMGGCM;
    try session.send(CmdID.CmdUpdateGroupPropertyScRsp, rsp);
}
pub fn onChangePropTimeline(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.ChangePropTimelineInfoCsReq, allocator);
    defer req.deinit();

    try session.send(CmdID.CmdChangePropTimelineInfoScRsp, protocol.ChangePropTimelineInfoScRsp{
        .retcode = 0,
        .prop_entity_id = req.prop_entity_id,
    });
}
pub fn onDeactivateFarmElement(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.DeactivateFarmElementCsReq, allocator);
    defer req.deinit();

    std.debug.print("DeactivateFarmElement: entity_id={}\n", .{req.entity_id});

    var rsp = protocol.DeactivateFarmElementScRsp.init(allocator);
    rsp.entity_id = req.entity_id;
    rsp.retcode = 0;

    try session.send(CmdID.CmdDeactivateFarmElementScRsp, rsp);
}

pub fn onActivateFarmElement(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.ActivateFarmElementCsReq, allocator);
    defer req.deinit();

    std.debug.print("ACTIVATE FARM ELEMENT ENTITY ID: {}\n", .{req.entity_id});
    try session.send(CmdID.CmdActivateFarmElementScRsp, protocol.ActivateFarmElementScRsp{
        .retcode = 0,
        .world_level = req.world_level,
        .entity_id = req.entity_id,
    });
}
pub fn onInteractProp(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.InteractPropCsReq, allocator);
    defer req.deinit();

    std.debug.print("InteractProp: entity_id={} interact_id={}\n", .{ req.prop_entity_id, req.interact_id });

    // 不立即发送响应，先根据交互类型处理（例如宝箱打开）并在末尾发送合适的 prop_state
    var rsp = protocol.InteractPropScRsp.init(allocator);
    rsp.prop_entity_id = req.prop_entity_id;
    rsp.retcode = 0;

    // 检查是否为宝箱交互（通过解析�?InteractConfig），若是尝试授予奖励
    const interact_cfg = &ConfigManager.global_game_config_cache.interact_config;
    var is_chest_open: bool = false;
    for (interact_cfg.interact_config.items) |e| {
        if (e.interact_id == req.interact_id) {
            // 检�?src/target 是否提到 "Chest" 并且 target �?ChestUsed �?Open
            if (e.target_state) |t| {
                if (std.mem.indexOf(u8, t, "ChestUsed") != null or std.mem.indexOf(u8, t, "Open") != null) {
                    if (e.src_state) |s| {
                        if (std.mem.indexOf(u8, s, "Chest") != null) {
                            is_chest_open = true;
                            break;
                        }
                    } else if (std.mem.indexOf(u8, t, "Chest") != null) {
                        // target 里包�?Chest 并且 target indicates open/used
                        is_chest_open = true;
                        break;
                    }
                }
            }
        }
    }

    var new_prop_state: u32 = 0;
    if (is_chest_open) {
        // 如果玩家没有 player_state 不处理奖�?
        if (session.player_state) |*state| {
            // 如果这个 chest 已经被打开则不重复处理
            var already: bool = false;
            for (state.opened_chests.items) |id| {
                if (id == req.prop_entity_id) {
                    already = true;
                    break;
                }
            }
            if (!already) {
                // set new_prop_state to 2 (commonly used for opened/used chests in resources)
                new_prop_state = 2;
                // 通知客户端宝箱打开
                

                // 发放奖励并保存（grantItems 内会保存�?                

                // 记录到玩家已开宝箱并持久化
                try state.opened_chests.append(req.prop_entity_id);
                try PlayerStateMod.save(state);
            } else {
                // already opened -> ensure client sees opened state
                new_prop_state = 2;
            }
        }
    } else {
        // not a chest open action �?leave default new_prop_state = 0
    }

    // send scene refresh so client updates prop visuals (add_entity with updated prop_state)
    if (new_prop_state != 0) {
        var grp_notify = protocol.SceneGroupRefreshScNotify.init(allocator);
        grp_notify.floor_id = 0;
        var g_list = std.ArrayList(protocol.GroupRefreshInfo).init(allocator);
        defer g_list.deinit();

        var g = protocol.GroupRefreshInfo.init(allocator);
        g.refresh_type = protocol.SceneGroupRefreshType.SCENE_GROUP_REFRESH_TYPE_LOADED;
        g.group_id = 0;

        var refresh_list = std.ArrayList(protocol.SceneEntityRefreshInfo).init(allocator);
        defer refresh_list.deinit();

        var r = protocol.SceneEntityRefreshInfo.init(allocator);
        // put add_entity = SceneEntityInfo{ .entity_id = req.prop_entity_id, .entity = .{ .prop = ScenePropInfo{ .prop_state = new_prop_state } } }
        var ent = protocol.SceneEntityInfo.init(allocator);
        ent.entity_id = req.prop_entity_id;
        var prop = protocol.ScenePropInfo.init(allocator);
        prop.prop_state = new_prop_state;
        ent.entity = .{ .prop = prop };
        r.PBBHAEHGGIO = .{ .add_entity = ent };
        try refresh_list.append(r);

        g.refresh_entity = refresh_list;
        try g_list.append(g);
        grp_notify.group_refresh_list = g_list;
        try session.send(CmdID.CmdSceneGroupRefreshScNotify, grp_notify);
    }

    // finally send the InteractProp response with the prop_state reflecting the change
    rsp.prop_state = new_prop_state;
    try session.send(CmdID.CmdInteractPropScRsp, rsp);
}

pub fn onChangeEraFlipperData(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.ChangeEraFlipperDataCsReq, allocator);
    defer req.deinit();

    try session.send(CmdID.CmdChangeEraFlipperDataScRsp, protocol.ChangeEraFlipperDataScRsp{
        .retcode = 0,
        .data = req.data,
    });
}
pub fn onSetTrainWorldId(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.SetTrainWorldIdCsReq, allocator);
    defer req.deinit();

    try session.send(CmdID.CmdSetTrainWorldIdScRsp, protocol.SetTrainWorldIdScRsp{
        .retcode = 0,
        .JHJPDNINCLJ = req.JHJPDNINCLJ,
    });
}
