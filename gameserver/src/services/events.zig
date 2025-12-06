const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const ConfigManager = @import("../manager/config_mgr.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

const activity_config = &ConfigManager.global_game_config_cache.activity_config;

pub fn onGetActivity(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetActivityScheduleConfigScRsp.init(allocator);
    var activ_list = protocol.ActivityScheduleData.init(allocator);
    //challenge mode pannel : 2100101
    for (activity_config.activity_config.items) |activityConf| {
        if (activityConf.panel_id != 30002) {
            activ_list.panel_id = activityConf.activity_id;
            for (activityConf.activity_module_list.items) |id| {
                activ_list.begin_time = 1664308800;
                activ_list.end_time = 4294967295;
                activ_list.activity_id = id;
                try rsp.schedule_data.append(activ_list);
            }
        }
    }
    rsp.retcode = 0;
    try session.send(CmdID.CmdGetActivityScheduleConfigScRsp, rsp);
}

pub fn onUpdateServerPrefsData(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.UpdateServerPrefsDataCsReq, allocator);
    defer req.deinit();
    try session.send(CmdID.CmdUpdateServerPrefsDataScRsp, protocol.UpdateServerPrefsDataScRsp{
        .retcode = 0,
        .server_prefs_id = req.server_prefs.?.server_prefs_id,
    });
}
