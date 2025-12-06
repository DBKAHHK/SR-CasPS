const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const Data = @import("../data.zig");
const PlayerStateMod = @import("../player_state.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const CmdID = protocol.CmdID;

const content = [_]u32{
    200001, 200002, 200003, 200004, 200005, 200006, 200007, 200008,
    150017, 150015, 150021, 150018, 130011, 130012, 130013, 150025,
    140006, 150026, 130014, 150034, 150029, 150035, 150041, 150039,
    150045, 150057, 150042, 150067, 150064, 150063, 150024, 171002,
    150068, 150070, 150071,
};

pub fn onPlayerGetToken(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.PlayerGetTokenScRsp.init(allocator);

    rsp.retcode = 0;
    rsp.uid = 1;

    try session.send(CmdID.CmdPlayerGetTokenScRsp, rsp);
}

pub fn onPlayerLogin(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.PlayerLoginCsReq, allocator);
    defer req.deinit();

    const uid: u32 = 1; // 先写死一个 UID，和 onPlayerGetToken 保持一致

    // 从存档加载 / 创建
    const state = try PlayerStateMod.loadOrCreate(session.allocator, uid);
    session.player_state = state;

    var basic_info = protocol.PlayerBasicInfo.init(allocator);
    basic_info.stamina = state.stamina;
    basic_info.level = state.level;
    basic_info.nickname = .{ .Const = "HyacineLover" }; // 名字先写死
    basic_info.world_level = state.world_level;
    basic_info.mcoin = state.mcoin;
    basic_info.hcoin = state.hcoin;
    basic_info.scoin = state.scoin;

    var rsp = protocol.PlayerLoginScRsp.init(allocator);
    rsp.retcode = 0;
    rsp.login_random = req.login_random;
    rsp.stamina = state.stamina;
    rsp.basic_info = basic_info;

    try session.send(CmdID.CmdPlayerLoginScRsp, rsp);
}

pub fn onPlayerLoginFinish(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var package_data = protocol.ContentPackageData.init(allocator);
    package_data.cur_content_id = 0;
    for (content) |id| {
        try package_data.content_package_list.append(protocol.ContentPackageInfo{
            .content_id = id,
            .status = protocol.ContentPackageStatus.ContentPackageStatus_Finished,
        });
    }
    try session.send(CmdID.CmdContentPackageSyncDataScNotify, protocol.ContentPackageSyncDataScNotify{
        .data = package_data,
    });
    try session.send(CmdID.CmdPlayerLoginFinishScRsp, protocol.PlayerLoginFinishScRsp{
        .retcode = 0,
    });
}

pub fn onContentPackageGetData(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.ContentPackageGetDataScRsp.init(allocator);
    rsp.retcode = 0;
    var package_data = protocol.ContentPackageData.init(allocator);
    package_data.cur_content_id = 0;
    for (content) |id| {
        try package_data.content_package_list.append(protocol.ContentPackageInfo{
            .content_id = id,
            .status = protocol.ContentPackageStatus.ContentPackageStatus_Finished,
        });
    }
    try session.send(CmdID.CmdContentPackageGetDataScRsp, rsp);
}

pub fn onSetClientPaused(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.SetClientPausedCsReq, allocator);
    defer req.deinit();

    try session.send(CmdID.CmdSetClientPausedScRsp, protocol.SetClientPausedScRsp{
        .retcode = 0,
        .paused = req.paused,
    });
}

pub fn onGetArchiveData(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var data = protocol.ArchiveData.init(allocator);
    try data.archive_avatar_id_list.append(1321);
    try data.archive_missing_equipment_id_list.append(23000);
    try session.send(CmdID.CmdGetArchiveDataScRsp, protocol.GetArchiveDataScRsp{
        .retcode = 0,
        .archive_data = data,
    });
}
pub fn onGetUpdatedArchiveData(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var data = protocol.ArchiveData.init(allocator);
    try data.archive_avatar_id_list.append(1321);
    try data.archive_missing_equipment_id_list.append(23000);
    try session.send(CmdID.CmdGetUpdatedArchiveDataScRsp, protocol.GetUpdatedArchiveDataScRsp{
        .retcode = 0,
        .archive_data = data,
    });
}
