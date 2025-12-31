const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const Config = @import("../data/game_config.zig");
const Res_config = @import("../data/res_config.zig");
const AvatarManager = @import("../manager/avatar_mgr.zig");
const ConfigManager = @import("../manager/config_mgr.zig");
const Uid = @import("../utils/uid.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

const config = &ConfigManager.global_game_config_cache.game_config;
const res_config = &ConfigManager.global_game_config_cache.res_config;
const mission_config = &ConfigManager.global_game_config_cache.main_mission_config;
const saved_values_config = &ConfigManager.global_game_config_cache.saved_values_config;
const map_entrance_config = &ConfigManager.global_game_config_cache.map_entrance_config;
const anchors = &ConfigManager.global_game_config_cache.anchor_config;

fn getBaseAvatarId(id: u32) u32 {
    return switch (id) {
        8001...8008 => 8001,
        1224 => 1001,
        else => id,
    };
}
inline fn toVector(v: anytype) protocol.Vector {
    return .{ .x = v.x, .y = v.y, .z = v.z };
}
fn getOrCreateGroup(
    group_map: *std.AutoHashMap(u32, protocol.SceneEntityGroupInfo),
    group_id: u32,
    allocator: Allocator,
) !*protocol.SceneEntityGroupInfo {
    if (group_map.getPtr(group_id)) |g| return g;
    var new_group = protocol.SceneEntityGroupInfo.init(allocator);
    new_group.state = 1;
    new_group.group_id = group_id;
    try group_map.put(group_id, new_group);
    return group_map.getPtr(group_id).?;
}
pub const SceneManager = struct {
    allocator: Allocator,
    pub fn init(allocator: Allocator) SceneManager {
        return .{ .allocator = allocator };
    }
    fn addAvatarEntities(
        scene_group: *protocol.SceneEntityGroupInfo,
        avatar_configs: []const Config.Avatar,
        tele_pos: protocol.Vector,
        tele_rot: protocol.Vector,
        uid: u32,
    ) !void {
        for (avatar_configs) |avatarConf| {
            const base_id = getBaseAvatarId(avatarConf.id);
            try scene_group.entity_list.append(.{
                .inst_id = 1,
                .entity_id = @intCast(base_id + 100000),
                .entity = .{
                    .actor = .{
                        .base_avatar_id = base_id,
                        .avatar_type = .AVATAR_FORMAL_TYPE,
                        .uid = uid,
                        .map_layer = 0,
                    },
                },
                .motion = .{ .pos = tele_pos, .rot = tele_rot },
            });
        }
    }
    fn addPropEntities(
        allocator: Allocator,
        group_map: *std.AutoHashMap(u32, protocol.SceneEntityGroupInfo),
        prop_configs: []const Res_config.Props,
        generator: *Uid.BaseUidGen(),
    ) !void {
        for (prop_configs) |propConf| {
            var scene_group = try getOrCreateGroup(group_map, propConf.groupId, allocator);
            var prop_info = protocol.ScenePropInfo.init(allocator);
            prop_info.prop_id = propConf.propId;
            prop_info.prop_state = propConf.propState;
            try scene_group.entity_list.append(.{
                .entity = .{ .prop = prop_info },
                .group_id = scene_group.group_id,
                .inst_id = propConf.instId,
                .entity_id = 1000 + generator.nextId(),
                .motion = .{ .pos = toVector(propConf.pos), .rot = toVector(propConf.rot) },
            });
        }
    }
    fn addMonsterEntities(
        allocator: Allocator,
        group_map: *std.AutoHashMap(u32, protocol.SceneEntityGroupInfo),
        monster_configs: []const Res_config.Monsters,
        generator: *Uid.BaseUidGen(),
    ) !void {
        for (monster_configs) |monsConf| {
            var scene_group = try getOrCreateGroup(group_map, monsConf.groupId, allocator);
            var monster_info = protocol.SceneNpcMonsterInfo.init(allocator);
            monster_info.monster_id = monsConf.monsterId;
            monster_info.event_id = monsConf.eventId;
            monster_info.world_level = 6;
            try scene_group.entity_list.append(.{
                .entity = .{ .npc_monster = monster_info },
                .group_id = scene_group.group_id,
                .inst_id = monsConf.instId,
                .entity_id = if ((monsConf.monsterId / 1000) % 10 == 3) monster_info.monster_id else generator.nextId(),
                .motion = .{ .pos = toVector(monsConf.pos), .rot = toVector(monsConf.rot) },
            });
        }
    }
    pub fn createScene(
        self: *SceneManager,
        plane_id: u32,
        floor_id: u32,
        entry_id: u32,
        teleport_id: u32,
    ) !protocol.SceneInfo {
        var generator = Uid.BaseUidGen().init();
        var scene_info = protocol.SceneInfo.init(self.allocator);
        scene_info.game_mode_type = 1;
        scene_info.plane_id = plane_id;
        scene_info.floor_id = floor_id;
        scene_info.entry_id = entry_id;

        var main_mission = std.ArrayList(u32).init(self.allocator);
        for (mission_config.main_mission_config.items) |id| {
            try main_mission.append(id.main_mission_id);
        }
        var mission_status = protocol.MissionStatusBySceneInfo.init(self.allocator);
        mission_status.finished_main_mission_id_list = main_mission;
        scene_info.scene_mission_info = mission_status;

        for (saved_values_config.floor_saved_values.items) |saved| {
            if (saved.floor_id == floor_id) {
                for (saved.saved_values.items) |values| {
                    try scene_info.floor_saved_data.append(.{
                        .key = .{ .Const = values.name orelse "" },
                        .value = values.max_value orelse 0,
                    });
                }
            }
        }

        scene_info.leader_entity_id = if (config.avatar_config.items.len > 0)
            @intCast(getBaseAvatarId(config.avatar_config.items[0].id) + 100000)
        else
            0;
        scene_info.world_id = 501;
        scene_info.client_pos_version = 1;
        var group_map = std.AutoHashMap(u32, protocol.SceneEntityGroupInfo).init(self.allocator);
        defer group_map.deinit();

        // Resolve spawn transform for this (planeId, entryId):
        // 1) teleportId match inside this scene
        // 2) first teleport inside this scene
        // 3) Anchor.json first anchor for this entry
        // 4) default (0,0,0)
        var spawn_pos: protocol.Vector = .{ .x = 0, .y = 0, .z = 0 };
        var spawn_rot: protocol.Vector = .{ .x = 0, .y = 0, .z = 0 };
        var have_spawn = false;

        for (res_config.scene_config.items) |sceneConf| {
            if (sceneConf.planeID != plane_id or sceneConf.entryID != entry_id) continue;

            if (teleport_id != 0) {
                for (sceneConf.teleports.items) |teleConf| {
                    if (teleConf.teleportId != teleport_id) continue;
                    spawn_pos = toVector(teleConf.pos);
                    spawn_rot = toVector(teleConf.rot);
                    have_spawn = true;
                    break;
                }
            }

            if (!have_spawn and sceneConf.teleports.items.len > 0) {
                const teleConf = sceneConf.teleports.items[0];
                spawn_pos = toVector(teleConf.pos);
                spawn_rot = toVector(teleConf.rot);
                have_spawn = true;
            }

            try addPropEntities(self.allocator, &group_map, sceneConf.props.items, &generator);
            try addMonsterEntities(self.allocator, &group_map, sceneConf.monsters.items, &generator);
            break;
        }

        if (!have_spawn) {
            for (anchors.anchor_config.items) |anchorConf| {
                if (anchorConf.entryID != entry_id) continue;
                if (anchorConf.anchor.items.len == 0) break;
                const a = anchorConf.anchor.items[0];
                spawn_pos = toVector(a.pos);
                spawn_rot = toVector(a.rot);
                have_spawn = true;
                break;
            }
        }

        // Always spawn avatar group so the client can enter the scene even if res.json lacks props/monsters.
        var scene_group = protocol.SceneEntityGroupInfo.init(self.allocator);
        scene_group.state = 1;
        try addAvatarEntities(&scene_group, config.avatar_config.items, spawn_pos, spawn_rot, 1);
        try scene_info.entity_group_list.append(scene_group);
        var iter = group_map.iterator();
        while (iter.next()) |entry| {
            const g = entry.value_ptr.*;
            try scene_info.entity_group_list.append(g);
            try scene_info.entity_list.appendSlice(g.entity_list.items);
            try scene_info.LDDIGMLCGDB.append(g.group_id);
            try scene_info.custom_data_list.append(.{ .group_id = g.group_id });
            try scene_info.group_state_list.append(.{
                .group_id = g.group_id,
                .state = 0,
                .is_default = true,
            });
        }
        const ranges = [_][2]usize{ .{ 0, 101 }, .{ 10000, 10051 }, .{ 20000, 20001 }, .{ 30000, 30020 } };
        for (ranges) |range| {
            for (range[0]..range[1]) |i| try scene_info.lighten_section_list.append(@intCast(i));
        }
        return scene_info;
    }
};
pub const ChallengeSceneManager = struct {
    allocator: Allocator,
    pub fn init(allocator: Allocator) ChallengeSceneManager {
        return .{ .allocator = allocator };
    }
    pub fn getAnchorMotion(entry_id: u32) ?protocol.MotionInfo {
        for (anchors.anchor_config.items) |anchorConf| {
            if (anchorConf.entryID != entry_id) continue;
            if (anchorConf.anchor.items.len == 0) break;
            const a = anchorConf.anchor.items[0];
            return protocol.MotionInfo{ .pos = toVector(a.pos), .rot = toVector(a.rot) };
        }
        return null;
    }
    fn createBaseScene(
        self: *ChallengeSceneManager,
        game_mode_type: u32,
        avatar_list: ArrayList(u32),
        plane_id: u32,
        floor_id: u32,
        entry_id: u32,
        world_id: ?u32,
        maze_group_id: u32,
    ) !protocol.SceneInfo {
        var scene_info = protocol.SceneInfo.init(self.allocator);
        scene_info.game_mode_type = game_mode_type;
        scene_info.plane_id = plane_id;
        scene_info.floor_id = floor_id;
        scene_info.entry_id = entry_id;
        scene_info.leader_entity_id = avatar_list.items[0];
        if (world_id) |wid| scene_info.world_id = wid;

        try scene_info.group_state_list.append(.{
            .group_id = maze_group_id,
            .is_default = true,
        });

        var scene_group = protocol.SceneEntityGroupInfo.init(self.allocator);
        scene_group.state = 1;
        scene_group.group_id = 0;

        var main_mission = std.ArrayList(u32).init(self.allocator);
        for (mission_config.main_mission_config.items) |id| {
            try main_mission.append(id.main_mission_id);
        }
        var mission_status = protocol.MissionStatusBySceneInfo.init(self.allocator);
        mission_status.finished_main_mission_id_list = main_mission;
        scene_info.scene_mission_info = mission_status;

        for (saved_values_config.floor_saved_values.items) |saved| {
            if (saved.floor_id == floor_id) {
                for (saved.saved_values.items) |values| {
                    try scene_info.floor_saved_data.append(.{
                        .key = .{ .Const = values.name orelse "" },
                        .value = values.max_value orelse 0,
                    });
                }
            }
        }

        for (avatar_list.items) |avatar_base_id| {
            const base_id = getBaseAvatarId(avatar_base_id);
            try scene_group.entity_list.append(.{
                .inst_id = 1,
                .entity_id = @intCast(base_id + 100000),
                .entity = .{
                    .actor = .{
                        .base_avatar_id = base_id,
                        .avatar_type = .AVATAR_FORMAL_TYPE,
                        .uid = 1,
                        .map_layer = 0,
                    },
                },
                .motion = .{ .pos = .{}, .rot = .{} },
            });
        }
        try scene_info.entity_group_list.append(scene_group);
        return scene_info;
    }
    fn addChallengeEntities(
        self: *ChallengeSceneManager,
        scene_info: *protocol.SceneInfo,
        group_id: u32,
        monster_id: u32,
        event_id: u32,
        generator: *Uid.BaseUidGen(),
    ) !void {
        for (res_config.scene_config.items) |sceneConf| {
            if (sceneConf.planeID != scene_info.plane_id) continue;
            for (sceneConf.monsters.items) |monsConf| {
                if (monsConf.groupId != group_id) continue;
                var scene_group = protocol.SceneEntityGroupInfo.init(self.allocator);
                scene_group.state = 1;
                scene_group.group_id = group_id;
                var monster_info = protocol.SceneNpcMonsterInfo.init(self.allocator);
                monster_info.monster_id = monster_id;
                monster_info.event_id = event_id;
                monster_info.world_level = 6;
                try scene_group.entity_list.append(.{
                    .entity = .{ .npc_monster = monster_info },
                    .group_id = group_id,
                    .inst_id = monsConf.instId,
                    .entity_id = generator.nextId(),
                    .motion = .{ .pos = toVector(monsConf.pos), .rot = toVector(monsConf.rot) },
                });
                try scene_info.entity_group_list.append(scene_group);
                break;
            }
            for (sceneConf.props.items) |propConf| {
                if (propConf.groupId != group_id) continue;
                var scene_group = protocol.SceneEntityGroupInfo.init(self.allocator);
                scene_group.state = 1;
                scene_group.group_id = group_id;
                var prop_info = protocol.ScenePropInfo.init(self.allocator);
                prop_info.prop_id = propConf.propId;
                prop_info.prop_state = propConf.propState;
                try scene_group.entity_list.append(.{
                    .entity = .{ .prop = prop_info },
                    .group_id = group_id,
                    .inst_id = propConf.instId,
                    .entity_id = generator.nextId(),
                    .motion = .{ .pos = toVector(propConf.pos), .rot = toVector(propConf.rot) },
                });
                try scene_info.entity_group_list.append(scene_group);
            }
        }
    }
    pub fn createScene(
        self: *ChallengeSceneManager,
        avatar_list: ArrayList(u32),
        plane_id: u32,
        floor_id: u32,
        entry_id: u32,
        world_id: u32,
        monster_id: u32,
        event_id: u32,
        group_id: u32,
        maze_group_id: u32,
    ) !protocol.SceneInfo {
        var scene_info = try self.createBaseScene(4, avatar_list, plane_id, floor_id, entry_id, world_id, maze_group_id);
        var generator = Uid.BaseUidGen().init();
        try self.addChallengeEntities(&scene_info, group_id, monster_id, event_id, &generator);
        return scene_info;
    }
    pub fn createPeakScene(
        self: *ChallengeSceneManager,
        avatar_list: ArrayList(u32),
        plane_id: u32,
        floor_id: u32,
        entry_id: u32,
        monster_id: u32,
        event_id: u32,
        group_id: u32,
        maze_group_id: u32,
    ) !protocol.SceneInfo {
        var scene_info = try self.createBaseScene(4, avatar_list, plane_id, floor_id, entry_id, null, maze_group_id);
        var generator = Uid.BaseUidGen().init();
        try self.addChallengeEntities(&scene_info, group_id, monster_id, event_id, &generator);
        return scene_info;
    }
};
pub const MazeMapManager = struct {
    allocator: Allocator,
    pub fn init(allocator: Allocator) MazeMapManager {
        return .{ .allocator = allocator };
    }
    pub fn setMazeMapData(
        self: *MazeMapManager,
        map_info: *protocol.SceneMapInfo,
        floor_id: u32,
    ) !void {
        var plane_ids_map = std.AutoHashMap(u32, void).init(self.allocator);
        defer plane_ids_map.deinit();
        for (map_entrance_config.map_entrance_config.items) |entrConf| {
            if (entrConf.floor_id == floor_id) {
                try plane_ids_map.put(entrConf.plane_id, {});
            }
        }
        map_info.maze_group_list = ArrayList(protocol.MazeGroup).init(self.allocator);
        map_info.maze_prop_list = ArrayList(protocol.MazePropState).init(self.allocator);
        for (res_config.scene_config.items) |sceneConf| {
            if (!plane_ids_map.contains(sceneConf.planeID)) continue;
            for (sceneConf.props.items) |propConf| {
                try map_info.maze_group_list.append(protocol.MazeGroup{
                    .DDNOEGPCACF = ArrayList(u32).init(self.allocator),
                    .group_id = propConf.groupId,
                });
                try map_info.maze_prop_list.append(protocol.MazePropState{
                    .group_id = propConf.groupId,
                    .config_id = propConf.instId,
                    .state = propConf.propState,
                });
            }
        }
    }
};
