const std = @import("std");

const Allocator = std.mem.Allocator;
const Reader = std.net.Stream.Reader;

const Self = @This();

cmd_id: u16,
head: []u8,
body: []u8,
allocator: Allocator,

const head_magic: u32 = 0x9D74C714;
const tail_magic: u32 = 0xD7A152C8;

pub const DecodeError = error{
    HeadMagicMismatch,
    TailMagicMismatch,
    PayloadTooBig,
};

pub fn read(reader: *Reader, allocator: Allocator) !Self {
    if (try reader.readInt(u32, .big) != Self.head_magic) {
        return Self.DecodeError.HeadMagicMismatch;
    }

    const cmd_id = try reader.readInt(u16, .big);
    const head_len = try reader.readInt(u16, .big);
    const body_len = try reader.readInt(u32, .big);

    if (body_len > 0xFFFFFF) {
        return Self.DecodeError.PayloadTooBig;
    }

    const head = try allocator.alloc(u8, head_len);
    errdefer allocator.free(head);

    const body = try allocator.alloc(u8, body_len);
    errdefer allocator.free(body);

    _ = try reader.readAll(head);
    _ = try reader.readAll(body);

    if (try reader.readInt(u32, .big) != Self.tail_magic) {
        return Self.DecodeError.TailMagicMismatch;
    }

    return .{
        .cmd_id = cmd_id,
        .head = head,
        .body = body,
        .allocator = allocator,
    };
}

pub fn getProto(self: *const Self, comptime T: type, allocator: Allocator) !T {
    return try T.decode(self.body, allocator);
}

pub fn encode(cmd_id: u16, head: []u8, body: []u8, allocator: Allocator) ![]u8 {
    var buf = try allocator.alloc(u8, 16 + head.len + body.len);

    std.mem.writeInt(u32, buf[0..4], Self.head_magic, .big);
    std.mem.writeInt(u16, buf[4..6], cmd_id, .big);
    std.mem.writeInt(u16, buf[6..8], @intCast(head.len), .big);
    std.mem.writeInt(u32, buf[8..12], @intCast(body.len), .big);
    @memcpy(buf[12..(12 + head.len)], head);
    @memcpy(buf[(12 + head.len)..(12 + head.len + body.len)], body);
    std.mem.writeInt(u32, buf[(12 + head.len + body.len)..][0..4], Self.tail_magic, .big);

    return buf;
}

pub fn deinit(self: *Self) void {
    self.allocator.free(self.head);
    self.allocator.free(self.body);
}
