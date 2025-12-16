const std = @import("std");
const json = std.json;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;

pub const BattleConfig = struct {
    battle_id: u32,
    stage_id: u32,
    cycle_count: u32,
    monster_wave: ArrayList(ArrayList(u32)),
    monster_wave_detail: ArrayList(ArrayList(MonsterDef)),
    monster_level: u32,
    blessings: ArrayList(Blessing),
    battle_type: ArrayList(u8),
    path_resonance_id: u32,
    custom_stats: ArrayList(CustomStat),
};

pub const Blessing = struct { id: u32, level: u32 };

pub const CustomStat = struct {
    key: []u8,
    value: i64,
};

fn clampU32FromJson(value: std.json.Value, default_value: u32) u32 {
    switch (value) {
        .integer => |iv| {
            if (iv < 0) return default_value;
            const max_u32: i64 = std.math.maxInt(u32);
            if (iv > max_u32) return std.math.maxInt(u32);
            return @intCast(iv);
        },
        .float => |fv| {
            if (fv <= 0) return default_value;
            if (fv >= @as(f64, @floatFromInt(std.math.maxInt(u32)))) return std.math.maxInt(u32);
            return @intFromFloat(fv);
        },
        .string => |s| {
            const parsed = std.fmt.parseInt(u64, s, 10) catch return default_value;
            if (parsed > std.math.maxInt(u32)) return std.math.maxInt(u32);
            return @intCast(parsed);
        },
        else => return default_value,
    }
}

pub const SkillLevel = struct {
    point_id: u32,
    level: u32,
};

pub const MonsterDef = struct {
    id: u32,
    level: u32,
    amount: u32,
    max_hp: u32 = 0,
};

pub const Lightcone = struct {
    id: u32,
    rank: u32,
    level: u32,
    promotion: u32,
    internal_uid: u32,
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
    internal_uid: u32,
};

pub const Avatar = struct {
    id: u32,
    hp: u32,
    sp: u32,
    sp_max: u32,
    level: u32,
    promotion: u32,
    rank: u32,
    internal_uid: u32,
    lightcone: Lightcone,
    relics: ArrayList(Relic),
    techniques: ArrayList(u32),
    use_technique: bool,
    skill_levels: ArrayList(SkillLevel),
};

const StatCount = struct {
    stat: u32,
    count: u32,
    step: u32,
};

pub const GameConfig = struct {
    battle_config: BattleConfig,
    avatar_config: ArrayList(Avatar),
    loadout: ArrayList(u32),

    pub fn deinit(self: *GameConfig) void {
        for (self.battle_config.monster_wave.items) |*wave| {
            wave.deinit();
        }
        self.battle_config.monster_wave.deinit();
        for (self.battle_config.monster_wave_detail.items) |*wave| {
            wave.deinit();
        }
        self.battle_config.monster_wave_detail.deinit();
        self.battle_config.blessings.deinit();
        const alloc = self.battle_config.custom_stats.allocator;
        for (self.battle_config.custom_stats.items) |*cs| {
            if (cs.key.len > 0) alloc.free(cs.key);
        }
        self.battle_config.custom_stats.deinit();
        self.battle_config.battle_type.deinit();

        for (self.avatar_config.items) |*avatar| {
            avatar.relics.deinit();
            avatar.techniques.deinit();
            avatar.skill_levels.deinit();
        }
        self.avatar_config.deinit();
        self.loadout.deinit();
    }
};

pub fn parseConfig(root: json.Value, allocator: Allocator) anyerror!GameConfig {
    var game_cfg = GameConfig{
        .battle_config = .{
            .battle_id = 0,
            .stage_id = 0,
            .cycle_count = 0,
            .monster_wave = ArrayList(ArrayList(u32)).init(allocator),
            .monster_wave_detail = ArrayList(ArrayList(MonsterDef)).init(allocator),
            .monster_level = 1,
            .blessings = ArrayList(Blessing).init(allocator),
            .battle_type = ArrayList(u8).init(allocator),
            .path_resonance_id = 0,
            .custom_stats = ArrayList(CustomStat).init(allocator),
        },
        .avatar_config = ArrayList(Avatar).init(allocator),
        .loadout = ArrayList(u32).init(allocator),
    };
    errdefer game_cfg.deinit();

    var avatar_map = AutoHashMap(u32, usize).init(allocator);
    defer avatar_map.deinit();

    if (root.object.get("avatars")) |avs| {
        var it = avs.object.iterator();
        while (it.next()) |entry| {
            const av = entry.value_ptr.*;

            const avatar_id: u32 = @intCast(av.object.get("avatar_id").?.integer);
            const level: u32 = @intCast(av.object.get("level").?.integer);
            const promotion: u32 = @intCast(av.object.get("promotion").?.integer);
            const hp_val: u32 = @intCast((av.object.get("max_hp") orelse json.Value{ .integer = 10000 }).integer);
            const sp_max_val: u32 = @intCast((av.object.get("sp_max") orelse json.Value{ .integer = 100 }).integer);
            const sp_cur_val: u32 = @intCast((av.object.get("sp_value") orelse json.Value{ .integer = sp_max_val }).integer);

            var rank: u32 = 0;
            if (av.object.get("data")) |dv| {
                if (dv.object.get("rank")) |rv| rank = @intCast(rv.integer);
            }

            const idx = game_cfg.avatar_config.items.len;
            try game_cfg.avatar_config.append(.{
                .id = avatar_id,
                .hp = hp_val,
                .sp = sp_cur_val,
                .sp_max = sp_max_val,
                .level = level,
                .promotion = promotion,
                .rank = rank,
                .lightcone = .{ .id = 0, .rank = 1, .level = 1, .promotion = 0, .internal_uid = 0 },
                .relics = ArrayList(Relic).init(allocator),
                .techniques = ArrayList(u32).init(allocator),
                .use_technique = av.object.get("techniques") != null,
                .internal_uid = @intCast((av.object.get("internal_uid") orelse json.Value{ .integer = 0 }).integer),
                .skill_levels = ArrayList(SkillLevel).init(allocator),
            });

            if (av.object.get("techniques")) |techs| {
                for (techs.array.items) |t| {
                    try game_cfg.avatar_config.items[idx].techniques.append(@intCast(t.integer));
                }
                if (techs.array.items.len > 0) game_cfg.avatar_config.items[idx].use_technique = true;
            }

            if (av.object.get("data")) |dv| {
                if (dv.object.get("skills")) |skills| {
                    var it_sk = skills.object.iterator();
                    while (it_sk.next()) |s_entry| {
                        const key = s_entry.key_ptr.*;
                        const val = s_entry.value_ptr.*;
                        const point_id = std.fmt.parseInt(u32, key, 10) catch continue;
                        const lvl_val: u32 = switch (val) {
                            .integer => |iv| @intCast(iv),
                            .float => |fv| @intFromFloat(fv),
                            else => 0,
                        };
                        if (lvl_val > 0) {
                            try game_cfg.avatar_config.items[idx].skill_levels.append(.{
                                .point_id = point_id,
                                .level = lvl_val,
                            });
                        }
                    }
                }
            }

            try avatar_map.put(avatar_id, idx);
        }
    }

    if (root.object.get("lightcones")) |lcs| {
        for (lcs.array.items) |lc| {
            const avatar_id: u32 = @intCast(lc.object.get("equip_avatar").?.integer);
            if (!avatar_map.contains(avatar_id)) continue;
            const idx = avatar_map.get(avatar_id).?;

            game_cfg.avatar_config.items[idx].lightcone = .{
                .id = @intCast(lc.object.get("item_id").?.integer),
                .rank = @intCast(lc.object.get("rank").?.integer),
                .level = @intCast(lc.object.get("level").?.integer),
                .promotion = @intCast(lc.object.get("promotion").?.integer),
                .internal_uid = @intCast((lc.object.get("internal_uid") orelse json.Value{ .integer = 0 }).integer),
            };
        }
    }

    if (root.object.get("relics")) |rels| {
        for (rels.array.items) |r| {
            const avatar_id: u32 = @intCast(r.object.get("equip_avatar").?.integer);
            if (!avatar_map.contains(avatar_id)) continue;
            const idx = avatar_map.get(avatar_id).?;

            const relic_id: u32 = @intCast(r.object.get("relic_id").?.integer);
            const level: u32 = @intCast(r.object.get("level").?.integer);
            const main_affix: u32 = @intCast(r.object.get("main_affix_id").?.integer);
            const internal_uid: u32 = @intCast((r.object.get("internal_uid") orelse json.Value{ .integer = 0 }).integer);

            const subs_val = r.object.get("sub_affixes");

            var sub_count: u32 = 0;
            var s1: u32 = 0;
            var c1: u32 = 0;
            var t1: u32 = 0;
            var s2: u32 = 0;
            var c2: u32 = 0;
            var t2: u32 = 0;
            var s3: u32 = 0;
            var c3: u32 = 0;
            var t3: u32 = 0;
            var s4: u32 = 0;
            var c4: u32 = 0;
            var t4: u32 = 0;

            if (subs_val) |subs| {
                sub_count = @intCast(subs.array.items.len);

                for (subs.array.items, 0..) |sv, i| {
                    const sid: u32 = @intCast(sv.object.get("sub_affix_id").?.integer);
                    const cnt: u32 = @intCast(sv.object.get("count").?.integer);
                    const step: u32 = @intCast(sv.object.get("step").?.integer);

                    switch (i) {
                        0 => {
                            s1 = sid;
                            c1 = cnt;
                            t1 = step;
                        },
                        1 => {
                            s2 = sid;
                            c2 = cnt;
                            t2 = step;
                        },
                        2 => {
                            s3 = sid;
                            c3 = cnt;
                            t3 = step;
                        },
                        3 => {
                            s4 = sid;
                            c4 = cnt;
                            t4 = step;
                        },
                        else => {},
                    }
                }
            }

            try game_cfg.avatar_config.items[idx].relics.append(.{
                .id = relic_id,
                .level = level,
                .main_affix_id = main_affix,
                .sub_count = sub_count,
                .stat1 = s1,
                .cnt1 = c1,
                .step1 = t1,
                .stat2 = s2,
                .cnt2 = c2,
                .step2 = t2,
                .stat3 = s3,
                .cnt3 = c3,
                .step3 = t3,
                .stat4 = s4,
                .cnt4 = c4,
                .step4 = t4,
                .internal_uid = internal_uid,
            });
        }
    }

    if (root.object.get("battle_config")) |bc| {
        if (bc.object.get("battle_id")) |v| game_cfg.battle_config.battle_id = @intCast(v.integer);
        if (bc.object.get("stage_id")) |v| game_cfg.battle_config.stage_id = @intCast(v.integer);
        if (bc.object.get("cycle_count")) |v| game_cfg.battle_config.cycle_count = @intCast(v.integer);
        if (bc.object.get("path_resonance_id")) |v| game_cfg.battle_config.path_resonance_id = @intCast(v.integer);
        if (bc.object.get("battle_type")) |v| {
            if (v.string.len > 0) {
                game_cfg.battle_config.battle_type.clearRetainingCapacity();
                try game_cfg.battle_config.battle_type.appendSlice(v.string);
            }
        }

        if (bc.object.get("blessings")) |bless| {
            for (bless.array.items) |b| {
                switch (b) {
                    .integer => |val| try game_cfg.battle_config.blessings.append(.{ .id = @intCast(val), .level = 1 }),
                    .object => |obj| {
                        if (obj.get("id")) |id_val| {
                            const lvl: u32 = if (obj.get("level")) |lv| @intCast(lv.integer) else 1;
                            try game_cfg.battle_config.blessings.append(.{
                                .id = @intCast(id_val.integer),
                                .level = lvl,
                            });
                        }
                    },
                    else => {},
                }
            }
        }

        if (bc.object.get("monsters")) |waves| {
            for (waves.array.items) |wave| {
                var w = ArrayList(u32).init(allocator);
                var w_detail = ArrayList(MonsterDef).init(allocator);

                const monsters = switch (wave) {
                    .array => wave.array.items,
                    .object => blk: {
                        var one = [_]json.Value{wave};
                        break :blk one[0..];
                    },
                    else => &[_]json.Value{},
                };

                for (monsters) |m| {
                    var mid: u32 = 0;
                    var amt: u32 = 1;
                    var lvl: u32 = 1;
                    var max_hp: u32 = 0;

                    switch (m) {
                        .object => |obj| {
                            if (obj.get("monster_id")) |v| mid = clampU32FromJson(v, 0) else if (obj.get("id")) |v| mid = clampU32FromJson(v, 0);
                            if (obj.get("amount")) |v| amt = clampU32FromJson(v, 1);
                            if (obj.get("level")) |v| lvl = clampU32FromJson(v, 1);
                            if (obj.get("max_hp")) |v| max_hp = clampU32FromJson(v, 0);
                        },
                        .integer => |v| {
                            mid = clampU32FromJson(json.Value{ .integer = v }, 0);
                        },
                        else => {},
                    }

                    if (mid == 0) continue;

                    if (lvl > game_cfg.battle_config.monster_level) game_cfg.battle_config.monster_level = lvl;
                    try w_detail.append(.{ .id = mid, .level = lvl, .amount = amt, .max_hp = max_hp });

                    var i: u32 = 0;
                    while (i < amt) : (i += 1) {
                        try w.append(mid);
                    }
                }

                try game_cfg.battle_config.monster_wave.append(w);
                try game_cfg.battle_config.monster_wave_detail.append(w_detail);
            }
        }

        if (bc.object.get("custom_stats")) |cs| {
            for (cs.array.items) |item| {
                if (item == .object) {
                    const obj = item.object;
                    if (obj.get("key")) |k| {
                        const v = obj.get("value") orelse json.Value{ .integer = 0 };
                        try game_cfg.battle_config.custom_stats.append(.{
                            .key = try allocator.dupe(u8, k.string),
                            .value = switch (v) {
                                .integer => |iv| @intCast(iv),
                                .float => |fv| @intFromFloat(fv),
                                else => 0,
                            },
                        });
                    }
                }
            }
        }
    }

    if (root.object.get("loadout")) |lo| {
        for (lo.array.items) |entry| {
            switch (entry) {
                .integer => |val| try game_cfg.loadout.append(@intCast(val)),
                .object => |obj| {
                    if (obj.get("avatar_id")) |v| {
                        try game_cfg.loadout.append(@intCast(v.integer));
                    } else if (obj.get("id")) |v| {
                        try game_cfg.loadout.append(@intCast(v.integer));
                    }
                },
                else => {},
            }
        }
    }

    return game_cfg;
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
