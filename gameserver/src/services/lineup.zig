const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const LineupManager = @import("../manager/lineup_mgr.zig");
const PlayerStateMod = @import("../player_state.zig");

const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

pub var leader_slot: u32 = 0;

pub fn onGetCurLineupData(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var lineup_mgr = LineupManager.LineupManager.init(allocator);
    const lineup = try lineup_mgr.createLineup();
    try session.send(CmdID.CmdGetCurLineupDataScRsp, protocol.GetCurLineupDataScRsp{
        .retcode = 0,
        .lineup = lineup,
    });
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

    var ids = std.ArrayList(u32).init(allocator);
    defer ids.deinit();

    for (req.lineup_slot_list.items) |ok| {
        try ids.append(ok.id);
    }
    const lineup = try LineupManager.buildLineup(allocator, ids.items, null);
    var rsp = protocol.SyncLineupNotify.init(allocator);
    rsp.lineup = lineup;
    try session.send(CmdID.CmdSyncLineupNotify, rsp);
    try session.send(CmdID.CmdReplaceLineupScRsp, protocol.ReplaceLineupScRsp{
        .retcode = 0,
    });
    // 替换编队（玩家操作），保存存档
    if (session.player_state) |*state| {
        try PlayerStateMod.save(state);
    }
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
