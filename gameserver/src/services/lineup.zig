const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const LineupManager = @import("../manager/lineup_mgr.zig");
const PlayerStateMod = @import("../player_state.zig");
const AvatarManager = @import("../manager/avatar_mgr.zig");

const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

pub var leader_slot: u32 = 0;
const MaxLineups = PlayerStateMod.MaxLineups;
const LineupSlots = PlayerStateMod.LineupSlots;

const default_lineup_names = [_][]const u8{
    "Team 1",
    "Team 2",
    "Team 3",
    "Team 4",
    "Team 5",
    "Team 6",
};

fn buildPresetLineup(allocator: Allocator, preset: PlayerStateMod.LineupPreset, index: u32) !protocol.LineupInfo {
    var ids = std.ArrayList(u32).init(allocator);
    defer ids.deinit();
    for (preset) |id| if (id != 0) try ids.append(id);
    if (ids.items.len == 0) try ids.append(AvatarManager.getMcId());

    var lineup = try LineupManager.buildLineup(allocator, ids.items, null);
    lineup.index = index;
    if (index < default_lineup_names.len) {
        lineup.name = .{ .Const = default_lineup_names[@intCast(index)] };
    }
    lineup.leader_slot = leader_slot;
    return lineup;
}

pub fn onGetCurLineupData(session: *Session, _: *const Packet, allocator: Allocator) !void {
    const lineup = if (session.player_state) |*state| blk: {
        const idx = state.cur_lineup_index;
        break :blk try buildPresetLineup(allocator, state.lineups[@intCast(idx)], idx);
    } else blk: {
        var lineup_mgr = LineupManager.LineupManager.init(allocator);
        break :blk try lineup_mgr.createLineup();
    };
    try session.send(CmdID.CmdGetCurLineupDataScRsp, protocol.GetCurLineupDataScRsp{
        .retcode = 0,
        .lineup = lineup,
    });
}

pub fn onGetAllLineupData(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetAllLineupDataScRsp.init(allocator);
    rsp.retcode = 0;

    if (session.player_state) |*state| {
        rsp.cur_index = state.cur_lineup_index;
        var i: u32 = 0;
        while (i < MaxLineups) : (i += 1) {
            const lineup = try buildPresetLineup(allocator, state.lineups[@intCast(i)], i);
            try rsp.lineup_list.append(lineup);
        }
    } else {
        rsp.cur_index = 0;
        var lineup_mgr = LineupManager.LineupManager.init(allocator);
        const lineup = try lineup_mgr.createLineup();
        try rsp.lineup_list.append(lineup);
    }

    try session.send(CmdID.CmdGetAllLineupDataScRsp, rsp);
}

pub fn onSwitchLineupIndex(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.SwitchLineupIndexCsReq, allocator);
    defer req.deinit();

    var rsp = protocol.SwitchLineupIndexScRsp.init(allocator);
    rsp.index = req.index;

    if (session.player_state == null or req.index >= MaxLineups) {
        rsp.retcode = 1;
        try session.send(CmdID.CmdSwitchLineupIndexScRsp, rsp);
        return;
    }

    // Re-bind as pointer to the optional payload for safe mutation.
    if (session.player_state) |*st| {
        st.cur_lineup_index = req.index;

        // Update runtime selected lineup used across services.
        var ids = std.ArrayList(u32).init(allocator);
        defer ids.deinit();
        for (st.lineups[@intCast(req.index)]) |id| if (id != 0) try ids.append(id);
        try LineupManager.getSelectedAvatarID(allocator, ids.items);

        const lineup = try buildPresetLineup(allocator, st.lineups[@intCast(req.index)], req.index);
        var sync = protocol.SyncLineupNotify.init(allocator);
        sync.lineup = lineup;
        try session.send(CmdID.CmdSyncLineupNotify, sync);

        rsp.retcode = 0;
        try session.send(CmdID.CmdSwitchLineupIndexScRsp, rsp);

        try PlayerStateMod.save(st);
    }
}

pub fn onChangeLineupLeader(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.ChangeLineupLeaderCsReq, allocator);
    defer req.deinit();

    leader_slot = req.slot;
    try session.send(CmdID.CmdChangeLineupLeaderScRsp, protocol.ChangeLineupLeaderScRsp{
        .slot = req.slot,
        .retcode = 0,
    });
    // 自动保存玩家存档，记录最新的 leader / 选中编队
    if (session.player_state) |*state| {
        try PlayerStateMod.save(state);
    }
}

pub fn onReplaceLineup(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.ReplaceLineupCsReq, allocator);
    defer req.deinit();

    var idx: u32 = req.index;
    if (idx >= MaxLineups) idx = 0;

    if (session.player_state) |*state| {
        // Persist into preset slots (max 4).
        var preset: PlayerStateMod.LineupPreset = std.mem.zeroes(PlayerStateMod.LineupPreset);
        for (req.lineup_slot_list.items) |slot_data| {
            if (slot_data.slot < LineupSlots) preset[@intCast(slot_data.slot)] = slot_data.id;
        }
        state.lineups[@intCast(idx)] = preset;
        try PlayerStateMod.save(state);

        // If replacing current lineup, refresh runtime selected lineup + notify client.
        if (state.cur_lineup_index == idx) {
            var ids = std.ArrayList(u32).init(allocator);
            defer ids.deinit();
            for (preset) |id| if (id != 0) try ids.append(id);
            try LineupManager.getSelectedAvatarID(allocator, ids.items);
        }

        const lineup = try buildPresetLineup(allocator, state.lineups[@intCast(idx)], idx);
        var sync = protocol.SyncLineupNotify.init(allocator);
        sync.lineup = lineup;
        try session.send(CmdID.CmdSyncLineupNotify, sync);
    }

    try session.send(CmdID.CmdReplaceLineupScRsp, protocol.ReplaceLineupScRsp{
        .retcode = 0,
    });
}

pub fn onSetLineupName(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.SetLineupNameCsReq, allocator);
    defer req.deinit();

    try session.send(CmdID.CmdSetLineupNameScRsp, protocol.SetLineupNameScRsp{
        .index = req.index,
        .name = req.name,
        .retcode = 0,
    });
}
