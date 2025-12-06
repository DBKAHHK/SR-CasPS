const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const Data = @import("../data.zig");
const ConfigManager = @import("../manager/config_mgr.zig");
const Uid = @import("../utils/uid.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

// can change these id here for initial display
const SupportAvatar = [_]u32{
    1407, 1403, 1402,
};
const ListAvatar = [_]u32{
    1401, 1001, 1225, 1317, 1222,
};

pub fn onGetPhoneData(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetPhoneDataScRsp.init(allocator);
    rsp.retcode = 0;
    rsp.cur_chat_bubble = 0;
    rsp.cur_phone_theme = 0;
    rsp.cur_phone_case = 254001;
    try rsp.owned_chat_bubbles.appendSlice(&Data.OwnedChatBubbles);
    try rsp.owned_phone_themes.appendSlice(&Data.OwnedPhoneThemes);
    try rsp.owned_phone_cases.appendSlice(&Data.OwnedPhoneCases);
    try session.send(CmdID.CmdGetPhoneDataScRsp, rsp);
}
pub fn onSelectPhoneTheme(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.SelectPhoneThemeCsReq, allocator);
    defer req.deinit();

    var rsp = protocol.SelectPhoneThemeScRsp.init(allocator);
    rsp.retcode = 0;
    rsp.cur_phone_theme = req.theme_id;
    try session.send(CmdID.CmdSelectPhoneThemeScRsp, rsp);
}
pub fn onSelectChatBubble(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.SelectChatBubbleCsReq, allocator);
    defer req.deinit();

    var rsp = protocol.SelectChatBubbleScRsp.init(allocator);
    rsp.retcode = 0;
    rsp.cur_chat_bubble = req.bubble_id;
    try session.send(CmdID.CmdSelectChatBubbleScRsp, rsp);
}
pub fn onGetPlayerBoardData(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetPlayerBoardDataScRsp.init(allocator);
    var generator = Uid.BaseUidGen().init();
    var display_list = protocol.DisplayAvatarVec.init(allocator);
    const player_icon_config = &ConfigManager.global_game_config_cache.player_icon_config;
    display_list.is_display = true;
    rsp.retcode = 0;
    try rsp.unlocked_personal_card_list.appendSlice(&Data.OwnedPersonalCardSkin);
    rsp.current_personal_card_id = 253001;
    // 默认玩家头像 id（当 player_state/用户没有自己选择头像时使用）
    rsp.current_head_icon_id = 200139;
    rsp.head_frame_info = .{
        .head_frame_expire_time = 4294967295,
        .head_frame_item_id = 226004,
    };
    rsp.signature = .{ .Const = "" };
    try rsp.assist_avatar_id_list.appendSlice(&SupportAvatar);
    for (ListAvatar) |id| {
        var A_list = protocol.DisplayAvatarData.init(allocator);
        A_list.avatar_id = id;
        A_list.pos = generator.nextId();
        try display_list.display_avatar_list.append(A_list);
    }
    rsp.display_avatar_vec = display_list;
    for (player_icon_config.player_icon_config.items) |head_id| {
        const head_icon = protocol.HeadIconData{
            .id = head_id.id,
        };
        try rsp.unlocked_head_icon_list.append(head_icon);
    }
    try session.send(CmdID.CmdGetPlayerBoardDataScRsp, rsp);
}
pub fn onSetAssistAvatar(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.SetAssistAvatarCsReq, allocator);
    defer req.deinit();

    var rsp = protocol.SetAssistAvatarScRsp.init(allocator);
    rsp.retcode = 0;
    rsp.avatar_id = req.avatar_id;
    rsp.avatar_id_list = req.avatar_id_list;
    try session.send(CmdID.CmdSetAssistAvatarScRsp, rsp);
}
pub fn onSetDisplayAvatar(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.SetDisplayAvatarCsReq, allocator);
    defer req.deinit();

    var rsp = protocol.SetDisplayAvatarScRsp.init(allocator);
    rsp.retcode = 0;
    rsp.display_avatar_list = req.display_avatar_list;
    try session.send(CmdID.CmdSetDisplayAvatarScRsp, rsp);
}

pub fn onSetSignature(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.SetSignatureCsReq, allocator);
    defer req.deinit();

    var rsp = protocol.SetSignatureScRsp.init(allocator);
    rsp.retcode = 0;
    rsp.signature = req.signature;
    try session.send(CmdID.CmdSetSignatureScRsp, rsp);
}
pub fn onSetGameplayBirthday(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.SetGameplayBirthdayCsReq, allocator);
    defer req.deinit();

    var rsp = protocol.SetGameplayBirthdayScRsp.init(allocator);
    rsp.retcode = 0;
    rsp.birthday = req.birthday;
    try session.send(CmdID.CmdSetGameplayBirthdayScRsp, rsp);
}
pub fn onSetHeadIcon(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.SetHeadIconCsReq, allocator);
    defer req.deinit();

    var rsp = protocol.SetHeadIconScRsp.init(allocator);
    rsp.retcode = 0;
    rsp.current_head_icon_id = req.id;
    std.debug.print("SET HEAD ICON ID: {}\n", .{req.id});
    try session.send(CmdID.CmdSetHeadIconScRsp, rsp);
}
pub fn onSelectPhoneCase(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.SelectPhoneCaseCsReq, allocator);
    defer req.deinit();

    var rsp = protocol.SelectPhoneCaseScRsp.init(allocator);
    rsp.retcode = 0;
    rsp.cur_phone_case = req.phone_case_id;
    std.debug.print("SET PHONE CASE ID: {}\n", .{req.phone_case_id});
    try session.send(CmdID.CmdSelectPhoneCaseScRsp, rsp);
}
pub fn onUpdatePlayerSetting(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.UpdatePlayerSettingCsReq, allocator);
    defer req.deinit();

    try session.send(CmdID.CmdUpdatePlayerSettingScRsp, protocol.UpdatePlayerSettingScRsp{
        .player_setting = req.player_setting,
        .retcode = 0,
    });
}
pub fn onGetPlayerDetailInfo(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.GetPlayerDetailInfoCsReq, allocator);
    defer req.deinit();

    var rsp = protocol.GetPlayerDetailInfoScRsp.init(allocator);
    rsp.retcode = 0;
    var detail = protocol.PlayerDetailInfo.init(allocator);
    detail.head_frame_info = .{
        .head_frame_expire_time = 4294967295,
        .head_frame_item_id = 226004,
    };
    // 默认展示头像
    detail.head_icon = 200139;
    detail.uid = req.uid;
    detail.world_level = 6;
    detail.level = 70;
    rsp.detail_info = detail;
    try session.send(CmdID.CmdGetPlayerDetailInfoScRsp, rsp);
}
pub fn onSetPersonalCard(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.SetPersonalCardCsReq, allocator);
    defer req.deinit();

    try session.send(CmdID.CmdSetPersonalCardScRsp, protocol.SetPersonalCardScRsp{
        .current_personal_card_id = req.id,
        .retcode = 0,
    });
}
