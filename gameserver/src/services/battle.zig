const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const Data = @import("../data.zig");
const BattleManager = @import("../manager/battle_mgr.zig");
const ConfigManager = @import("../manager/config_mgr.zig");
const Logic = @import("../utils/logic.zig");

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
