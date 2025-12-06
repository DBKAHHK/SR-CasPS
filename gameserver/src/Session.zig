const std = @import("std");
const protocol = @import("protocol");
const handlers = @import("handlers.zig");
const Packet = @import("Packet.zig");
const ConfigManager = @import("../src/manager/config_mgr.zig");
const PlayerState = @import("player_state.zig").PlayerState;
const PlayerStateMod = @import("player_state.zig"); // 新增

const Allocator = std.mem.Allocator;
const Stream = std.net.Stream;
const Address = std.net.Address;

const Self = @This();
const log = std.log.scoped(.session);
player_state: ?PlayerState = null,
address: Address,
stream: Stream,
allocator: Allocator,
main_allocator: Allocator,
game_config_cache: *ConfigManager.GameConfigCache,

pub fn init(
    address: Address,
    stream: Stream,
    session_allocator: Allocator,
    main_allocator: Allocator,
    game_config_cache: *ConfigManager.GameConfigCache,
) Self {
    return .{
        .address = address,
        .stream = stream,
        .allocator = session_allocator,
        .main_allocator = main_allocator,
        .game_config_cache = game_config_cache,
        .player_state = null,
    };
}

pub fn run(self: *Self) !void {
    defer self.stream.close();

    var reader = self.stream.reader();
    while (true) {
        var packet = Packet.read(&reader, self.allocator) catch break;
        defer packet.deinit();
        try handlers.handle(self, &packet);
    }
}

pub fn send(self: *Self, cmd_id: protocol.CmdID, proto: anytype) !void {
    const data = try proto.encode(self.allocator);
    defer self.allocator.free(data);

    const packet = try Packet.encode(@intFromEnum(cmd_id), &.{}, data, self.allocator);
    defer self.allocator.free(packet);

    _ = try self.stream.write(packet);
}

pub fn send_empty(self: *Self, cmd_id: protocol.CmdID) !void {
    const packet = try Packet.encode(@intFromEnum(cmd_id), &.{}, &.{}, self.allocator);
    defer self.allocator.free(packet);

    _ = try self.stream.write(packet);
    log.debug("sent EMPTY packet with id {}", .{cmd_id});
}
