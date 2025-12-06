const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const Data = @import("../data.zig");
const LineupManager = @import("../manager/lineup_mgr.zig");
const Sync = @import("../commands/sync.zig");
const AvatarManager = @import("../manager/avatar_mgr.zig");
const ConfigManager = @import("../manager/config_mgr.zig");
const PlayerStateMod = @import("../player_state.zig"); // 新增
const ItemDb = @import("../item_db.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

const config = &ConfigManager.global_game_config_cache.game_config;

pub fn syncBag(session: *Session, allocator: Allocator) !void {
    var rsp = protocol.GetBagScRsp.init(allocator);
    rsp.equipment_list = std.ArrayList(protocol.Equipment).init(allocator);
    rsp.relic_list = std.ArrayList(protocol.Relic).init(allocator);

    const game_config = session.game_config_cache;
    _ = game_config; // 避免 unused local constant 报错

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

    // 2) 装备 / 遗器：沿用你原来的做法（根据 avatar_config 自动生成一套）
    for (config.avatar_config.items) |avatarConf| {
        const lc = try AvatarManager.createEquipment(avatarConf.lightcone, avatarConf.id);
        try rsp.equipment_list.append(lc);
        for (avatarConf.relics.items) |input| {
            const r = try AvatarManager.createRelic(allocator, input, avatarConf.id);
            try rsp.relic_list.append(r);
        }
    }

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

pub fn grantItems(session: *Session, allocator: Allocator, items: []const protocol.PileItem) !void {
    if (session.player_state) |*state| {
        for (items) |it| {
            const tid: u32 = it.item_id;
            const count: u32 = it.item_num;

            // 你自己确认：1 / 2 和 mcoin / scoin 对应关系
            switch (tid) {
                2 => { // Credit
                    state.scoin += count;
                },
                1 => { // Stellar Jade
                    state.mcoin += count;
                },
                else => {
                    try state.inventory.addMaterial(tid, count);
                },
            }
        }
        try PlayerStateMod.save(state);
        const notify = protocol.PlayerSyncScNotify.init(allocator);
        // 填必要字段，比如货币、材料列表
        try session.send(CmdID.CmdPlayerSyncScNotify, notify);
    }

    // 这里只负责“数据层”的加东西 + 存档
    try syncBag(session, allocator);
}

pub fn grantFixedChestReward(session: *Session, allocator: Allocator) !void {
    if (session.player_state != null) {
        // 按要求：读取 item_db 并固定发放 星琼 50、信用点 50000
        const star_cfg = ItemDb.findById(1);
        const credit_cfg = ItemDb.findById(2);

        // 准备奖励列表（允许任一缺失时仍尽量发放存在的）
        var rewards = std.ArrayList(protocol.PileItem).init(allocator);
        defer rewards.deinit();

        if (star_cfg) |s| {
            try rewards.append(protocol.PileItem{ .item_id = s.id, .item_num = 50 });
        }
        if (credit_cfg) |c| {
            try rewards.append(protocol.PileItem{ .item_id = c.id, .item_num = 50000 });
        }

        if (rewards.items.len > 0) {
            try grantItems(session, allocator, rewards.items);
            // 也发个奖励吐司给客户端，方便玩家在 UI 看到
            try sendRewardToast(session, allocator, rewards.items);
        }
    } else {
        // 没有玩家存档则什么也不做
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
    // 用 SellItemScRsp 来承载 return_item_list
    var rsp = protocol.SellItemScRsp.init(allocator);
    rsp.retcode = 0;

    // ItemList 里面装的是 Item（item_id + num），不是 PileItem
    var item_array = std.ArrayList(protocol.Item).init(allocator);

    // 把每个 PileItem 转成 Item 再塞进去
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
