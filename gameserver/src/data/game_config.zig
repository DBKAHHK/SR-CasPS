const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const BattleConfig = struct {
    battle_id: u32,
    stage_id: u32,
    cycle_count: u32,
    monster_wave: ArrayList(ArrayList(u32)),
    monster_level: u32,
    blessings: ArrayList(u32),
};

pub const Lightcone = struct {
    id: u32,
    rank: u32,
    level: u32,
    promotion: u32,
};

pub const Relic = struct {
    id: u32,
    level: u32,
    main_affix_id: u32,
    sub_count: u32,
    stat1: u32,
    cnt1: u32,
    step1: u32,
    stat2: u32,
    cnt2: u32,
    step2: u32,
    stat3: u32,
    cnt3: u32,
    step3: u32,
    stat4: u32,
    cnt4: u32,
    step4: u32,
};

pub const Avatar = struct {
    id: u32,
    hp: u32,
    sp: u32,
    level: u32,
    promotion: u32,
    rank: u32,
    lightcone: Lightcone,
    relics: ArrayList(Relic),
    use_technique: bool,
};

const StatCount = struct {
    stat: u32,
    count: u32,
    step: u32,
};

pub const GameConfig = struct {
    battle_config: BattleConfig,
    avatar_config: ArrayList(Avatar),

    pub fn deinit(self: *GameConfig) void {
        for (self.battle_config.monster_wave.items) |*wave| {
            wave.deinit();
        }
        self.battle_config.monster_wave.deinit();
        self.battle_config.blessings.deinit();

        for (self.avatar_config.items) |*avatar| {
            avatar.relics.deinit();
        }
        self.avatar_config.deinit();
    }
};

pub fn parseConfig(root: std.json.Value, allocator: Allocator) anyerror!GameConfig {
    const battle_config_json = root.object.get("battle_config").?;
    var battle_config = BattleConfig{
        .battle_id = @intCast(battle_config_json.object.get("battle_id").?.integer),
        .stage_id = @intCast(battle_config_json.object.get("stage_id").?.integer),
        .cycle_count = @intCast(battle_config_json.object.get("cycle_count").?.integer),
        .monster_wave = ArrayList(ArrayList(u32)).init(allocator),
        .monster_level = @intCast(battle_config_json.object.get("monster_level").?.integer),
        .blessings = ArrayList(u32).init(allocator),
    };

    for (battle_config_json.object.get("monster_wave").?.array.items) |wave| {
        var wave_list = ArrayList(u32).init(allocator);
        for (wave.array.items) |monster| {
            try wave_list.append(@intCast(monster.integer));
        }
        try battle_config.monster_wave.append(wave_list);
    }
    for (battle_config_json.object.get("blessings").?.array.items) |blessing| {
        try battle_config.blessings.append(@intCast(blessing.integer));
    }

    var avatar_config = ArrayList(Avatar).init(allocator);
    for (root.object.get("avatar_config").?.array.items) |avatar_json| {
        var avatar = Avatar{
            .id = @intCast(avatar_json.object.get("id").?.integer),
            .hp = @intCast(avatar_json.object.get("hp").?.integer),
            .sp = @intCast(avatar_json.object.get("sp").?.integer),
            .level = @intCast(avatar_json.object.get("level").?.integer),
            .promotion = @intCast(avatar_json.object.get("promotion").?.integer),
            .rank = @intCast(avatar_json.object.get("rank").?.integer),
            .lightcone = undefined,
            .relics = ArrayList(Relic).init(allocator),
            .use_technique = avatar_json.object.get("use_technique").?.bool,
        };

        const lightcone_json = avatar_json.object.get("lightcone").?;
        avatar.lightcone = Lightcone{
            .id = @intCast(lightcone_json.object.get("id").?.integer),
            .rank = @intCast(lightcone_json.object.get("rank").?.integer),
            .level = @intCast(lightcone_json.object.get("level").?.integer),
            .promotion = @intCast(lightcone_json.object.get("promotion").?.integer),
        };

        for (avatar_json.object.get("relics").?.array.items) |relic_str| {
            const relic = try parseRelic(relic_str.string, allocator);
            try avatar.relics.append(relic);
        }

        try avatar_config.append(avatar);
    }

    return GameConfig{
        .battle_config = battle_config,
        .avatar_config = avatar_config,
    };
}

fn parseRelic(relic_str: []const u8, allocator: Allocator) !Relic {
    var tokens = ArrayList([]const u8).init(allocator);
    defer tokens.deinit();

    var iterator = std.mem.tokenizeScalar(u8, relic_str, ',');

    while (iterator.next()) |token| {
        try tokens.append(token);
    }

    const tokens_slice = tokens.items;

    if (tokens_slice.len < 5) {
        std.debug.print("relic parsing critical error (too few fields): {s}\n", .{relic_str});
        return error.InsufficientTokens;
    }

    const stat1 = try parseStatCount(tokens_slice[4]);
    const stat2 = if (tokens_slice.len > 5) try parseStatCount(tokens_slice[5]) else StatCount{ .stat = 0, .count = 0, .step = 0 };
    const stat3 = if (tokens_slice.len > 6) try parseStatCount(tokens_slice[6]) else StatCount{ .stat = 0, .count = 0, .step = 0 };
    const stat4 = if (tokens_slice.len > 7) try parseStatCount(tokens_slice[7]) else StatCount{ .stat = 0, .count = 0, .step = 0 };

    const relic = Relic{
        .id = try std.fmt.parseInt(u32, tokens_slice[0], 10),
        .level = try std.fmt.parseInt(u32, tokens_slice[1], 10),
        .main_affix_id = try std.fmt.parseInt(u32, tokens_slice[2], 10),
        .sub_count = try std.fmt.parseInt(u32, tokens_slice[3], 10),
        .stat1 = stat1.stat,
        .cnt1 = stat1.count,
        .step1 = stat1.step,
        .stat2 = stat2.stat,
        .cnt2 = stat2.count,
        .step2 = stat2.step,
        .stat3 = stat3.stat,
        .cnt3 = stat3.count,
        .step3 = stat3.step,
        .stat4 = stat4.stat,
        .cnt4 = stat4.count,
        .step4 = stat4.step,
    };

    return relic;
}

fn parseStatCount(token: []const u8) !StatCount {
    if (std.mem.indexOfScalar(u8, token, ':')) |first_colon| {
        if (std.mem.indexOfScalar(u8, token[first_colon + 1 ..], ':')) |second_colon_offset| {
            const second_colon = first_colon + 1 + second_colon_offset;
            const stat = try std.fmt.parseInt(u32, token[0..first_colon], 10);
            const count = try std.fmt.parseInt(u32, token[first_colon + 1 .. second_colon], 10);
            const step = try std.fmt.parseInt(u32, token[second_colon + 1 ..], 10);
            return StatCount{ .stat = stat, .count = count, .step = step };
        } else {
            return error.InvalidFormat;
        }
    } else {
        return error.InvalidFormat;
    }
}
