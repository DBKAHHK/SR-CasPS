const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");

const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

const script = blk: {
    const encoded = "bG9jYWwgZnVuY3Rpb24gc2V0VGV4dENvbXBvbmVudChwYXRoLCBuZXdUZXh0KQogICAgbG9jYWwgb2JqID0gQ1MuVW5pdHlFbmdpbmUuR2FtZU9iamVjdC5GaW5kKHBhdGgpCiAgICBpZiBvYmogdGhlbgogICAgICAgIGxvY2FsIHRleHRDb21wb25lbnQgPSBvYmo6R2V0Q29tcG9uZW50SW5DaGlsZHJlbih0eXBlb2YoQ1MuUlBHLkNsaWVudC5Mb2NhbGl6ZWRUZXh0KSkKICAgICAgICBpZiB0ZXh0Q29tcG9uZW50IHRoZW4KICAgICAgICAgICAgdGV4dENvbXBvbmVudC50ZXh0ID0gbmV3VGV4dAogICAgICAgIGVuZAogICAgZW5kCmVuZAoKc2V0VGV4dENvbXBvbmVudCgKICAgICJVSVJvb3QvQWJvdmVEaWFsb2cvQmV0YUhpbnREaWFsb2coQ2xvbmUpIiwKICAgICI8Y29sb3I9I0ZGN0JFQT5DYXN0b3JpY2VQUyBpcyBhIGZyZWUgYW5kIG9wZW4gc291cmNlIHNvZnR3YXJlLjwvY29sb3I+IgopCgpzZXRUZXh0Q29tcG9uZW50KAogICAgIlZlcnNpb25UZXh0IiwKICAgICI8Y29sb3I9I0E2NzVGRj5IeWFjaW5lTG92ZXIgfCBCYXNlZCBvbiBEYWhsaWFTUiB8IERpc2NvcmQuZ2cvZHluOU5qQnd6WjwvY29sb3I+IgopCg==";
    const decoded_len = std.base64.standard.Decoder.calcSizeForSlice(encoded) catch unreachable;
    var decoded: [1024]u8 = undefined;
    _ = std.base64.standard.Decoder.decode(decoded[0..decoded_len], encoded) catch unreachable;
    break :blk decoded[0..decoded_len].*;
};

pub fn onPlayerHeartBeat(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.PlayerHeartBeatCsReq, allocator);
    defer req.deinit();
    const dest_buf = try allocator.dupe(u8, &script);
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
