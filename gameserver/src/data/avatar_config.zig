const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const AvatarSkillTree = struct {
    point_id: u32,
    avatar_id: u32,
    level: u32,
    max_level: u32,
};

pub const AvatarSkillTreeConfig = struct {
    avatar_skill_tree_config: ArrayList(AvatarSkillTree),
    pub fn deinit(self: *AvatarSkillTreeConfig) void {
        self.avatar_skill_tree_config.deinit();
    }
};
pub const Element = enum(u8) {
    Physical,
    Fire,
    Ice,
    Thunder,
    Wind,
    Quantum,
    Imaginary,
    None,
};

pub const Avatar = struct {
    avatar_id: u32,
    adventure_player_id: u32,
    damage_type: Element,
    rarity: u32,
};

pub const AvatarConfig = struct {
    avatar_config: std.ArrayList(Avatar),

    pub fn deinit(self: *AvatarConfig) void {
        self.avatar_config.deinit();
    }
};

pub fn parseAvatarConfig(root: std.json.Value, allocator: std.mem.Allocator) !AvatarConfig {
    var avatar_config = std.ArrayList(Avatar).init(allocator);
    const avatars = root.object.get("avatar_config").?.array.items;

    for (avatars) |avatar_json| {
        const avatar = Avatar{
            .avatar_id = @intCast(avatar_json.object.get("AvatarID").?.integer),
            .adventure_player_id = @intCast(avatar_json.object.get("AdventurePlayerID").?.integer),
            .damage_type = parseElement(avatar_json.object.get("DamageType").?.string),
            .rarity = parseRarity(avatar_json.object.get("Rarity").?.string),
        };

        try avatar_config.append(avatar);
    }

    return AvatarConfig{ .avatar_config = avatar_config };
}

pub fn parseAvatarSkillTreeConfig(root: std.json.Value, allocator: Allocator) anyerror!AvatarSkillTreeConfig {
    var avatar_skill_tree = ArrayList(AvatarSkillTree).init(allocator);
    for (root.object.get("avatar_skill_tree").?.array.items) |skill_json| {
        const skill = AvatarSkillTree{
            .point_id = @intCast(skill_json.object.get("PointID").?.integer),
            .avatar_id = @intCast(skill_json.object.get("AvatarID").?.integer),
            .level = @intCast(skill_json.object.get("Level").?.integer),
            .max_level = @intCast(skill_json.object.get("MaxLevel").?.integer),
        };
        try avatar_skill_tree.append(skill);
    }

    return AvatarSkillTreeConfig{
        .avatar_skill_tree_config = avatar_skill_tree,
    };
}
pub fn parseElement(str: []const u8) Element {
    if (std.mem.eql(u8, str, "Physical")) return .Physical;
    if (std.mem.eql(u8, str, "Fire")) return .Fire;
    if (std.mem.eql(u8, str, "Ice")) return .Ice;
    if (std.mem.eql(u8, str, "Thunder")) return .Thunder;
    if (std.mem.eql(u8, str, "Wind")) return .Wind;
    if (std.mem.eql(u8, str, "Quantum")) return .Quantum;
    if (std.mem.eql(u8, str, "Imaginary")) return .Imaginary;
    return .None;
}

fn parseRarity(str: []const u8) u32 {
    return if (std.mem.eql(u8, str, "CombatPowerAvatarRarityType4")) 4 else 5;
}
