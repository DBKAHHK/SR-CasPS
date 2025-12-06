const std = @import("std");
const json = std.json;

const GameConfig = @import("game_config.zig").GameConfig;
const Avatar = @import("game_config.zig").Avatar;
const Lightcone = @import("game_config.zig").Lightcone;
const Relic = @import("game_config.zig").Relic;
const BattleConfig = @import("game_config.zig").BattleConfig;
const Allocator = std.mem.Allocator;

/// 从 freesr-data.json 生成完整 GameConfig
pub fn loadFromFreesr(allocator: Allocator) !GameConfig {
    const cwd = std.fs.cwd();

    const file = cwd.openFile("freesr-data.json", .{}) catch |err| switch (err) {
        error.FileNotFound => return error.FileNotFound,
        else => return err,
    };
    defer file.close();

    const data = try file.readToEndAlloc(allocator, 16 * 1024 * 1024);
    defer allocator.free(data);

    var parsed = try json.parseFromSlice(json.Value, allocator, data, .{});
    defer parsed.deinit();
    const root = parsed.value;

    // 初始化 GameConfig
    var game_cfg = GameConfig{
        .battle_config = .{
            .battle_id = 0,
            .stage_id = 0,
            .cycle_count = 0,
            .monster_wave = std.ArrayList(std.ArrayList(u32)).init(allocator),
            .monster_level = 1,
            .blessings = std.ArrayList(u32).init(allocator),
        },
        .avatar_config = std.ArrayList(Avatar).init(allocator),
    };

    // ============ 1. 建立 avatar_id → index 映射 ============
    var avatar_map = std.AutoHashMap(u32, usize).init(allocator);

    if (root.object.get("avatars")) |avs| {
        var it = avs.object.iterator();
        while (it.next()) |entry| {
            const av = entry.value_ptr.*;

            const avatar_id: u32 = @intCast(av.object.get("avatar_id").?.integer);
            const level: u32 = @intCast(av.object.get("level").?.integer);
            const promotion: u32 = @intCast(av.object.get("promotion").?.integer);

            var rank: u32 = 0;
            if (av.object.get("data")) |dv| {
                if (dv.object.get("rank")) |rv| rank = @intCast(rv.integer);
            }

            const idx = game_cfg.avatar_config.items.len;

            try game_cfg.avatar_config.append(.{
                .id = avatar_id,
                .hp = 100,
                .sp = 50,
                .level = level,
                .promotion = promotion,
                .rank = rank,
                .lightcone = .{ .id = 0, .rank = 1, .level = 1, .promotion = 0 },
                .relics = std.ArrayList(Relic).init(allocator),
                .use_technique = false,
            });

            try avatar_map.put(avatar_id, idx);
        }
    }

    // ============ 2. 解析 lightcones ============
    if (root.object.get("lightcones")) |lcs| {
        for (lcs.array.items) |lc| {
            const avatar_id: u32 = @intCast(lc.object.get("equip_avatar").?.integer);
            const item_id: u32 = @intCast(lc.object.get("item_id").?.integer);
            const level: u32 = @intCast(lc.object.get("level").?.integer);
            const promotion: u32 = @intCast(lc.object.get("promotion").?.integer);
            const rank: u32 = @intCast(lc.object.get("rank").?.integer);

            if (!avatar_map.contains(avatar_id)) continue;
            const idx = avatar_map.get(avatar_id).?;

            game_cfg.avatar_config.items[idx].lightcone = .{
                .id = item_id,
                .rank = rank,
                .level = level,
                .promotion = promotion,
            };
        }
    }

    // ============ 3. 解析 relics ============
    if (root.object.get("relics")) |rels| {
        for (rels.array.items) |r| {
            const avatar_id: u32 = @intCast(r.object.get("equip_avatar").?.integer);
            if (!avatar_map.contains(avatar_id)) continue;
            const idx = avatar_map.get(avatar_id).?;

            const relic_id: u32 = @intCast(r.object.get("relic_id").?.integer);
            const level: u32 = @intCast(r.object.get("level").?.integer);
            const main_affix: u32 = @intCast(r.object.get("main_affix_id").?.integer);

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
            });
        }
    }

    // ============ 4. 解析 battle_config ============
    if (root.object.get("battle_config")) |bc| {
        if (bc.object.get("stage_id")) |sid|
            game_cfg.battle_config.stage_id = @intCast(sid.integer);

        if (bc.object.get("cycle_count")) |cc|
            game_cfg.battle_config.cycle_count = @intCast(cc.integer);

        if (bc.object.get("blessings")) |bless|
            for (bless.array.items) |b|
                try game_cfg.battle_config.blessings.append(@intCast(b.object.get("id").?.integer));

        // monsters: [[ { monster_id, amount, level } ]]
        if (bc.object.get("monsters")) |waves| {
            for (waves.array.items) |wave| {
                var w = std.ArrayList(u32).init(allocator);

                for (wave.array.items) |m| {
                    const mid: u32 = @intCast(m.object.get("monster_id").?.integer);
                    const amt: u32 = @intCast(m.object.get("amount").?.integer);
                    const lvl: u32 = @intCast(m.object.get("level").?.integer);

                    if (lvl > game_cfg.battle_config.monster_level)
                        game_cfg.battle_config.monster_level = lvl;

                    var i: u32 = 0;
                    while (i < amt) : (i += 1)
                        try w.append(mid);
                }

                try game_cfg.battle_config.monster_wave.append(w);
            }
        }
    }

    return game_cfg;
}
