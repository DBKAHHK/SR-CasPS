const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const Data = @import("../data.zig");
const BattleManager = @import("../manager/battle_mgr.zig");
const ConfigManager = @import("../manager/config_mgr.zig");
const Logic = @import("../utils/logic.zig");
const SceneManager = @import("../manager/scene_mgr.zig");
const LineupManager = @import("../manager/lineup_mgr.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

const log = std.log.scoped(.scene_service);

pub var on_battle: bool = false;

pub fn onStartCocoonStage(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.StartCocoonStageCsReq, allocator);
    defer req.deinit();
    var battle_manager = BattleManager.BattleManager.init(allocator);
    var battle = try battle_manager.createBattle();
    _ = &battle;
    on_battle = true;
    try session.send(CmdID.CmdStartCocoonStageScRsp, protocol.StartCocoonStageScRsp{
        .retcode = 0,
        .cocoon_id = req.cocoon_id,
        .prop_entity_id = req.prop_entity_id,
        .wave = req.wave,
        .battle_info = battle,
    });
}
pub fn onQuickStartCocoonStage(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.QuickStartCocoonStageCsReq, allocator);
    defer req.deinit();
    var battle_manager = BattleManager.BattleManager.init(allocator);
    var battle = try battle_manager.createBattle();
    _ = &battle;
    on_battle = true;
    try session.send(CmdID.CmdQuickStartCocoonStageScRsp, protocol.QuickStartCocoonStageScRsp{
        .retcode = 0,
        .cocoon_id = req.cocoon_id,
        .wave = req.wave,
        .battle_info = battle,
    });
}
pub fn onQuickStartFarmElement(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.QuickStartFarmElementCsReq, allocator);
    defer req.deinit();
    var battle_manager = BattleManager.BattleManager.init(allocator);
    var battle = try battle_manager.createBattle();
    _ = &battle;
    on_battle = true;
    try session.send(CmdID.CmdQuickStartFarmElementScRsp, protocol.QuickStartFarmElementScRsp{
        .retcode = 0,
        .world_level = req.world_level,
        .LOFAFGIPDFP = req.LOFAFGIPDFP,
        .battle_info = battle,
    });
}
pub fn onStartBattleCollege(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.StartBattleCollegeCsReq, allocator);
    defer req.deinit();
    var battle_manager = BattleManager.BattleManager.init(allocator);
    var battle = try battle_manager.createBattle();
    _ = &battle;
    on_battle = true;
    try session.send(CmdID.CmdStartBattleCollegeScRsp, protocol.StartBattleCollegeScRsp{
        .retcode = 0,
        .id = req.id,
        .battle_info = battle,
    });
}
pub fn onSceneCastSkill(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    var battle_manager = BattleManager.BattleManager.init(allocator);
    var battle = try battle_manager.createBattle();
    defer BattleManager.deinitSceneBattleInfo(&battle);
    var challenge_manager = BattleManager.ChallegeStageManager.init(allocator, &ConfigManager.global_game_config_cache);
    var challenge = try challenge_manager.createChallegeStage();
    defer BattleManager.deinitSceneBattleInfo(&challenge);
    const req = try packet.getProto(protocol.SceneCastSkillCsReq, allocator);
    defer req.deinit();
    var battle_info: ?protocol.SceneBattleInfo = null;
    var monster_battle_info_list = ArrayList(protocol.HitMonsterBattleInfo).init(allocator);
    Highlight("SKILL INDEX: {}", .{req.skill_index});
    Highlight("ATTACKED BY ENTITY ID: {}", .{req.attacked_by_entity_id});

    // Technique animation: consume MP and notify client (best-effort; we don't persist MP yet).
    if (req.skill_index > 0) {
        try session.send(CmdID.CmdSceneCastSkillMpUpdateScNotify, protocol.SceneCastSkillMpUpdateScNotify{
            .cast_entity_id = req.cast_entity_id,
            .mp = 4,
        });
    }
    const is_challenge = Logic.Challenge().ChallengeMode();
    for (req.assist_monster_entity_id_list.items) |id| {
        const attacker_id = req.attacked_by_entity_id;
        const skill_index = req.skill_index;
        const bt = getBattleType(id, attacker_id, skill_index, is_challenge);
        if (is_challenge) {
            if ((attacker_id <= 1000) or (id < 1000)) {
                Highlight("CHALLENGE, MONSTER ENTITY ID: {} -> {}", .{ id, bt });
                try monster_battle_info_list.append(.{
                    .target_monster_entity_id = id,
                    .monster_battle_type = bt,
                });
                if (bt == protocol.MonsterBattleType.MONSTER_BATTLE_TYPE_TRIGGER_BATTLE) {
                    battle_info = challenge;
                }
            }
        } else {
            if ((attacker_id <= 1000 or attacker_id > 1000000) or (id < 1000 or id > 1000000)) {
                Highlight("BATTLE, MONSTER ENTITY ID: {} -> {}", .{ id, bt });
                try monster_battle_info_list.append(.{
                    .target_monster_entity_id = id,
                    .monster_battle_type = bt,
                });
                if (bt == protocol.MonsterBattleType.MONSTER_BATTLE_TYPE_TRIGGER_BATTLE) {
                    battle_info = battle;
                    on_battle = true;
                }
            }
        }
    }
    try session.send(CmdID.CmdSceneCastSkillScRsp, protocol.SceneCastSkillScRsp{
        .retcode = 0,
        .cast_entity_id = req.cast_entity_id,
        .monster_battle_info = monster_battle_info_list,
        .battle_info = battle_info,
    });
}

pub fn onGetCurBattleInfo(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var battle_manager = BattleManager.BattleManager.init(allocator);
    var battle = try battle_manager.createBattle();
    defer BattleManager.deinitSceneBattleInfo(&battle);
    var challenge_manager = BattleManager.ChallegeStageManager.init(allocator, &ConfigManager.global_game_config_cache);
    var challenge = try challenge_manager.createChallegeStage();
    defer BattleManager.deinitSceneBattleInfo(&challenge);

    var rsp = protocol.GetCurBattleInfoScRsp.init(allocator);
    rsp.battle_info = if (Logic.Challenge().ChallengeMode()) challenge else if (on_battle == true) battle else null;
    rsp.retcode = 0;
    try session.send(CmdID.CmdGetCurBattleInfoScRsp, rsp);
}

pub fn onPVEBattleResult(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.PVEBattleResultCsReq, allocator);
    defer req.deinit();
    var rsp = protocol.PVEBattleResultScRsp.init(allocator);
    rsp.battle_id = req.battle_id;
    rsp.end_status = req.end_status;
    rsp.stage_id = req.stage_id;
    on_battle = false;
    try session.send(CmdID.CmdPVEBattleResultScRsp, rsp);

    // 多关卡高难度副本（MOC/PF/AS）：胜利后自动切到下一关
    if (!Logic.Challenge().ChallengeMode()) return;

    // ChallengePeak: client expects ChallengePeakSettleScNotify after battle; sending normal ChallengeSettleNotify
    // will cause loading to hang.
    if (Logic.Challenge().ChallengePeakMode()) {
        var settle = protocol.ChallengePeakSettleScNotify.init(allocator);
        settle.peak_id = Logic.Challenge().GetChallengePeakID();
        settle.is_win = req.end_status == .BATTLE_END_WIN;
        settle.hard_mode_has_passed = settle.is_win and Logic.Challenge().ChallengePeakHard();

        try session.send(CmdID.CmdChallengePeakSettleScNotify, settle);
        Logic.Challenge().resetChallengeState();
        return;
    }

    if (req.end_status != .BATTLE_END_WIN) return;

    const challenge_id = Logic.Challenge().GetChallengeID();
    const ids = Logic.Challenge().GetSceneIDs();
    const cur_event_id = ids[5];

    const challenge_cfg = &ConfigManager.global_game_config_cache.challenge_maze_config;
    const entrance_cfg = &ConfigManager.global_game_config_cache.map_entrance_config;
    const maze_cfg = &ConfigManager.global_game_config_cache.maze_config;

    var next_event_id: ?u32 = null;
    var next_monster_id: ?u32 = null;
    var next_entry_id: ?u32 = null;
    var next_plane_id: ?u32 = null;
    var next_floor_id: ?u32 = null;
    var next_world_id: ?u32 = null;
    var next_group_id: ?u32 = null;
    var next_maze_group_id: ?u32 = null;

    var has_second_half_cfg: bool = false;

    for (challenge_cfg.challenge_config.items) |challengeConf| {
        if (challengeConf.id != challenge_id) continue;

        const use_first = !Logic.Challenge().InSecondHalf();
        has_second_half_cfg = challengeConf.event_id_list2.items.len != 0 and challengeConf.npc_monster_id_list2.items.len != 0 and challengeConf.maze_group_id2 != null;
        const event_list = if (use_first) challengeConf.event_id_list1.items else challengeConf.event_id_list2.items;
        const monster_list = if (use_first) challengeConf.npc_monster_id_list1.items else challengeConf.npc_monster_id_list2.items;

        if (event_list.len == 0 or monster_list.len == 0) break;

        var idx: ?usize = null;
        for (event_list, 0..) |eid, i| {
            if (eid == cur_event_id) {
                idx = i;
                break;
            }
        }
        if (idx == null) break;
        const i = idx.?;
        // No more stages in this half.
        if (i + 1 >= event_list.len or i + 1 >= monster_list.len) break;

        next_event_id = event_list[i + 1];
        next_monster_id = monster_list[i + 1];

        const entrance_id = if (use_first) challengeConf.map_entrance_id else challengeConf.map_entrance_id2;
        const maze_group_id_opt = if (use_first) challengeConf.maze_group_id1 else challengeConf.maze_group_id2 orelse challengeConf.maze_group_id1;
        next_group_id = maze_group_id_opt;
        next_maze_group_id = maze_group_id_opt;
        next_entry_id = entrance_id;

        for (entrance_cfg.map_entrance_config.items) |entrance| {
            if (entrance.id != entrance_id) continue;
            next_floor_id = entrance.floor_id;
            for (maze_cfg.maze_plane_config.items) |maze| {
                if (Logic.contains(&maze.floor_id_list, entrance.floor_id)) {
                    next_world_id = maze.world_id;
                    next_plane_id = maze.challenge_plane_id;
                    break;
                }
            }
            break;
        }
        break;
    }

    // No next stage in this half: either wait for EnterChallengeNextPhase (MOC/PF/AS 2nd half),
    // or finish the whole challenge and send settle notify.
    if (next_event_id == null or next_monster_id == null or next_entry_id == null or next_plane_id == null or next_floor_id == null or next_world_id == null or next_group_id == null or next_maze_group_id == null) {
        if (!Logic.Challenge().InSecondHalf() and has_second_half_cfg and Logic.Challenge().HasSecondLineup()) {
            // First half finished; send phase settle so client shows "next phase" and then
            // client will send EnterChallengeNextPhaseCsReq.
            var phase_settle = protocol.ChallengeBossPhaseSettleNotify.init(allocator);
            phase_settle.is_win = true;
            phase_settle.is_second_half = false;
            phase_settle.phase = 1;
            phase_settle.star = 7;
            phase_settle.challenge_id = challenge_id;
            try session.send(CmdID.CmdChallengeBossPhaseSettleNotify, phase_settle);
            return;
        }

        var settle = protocol.ChallengeSettleNotify.init(allocator);
        settle.is_win = true;
        settle.challenge_id = challenge_id;
        settle.star = 7;
        settle.challenge_score = 0;
        settle.score_two = 0;
        try session.send(CmdID.CmdChallengeSettleNotify, settle);
        return;
    }

    Logic.Challenge().SetChallengeInfo(
        next_floor_id.?,
        next_world_id.?,
        next_monster_id.?,
        next_event_id.?,
        next_group_id.?,
        next_maze_group_id.?,
        next_plane_id.?,
        next_entry_id.?,
    );

    var lineup_manager = LineupManager.ChallengeLineupManager.init(allocator);
    const lineup = try lineup_manager.createLineup(Logic.Challenge().GetAvatarIDs());
    var scene_challenge_manager = SceneManager.ChallengeSceneManager.init(allocator);
    const new_ids = Logic.Challenge().GetSceneIDs();
    const scene_info = try scene_challenge_manager.createScene(
        Logic.Challenge().GetAvatarIDs(),
        new_ids[0],
        new_ids[1],
        new_ids[2],
        new_ids[3],
        new_ids[4],
        new_ids[5],
        new_ids[6],
        new_ids[7],
    );
    try session.send(CmdID.CmdQuitBattleScNotify, protocol.QuitBattleScNotify{});
    try session.send(CmdID.CmdEnterSceneByServerScNotify, protocol.EnterSceneByServerScNotify{
        .reason = protocol.EnterSceneReason.ENTER_SCENE_REASON_NONE,
        .lineup = lineup,
        .scene = scene_info,
    });
}

pub fn onSceneCastSkillCostMp(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.SceneCastSkillCostMpCsReq, allocator);
    defer req.deinit();
    try session.send(CmdID.CmdSceneCastSkillCostMpScRsp, protocol.SceneCastSkillCostMpScRsp{
        .retcode = 0,
        .cast_entity_id = req.cast_entity_id,
    });
}

pub fn onSyncClientResVersion(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.SyncClientResVersionCsReq, allocator);
    defer req.deinit();
    std.debug.print("CLIENT RES VERSION: {}\n", .{req.client_res_version});
    try session.send(CmdID.CmdSyncClientResVersionScRsp, protocol.SyncClientResVersionScRsp{
        .retcode = 0,
        .client_res_version = req.client_res_version,
    });
}

fn Highlight(comptime msg: []const u8, args: anytype) void {
    std.debug.print("\x1b[33m", .{});
    std.debug.print(msg, args);
    std.debug.print("\x1b[0m\n", .{});
}
fn getBattleType(id: u32, attacker_id: u32, skill_index: u32, is_challenge: bool) protocol.MonsterBattleType {
    if (skill_index != 1) {
        return protocol.MonsterBattleType.MONSTER_BATTLE_TYPE_TRIGGER_BATTLE;
    }
    if (attacker_id >= 1 and attacker_id <= 1000) {
        return protocol.MonsterBattleType.MONSTER_BATTLE_TYPE_TRIGGER_BATTLE;
    }
    if (attacker_id >= 100000) {
        const attacker_offset = attacker_id - 100000;
        if (Logic.inlist(attacker_offset, &Data.IgnoreBattle)) {
            return protocol.MonsterBattleType.MONSTER_BATTLE_TYPE_NO_BATTLE;
        }
        if (Logic.inlist(attacker_offset, &Data.SkipBattle)) {
            if (is_challenge) {
                return protocol.MonsterBattleType.MONSTER_BATTLE_TYPE_TRIGGER_BATTLE;
            } else {
                if (id > 1000000) {
                    return protocol.MonsterBattleType.MONSTER_BATTLE_TYPE_TRIGGER_BATTLE;
                } else {
                    return protocol.MonsterBattleType.MONSTER_BATTLE_TYPE_DIRECT_DIE_SKIP_BATTLE;
                }
            }
        }
    }
    return protocol.MonsterBattleType.MONSTER_BATTLE_TYPE_TRIGGER_BATTLE;
}
