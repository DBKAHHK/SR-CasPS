const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");

const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

const OwnedPet = [_]u32{ 251001, 251002, 251003 };

pub fn onGetPetData(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetPetDataScRsp.init(allocator);
    rsp.retcode = 0;
    rsp.cur_pet_id = 1003;
    try rsp.unlocked_pet_id.appendSlice(&OwnedPet);
    try session.send(CmdID.CmdGetPetDataScRsp, rsp);
}
pub fn onRecallPet(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.RecallPetCsReq, allocator);
    defer req.deinit();
    std.debug.print("REQUEST RECALL PET: {}\n", .{req.summoned_pet_id});
    try session.send(CmdID.CmdRecallPetScRsp, protocol.RecallPetScRsp{
        .retcode = 0,
        .cur_pet_id = req.summoned_pet_id,
        .select_pet_id = req.summoned_pet_id,
    });
}
pub fn onSummonPet(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.SummonPetCsReq, allocator);
    defer req.deinit();
    std.debug.print("REQUEST SUMMON PET: {}\n", .{req.summoned_pet_id});
    try session.send(CmdID.CmdCurPetChangedScNotify, protocol.CurPetChangedScNotify{
        .cur_pet_id = req.summoned_pet_id,
    });
    try session.send(CmdID.CmdSummonPetScRsp, protocol.SummonPetScRsp{
        .retcode = 0,
        .cur_pet_id = req.summoned_pet_id,
        .select_pet_id = req.summoned_pet_id,
    });
}
