const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const Data = @import("../data.zig");
const GameConfig = @import("../data/game_config.zig");
const LineupManager = @import("../manager/lineup_mgr.zig");
const Sync = @import("../commands/sync.zig");
const AvatarManager = @import("../manager/avatar_mgr.zig");
const ConfigManager = @import("../manager/config_mgr.zig");
const PlayerStateMod = @import("../player_state.zig"); // 新增
const ItemDb = @import("../item_db.zig");
const BattleManager = @import("../manager/battle_mgr.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

const config = &ConfigManager.global_game_config_cache.game_config;

fn findAvatarConfig(avatar_id: u32) ?*const GameConfig.Avatar {
    for (config.avatar_config.items) |*avatar| {
        if (avatar.id == avatar_id) return avatar;
    }
    return null;
}

fn appendAvatarEquipmentAndRelics(
    allocator: Allocator,
    rsp: *protocol.GetBagScRsp,
    avatarConf: *const GameConfig.Avatar,
    seen: *std.AutoHashMap(u32, bool),
) !void {
    const avatar_id = avatarConf.id;
    if (seen.contains(avatar_id)) return;
    _ = try seen.put(avatar_id, true);
    const lc = try AvatarManager.createEquipment(avatarConf.lightcone, avatar_id);
    try rsp.equipment_list.append(lc);
    for (avatarConf.relics.items) |input| {
        const relic = try AvatarManager.createRelic(allocator, input, avatar_id);
        try rsp.relic_list.append(relic);
    }
}

fn appendAllAvatarEquipments(allocator: Allocator, rsp: *protocol.GetBagScRsp) !void {
    var seen = std.AutoHashMap(u32, bool).init(allocator);
    defer seen.deinit();

    for (config.avatar_config.items) |*avatarConf| {
        try appendAvatarEquipmentAndRelics(allocator, rsp, avatarConf, &seen);
    }

    var lineup_mgr = LineupManager.LineupManager.init(allocator);
    var lineup = try lineup_mgr.createLineup();
    defer LineupManager.deinitLineupInfo(&lineup);

    var ensure_list = ArrayList(u32).init(allocator);
    defer ensure_list.deinit();
    for (lineup.avatar_list.items) |avatar| {
        try ensure_list.append(avatar.id);
    }
    for (BattleManager.funmodeAvatarID.items) |avatar_id| {
        try ensure_list.append(avatar_id);
    }

    for (ensure_list.items) |avatar_id| {
        if (seen.contains(avatar_id)) continue;
        if (findAvatarConfig(avatar_id)) |avatarConf| {
            try appendAvatarEquipmentAndRelics(allocator, rsp, avatarConf, &seen);
        }
    }
}

pub fn syncBag(session: *Session, allocator: Allocator) !void {
    ConfigManager.UpdateGameConfig() catch |err| {
        std.log.err("Failed to reload freesr-data.json: {any}", .{err});
    };

    var rsp = protocol.GetBagScRsp.init(allocator);
    rsp.equipment_list = std.ArrayList(protocol.Equipment).init(allocator);
    rsp.relic_list = std.ArrayList(protocol.Relic).init(allocator);

    if (session.player_state) |*state| {
        for (state.inventory.materials.items) |mat| {
            try rsp.material_list.append(.{
                .tid = mat.tid,
                .num = mat.count, // GetBagScRsp 要求的字段名本来就是 num，保留即可
            });
        }
    } else {
        for (Data.ItemList) |tid| {
            try rsp.material_list.append(.{
                .tid = tid,
                .num = 100,
            });
        }
    }

    // 2) 装备 / 遗器：根据所有角色生成可展示的光锥与遗器
    try appendAllAvatarEquipments(allocator, &rsp);

    try session.send(CmdID.CmdGetBagScRsp, rsp);
}
pub fn onGetBag(session: *Session, _: *const Packet, allocator: Allocator) !void {
    try syncBag(session, allocator);
}

pub fn onUseItem(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.UseItemCsReq, allocator);
    defer req.deinit();

    var rsp = protocol.UseItemScRsp.init(allocator);
    rsp.use_item_id = req.use_item_id;
    rsp.use_item_count = req.use_item_count;
    rsp.retcode = 0;

    // 没有玩家状态就直接返回错误
    if (session.player_state) |*state| {
        const tid: u32 = @intCast(req.use_item_id);
        const count: u32 = @intCast(req.use_item_count);

        const ok = state.inventory.removeMaterial(tid, count);
        if (!ok) {
            rsp.retcode = 1; // 数量不足
        } else {
            // TODO: 如果你以后想让某些道具有特殊效果，可以在这里根据 tid 做处理
            try PlayerStateMod.save(state);
            try syncBag(session, allocator);
        }
    } else {
        rsp.retcode = 1;
    }

    // 你原来这里会顺便重新建一个默认编队并 Sync，一般道具使用其实不需要，
    // 但是为了不影响现有表现，先保留
    var sync = protocol.SyncLineupNotify.init(allocator);
    var lineup_mgr = LineupManager.LineupManager.init(allocator);
    const lineup = try lineup_mgr.createLineup();
    sync.lineup = lineup;
    try session.send(CmdID.CmdSyncLineupNotify, sync);

    try session.send(CmdID.CmdUseItemScRsp, rsp);
}

fn mergePileItems(allocator: Allocator, items: []const protocol.PileItem) !std.ArrayList(protocol.PileItem) {
    var merged = std.ArrayList(protocol.PileItem).init(allocator);
    if (items.len == 0) return merged;

    var map = std.AutoHashMap(u32, u32).init(allocator);
    defer map.deinit();

    for (items) |it| {
        const existing = map.get(it.item_id) orelse 0;
        map.put(it.item_id, existing + it.item_num) catch {};
    }

    var it = map.iterator();
    while (it.next()) |entry| {
        try merged.append(.{
            .item_id = entry.key_ptr.*,
            .item_num = entry.value_ptr.*,
        });
    }
    return merged;
}

/// data-only grant + save（聚合同 id 的奖励，近似 LunarCore 的“先合并再发放”思路）
pub fn grantItems(session: *Session, allocator: Allocator, items: []const protocol.PileItem) !void {
    if (session.player_state) |*state| {
        var merged = try mergePileItems(allocator, items);
        defer merged.deinit();

        for (merged.items) |it| {
            const tid: u32 = it.item_id;
            const count: u32 = it.item_num;

            // 用 item_db 的类型信息简单分流；未知则走回退
            if (ItemDb.findById(tid)) |cfg| {
                switch (cfg.item_type) {
                    .Currency => switch (tid) {
                        2 => state.scoin += count, // Credit
                        1 => state.mcoin += count, // Stellar Jade
                        else => try state.inventory.addMaterial(tid, count),
                    },
                    else => try state.inventory.addMaterial(tid, count),
                }
            } else {
                switch (tid) {
                    2 => state.scoin += count,
                    1 => state.mcoin += count,
                    else => try state.inventory.addMaterial(tid, count),
                }
            }
        }
        try PlayerStateMod.save(state);
        const notify = protocol.PlayerSyncScNotify.init(allocator);
        try session.send(CmdID.CmdPlayerSyncScNotify, notify);
    }

    // 这里只负责“数据层”的加东西 + 存档
    try syncBag(session, allocator);
}

fn resolvePropIdByEntityId(entity_id: u32) ?u32 {
    const res_cfg = &ConfigManager.global_game_config_cache.res_config;
    for (res_cfg.scene_config.items) |scene| {
        for (scene.props.items) |prop| {
            if (prop.instId == entity_id) return prop.propId;
        }
    }
    return null;
}

pub fn grantFixedChestReward(session: *Session, allocator: Allocator, prop_entity_id: u32) !void {
    _ = session.player_state orelse return;

    // Lightweight drop logic borrowed from LunarCore: small HC + exp + a credit roll, scaled a bit per prop_id.
    const prop_id = resolvePropIdByEntityId(prop_entity_id);
    const tier: u32 = if (prop_id) |pid| blk: {
        if (pid >= 6000) break :blk 3;
        if (pid >= 3000) break :blk 2;
        break :blk 1;
    } else 1;

    var prng = std.Random.DefaultPrng.init(@intCast(std.time.nanoTimestamp()));
    const rand = prng.random();

    const jade_amt: u32 = 5 * tier;
    const exp_amt: u32 = 5 * tier;
    const credit_amt: u32 = (20 * tier) + rand.intRangeAtMost(u32, 0, 80 * tier);

    var rewards = std.ArrayList(protocol.PileItem).init(allocator);
    defer rewards.deinit();

    if (ItemDb.findById(1)) |s| {
        try rewards.append(.{ .item_id = s.id, .item_num = jade_amt });
    }
    if (ItemDb.findById(21)) |exp_item| {
        try rewards.append(.{ .item_id = exp_item.id, .item_num = exp_amt });
    }
    if (ItemDb.findById(2)) |c| {
        try rewards.append(.{ .item_id = c.id, .item_num = credit_amt });
    }

    if (rewards.items.len > 0) {
        try grantItems(session, allocator, rewards.items);
        try sendRewardToast(session, allocator, rewards.items);
    }
}

pub fn grantBreakableReward(session: *Session, allocator: Allocator) !void {
    _ = session;
    _ = allocator;
    // TODO: 可击破物奖励逻辑，同上
}

pub fn sendOpenChestNotify(session: *Session, allocator: Allocator, chest_id: u32) !void {
    var notify = protocol.OpenChestScNotify.init(allocator);
    notify.chest_id = chest_id;
    try session.send(CmdID.CmdOpenChestScNotify, notify);
}
pub fn sendRewardToast(
    session: *Session,
    allocator: Allocator,
    items: []const protocol.PileItem,
) !void {
    var rsp = protocol.SellItemScRsp.init(allocator);
    rsp.retcode = 0;

    var item_array = std.ArrayList(protocol.Item).init(allocator);

    for (items) |p| {
        try item_array.append(.{
            .item_id = p.item_id,
            .num = p.item_num,
        });
    }

    const list = protocol.ItemList{
        .item_list = item_array,
    };
    rsp.return_item_list = list;

    try session.send(CmdID.CmdSellItemScRsp, rsp);
}
