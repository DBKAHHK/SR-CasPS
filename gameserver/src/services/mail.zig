const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const PlayerStateMod = @import("../player_state.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

const MailAttachment = struct { item_id: u32, num: u32 };
const StoredMail = struct {
    id: u32,
    sender: []const u8,
    title: []const u8,
    content: []const u8,
    is_read: bool = false,
    claimed: bool = false,
    time: i64,
    expire_time: i64,
    mail_type: protocol.MailType = protocol.MailType.MAIL_TYPE_STAR,
    attachments: []const MailAttachment = &.{},
};

const Mailbox = struct {
    mails: std.ArrayList(StoredMail),
};

var next_mail_id = std.atomic.Value(u32).init(1000);
var mailboxes: std.AutoHashMap(u32, Mailbox) = std.AutoHashMap(u32, Mailbox).init(std.heap.page_allocator);

fn mailboxForUid(uid: u32) *Mailbox {
    if (mailboxes.getPtr(uid)) |mb| return mb;
    const mb = Mailbox{ .mails = std.ArrayList(StoredMail).init(std.heap.page_allocator) };
    mailboxes.put(uid, mb) catch {};
    return mailboxes.getPtr(uid).?;
}

fn ensureDefaultMail(uid: u32) void {
    const mb = mailboxForUid(uid);
    if (mb.mails.items.len != 0) return;
    const now: i64 = @intCast(std.time.timestamp());
    mb.mails.append(.{
        .id = 1,
        .sender = "March 7th",
        .title = "Readme",
        .content = "CastoricePS is a free and open-source sofware\nJoin Discord.gg/dyn9NjBwzZ for more info.",
        .time = now,
        .expire_time = now + 365 * 24 * 3600,
        .attachments = &[_]MailAttachment{
            .{ .item_id = 1, .num = 10000 },
        },
    }) catch {};
}

fn toProtoMail(allocator: Allocator, m: StoredMail) !protocol.ClientMail {
    var mail = protocol.ClientMail.init(allocator);
    mail.id = m.id;
    mail.sender = .{ .Const = m.sender };
    mail.title = .{ .Const = m.title };
    mail.content = .{ .Const = m.content };
    mail.is_read = m.is_read;
    mail.time = m.time;
    mail.expire_time = m.expire_time;
    mail.mail_type = m.mail_type;

    var item_attachment = ArrayList(protocol.Item).init(allocator);
    for (m.attachments) |a| {
        try item_attachment.append(.{ .item_id = a.item_id, .num = a.num });
    }
    mail.attachment = .{ .item_list = item_attachment };
    return mail;
}

pub const PushMailArgs = struct {
    sender: []const u8,
    title: []const u8,
    content: []const u8,
    attachments: []const protocol.Item = &.{},
};

pub fn pushMail(uid: u32, args: PushMailArgs) !u32 {
    const mb = mailboxForUid(uid);
    ensureDefaultMail(uid);

    const id = next_mail_id.fetchAdd(1, .seq_cst);
    const now: i64 = @intCast(std.time.timestamp());

    var attachment_list = std.ArrayList(MailAttachment).init(std.heap.page_allocator);
    defer attachment_list.deinit();
    for (args.attachments) |it| {
        if (it.num == 0) continue;
        try attachment_list.append(.{ .item_id = it.item_id, .num = it.num });
    }

    const stored = StoredMail{
        .id = id,
        .sender = args.sender,
        .title = args.title,
        .content = try std.heap.page_allocator.dupe(u8, args.content),
        .time = now,
        .expire_time = now + 30 * 24 * 3600,
        .attachments = try std.heap.page_allocator.dupe(MailAttachment, attachment_list.items),
    };

    try mb.mails.append(stored);
    return id;
}

pub fn onGetMail(session: *Session, _: *const Packet, allocator: Allocator) !void {
    const uid: u32 = if (session.player_state) |st| st.uid else 1;
    ensureDefaultMail(uid);
    const mb = mailboxForUid(uid);

    var rsp = protocol.GetMailScRsp.init(allocator);
    rsp.total_num = @intCast(mb.mails.items.len);
    rsp.is_end = true;
    rsp.start = 0;
    rsp.retcode = 0;

    for (mb.mails.items) |m| {
        try rsp.mail_list.append(try toProtoMail(allocator, m));
    }

    try session.send(CmdID.CmdGetMailScRsp, rsp);
}

pub fn onTakeMailAttachment(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.TakeMailAttachmentCsReq, allocator);
    defer req.deinit();

    const uid: u32 = if (session.player_state) |st| st.uid else 1;
    ensureDefaultMail(uid);
    const mb = mailboxForUid(uid);

    var granted = ArrayList(protocol.Item).init(allocator);
    var succ_ids = ArrayList(u32).init(allocator);

    for (req.mail_id_list.items) |mail_id| {
        var found = false;
        for (mb.mails.items) |*m| {
            if (m.id != mail_id) continue;
            found = true;
            if (m.claimed) break;
            m.claimed = true;
            m.is_read = true;
            for (m.attachments) |a| {
                try granted.append(.{ .item_id = a.item_id, .num = a.num });
                if (session.player_state) |*state| {
                    try state.inventory.addMaterial(a.item_id, a.num);
                }
            }
            break;
        }
        if (found) try succ_ids.append(mail_id);
    }

    if (session.player_state) |*state| {
        try PlayerStateMod.save(state);
    }

    // Send item grant sync (best-effort).
    if (granted.items.len > 0) {
        var sync = protocol.PlayerSyncScNotify.init(allocator);
        for (granted.items) |it| {
            try sync.material_list.append(.{ .tid = it.item_id, .num = it.num });
        }
        try session.send(CmdID.CmdPlayerSyncScNotify, sync);
    }

    var rsp = protocol.TakeMailAttachmentScRsp.init(allocator);
    rsp.retcode = 0;
    rsp.succ_mail_id_list = succ_ids;
    if (granted.items.len > 0) {
        var list = protocol.ItemList.init(allocator);
        try list.item_list.appendSlice(granted.items);
        rsp.attachment = list;
    }
    try session.send(CmdID.CmdTakeMailAttachmentScRsp, rsp);
}
