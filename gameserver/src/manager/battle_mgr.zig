const std = @import("std");
const protocol = @import("protocol");
const Config = @import("../data/game_config.zig");
const Data = @import("../data.zig");
const Lineup = @import("../services/lineup.zig");
const ConfigManager = @import("config_mgr.zig");
const Logic = @import("../utils/logic.zig");
const AvatarConfig = @import("../data/avatar_config.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

const skill_config = &ConfigManager.global_game_config_cache.avatar_skill_config;
const config = &ConfigManager.global_game_config_cache.game_config;

// Will be filled from saved lineup or misc.json defaults; start empty to avoid config fallback.
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub var selectedAvatarID = std.ArrayList(u32).init(gpa.allocator());
pub var funmodeAvatarID = std.ArrayList(u32).init(gpa.allocator());

fn getAvatarElement(avatar_id: u32) AvatarConfig.Element {
    const avatars = &ConfigManager.global_game_config_cache.avatar_config;
    for (avatars.avatar_config.items) |avatar| {
        if (avatar.avatar_id == avatar_id) {
            return avatar.damage_type;
        }
    }
    return .None;
}

fn getAttackerBuffId() u32 {
    const list = if (!Logic.FunMode().FunMode()) selectedAvatarID.items else funmodeAvatarID.items;
    if (list.len == 0) return 0;
    const slot = if (Lineup.leader_slot < list.len) Lineup.leader_slot else 0;
    const avatar_id = list[slot];
    const element = getAvatarElement(avatar_id);
    return switch (element) {
        .Physical => 1000111,
        .Fire => 1000112,
        .Ice => 1000113,
        .Thunder => 1000114,
        .Wind => 1000115,
        .Quantum => 1000116,
        .Imaginary => 1000117,
        .None => 0,
    };
}

fn createBattleRelic(allocator: Allocator, id: u32, level: u32, main_affix_id: u32, stat1: u32, cnt1: u32, step1: u32, stat2: u32, cnt2: u32, step2: u32, stat3: u32, cnt3: u32, step3: u32, stat4: u32, cnt4: u32, step4: u32) !protocol.BattleRelic {
    var relic = protocol.BattleRelic{ .id = id, .main_affix_id = main_affix_id, .level = level, .sub_affix_list = ArrayList(protocol.RelicAffix).init(allocator) };
    if (stat1 != 0) try relic.sub_affix_list.append(protocol.RelicAffix{ .affix_id = stat1, .cnt = cnt1, .step = step1 });
    if (stat2 != 0) try relic.sub_affix_list.append(protocol.RelicAffix{ .affix_id = stat2, .cnt = cnt2, .step = step2 });
    if (stat3 != 0) try relic.sub_affix_list.append(protocol.RelicAffix{ .affix_id = stat3, .cnt = cnt3, .step = step3 });
    if (stat4 != 0) try relic.sub_affix_list.append(protocol.RelicAffix{ .affix_id = stat4, .cnt = cnt4, .step = step4 });
    return relic;
}

fn applyCustomStats(avatar: *protocol.BattleAvatar, custom_stats: []const Config.CustomStat) void {
    if (avatar.sp_bar == null) {
        avatar.sp_bar = .{ .cur_sp = 0, .max_sp = 10000 };
    }
    const sp = &avatar.sp_bar.?;

    for (custom_stats) |cs| {
        if (cs.value <= 0) continue;
        if (std.mem.eql(u8, cs.key, "hp")) {
            avatar.hp = @intCast(cs.value * 100);
        } else if (std.mem.eql(u8, cs.key, "sp")) {
            sp.cur_sp = @intCast(cs.value * 100);
        } else if (std.mem.eql(u8, cs.key, "sp_max")) {
            sp.max_sp = @intCast(cs.value * 100);
        }
    }
    if (sp.cur_sp > sp.max_sp) sp.cur_sp = sp.max_sp;
}

fn createBattleAvatar(allocator: Allocator, avatarConf: Config.Avatar, custom_stats: []const Config.CustomStat) !protocol.BattleAvatar {
    var avatar = protocol.BattleAvatar.init(allocator);
    avatar.id = avatarConf.id;
    avatar.hp = avatarConf.hp * 100;
    avatar.sp_bar = .{ .cur_sp = avatarConf.sp * 100, .max_sp = 10000 };
    avatar.level = avatarConf.level;
    avatar.rank = avatarConf.rank;
    avatar.promotion = avatarConf.promotion;
    avatar.avatar_type = .AVATAR_FORMAL_TYPE;
    if (Logic.inlist(avatar.id, &Data.EnhanceAvatarID)) avatar.enhanced_id = 1;

    for (avatarConf.relics.items) |relic| {
        const r = try createBattleRelic(allocator, relic.id, relic.level, relic.main_affix_id, relic.stat1, relic.cnt1, relic.step1, relic.stat2, relic.cnt2, relic.step2, relic.stat3, relic.cnt3, relic.step3, relic.stat4, relic.cnt4, relic.step4);
        try avatar.relic_list.append(r);
    }

    const lc = protocol.BattleEquipment{
        .id = avatarConf.lightcone.id,
        .rank = avatarConf.lightcone.rank,
        .level = avatarConf.lightcone.level,
        .promotion = avatarConf.lightcone.promotion,
    };
    try avatar.equipment_list.append(lc);

    for (skill_config.avatar_skill_tree_config.items) |skill| {
        if (skill.avatar_id == avatar.id) {
            if (skill.level == skill.max_level) {
                try avatar.skilltree_list.append(.{
                    .point_id = skill.point_id,
                    .level = skill.max_level,
                });
            }
        }
    }
    applyCustomStats(&avatar, custom_stats);
    return avatar;
}

const BuffRule = struct {
    avatar_id: u32,
    buffs: []const struct {
        id: u32,
        owner_is_avatar: bool = true,
        dynamic_values: []const protocol.BattleBuff.DynamicValuesEntry = &.{},
    },
};

const technique_buffs = [_]BuffRule{
    .{
        .avatar_id = 1208,
        .buffs = &.{
            .{ .id = 120801, .dynamic_values = &.{
                .{ .key = .{ .Const = "SkillIndex" }, .value = 0 },
            } },
            .{ .id = 120802, .dynamic_values = &.{
                .{ .key = .{ .Const = "SkillIndex" }, .value = 0 },
            } },
        },
    },
    .{
        .avatar_id = 1224,
        .buffs = &.{
            .{ .id = 122402, .dynamic_values = &.{
                .{ .key = .{ .Const = "SkillIndex" }, .value = 0 },
            } },
            .{ .id = 122403, .dynamic_values = &.{
                .{ .key = .{ .Const = "SkillIndex" }, .value = 0 },
            } },
            .{ .id = 122401, .dynamic_values = &.{
                .{ .key = .{ .Const = "#ADF_1" }, .value = 3 },
                .{ .key = .{ .Const = "#ADF_2" }, .value = 3 },
            } },
        },
    },
    .{
        .avatar_id = 1304,
        .buffs = &.{.{ .id = 130403, .dynamic_values = &.{
            .{ .key = .{ .Const = "SkillIndex" }, .value = 3 },
        } }},
    },
    .{
        .avatar_id = 1306,
        .buffs = &.{
            .{ .id = 130601, .dynamic_values = &.{
                .{ .key = .{ .Const = "SkillIndex" }, .value = 0 },
            } },
            .{ .id = 130602, .dynamic_values = &.{
                .{ .key = .{ .Const = "SkillIndex" }, .value = 0 },
            } },
        },
    },
    .{
        .avatar_id = 1308,
        .buffs = &.{
            .{ .id = 130803, .dynamic_values = &.{
                .{ .key = .{ .Const = "SkillIndex" }, .value = 0 },
            } },
        },
    },
    .{
        .avatar_id = 1309,
        .buffs = &.{
            .{ .id = 130901, .dynamic_values = &.{
                .{ .key = .{ .Const = "SkillIndex" }, .value = 0 },
            } },
            .{ .id = 130902, .dynamic_values = &.{
                .{ .key = .{ .Const = "SkillIndex" }, .value = 0 },
            } },
        },
    },
    .{
        .avatar_id = 1310,
        .buffs = &.{
            .{ .id = 131001, .dynamic_values = &.{
                .{ .key = .{ .Const = "SkillIndex" }, .value = 0 },
            } },
            .{ .id = 131002, .dynamic_values = &.{
                .{ .key = .{ .Const = "SkillIndex" }, .value = 0 },
            } },
            .{ .id = 1000112, .dynamic_values = &.{
                .{ .key = .{ .Const = "SkillIndex" }, .value = 0 },
            } },
        },
    },
    .{
        .avatar_id = 1412,
        .buffs = &.{
            .{ .id = 141201, .dynamic_values = &.{
                .{ .key = .{ .Const = "SkillIndex" }, .value = 0 },
            } },
            .{
                .id = 1000121,
                .owner_is_avatar = false,
                .dynamic_values = &.{
                    .{ .key = .{ .Const = "SkillIndex" }, .value = 0 },
                },
            },
        },
    },
    .{
        .avatar_id = 1414,
        .buffs = &.{
            .{ .id = 141401, .dynamic_values = &.{
                .{ .key = .{ .Const = "SkillIndex" }, .value = 0 },
            } },
            .{
                .id = 1000121,
                .owner_is_avatar = false,
                .dynamic_values = &.{
                    .{ .key = .{ .Const = "SkillIndex" }, .value = 0 },
                },
            },
        },
    },
};

fn addTechniqueBuffs(allocator: Allocator, battle: *protocol.SceneBattleInfo, avatar: protocol.BattleAvatar, avatarConf: Config.Avatar, avatar_index: u32) !void {
    if (!avatarConf.use_technique) return;

    var targetIndexList = ArrayList(u32).init(allocator);
    errdefer targetIndexList.deinit();
    try targetIndexList.append(0);

    const buffedAvatarId = switch (avatar.id) {
        8004 => 8003,
        8006 => 8005,
        8008 => 8007,
        else => avatar.id,
    };

    if (Logic.inlist(buffedAvatarId, &Data.IgnoreToughness)) {
        var buff = protocol.BattleBuff{
            .id = 1000119,
            .level = 1,
            .owner_index = @intCast(avatar_index),
            .wave_flag = 0xFFFFFFFF,
            .target_index_list = try targetIndexList.clone(),
            .dynamic_values = ArrayList(protocol.BattleBuff.DynamicValuesEntry).init(allocator),
        };
        try buff.dynamic_values.append(.{ .key = .{ .Const = "SkillIndex" }, .value = 0 });
        try battle.buff_list.append(buff);
    }

    var found_custom_buff = false;
    for (technique_buffs) |rule| {
        if (rule.avatar_id == buffedAvatarId) {
            found_custom_buff = true;
            for (rule.buffs) |buff_def| {
                var buff = protocol.BattleBuff{
                    .id = buff_def.id,
                    .level = 1,
                    .owner_index = if (buff_def.owner_is_avatar) @intCast(avatar_index) else Lineup.leader_slot,
                    .wave_flag = 0xFFFFFFFF,
                    .target_index_list = try targetIndexList.clone(),
                    .dynamic_values = ArrayList(protocol.BattleBuff.DynamicValuesEntry).init(allocator),
                };
                try buff.dynamic_values.appendSlice(buff_def.dynamic_values);
                try battle.buff_list.append(buff);
            }
            break;
        }
    }
    if (!found_custom_buff) {
        var buff = protocol.BattleBuff{
            .id = buffedAvatarId * 100 + 1,
            .level = 1,
            .owner_index = @intCast(avatar_index),
            .wave_flag = 0xFFFFFFFF,
            .target_index_list = try targetIndexList.clone(),
            .dynamic_values = ArrayList(protocol.BattleBuff.DynamicValuesEntry).init(allocator),
        };
        try buff.dynamic_values.append(.{ .key = .{ .Const = "SkillIndex" }, .value = 0 });
        try battle.buff_list.append(buff);
    }
    targetIndexList.deinit();
}

fn addGolbalPassive(allocator: Allocator, battle: *protocol.SceneBattleInfo) !void {
    if (Logic.inlist(1407, Data.AllAvatars)) {
        var targetIndexList = ArrayList(u32).init(allocator);
        errdefer targetIndexList.deinit();
        try targetIndexList.append(0);
        var mazebuff_data = protocol.BattleBuff{
            .id = 140703,
            .level = 1,
            .owner_index = 1,
            .wave_flag = 0xFFFFFFFF,
            .target_index_list = try targetIndexList.clone(),
            .dynamic_values = ArrayList(protocol.BattleBuff.DynamicValuesEntry).init(allocator),
        };
        try mazebuff_data.dynamic_values.append(.{ .key = .{ .Const = "SkillIndex" }, .value = 0 });
        try battle.buff_list.append(mazebuff_data);
        targetIndexList.deinit();
    }
}

fn addTriggerAttack(allocator: Allocator, battle: *protocol.SceneBattleInfo) !void {
    var targetIndexList = ArrayList(u32).init(allocator);
    errdefer targetIndexList.deinit();
    try targetIndexList.append(0);
    var attack = protocol.BattleBuff{
        .id = getAttackerBuffId(),
        .level = 1,
        .owner_index = Lineup.leader_slot,
        .wave_flag = 0xFFFFFFFF,
        .target_index_list = try targetIndexList.clone(),
        .dynamic_values = ArrayList(protocol.BattleBuff.DynamicValuesEntry).init(allocator),
    };
    try attack.dynamic_values.append(.{ .key = .{ .Const = "SkillIndex" }, .value = 1 });
    try battle.buff_list.append(attack);
    targetIndexList.deinit();
}

fn createBattleInfo(allocator: Allocator, game_config: *const Config.GameConfig, stage_monster_wave_len: u32, stage_id: u32, rounds_limit: u32) protocol.SceneBattleInfo {
    var battle = protocol.SceneBattleInfo.init(allocator);
    battle.battle_id = game_config.battle_config.battle_id;
    battle.stage_id = stage_id;
    battle.logic_random_seed = @intCast(@mod(std.time.timestamp(), 0xFFFFFFFF));
    battle.rounds_limit = rounds_limit;
    battle.monster_wave_length = @intCast(stage_monster_wave_len);
    battle.world_level = 6;
    return battle;
}

fn addMonsterWaves(allocator: Allocator, battle: *protocol.SceneBattleInfo, monster_wave_configs: std.ArrayList(std.ArrayList(u32)), monster_level: u32) !void {
    for (monster_wave_configs.items) |wave| {
        var monster_wave = protocol.SceneMonsterWave.init(allocator);
        monster_wave.monster_param = protocol.SceneMonsterWaveParam{ .level = monster_level };
        for (wave.items) |mob_id| {
            try monster_wave.monster_list.append(.{ .monster_id = mob_id, .max_hp = Logic.FunMode().GetHp() });
        }
        try battle.monster_wave_list.append(monster_wave);
    }
}

fn addStageBlessings(allocator: Allocator, battle: *protocol.SceneBattleInfo, blessings: []const Config.Blessing) !void {
    for (blessings) |blessing| {
        var targetIndexList = ArrayList(u32).init(allocator);
        errdefer targetIndexList.deinit();
        try targetIndexList.append(0);
        var buff = protocol.BattleBuff{
            .id = blessing.id,
            .level = 1,
            .owner_index = 0xffffffff,
            .wave_flag = 0xffffffff,
            .target_index_list = try targetIndexList.clone(),
            .dynamic_values = ArrayList(protocol.BattleBuff.DynamicValuesEntry).init(allocator),
        };
        try buff.dynamic_values.append(.{ .key = .{ .Const = "SkillIndex" }, .value = 0 });
        try battle.buff_list.append(buff);
        targetIndexList.deinit();
    }
}

fn addBattleTargets(allocator: Allocator, battle: *protocol.SceneBattleInfo) !void {
    battle.battle_target_info = ArrayList(protocol.SceneBattleInfo.BattleTargetInfoEntry).init(allocator);

    var pfTargetHead = protocol.BattleTargetList{ .battle_target_list = ArrayList(protocol.BattleTarget).init(allocator) };
    if (Logic.Challenge().ChallengeMode()) {
        if (Logic.CustomMode().FirstNode()) {
            try pfTargetHead.battle_target_list.append(.{ .id = 10003, .progress = 0, .total_progress = 80000 });
        } else {
            try pfTargetHead.battle_target_list.append(.{ .id = 10003, .progress = 40000, .total_progress = 80000 });
        }
    } else {
        try pfTargetHead.battle_target_list.append(.{ .id = 10002, .progress = 0, .total_progress = 80000 });
    }

    var pfTargetTail = protocol.BattleTargetList{ .battle_target_list = ArrayList(protocol.BattleTarget).init(allocator) };
    try pfTargetTail.battle_target_list.append(.{ .id = 2001, .progress = 0, .total_progress = 0 });
    try pfTargetTail.battle_target_list.append(.{ .id = 2002, .progress = 0, .total_progress = 0 });

    var asTargetHead = protocol.BattleTargetList{ .battle_target_list = ArrayList(protocol.BattleTarget).init(allocator) };
    try asTargetHead.battle_target_list.append(.{ .id = 90005, .progress = 2000, .total_progress = 0 });

    switch (battle.stage_id) {
        30019000...30019100, 30021000...30021100, 30301000...30319000 => { // PF
            try battle.battle_target_info.append(.{ .key = 1, .value = pfTargetHead });
            for (2..4) |i| {
                try battle.battle_target_info.append(.{ .key = @intCast(i), .value = protocol.BattleTargetList{ .battle_target_list = ArrayList(protocol.BattleTarget).init(allocator) } });
            }
            try battle.battle_target_info.append(.{ .key = 5, .value = pfTargetTail });
        },
        420100...420900 => { // AS
            try battle.battle_target_info.append(.{ .key = 1, .value = asTargetHead });
        },
        else => {},
    }
}
fn commonBattleSetup(
    allocator: Allocator,
    battle: *protocol.SceneBattleInfo,
    selected_avatar_ids: []const u32,
    avatar_configs: []const Config.Avatar,
    monster_wave_configs: std.ArrayList(std.ArrayList(u32)),
    monster_level: u32,
    stage_blessings: []const Config.Blessing,
    custom_stats: []const Config.CustomStat,
) !void {
    var avatarIndex: u32 = 0;
    for (selected_avatar_ids) |selected_id| {
        for (avatar_configs) |avatarConf| {
            if (avatarConf.id == selected_id) {
                const avatar = try createBattleAvatar(allocator, avatarConf, custom_stats);
                try addTechniqueBuffs(allocator, battle, avatar, avatarConf, avatarIndex);
                try battle.battle_avatar_list.append(avatar);
                avatarIndex += 1;
            }
        }
    }

    try addMonsterWaves(allocator, battle, monster_wave_configs, monster_level);
    try addTriggerAttack(allocator, battle);
    try addStageBlessings(allocator, battle, stage_blessings);
    try addGolbalPassive(allocator, battle);
    try addBattleTargets(allocator, battle);
}
pub const BattleManager = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) BattleManager {
        return BattleManager{ .allocator = allocator };
    }

    pub fn createBattle(self: *BattleManager) !protocol.SceneBattleInfo {
        try ConfigManager.UpdateGameConfig();
        var battle = createBattleInfo(
            self.allocator,
            config,
            @intCast(config.battle_config.monster_wave.items.len),
            config.battle_config.stage_id,
            config.battle_config.cycle_count,
        );

        try commonBattleSetup(
            self.allocator,
            &battle,
            if (!Logic.FunMode().FunMode()) selectedAvatarID.items else funmodeAvatarID.items,
            config.avatar_config.items,
            config.battle_config.monster_wave,
            config.battle_config.monster_level,
            config.battle_config.blessings.items,
            config.battle_config.custom_stats.items,
        );

        return battle;
    }
};

pub const ChallegeStageManager = struct {
    allocator: Allocator,
    game_config_cache: *ConfigManager.GameConfigCache,

    pub fn init(allocator: Allocator, cache: *ConfigManager.GameConfigCache) ChallegeStageManager {
        return ChallegeStageManager{
            .allocator = allocator,
            .game_config_cache = cache,
        };
    }

    pub fn createChallegeStage(self: *ChallegeStageManager) !protocol.SceneBattleInfo {
        if (!Logic.Challenge().FoundStage()) {
            std.log.info("Challenge stage ID is 0, skipping challenge battle creation and returning an empty battle info.", .{});
            return protocol.SceneBattleInfo.init(self.allocator);
        }

        try ConfigManager.UpdateGameConfig();
        const stage_config = &self.game_config_cache.stage_config;
        var battle: protocol.SceneBattleInfo = undefined;
        var found_stage = false;

        for (stage_config.stage_config.items) |stageConf| {
            if (stageConf.stage_id == Logic.Challenge().GetChallengeStageID()) {
                battle = createBattleInfo(
                    self.allocator,
                    config,
                    @intCast(stageConf.monster_list.items.len),
                    stageConf.stage_id,
                    if (Logic.Challenge().GetChallengeMode() != 1) 30 else 4,
                );
                found_stage = true;
                var chal_blessings = ArrayList(Config.Blessing).init(self.allocator);
                defer chal_blessings.deinit();
                for (Logic.Challenge().GetChallengeBlessingID()) |id| {
                    try chal_blessings.append(.{ .id = id, .level = 1 });
                }

                try commonBattleSetup(
                    self.allocator,
                    &battle,
                    if (!Logic.FunMode().FunMode()) selectedAvatarID.items else funmodeAvatarID.items,
                    config.avatar_config.items,
                    stageConf.monster_list,
                    stageConf.level,
                    chal_blessings.items,
                    config.battle_config.custom_stats.items,
                );
                break;
            }
        }
        if (!found_stage) {
            std.log.err("Challenge stage with ID {d} not found in config.", .{Logic.Challenge().GetChallengeStageID()});
            return error.StageNotFound;
        }
        return battle;
    }
};

pub fn deinitSceneBattleInfo(battle: *protocol.SceneBattleInfo) void {
    for (battle.battle_avatar_list.items) |*avatar| {
        for (avatar.relic_list.items) |*relic| {
            relic.sub_affix_list.deinit();
        }
        avatar.relic_list.deinit();
        avatar.equipment_list.deinit();
        avatar.skilltree_list.deinit();
    }
    battle.battle_avatar_list.deinit();

    for (battle.buff_list.items) |*buff| {
        buff.target_index_list.deinit();
        buff.dynamic_values.deinit();
    }
    battle.buff_list.deinit();

    for (battle.monster_wave_list.items) |*wave| {
        wave.monster_list.deinit();
    }
    battle.monster_wave_list.deinit();

    for (battle.battle_target_info.items) |*entry| {
        if (entry.value) |*v| {
            v.battle_target_list.deinit();
        }
    }
    battle.battle_target_info.deinit();
}
