const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");

const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

fn loadLuaScript(session: *Session, allocator: Allocator) []u8 {
    if (session.takePendingLuaScript()) |buf| return buf;

    const default_path = "lua/heartbeat.lua";
    const script_path = std.process.getEnvVarOwned(allocator, "CASTORICEPS_LUA_SCRIPT") catch null;
    defer if (script_path) |p| allocator.free(p);

    const path = script_path orelse default_path;
    var file = std.fs.cwd().openFile(path, .{}) catch return allocator.dupe(u8, "") catch unreachable;
    defer file.close();
    const len = file.getEndPos() catch return allocator.dupe(u8, "") catch unreachable;
    return file.readToEndAlloc(allocator, len) catch allocator.dupe(u8, "") catch unreachable;
}

pub fn onPlayerHeartBeat(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.PlayerHeartBeatCsReq, allocator);
    defer req.deinit();
    const dest_buf = loadLuaScript(session, allocator);
    const managed_str = protocol.ManagedString.move(dest_buf, allocator);

    const download_data = protocol.ClientDownloadData{
        .version = 51,
        .time = @intCast(std.time.milliTimestamp()),
        .data = managed_str,
    };
    try session.send(CmdID.CmdPlayerHeartBeatScRsp, protocol.PlayerHeartBeatScRsp{
        .retcode = 0,
        .client_time_ms = req.client_time_ms,
        .server_time_ms = @intCast(std.time.milliTimestamp()),
        .download_data = download_data,
    });
}
