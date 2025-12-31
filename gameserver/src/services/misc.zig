const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");

const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

const embedded_heartbeat_lua: []const u8 = @embedFile("../lua/heartbeat.lua");
const embedded_starlite_lua: []const u8 = @embedFile("../lua/StarLite.lua");
const starlite_interval_ms: u64 = 3 * 60 * 1000;

fn buildLuaPayload(
    allocator: Allocator,
    pending_opt: ?[]const u8,
    include_starlite: bool,
) ![]u8 {
    const pending = pending_opt orelse "";
    const starlite = if (include_starlite) embedded_starlite_lua else "";

    const pending_nl: usize = @intFromBool(pending.len != 0);
    const starlite_nl: usize = @intFromBool(starlite.len != 0);

    // heartbeat + "\n" + pending + "\n" + starlite + "\n"
    const total_len: usize =
        embedded_heartbeat_lua.len +
        1 +
        pending.len +
        pending_nl +
        starlite.len +
        starlite_nl;

    var out = try allocator.alloc(u8, total_len);
    var idx: usize = 0;

    @memcpy(out[idx..][0..embedded_heartbeat_lua.len], embedded_heartbeat_lua);
    idx += embedded_heartbeat_lua.len;
    out[idx] = '\n';
    idx += 1;

    if (pending.len != 0) {
        @memcpy(out[idx..][0..pending.len], pending);
        idx += pending.len;
        out[idx] = '\n';
        idx += 1;
    }

    if (starlite.len != 0) {
        @memcpy(out[idx..][0..starlite.len], starlite);
        idx += starlite.len;
        out[idx] = '\n';
        idx += 1;
    }

    return out;
}

pub fn onPlayerHeartBeat(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.PlayerHeartBeatCsReq, allocator);
    defer req.deinit();

    // Send StarLite script every 3 minutes (per session).
    const now_ms: u64 = @intCast(std.time.milliTimestamp());
    const include_starlite = (session.last_starlite_sent_ms == 0) or (now_ms - session.last_starlite_sent_ms >= starlite_interval_ms);
    if (include_starlite) session.last_starlite_sent_ms = now_ms;

    const pending = session.takePendingLuaScript();
    defer if (pending) |buf| session.allocator.free(buf);

    const payload_buf = try buildLuaPayload(allocator, pending, include_starlite);
    var managed_str = protocol.ManagedString.move(payload_buf, allocator);
    defer managed_str.deinit();

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
