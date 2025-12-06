const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const Data = @import("../data.zig");
const ConfigManager = @import("../manager/config_mgr.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

pub fn onGetMissionStatus(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.GetMissionStatusCsReq, allocator);
    defer req.deinit();

    var rsp = protocol.GetMissionStatusScRsp.init(allocator);
    const main_mission_config = &ConfigManager.global_game_config_cache.main_mission_config;
    rsp.retcode = 0;
    for (req.sub_mission_id_list.items) |id| {
        try rsp.sub_mission_status_list.append(protocol.Mission{ .id = id, .status = protocol.MissionStatus.MISSION_FINISH, .progress = 1 });
    }
    for (main_mission_config.main_mission_config.items) |main_missionConf| {
        try rsp.finished_main_mission_id_list.append(main_missionConf.main_mission_id);
        try rsp.curversion_finished_main_mission_id_list.append(main_missionConf.main_mission_id);
    }
    try session.send(CmdID.CmdGetMissionStatusScRsp, rsp);
}

pub fn onGetTutorialGuideStatus(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetTutorialGuideScRsp.init(allocator);
    const tutorial_guide_config = &ConfigManager.global_game_config_cache.tutorial_guide_config;
    rsp.retcode = 0;
    for (tutorial_guide_config.tutorial_guide_config.items) |guideConf| {
        try rsp.tutorial_guide_list.append(protocol.TutorialGuide{ .id = guideConf.guide_group_id, .status = protocol.TutorialStatus.TUTORIAL_FINISH });
    }

    try session.send(CmdID.CmdGetTutorialGuideScRsp, rsp);
}

pub fn onGetTutorialStatus(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetTutorialScRsp.init(allocator);
    const tutorial_guide_config = &ConfigManager.global_game_config_cache.tutorial_config;
    rsp.retcode = 0;
    for (tutorial_guide_config.tutorial_config.items) |tutorialConf| {
        try rsp.tutorial_list.append(protocol.Tutorial{ .id = tutorialConf.tutorial_id, .status = protocol.TutorialStatus.TUTORIAL_FINISH });
    }
    try session.send(CmdID.CmdGetTutorialScRsp, rsp);
}
pub fn onFinishTalkMission(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.FinishTalkMissionCsReq, allocator);
    defer req.deinit();

    var rsp = protocol.FinishTalkMissionScRsp.init(allocator);
    rsp.sub_mission_id = req.sub_mission_id;
    rsp.custom_value_list = req.custom_value_list;
    rsp.talk_str = req.talk_str;
    rsp.retcode = 0;
    try session.send(CmdID.CmdFinishTalkMissionScRsp, rsp);
}
pub fn onGetQuestData(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetQuestDataScRsp.init(allocator);
    const quest_config = &ConfigManager.global_game_config_cache.quest_config;
    for (quest_config.quest_config.items) |id| {
        var quest = protocol.Quest.init(allocator);
        quest.id = id.quest_id;
        quest.progress = 200;
        switch (id.quest_id) {
            2200503, 2200504, 2200505, 2200506 => quest.status = protocol.QuestStatus.QUEST_FINISH,
            else => quest.status = protocol.QuestStatus.QUEST_CLOSE,
        }
        try rsp.quest_list.append(quest);
    }
    rsp.retcode = 0;
    try session.send(CmdID.CmdGetQuestDataScRsp, rsp);
}
// added this to auto detect new tutorial guide id
pub fn onUnlockTutorialGuide(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.UnlockTutorialGuideCsReq, allocator);
    defer req.deinit();

    var rsp = protocol.UnlockTutorialGuideScRsp.init(allocator);
    rsp.retcode = 0;
    std.debug.print("UNLOCK TUTORIAL GUIDE ID: {}\n", .{req.group_id});
    try session.send(CmdID.CmdUnlockTutorialGuideScRsp, rsp);
}
// added this to auto detect new tutorial id
pub fn onUnlockTutorial(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.UnlockTutorialCsReq, allocator);
    defer req.deinit();

    var rsp = protocol.UnlockTutorialScRsp.init(allocator);
    rsp.retcode = 0;
    std.debug.print("UNLOCK TUTORIAL ID: {}\n", .{req.tutorial_id});
    try session.send(CmdID.CmdUnlockTutorialScRsp, rsp);
}
