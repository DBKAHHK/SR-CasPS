const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const PlayerStateMod = @import("../player_state.zig");
const ItemService = @import("item.zig");
const CmdID = protocol.CmdID;

const Allocator = std.mem.Allocator;

/// 简单经验表：先硬编码，后面可以用 JSON 替换
fn avatarExpValue(tid: u32) u32 {
    return switch (tid) {
        2001 => 1000, // 例子：小经验书
        2002 => 5000, // 中经验书
        2003 => 10000, // 大经验书
        else => 0,
    };
}

/// 从 PlayerState 中找到某个角色（按 avatar_id）
fn findAvatarMut(state: *PlayerStateMod.PlayerState, avatar_id: u32) ?*PlayerStateMod.AvatarState {
    for (state.avatars.items) |*av| {
        if (av.id == avatar_id) return av;
    }
    return null;
}

/// 角色升级请求处理
pub fn onAvatarExpUp(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.AvatarExpUpCsReq, allocator);
    defer req.deinit();

    var rsp = protocol.AvatarExpUpScRsp.init(allocator);
    rsp.return_item_list = std.ArrayList(protocol.PileItem).init(allocator);

    if (session.player_state) |*state| {
        const avatar_id: u32 = req.avatar_id; // 字段名按你 proto 实际改

        const avatar = findAvatarMut(state, avatar_id) orelse {
            // 找不到角色
            rsp.retcode = 1;
            try session.send(CmdID.CmdAvatarExpUpScRsp, rsp);
            return;
        };

        // 1) 校验 & 扣除材料（经验书等）
        var total_exp: u32 = 0;
        for (req.cost_item_list.items) |p| { // 字段名按 proto 改
            const tid: u32 = p.item_id;
            const cnt: u32 = p.item_num;

            // 背包扣除
            const ok = state.inventory.removeMaterial(tid, cnt);
            if (!ok) {
                // 材料不足，回滚就先不做了，直接失败
                rsp.retcode = 2;
                try session.send(CmdID.CmdAvatarExpUpScRsp, rsp);
                return;
            }

            const per = avatarExpValue(tid);
            total_exp += per * cnt;
        }

        // 2) 将扣掉的材料写进 return_item_list（如果协议需要“展示消耗内容”）
        // 这里你也可以不填，直接让客户端走本地逻辑
        for (req.cost_item_list.items) |p| {
            try rsp.return_item_list.append(p);
        }

        // 3) 应用经验到角色上
        // 这里先假设有字段 level / exp，最大级 80
        const max_level: u32 = 80;

        avatar.exp += total_exp;
        while (avatar.level < max_level) {
            const need = levelUpExpRequirement(avatar.level);
            if (avatar.exp < need) break;
            avatar.exp -= need;
            avatar.level += 1;
        }
        if (avatar.level >= max_level) {
            avatar.level = max_level;
            avatar.exp = 0;
        }

        try PlayerStateMod.save(state);

        // 角色等级变更后，推荐用你现有的同步逻辑（比如 SyncLineupNotify 或 AvatarSync）
        // TODO: 调用你项目现有的 avatar sync 逻辑

        rsp.retcode = 0;
    } else {
        rsp.retcode = 1;
    }

    try session.send(CmdID.CmdAvatarExpUpScRsp, rsp);
}

/// 简单的升级经验需求表：后面可替换成 Dimbreath 的 LevelConfig
fn levelUpExpRequirement(level: u32) u32 {
    return switch (level) {
        1...20 => 1000,
        21...40 => 2000,
        41...60 => 4000,
        61...80 => 8000,
        else => 999_999_999, // 超出范围时不给再升
    };
}
