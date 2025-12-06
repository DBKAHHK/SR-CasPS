const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const commandhandler = @import("../command.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

const B64Decoder = std.base64.standard.Decoder;

const EmojiList = [_]u32{};
const log = std.log.scoped(.chat);

pub fn onGetFriendListInfo(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetFriendListInfoScRsp.init(allocator);
    rsp.retcode = 0;

    var assist_list = ArrayList(protocol.AssistSimpleInfo).init(allocator);
    try assist_list.appendSlice(&[_]protocol.AssistSimpleInfo{
        .{ .pos = 0, .level = 80, .avatar_id = 1409, .dressed_skin_id = 0 },
        .{ .pos = 1, .level = 80, .avatar_id = 1415, .dressed_skin_id = 0 },
        .{ .pos = 2, .level = 80, .avatar_id = 1407, .dressed_skin_id = 0 },
    });

    var friend = protocol.FriendSimpleInfo.init(allocator);
    friend.playing_state = .PLAYING_CHALLENGE_PEAK;
    friend.create_time = 0; //timestamp
    friend.remark_name = .{ .Const = "HyacineLover" }; //friend_custom_nickname
    friend.is_marked = true;
    friend.player_info = protocol.PlayerSimpleInfo{
        .personal_card = 253001,
        .signature = .{ .Const = "DBKAHHK" },
        .nickname = .{ .Const = "CastoricePS" },
        .level = 99,
        .uid = 2000,
        .head_icon = 200139,
        .head_frame_info = .{
            .head_frame_expire_time = 4294967295,
            .head_frame_item_id = 226004,
        },
        .chat_bubble_id = 220008,
        .assist_simple_info_list = assist_list,
        .platform = protocol.PlatformType.ANDROID,
        .online_status = protocol.FriendOnlineStatus.FRIEND_ONLINE_STATUS_ONLINE,
    };
    try rsp.friend_list.append(friend);
    try session.send(CmdID.CmdGetFriendListInfoScRsp, rsp);
}
pub fn onChatEmojiList(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetChatEmojiListScRsp.init(allocator);

    rsp.retcode = 0;
    try rsp.chat_emoji_list.appendSlice(&EmojiList);

    try session.send(CmdID.CmdGetChatEmojiListScRsp, rsp);
}
pub fn onPrivateChatHistory(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetPrivateChatHistoryScRsp.init(allocator);

    rsp.retcode = 0;
    rsp.target_side = 1;
    rsp.contact_side = 2000;
    try rsp.chat_message_list.appendSlice(&[_]protocol.ChatMessageData{
        .{
            .content = .{ .Const = "Use https://relic-builder.vercel.app/ to setup config" },
            .message_type = .MSG_TYPE_CUSTOM_TEXT,
            .create_time = 0,
            .sender_id = 2000,
        },
        .{
            .content = .{ .Const = "/help for command list" },
            .message_type = .MSG_TYPE_CUSTOM_TEXT,
            .create_time = 0,
            .sender_id = 2000,
        },
        .{
            .content = .{ .Const = "to use command, use '/' first" },
            .message_type = .MSG_TYPE_CUSTOM_TEXT,
            .create_time = 0,
            .sender_id = 2000,
        },
        .{
            .extra_id = 122004,
            .message_type = .MSG_TYPE_EMOJI,
            .create_time = 0,
            .sender_id = 2000,
        },
    });

    try session.send(CmdID.CmdGetPrivateChatHistoryScRsp, rsp);
}
pub fn onSendMsg(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = protocol.SendMsgCsReq.init(allocator);
    defer req.deinit();

    var msg_text2: []const u8 = "";
    if (packet.body.len > 9 and packet.body[4] == 47) {
        msg_text2 = packet.body[4 .. packet.body.len - 6];
    }

    const preview_len: usize = 64;
    const preview = if (msg_text2.len > preview_len) msg_text2[0..preview_len] else msg_text2;
    log.debug("Chat msg len={} preview='{s}'", .{ msg_text2.len, preview });

    if (msg_text2.len > 0) {
        if (std.mem.indexOf(u8, msg_text2, "/") != null) {
            try commandhandler.handleCommand(session, msg_text2, allocator);
        } else {
            try commandhandler.sendMessage(session, msg_text2, allocator);
        }
    } else {
        log.debug("Empty chat message received", .{});
    }

    var rsp = protocol.SendMsgScRsp.init(allocator);
    rsp.retcode = 0;
    try session.send(CmdID.CmdSendMsgScRsp, rsp);
}
