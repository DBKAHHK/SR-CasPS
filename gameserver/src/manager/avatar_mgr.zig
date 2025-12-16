const std = @import("std");
const protocol = @import("protocol");
const Config = @import("../data/game_config.zig");
const Session = @import("../Session.zig");
const Data = @import("../data.zig");
const Logic = @import("../utils/logic.zig");
const MiscDefaults = @import("../data/misc_defaults.zig");
const ConfigManager = @import("../manager/config_mgr.zig");
const Uid = @import("../utils/uid.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

const config = &ConfigManager.global_game_config_cache.game_config;
const skill_config = &ConfigManager.global_game_config_cache.avatar_skill_config;

pub var m7th: u32 = 1224;
pub var mc_id: u32 = 0;

fn stableItemUid(tag: []const u8, avatar_id: u32, tid: u32, slot: u32) u32 {
    var h = std.hash.Wyhash.init(0);
    h.update(tag);
    h.update(std.mem.asBytes(&avatar_id));
    h.update(std.mem.asBytes(&tid));
    h.update(std.mem.asBytes(&slot));
    const v: u64 = h.final();
    // keep it non-zero and inside u32
    const u: u32 = @intCast(@as(u64, 1) + (v % @as(u64, 0xFFFF_FFFE)));
    return u;
}

fn mapMcId(gender: MiscDefaults.Gender, path: MiscDefaults.Path) u32 {
    const base: u32 = switch (path) {
        .warrior => 0,
        .knight => 1,
        .shaman => 2,
        .memory => 3,
    };
    const offset: u32 = if (gender == .male) 0 else 1;
    return 8001 + base * 2 + offset;
}

fn ensureMcFromMisc() void {
    mc_id = mapMcId(ConfigManager.global_misc_defaults.mc_gender, ConfigManager.global_misc_defaults.mc_path);
}

pub fn getMcId() u32 {
    if (mc_id < 8001 or mc_id > 8008) {
        ensureMcFromMisc();
    }
    return mc_id;
}

pub fn setMc(gender: MiscDefaults.Gender, path: MiscDefaults.Path) void {
    mc_id = mapMcId(gender, path);
    ConfigManager.global_misc_defaults.mc_gender = gender;
    ConfigManager.global_misc_defaults.mc_path = path;
}

fn mcIdFromMultiPath(t: protocol.MultiPathAvatarType) ?u32 {
    return switch (t) {
        .BoyWarriorType => 8001,
        .GirlWarriorType => 8002,
        .BoyKnightType => 8003,
        .GirlKnightType => 8004,
        .BoyShamanType => 8005,
        .GirlShamanType => 8006,
        .BoyMemoryType => 8007,
        .GirlMemoryType => 8008,
        else => null,
    };
}

pub fn setMcFromMultiPath(t: protocol.MultiPathAvatarType) void {
    if (mcIdFromMultiPath(t)) |id| {
        const gender: MiscDefaults.Gender = if ((id % 2) == 1) .male else .female;
        const path_index = (id - 8001) / 2;
        const path: MiscDefaults.Path = switch (path_index) {
            0 => .warrior,
            1 => .knight,
            2 => .shaman,
            else => .memory,
        };
        setMc(gender, path);
    }
}

pub fn createAvatar(
    allocator: Allocator,
    avatarConf: Config.Avatar,
) !protocol.Avatar {
    var avatar = protocol.Avatar.init(allocator);
    avatar.base_avatar_id = switch (avatarConf.id) {
        8001...8008 => 8001,
        1224 => 1001,
        else => avatarConf.id,
    };
    avatar.level = avatarConf.level;
    avatar.promotion = avatarConf.promotion;
    avatar.rank = avatarConf.rank;
    avatar.dressed_skin_id = getSkinId(avatar.base_avatar_id);
    if (Logic.inlist(avatar.base_avatar_id, &Data.EnhanceAvatarID)) {
        avatar.unk_enhanced_id = 1;
    }
    avatar.has_taken_promotion_reward_list = ArrayList(u32).init(allocator);
    for (1..6) |i| {
        try avatar.has_taken_promotion_reward_list.append(@intCast(i));
    }
    // 角色穿戴的光锥/遗器需要和 GetBag 返回的 unique_id 对得上；
    // 当 freesr-data 缺失 internal_uid 时，使用稳定派生的 uid，避免因生成顺序/重置导致不一致。
    avatar.equipment_unique_id = if (avatarConf.lightcone.id == 0)
        0
    else if (avatarConf.lightcone.internal_uid != 0)
        avatarConf.lightcone.internal_uid
    else
        stableItemUid("LC", avatarConf.id, avatarConf.lightcone.id, 0);

    avatar.equip_relic_list = ArrayList(protocol.EquipRelic).init(allocator);
    const max_slots: usize = 6;
    const count: usize = @min(max_slots, avatarConf.relics.items.len);
    for (0..count) |i| {
        const relic_conf = avatarConf.relics.items[i];
        const relic_uid = if (relic_conf.id == 0)
            0
        else if (relic_conf.internal_uid != 0)
            relic_conf.internal_uid
        else
            stableItemUid("RELIC", avatarConf.id, relic_conf.id, @intCast(i));
        try avatar.equip_relic_list.append(.{
            .relic_unique_id = relic_uid,
            .type = @intCast(i),
        });
    }
    for (count..max_slots) |i| {
        try avatar.equip_relic_list.append(.{
            .relic_unique_id = 0,
            .type = @intCast(i),
        });
    }
    try createSkillTree(avatar.base_avatar_id, &avatar.skilltree_list, avatarConf.skill_levels.items);
    return avatar;
}
pub fn createAllAvatar(
    allocator: Allocator,
    Avatar_id: u32,
) !protocol.Avatar {
    var avatar = protocol.Avatar.init(allocator);
    avatar.base_avatar_id = Avatar_id;
    avatar.level = 80;
    avatar.promotion = 6;
    avatar.rank = 6;
    avatar.dressed_skin_id = getSkinId(avatar.base_avatar_id);
    if (Logic.inlist(avatar.base_avatar_id, &Data.EnhanceAvatarID)) {
        avatar.unk_enhanced_id = 1;
    }
    avatar.has_taken_promotion_reward_list = ArrayList(u32).init(allocator);
    for (1..6) |i| {
        try avatar.has_taken_promotion_reward_list.append(@intCast(i));
    }
    try createSkillTree(avatar.base_avatar_id, &avatar.skilltree_list, &[_]Config.SkillLevel{});
    return avatar;
}

fn createSkillTree(
    base_avatar_id: u32,
    skilltree_list: *std.ArrayList(protocol.AvatarSkillTree),
    overrides: []const Config.SkillLevel,
) !void {
    for (skill_config.avatar_skill_tree_config.items) |skill| {
        if (skill.avatar_id == base_avatar_id) {
            var level: ?u32 = null;
            for (overrides) |ov| {
                if (ov.point_id == skill.point_id) {
                    level = ov.level;
                    break;
                }
            }
            if (level == null and skill.level == skill.max_level) {
                level = skill.max_level;
            }
            if (level) |lv| {
                try skilltree_list.append(.{
                    .point_id = skill.point_id,
                    .level = lv,
                });
            }
        }
    }
}

pub fn createEquipment(
    lightconeConf: Config.Lightcone,
    dress_avatar_id: u32,
) !protocol.Equipment {
    return protocol.Equipment{
        .unique_id = if (lightconeConf.internal_uid != 0)
            lightconeConf.internal_uid
        else
            stableItemUid("LC", dress_avatar_id, lightconeConf.id, 0),
        .tid = lightconeConf.id,
        .is_protected = true,
        .level = lightconeConf.level,
        .rank = lightconeConf.rank,
        .promotion = lightconeConf.promotion,
        .dress_avatar_id = dress_avatar_id,
    };
}

pub fn createRelic(
    allocator: Allocator,
    relicConf: Config.Relic,
    dress_avatar_id: u32,
    slot: u32,
) !protocol.Relic {
    var r = protocol.Relic{
        .tid = relicConf.id,
        .main_affix_id = relicConf.main_affix_id,
        .unique_id = if (relicConf.internal_uid != 0)
            relicConf.internal_uid
        else
            stableItemUid("RELIC", dress_avatar_id, relicConf.id, slot),
        .exp = 0,
        .dress_avatar_id = dress_avatar_id,
        .is_protected = true,
        .level = relicConf.level,
        .sub_affix_list = ArrayList(protocol.RelicAffix).init(allocator),
        .reforge_sub_affix_list = ArrayList(protocol.RelicAffix).init(allocator),
    };
    try r.sub_affix_list.append(protocol.RelicAffix{ .affix_id = relicConf.stat1, .cnt = relicConf.cnt1, .step = relicConf.step1 });
    try r.sub_affix_list.append(protocol.RelicAffix{ .affix_id = relicConf.stat2, .cnt = relicConf.cnt2, .step = relicConf.step2 });
    try r.sub_affix_list.append(protocol.RelicAffix{ .affix_id = relicConf.stat3, .cnt = relicConf.cnt3, .step = relicConf.step3 });
    try r.sub_affix_list.append(protocol.RelicAffix{ .affix_id = relicConf.stat4, .cnt = relicConf.cnt4, .step = relicConf.step4 });
    return r;
}

pub fn createAllMultiPath(
    allocator: std.mem.Allocator,
    game_config: *const Config.GameConfig,
) !ArrayList(protocol.MultiPathAvatarInfo) {
    var multis = ArrayList(protocol.MultiPathAvatarInfo).init(allocator);
    const avatar_types = [_]protocol.MultiPathAvatarType{
        .GirlWarriorType,
        .GirlKnightType,
        .GirlShamanType,
        .GirlMemoryType,
        .BoyWarriorType,
        .BoyKnightType,
        .BoyShamanType,
        .BoyMemoryType,
        .Mar_7thKnightType,
        .Mar_7thRogueType,
    };
    const TYPE_COUNT = avatar_types.len;
    var groups: [TYPE_COUNT]ArrayList(u32) = undefined;
    for (0..TYPE_COUNT) |i| groups[i] = ArrayList(u32).init(allocator);

    var counts: [TYPE_COUNT]u32 = [_]u32{0} ** TYPE_COUNT;
    var indexes: [TYPE_COUNT]u32 = [_]u32{0} ** TYPE_COUNT;
    var ranks: [TYPE_COUNT]u32 = [_]u32{0} ** TYPE_COUNT;

    const total = @as(u32, @intCast(game_config.avatar_config.items.len));

    for (game_config.avatar_config.items) |avatar| {
        for (0..TYPE_COUNT) |i| counts[i] += 1;

        const typ = getAvatarType(avatar.id);
        var found_index: usize = TYPE_COUNT;
        for (0..TYPE_COUNT) |i| {
            if (avatar_types[i] == typ) {
                found_index = i;
                break;
            }
        }

        if (found_index != TYPE_COUNT) {
            try groups[found_index].append(avatar.id);
            ranks[found_index] = avatar.rank;
            indexes[found_index] = total + 1 - counts[found_index];
        }
    }
    for (0..TYPE_COUNT) |i| {
        var multi = protocol.MultiPathAvatarInfo.init(allocator);
        multi.avatar_id = avatar_types[i];

        // 将 MultiPath 的装备/遗器 unique_id 与 GetBag/AvatarData 对齐：
        // 1) 优先使用 freesr-data 的 internal_uid
        // 2) 缺失时使用稳定派生 uid（不依赖全局 UID 生成顺序）
        const t = avatar_types[i];
        const inferred_avatar_id: u32 = if (mcIdFromMultiPath(t)) |id|
            id
        else switch (t) {
            .Mar_7thKnightType => 1001,
            .Mar_7thRogueType => 1224,
            else => @intCast(@intFromEnum(t)),
        };

        // rank/skin
        multi.rank = ranks[i];
        const base_id: u32 = switch (inferred_avatar_id) {
            8001...8008 => 8001,
            1224 => 1001,
            else => inferred_avatar_id,
        };
        multi.dressed_skin_id = getSkinId(base_id);

        // find avatar config for equipment/relics
        var avatar_conf: ?Config.Avatar = null;
        for (game_config.avatar_config.items) |av| {
            if (av.id == inferred_avatar_id) {
                avatar_conf = av;
                break;
            }
        }

        if (avatar_conf) |av| {
            multi.rank = av.rank;
            multi.path_equipment_id = if (av.lightcone.id == 0)
                0
            else if (av.lightcone.internal_uid != 0)
                av.lightcone.internal_uid
            else
                stableItemUid("LC", av.id, av.lightcone.id, 0);

            multi.equip_relic_list = ArrayList(protocol.EquipRelic).init(allocator);
            const max_slots: usize = 6;
            const count: usize = @min(max_slots, av.relics.items.len);
            for (0..count) |slot| {
                const rc = av.relics.items[slot];
                const relic_uid: u32 = if (rc.id == 0)
                    0
                else if (rc.internal_uid != 0)
                    rc.internal_uid
                else
                    stableItemUid("RELIC", av.id, rc.id, @intCast(slot));
                try multi.equip_relic_list.append(.{ .relic_unique_id = relic_uid, .type = @intCast(slot) });
            }
            for (count..max_slots) |slot| {
                try multi.equip_relic_list.append(.{ .relic_unique_id = 0, .type = @intCast(slot) });
            }
        } else {
            multi.path_equipment_id = 0;
            multi.equip_relic_list = ArrayList(protocol.EquipRelic).init(allocator);
            for (0..6) |slot| {
                try multi.equip_relic_list.append(.{ .relic_unique_id = 0, .type = @intCast(slot) });
            }
        }

        multi.multi_path_skill_tree = ArrayList(protocol.AvatarSkillTree).init(allocator);
        for (groups[i].items) |avatar_id| {
            var skill_list = ArrayList(protocol.AvatarSkillTree).init(allocator);
            try createSkillTree(avatar_id, &skill_list, findSkillLevels(avatar_id));
            try multi.multi_path_skill_tree.appendSlice(skill_list.items);
            skill_list.deinit();
        }
        try multis.append(multi);
    }
    for (0..TYPE_COUNT) |i| groups[i].deinit();

    return multis;
}
fn findSkillLevels(avatar_id: u32) []const Config.SkillLevel {
    for (config.avatar_config.items) |avatar| {
        if (avatar.id == avatar_id) return avatar.skill_levels.items;
    }
    return &[_]Config.SkillLevel{};
}
fn getAvatarType(id: u32) protocol.MultiPathAvatarType {
    return switch (id) {
        1001 => .Mar_7thKnightType,
        1224 => .Mar_7thRogueType,
        else => {
            if (id < 8001 or id > 8008) return .MultiPathAvatarTypeNone; // fallback
            const base = (id - 8001) / 2;
            const is_boy = (id % 2) == 1;

            return switch (base) {
                0 => if (is_boy) .BoyWarriorType else .GirlWarriorType,
                1 => if (is_boy) .BoyKnightType else .GirlKnightType,
                2 => if (is_boy) .BoyShamanType else .GirlShamanType,
                3 => if (is_boy) .BoyMemoryType else .GirlMemoryType,
                else => .GirlMemoryType,
            };
        },
    };
}
pub fn getSkinId(avatar_id: u32) u32 {
    for (Data.AvatarSkinMap) |entry| {
        if (entry.avatar_id == avatar_id) return entry.skin_id;
    }
    return 0;
}
pub fn updateSkinId(avatar_id: u32, new_skin_id: u32) void {
    for (&Data.AvatarSkinMap) |*entry| {
        if (entry.avatar_id == avatar_id) {
            entry.skin_id = new_skin_id;
            return;
        }
    }
}
pub fn syncAvatarData(session: *Session, allocator: Allocator) !void {
    var sync = protocol.PlayerSyncScNotify.init(allocator);
    defer sync.deinit();
    Uid.resetGlobalUidGens();
    var char = protocol.AvatarSync.init(allocator);
    for (Data.AllAvatars) |id| {
        const avatar = try createAllAvatar(allocator, id);
        try char.avatar_list.append(avatar);
    }
    for (config.avatar_config.items) |avatarConf| {
        const avatar = try createAvatar(allocator, avatarConf);
        try char.avatar_list.append(avatar);
    }
    const multis = try createAllMultiPath(allocator, config);
    defer multis.deinit();
    sync.avatar_sync = char;
    try sync.multi_path_avatar_info_list.appendSlice(multis.items);
    try session.send(CmdID.CmdPlayerSyncScNotify, sync);
}
