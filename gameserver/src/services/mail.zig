const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const ItemService = @import("item.zig");
const AvatarService = @import("avatar_service.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

const B64Decoder = std.base64.standard.Decoder;

pub fn onGetMail(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetMailScRsp.init(allocator);
    var item_attachment = ArrayList(protocol.Item).init(allocator);
    try item_attachment.appendSlice(&[_]protocol.Item{
        .{ .item_id = 1407, .num = 1 },
        .{ .item_id = 1321, .num = 1 },
        .{ .item_id = 1, .num = 10000 },
    });
    var mail = protocol.ClientMail.init(allocator);
    mail.sender = .{ .Const = "March 7th" };
    mail.title = .{ .Const = "Readme" };
    mail.is_read = false;
    mail.id = 1;
    mail.content = .{ .Const = "CastoricePS is a free and open-source sofware" };
    mail.time = 1723334400;
    mail.expire_time = 17186330890;
    mail.mail_type = protocol.MailType.MAIL_TYPE_STAR;
    mail.attachment = .{ .item_list = item_attachment };

    var mail_list = ArrayList(protocol.ClientMail).init(allocator);
    try mail_list.append(mail);

    rsp.total_num = 1;
    rsp.is_end = true;
    rsp.start = 0;
    rsp.retcode = 0;
    rsp.mail_list = mail_list;

    try session.send(CmdID.CmdGetMailScRsp, rsp);
}

pub fn onTakeMailAttachment(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.TakeMailAttachmentCsReq, allocator);
    defer req.deinit();
    var rsp = protocol.TakeMailAttachmentScRsp.init(allocator);
    rsp.retcode = 0;
    rsp.succ_mail_id_list = req.mail_id_list;
    try session.send(CmdID.CmdTakeMailAttachmentScRsp, rsp);
}
